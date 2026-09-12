import Foundation
import SwiftData

/// One screen of the Active Workout pager.
///
/// The old screen was a single scroll of collapsed cards, which meant the
/// lifter's actual subject — the exercise in front of them — competed for space
/// with seven others they were not doing. Paging makes the subject the page.
///
/// The cases are not simply "one page per exercise", because two of the app's
/// execution structures are *groups whose members interleave*:
///
/// - A **superset** alternates between members within a round
///   (`WorkoutFlowResolver.alternatingTarget`). Giving each member its own page
///   would make the current-set pointer jump pages between every set, which is
///   the opposite of what paging is for.
/// - An **execution block** (circuit, EMOM, AMRAP, complex…) owns a shared
///   clock, a shared round count, and one score. Splitting it across pages
///   would split the clock from the work it is timing.
///
/// So a page is "the unit of work you are currently inside", which is sometimes
/// one exercise and sometimes a group of them. A mid-session stretch is the
/// same idea: one movement between two exercises, not a second workout.
enum WorkoutStagePage: Hashable, Identifiable {
    /// A standalone exercise entry, addressed by its model identity.
    case exercise(PersistentIdentifier)
    /// Every member of one superset group, alternating on a single page.
    case superset(UUID)
    /// Every component of one execution block, under its shared clock.
    case block(UUID)
    /// One mid-session mobility movement, addressed by its `MobilitySession.id`.
    case mobility(UUID)
    /// The terminal page: session summary and the hand-off to review and save.
    case finish

    var id: String {
        switch self {
        case .exercise(let identifier): "exercise-\(identifier.hashValue)"
        case .superset(let groupID): "superset-\(groupID.uuidString)"
        case .block(let blockID): "block-\(blockID.uuidString)"
        case .mobility(let sessionID): "mobility-\(sessionID.uuidString)"
        case .finish: "finish"
        }
    }

    var isFinish: Bool {
        if case .finish = self { return true }
        return false
    }

    var isMobility: Bool {
        if case .mobility = self { return true }
        return false
    }
}

/// Where a mid-session stretch sits in the Active Workout pager.
///
/// Evidence stays on `MobilitySession`. This only answers "after which
/// exercise page should the stretch appear", so Bench → stretch → next
/// exercise is a real sequence rather than a takeover.
struct MidWorkoutMobilityStage: Equatable {
    let sessionID: UUID
    let name: String
    /// The exercise (or group) page the stretch was added from. `nil` when
    /// the stretch was added with no exercise yet, or after relaunch when
    /// that page is unknown.
    let afterPage: WorkoutStagePage?
    /// True when the stretch was added with no exercises yet, so lifts
    /// added afterwards follow it: stretch → Bench, not the reverse.
    let placesBeforeExercises: Bool
}

/// Builds and resolves the pager's page list.
///
/// Deliberately free of view state so the ordering rules can be tested without
/// a `View`: the pager is only correct if its pages stay in lockstep with
/// `WorkoutFlowResolver`'s idea of what comes next, and that agreement is worth
/// asserting directly.
@MainActor
enum WorkoutStagePlan {
    /// Document order, with grouped entries collapsed to a single page at the
    /// position of their first member, an optional mid-session stretch spliced
    /// after the exercise it was added from, and `.finish` appended last.
    ///
    /// A group emits its page where its *first* member sits rather than where
    /// the group is "declared", because `SupersetGrouping` only guarantees
    /// members are contiguous — there is no separate group record carrying an
    /// order of its own.
    static func pages(
        for workout: Workout,
        mobilityStage: MidWorkoutMobilityStage? = nil
    ) -> [WorkoutStagePage] {
        var pages: [WorkoutStagePage] = []
        var seenBlocks: Set<UUID> = []
        var seenSupersets: Set<UUID> = []

        for entry in workout.orderedExercises {
            // Block membership outranks superset membership: a block already
            // describes how its components interleave, and an entry carrying
            // both would otherwise appear on two pages.
            if let blockID = entry.executionBlockID {
                guard seenBlocks.insert(blockID).inserted else { continue }
                pages.append(.block(blockID))
            } else if let groupID = entry.supersetGroupID {
                guard seenSupersets.insert(groupID).inserted else { continue }
                pages.append(.superset(groupID))
            } else {
                pages.append(.exercise(entry.persistentModelID))
            }
        }

        if let mobilityStage {
            let mobilityPage = WorkoutStagePage.mobility(mobilityStage.sessionID)
            pages.insert(mobilityPage, at: insertIndex(for: mobilityStage, in: pages, workout: workout))
        }

        pages.append(.finish)
        return pages
    }

