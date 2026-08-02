import Foundation

/// The single deterministic source for the current set in every workout
/// surface. It preserves the legacy linear order for ungrouped exercises and
/// alternates grouped exercises by completed-round count.
@MainActor
enum WorkoutSetSelector {
    static func nextIncompleteSet(
        in workout: Workout
    ) -> (entry: ExerciseEntry, set: ExerciseSet)? {
        let adapter = Adapter(workout: workout)
        guard let target = WorkoutFlowResolver.currentTarget(in: adapter.snapshot),
              let entry = adapter.entries[target.entryID],
              let set = entry.orderedSets.first(where: { $0.id == target.setID })
        else { return nil }
        return (entry, set)
    }

    /// Call after the set has been marked complete. The result is the entry
    /// that should be disclosed next, including the next member of a superset.
    static func nextEntry(afterCompleting entry: ExerciseEntry, in workout: Workout) -> ExerciseEntry? {
        nextIncompleteSet(in: workout)?.entry
    }

    /// Returns nil when the next set is another member's turn in the current
    /// round or when the workout is complete. A non-nil result is the rest
    /// duration that should begin after this completion.
    static func restSeconds(
        afterCompleting entry: ExerciseEntry,
        in workout: Workout,
        defaultSeconds: Int
    ) -> Int? {
        let adapter = Adapter(workout: workout)
        guard let entryID = adapter.ids[ObjectIdentifier(entry)] else { return nil }
        let result = WorkoutFlowResolver.resolve(
            WorkoutFlowContext(
                workout: adapter.snapshot,
                completedEntryID: entryID,
                completedSetID: nil,
                defaultRestSeconds: defaultSeconds
            )
        )
        guard case let .transition(transition) = result else { return nil }
        guard case let .rest(seconds) = transition.restDirective else { return nil }
        return seconds
    }

    /// Resolves the full post-completion transition for a concrete performed
    /// set. This is the mutation workflow's bridge into the pure resolver;
    /// presentation callers that only need a duration keep using
    /// `restSeconds(afterCompleting:in:defaultSeconds:)`.
    static func transition(
        afterCompleting set: ExerciseSet,
        in entry: ExerciseEntry,
        workout: Workout,
        defaultSeconds: Int
    ) -> WorkoutTransition? {
        let adapter = Adapter(workout: workout)
        guard let entryID = adapter.ids[ObjectIdentifier(entry)] else { return nil }
        let result = WorkoutFlowResolver.resolve(
            WorkoutFlowContext(
                workout: adapter.snapshot,
                completedEntryID: entryID,
                completedSetID: set.id,
                defaultRestSeconds: defaultSeconds
            )
        )
        guard case .transition(let transition) = result else { return nil }
        return transition
    }

    static func groupMembers(of entry: ExerciseEntry, in workout: Workout) -> [ExerciseEntry] {
        guard let groupID = entry.supersetGroupID else { return [entry] }
        return workout.orderedExercises.filter { $0.supersetGroupID == groupID }
    }

    private struct Adapter {
        let snapshot: WorkoutFlowSnapshot
        let entries: [WorkoutFlowEntryID: ExerciseEntry]
        let ids: [ObjectIdentifier: WorkoutFlowEntryID]

        init(workout: Workout) {
            let ordered = workout.orderedExercises
            var mappedEntries: [WorkoutFlowEntryID: ExerciseEntry] = [:]
            var mappedIDs: [ObjectIdentifier: WorkoutFlowEntryID] = [:]
            let snapshots = ordered.enumerated().map { occurrence, entry in
                let id = WorkoutFlowEntryID(orderIndex: entry.orderIndex, orderedOccurrence: occurrence)
                mappedEntries[id] = entry
                mappedIDs[ObjectIdentifier(entry)] = id
                return WorkoutFlowEntrySnapshot(
                    id: id,
                    orderIndex: entry.orderIndex,
                    supersetGroupID: entry.supersetGroupID,
                    prescribedRestSeconds: entry.prescribedRestSeconds,
                    sets: entry.orderedSets.map {
                        WorkoutFlowSetSnapshot(id: $0.id, orderIndex: $0.orderIndex, isCompleted: $0.done)
                    }
                )
            }
            snapshot = WorkoutFlowSnapshot(entries: snapshots)
            entries = mappedEntries
            ids = mappedIDs
        }
    }
}
