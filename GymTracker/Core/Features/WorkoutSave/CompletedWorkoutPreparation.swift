import Foundation
import SwiftData

/// What preparing a workout for save actually did to the object graph.
///
/// The counts are the same ones the Review screen already promises the lifter
/// ("18 completed sets will be saved; 3 incomplete sets will be excluded"), so
/// after a save they can be reported back as fact rather than recomputed from
/// a graph that has since been pruned.
struct CompletedWorkoutSummary: Equatable {
    var savedExerciseCount: Int = 0
    var savedSetCount: Int = 0
    var removedIncompleteSetCount: Int = 0
    var removedEmptyExerciseCount: Int = 0
    var removedEmptyBlockCount: Int = 0
}

/// The graph work that turns an active workout into a completed one.
///
/// Extracted from `WorkoutViewModel.saveWorkout`, which previously interleaved
/// four separable concerns: validating, pruning the graph, advancing plan and
/// rotation progression, and committing. Pruning is the part with no
/// dependency on plans, Live Activities, or the view model's own lifecycle, so
/// it is the part that can be reasoned about — and characterized — on its own.
///
/// It is not pure in the functional sense: it mutates the SwiftData graph and
/// deletes children, which is the whole point. What it does provide is a
/// *described* result, so a test can assert exactly what was pruned and a
/// caller can report the counts without re-deriving them from the pruned
/// graph. `WorkoutCompletionTransaction` (RA-008) is expected to absorb this as
/// its preparation step.
///
/// Deliberately does **not** commit. The caller owns the transaction boundary,
/// because a rollback has to undo progression advancement as well as this
/// pruning, and only the caller knows about both.
enum CompletedWorkoutPreparationService {
    /// Prunes incomplete work and finalizes the workout's completed state.
    ///
    /// - Returns: a description of what was removed and kept, or `nil` when the
    ///   workout has no completed set. A `nil` return leaves the graph
    ///   **untouched** so an invalid save never damages a draft the lifter is
    ///   still working on.
    static func prepare(
        _ workout: Workout,
        at date: Date = .now,
        using modelContext: ModelContext
    ) -> CompletedWorkoutSummary? {
        // Validate before pruning anything.
        guard workout.completedSetCount > 0 else { return nil }

        var summary = CompletedWorkoutSummary()

        // Incomplete work is intentionally excluded from historical truth.
        // Removing a SwiftData relationship alone does not delete its model, so
        // each child is deleted explicitly.
        for exercise in workout.exercises {
            let incompleteSets = exercise.sets.filter { !$0.done }
            summary.removedIncompleteSetCount += incompleteSets.count
            exercise.sets.removeAll { !$0.done }
            for set in incompleteSets {
                modelContext.delete(set)
            }
            exercise.normalizeSetOrder()
        }

        // Added-but-never-started exercises do not belong in history. An empty
        // component entry inside an execution block is different: keeping it
        // preserves the intended circuit/complex membership when the lifter
        // saves a partial block.
        let emptyExercises = workout.exercises.filter {
            $0.sets.isEmpty && $0.executionBlockID == nil
        }
        summary.removedEmptyExerciseCount = emptyExercises.count
        workout.exercises.removeAll { exercise in
            emptyExercises.contains { $0.persistentModelID == exercise.persistentModelID }
        }
        for exercise in emptyExercises {
            modelContext.delete(exercise)
        }

        for block in workout.orderedExecutionBlocks {
            if WorkoutExecutionBlockService.entries(in: block, workout: workout).isEmpty {
                summary.removedEmptyBlockCount += 1
                workout.executionBlocks.removeAll { $0 === block }
                modelContext.delete(block)
            } else {
                WorkoutExecutionBlockService.finalizeForWorkoutSave(block, at: date)
            }
        }

        workout.name = normalized(workout.name)
        workout.notes = normalized(workout.notes)

        workout.normalizeExerciseOrder()
        workout.status = .completed
        workout.endTime = date
        workout.restEndDate = nil

        summary.savedExerciseCount = workout.exercises.count
        summary.savedSetCount = workout.exercises.reduce(0) { $0 + $1.sets.count }
        return summary
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