    /// After the named exercise page when that page still exists; otherwise
    /// after the last completed work page, or after the first page when the
    /// session is still untouched. An empty workout puts the stretch first.
    private static func insertIndex(
        for stage: MidWorkoutMobilityStage,
        in pages: [WorkoutStagePage],
        workout: Workout
    ) -> Int {
        if stage.placesBeforeExercises {
            return 0
        }
        if let afterPage = stage.afterPage, let index = pages.firstIndex(of: afterPage) {
            return index + 1
        }
        var lastComplete = -1
        for (index, page) in pages.enumerated() {
            if progress(of: page, in: workout) == .complete {
                lastComplete = index
            }
        }
        if lastComplete >= 0 { return lastComplete + 1 }
        return pages.isEmpty ? 0 : 1
    }

    /// The entries a page is responsible for, in document order. Empty for
    /// `.finish`, and empty for a group whose members have all been removed —
    /// which is exactly when the page should stop being rendered.
    static func entries(for page: WorkoutStagePage, in workout: Workout) -> [ExerciseEntry] {
        switch page {
        case .exercise(let identifier):
            return workout.orderedExercises.filter { $0.persistentModelID == identifier }
        case .superset(let groupID):
            return workout.orderedExercises.filter { $0.supersetGroupID == groupID }
        case .block(let blockID):
            return workout.orderedExercises.filter { $0.executionBlockID == blockID }
        case .mobility, .finish:
            return []
        }
    }

    /// The page an entry lives on. Used to follow the flow resolver: when the
    /// next incomplete set moves to another exercise, the pager turns to
    /// whichever page owns it.
    static func page(containing entry: ExerciseEntry) -> WorkoutStagePage {
        if let blockID = entry.executionBlockID { return .block(blockID) }
        if let groupID = entry.supersetGroupID { return .superset(groupID) }
        return .exercise(entry.persistentModelID)
    }

    /// Off-screen pager pages must not steal the visible stage. A focused set
    /// is accepted only when it lives on the page already on screen.
    static func acceptsFocus(
        on focusedPage: WorkoutStagePage,
        whileShowing visiblePage: WorkoutStagePage
    ) -> Bool {
        focusedPage == visiblePage
    }

    /// The next unfinished page in document order. An active stretch counts as
    /// unfinished work at the slot it was inserted into, so completing Bench
    /// lands on the stretch instead of skipping to the next lift.
    static func currentPage(
        in workout: Workout,
        mobilityStage: MidWorkoutMobilityStage? = nil
    ) -> WorkoutStagePage {
        let ordered = pages(for: workout, mobilityStage: mobilityStage)
        for page in ordered where page.isFinish == false {
            if page.isMobility { return page }
            if entries(for: page, in: workout).contains(where: { entry in
                entry.orderedSets.contains { !$0.done }
            }) {
                return page
            }
        }
        return .finish
    }

    /// Completion state of a page, for the segmented progress rail.
    enum Progress: Hashable {
        /// Nothing logged yet.
        case untouched
        /// Some sets logged, some outstanding.
        case started
        /// Every set logged.
        case complete
    }

    static func progress(of page: WorkoutStagePage, in workout: Workout) -> Progress {
        if case .mobility = page { return .started }
        let sets = entries(for: page, in: workout).flatMap(\.orderedSets)
        guard !sets.isEmpty else { return .untouched }
        let completed = sets.filter(\.done).count
        if completed == 0 { return .untouched }
        return completed == sets.count ? .complete : .started
    }
}
