import Foundation

/// Splits an exercise's sets into the two groups a lifter actually thinks in.
///
/// Warm-up sets are not small working sets. They are excluded from volume
/// (`ExerciseDetailAnalyticsService`), excluded from record eligibility
/// (`StrengthAnalyticsPolicy`), excluded from the prescribed set count
/// (`ActiveWorkoutRecommendationMutationService`), and generated as a ramp at a
/// percentage of the working load (`ProgramWarmupSnapshotter`). Everything in
/// the model already treats them as a different kind of thing; only the UI was
/// still listing them as rows 1 and 2 of one undifferentiated table, where the
/// only hint of their role was a "W (1)" subscript under the set number.
///
/// Keeping this as free functions over a plain array — rather than a method on
/// `ExerciseEntry` — means the grouping rule can be asserted without building a
/// SwiftData graph.
enum StageSetGrouping {
    enum Kind: Hashable {
        case warmUp
        case working
    }

    struct Group: Identifiable {
        let kind: Kind
        /// Sets in this group, in the exercise's own order.
        let sets: [ExerciseSet]
        /// The set's position in the *whole* exercise, needed because every
        /// downstream API (`SetRowView`, focus, accessibility identifiers,
        /// previous-performance lookup) indexes against the full list.
        let absoluteIndices: [Int]

        var id: Kind { kind }

        var completedCount: Int { sets.filter(\.done).count }
        var isComplete: Bool { !sets.isEmpty && completedCount == sets.count }

        /// Pairs each set with its index in the full exercise, which is what
        /// rows need to render and address themselves.
        var indexedSets: [(index: Int, set: ExerciseSet)] {
            zip(absoluteIndices, sets).map { (index: $0, set: $1) }
        }
    }

    /// Warm-ups first, then working sets. Empty groups are dropped, so an
    /// exercise with no warm-up renders exactly one section and no orphan
    /// heading.
    ///
    /// Partitioning rather than taking a leading run: warm-ups are inserted
    /// ahead of working sets by the snapshotter, but a lifter can add one at
    /// any position or retype an existing set as a warm-up mid-session, and a
    /// run-based split would silently drop those into the working group. Order
    /// *within* each group is preserved, so a partition never reorders work the
    /// lifter can see.
    static func groups(for sets: [ExerciseSet]) -> [Group] {
        var warmUpSets: [ExerciseSet] = []
        var warmUpIndices: [Int] = []
        var workingSets: [ExerciseSet] = []
        var workingIndices: [Int] = []

        for (index, set) in sets.enumerated() {
            if set.setType == .warmup {
                warmUpSets.append(set)
                warmUpIndices.append(index)
            } else {
                workingSets.append(set)
                workingIndices.append(index)
            }
        }

        var groups: [Group] = []
        if !warmUpSets.isEmpty {
            groups.append(Group(kind: .warmUp, sets: warmUpSets, absoluteIndices: warmUpIndices))
        }
        if !workingSets.isEmpty {
            groups.append(Group(kind: .working, sets: workingSets, absoluteIndices: workingIndices))
        }
        return groups
    }

    /// Whether the warm-up section should start collapsed.
    ///
    /// A finished ramp is history: it has told the lifter what it had to tell
    /// them, and leaving it expanded pushes the working sets — the reason they
    /// opened the page — below the fold. It only auto-collapses once *every*
    /// warm-up is logged, so a partially finished ramp stays visible.
    static func shouldCollapseWarmUp(_ groups: [Group]) -> Bool {
        groups.first { $0.kind == .warmUp }?.isComplete ?? false
    }
}
