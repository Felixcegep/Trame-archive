import SwiftData
import XCTest
@testable import GymTracker

/// An App Intent or Live Activity button executes in-process but constructs
/// its own `ModelContext` against the shared container (see
/// `ActiveWorkoutMutationService`'s doc comment). Before GT-02, nothing told
/// the root-owned `WorkoutViewModel` — bound to a different context — that a
/// mutation had landed, so the open Active Workout UI could keep showing
/// stale state until a relaunch. These tests simulate that two-context
/// scenario directly, without a live view hierarchy.
@MainActor
final class ActiveWorkoutCrossContextSyncTests: XCTestCase {
    /// Two sets, not one — completing the *only* set in a workout leaves
    /// nothing left to rest before, so `WorkoutSetSelector` legitimately
    /// starts no rest for that case. A second set is needed to exercise the
    /// rest-started path.
    private func makeWorkout(in context: ModelContext) -> Workout {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        let firstSet = ExerciseSet(repetitions: 8, weight: 100, orderIndex: 0, usedMetric: .metric)
        let secondSet = ExerciseSet(repetitions: 8, weight: 100, orderIndex: 1, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [firstSet, secondSet], usedMetric: .metric)
        let workout = Workout(name: "Cross-context workout")
        workout.exercises = [entry]
        context.insert(workout)
        return workout
    }

    func testOpenViewModelObservesACompletedSetMutationAppliedThroughASeparateContext() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let appContext = ModelContext(container)
        let intentContext = ModelContext(container)

        let workout = makeWorkout(in: appContext)
        try appContext.save()

        let workoutVM = WorkoutViewModel()
        XCTAssertTrue(workoutVM.restoreActiveWorkout(using: appContext))
        let boundEntry = try XCTUnwrap(workoutVM.activeWorkout?.exercises.first)
        XCTAssertFalse(try XCTUnwrap(boundEntry.orderedSets.first).done)

        let result = ActiveWorkoutMutationService(modelContext: intentContext)
            .completeCurrentSet(workoutID: workout.id, expectedExerciseOrderIndex: 0, expectedSetOrderIndex: 0)
        guard case .applied = result else {
            return XCTFail("Expected the intent-side mutation to apply")
        }

        // The root subscriber's job: refetch into the app-side context.
        XCTAssertTrue(workoutVM.handleExternalWorkoutChange(workoutID: workout.id, using: appContext))

        let reconciledEntry = try XCTUnwrap(workoutVM.activeWorkout?.exercises.first)
        XCTAssertTrue(try XCTUnwrap(reconciledEntry.orderedSets.first).done, "The completed set applied via a separate context must be visible after reconciliation.")
        XCTAssertNotNil(workoutVM.activeWorkout?.restEndDate, "Rest started by the intent-side mutation must also be visible.")
    }

    func testPausedRestAppliedThroughASeparateContextIsImmediatelyVisible() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let appContext = ModelContext(container)
        let intentContext = ModelContext(container)

        let workout = makeWorkout(in: appContext)
        workout.restEndDate = Date().addingTimeInterval(60)
        try appContext.save()

        let workoutVM = WorkoutViewModel()
        XCTAssertTrue(workoutVM.restoreActiveWorkout(using: appContext))

        let result = ActiveWorkoutMutationService(modelContext: intentContext).pauseRest(workoutID: workout.id)
        guard case .applied = result else {
            return XCTFail("Expected the pause to apply")
        }

        XCTAssertTrue(workoutVM.handleExternalWorkoutChange(workoutID: workout.id, using: appContext))
        XCTAssertNil(workoutVM.activeWorkout?.restEndDate)
        XCTAssertNotNil(workoutVM.activeWorkout?.pausedRemainingTime)
    }

    func testFailedIntentSideSaveNeverChangesTheAppSideViewModel() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let appContext = ModelContext(container)
        let intentContext = ModelContext(container)

        let workout = makeWorkout(in: appContext)
        try appContext.save()

        let workoutVM = WorkoutViewModel()
        XCTAssertTrue(workoutVM.restoreActiveWorkout(using: appContext))

        // A stale/invalid action (wrong expected indices) must not advance
        // any set, and must not report `.applied`.
        let result = ActiveWorkoutMutationService(modelContext: intentContext)
            .completeCurrentSet(workoutID: workout.id, expectedExerciseOrderIndex: 9, expectedSetOrderIndex: 9)
        guard case .stale = result else {
            return XCTFail("Expected a stale result for mismatched indices")
        }

        let entry = try XCTUnwrap(workoutVM.activeWorkout?.exercises.first)
        XCTAssertFalse(try XCTUnwrap(entry.orderedSets.first).done)
    }

    func testDiscardedWorkoutIsRemovedFromTheAppSideViewModelAfterReconciliation() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let appContext = ModelContext(container)
        let otherContext = ModelContext(container)

        let workout = makeWorkout(in: appContext)
        try appContext.save()

        let workoutVM = WorkoutViewModel()
        XCTAssertTrue(workoutVM.restoreActiveWorkout(using: appContext))

        // Simulate the workout being saved/discarded from elsewhere: it is
        // no longer `.active` once fetched from the other context.
        let otherWorkout = try XCTUnwrap(
            try otherContext.fetch(FetchDescriptor<Workout>()).first(where: { $0.id == workout.id })
        )
        otherWorkout.status = .completed
        otherWorkout.endTime = .now
        try otherContext.save()

        XCTAssertFalse(workoutVM.handleExternalWorkoutChange(workoutID: workout.id, using: appContext))
        XCTAssertNil(workoutVM.activeWorkout, "Once no active record remains, the view model must clear itself rather than keep showing stale state.")
    }
}
