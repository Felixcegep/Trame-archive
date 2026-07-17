import Foundation

/// The single deterministic source for the current set in every workout
/// surface. It preserves the legacy linear order for ungrouped exercises and
/// alternates grouped exercises by completed-round count.
@MainActor
enum WorkoutSetSelector {
    static func nextIncompleteSet(
        in workout: Workout
    ) -> (entry: ExerciseEntry, set: ExerciseSet)? {
        for entry in workout.orderedExercises {
            guard let set = entry.orderedSets.first(where: { !$0.done }) else { continue }

            guard entry.supersetGroupID != nil else {
                return (entry, set)
            }

            return nextIncompleteSet(in: groupMembers(of: entry, in: workout))
        }
        return nil
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
        guard nextIncompleteSet(in: workout) != nil else { return nil }

        guard entry.supersetGroupID != nil else {
            return max(0, entry.prescribedRestSeconds ?? defaultSeconds)
        }

        let members = groupMembers(of: entry, in: workout)
        let completedCount = entry.orderedSets.filter(\.done).count
        let nextRoundCount = members
            .filter { $0.orderedSets.contains(where: { !$0.done }) }
            .map { $0.orderedSets.filter(\.done).count }
            .min()

        // A member still behind the completed entry is due before rest.
        if let nextRoundCount, nextRoundCount < completedCount {
            return nil
        }

        let groupRest = members.compactMap(\.prescribedRestSeconds).max()
        return max(0, groupRest ?? defaultSeconds)
    }

    static func groupMembers(of entry: ExerciseEntry, in workout: Workout) -> [ExerciseEntry] {
        guard let groupID = entry.supersetGroupID else { return [entry] }
        return workout.orderedExercises.filter { $0.supersetGroupID == groupID }
    }

    private static func nextIncompleteSet(
        in members: [ExerciseEntry]
    ) -> (entry: ExerciseEntry, set: ExerciseSet)? {
        members
            .compactMap { entry -> (entry: ExerciseEntry, set: ExerciseSet, completed: Int)? in
                guard let set = entry.orderedSets.first(where: { !$0.done }) else { return nil }
                return (entry, set, entry.orderedSets.filter(\.done).count)
            }
            .sorted {
                $0.completed == $1.completed
                    ? $0.entry.orderIndex < $1.entry.orderIndex
                    : $0.completed < $1.completed
            }
            .first
            .map { ($0.entry, $0.set) }
    }
}
