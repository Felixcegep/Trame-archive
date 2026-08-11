import Foundation

/// Historical, descriptive discipline evidence for one journey chapter.
///
/// The projection deliberately groups by both the frozen discipline and the
/// record vocabulary supplied by its frozen policy. A strongman carry and a
/// strongman hold are both strongman, but load-distance and load-duration are
/// not one compatible metric. Unknown snapshots remain a visible bucket rather
/// than being reclassified from the mutable Exercise relationship.
struct TrainingJourneyDisciplineDistribution: Equatable, Sendable {
    struct Slice: Identifiable, Equatable, Sendable {
        let id: String
        let discipline: SportDiscipline?
        let recordKinds: [SportRecordKind]
        let entryCount: Int
        let proportion: Double
        let evidence: [AnalyticsSourceReference]

        var isUnknown: Bool { discipline == nil }

        /// Stable navigation/digest identifiers for the performed evidence
        /// represented by this slice.
        var evidenceIDs: [String] { evidence.map(\.id) }
    }

    let totalEntryCount: Int
    let classifiedEntryCount: Int
    let unknownEntryCount: Int
    let slices: [Slice]

    var hasEvidence: Bool { totalEntryCount > 0 }

    static let empty = Self(
        totalEntryCount: 0,
        classifiedEntryCount: 0,
        unknownEntryCount: 0,
        slices: []
    )

    /// Reads only entries in completed workouts. `sportDisciplineSnapshotRaw`
    /// is intentionally inspected directly: the convenience accessor falls
    /// back to the live Exercise for legacy rows, which is unsafe for a
    /// historical distribution because a catalogue edit would rewrite it.
    static func project(workouts: [Workout]) -> Self {
        let completedWorkouts = workouts.filter(\.isCompleted)
        let evidence = completedWorkouts.flatMap { workout in
            workout.orderedExercises.map {
                EntryEvidence(workout: workout, entry: $0)
            }
        }
        guard evidence.isEmpty == false else { return .empty }

        var grouped: [GroupKey: [EntryEvidence]] = [:]
        for item in evidence {
            guard let raw = item.entry.sportDisciplineSnapshotRaw,
                  let discipline = SportDiscipline(rawValue: raw)
            else {
                grouped[.unknown, default: []].append(item)
                continue
            }

            let eventFamily = item.entry.strongmanEventFamilySnapshotRaw
                .flatMap(StrongmanEventFamily.init(rawValue:))
            let policy = SportAnalyticsPolicyResolver.policy(
                discipline: discipline,
                strongmanEventFamily: eventFamily
            )
            let recordKinds = policy.supportedRecords(for: item.entry)
                .sorted { $0.rawValue < $1.rawValue }
            grouped[GroupKey(discipline: discipline, recordKinds: recordKinds), default: []]
                .append(item)
        }

        let total = evidence.count
        let slices = grouped
            .map { key, items in
                let sortedEvidence = items
                    .map { AnalyticsSourceReference(workoutID: $0.workout.id, entryID: $0.entry.id) }
                    .sorted { $0.id < $1.id }
                return Slice(
                    id: key.id,
                    discipline: key.discipline,
                    recordKinds: key.recordKinds,
                    entryCount: items.count,
                    proportion: Double(items.count) / Double(total),
                    evidence: sortedEvidence
                )
            }
            .sorted { lhs, rhs in
                if lhs.isUnknown != rhs.isUnknown { return lhs.isUnknown == false }
                if lhs.entryCount != rhs.entryCount { return lhs.entryCount > rhs.entryCount }
                return lhs.id < rhs.id
            }

        let unknown = grouped[.unknown]?.count ?? 0
        return Self(
            totalEntryCount: total,
            classifiedEntryCount: total - unknown,
            unknownEntryCount: unknown,
            slices: slices
        )
    }

    private struct EntryEvidence {
        let workout: Workout
        let entry: ExerciseEntry
    }

    private struct GroupKey: Hashable {
        let discipline: SportDiscipline?
        let recordKinds: [SportRecordKind]

        static let unknown = Self(discipline: nil, recordKinds: [])

        var id: String {
            let disciplineID = discipline?.rawValue ?? "unknown"
            let metricID = recordKinds.map(\.rawValue).joined(separator: ",")
            return "\(disciplineID)|\(metricID)"
        }
    }
}
