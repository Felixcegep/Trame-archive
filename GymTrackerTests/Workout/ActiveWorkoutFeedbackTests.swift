import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ActiveWorkoutFeedbackTests: XCTestCase {
    func testRestCompletionCountIncrementsExactlyOnceAtTheDeadline() async throws {
        let fixture = try makeFixture()
        let active = ActiveWorkoutViewModel(workoutVM: fixture.viewModel, modelContext: fixture.context)
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .straight, restSeconds: 1)
        fixture.workout.executionBlocks = [block]
        try fixture.context.save()

        active.startRest(after: block)
        try await Task.sleep(for: .milliseconds(1_250))

        XCTAssertEqual(active.restCompletionCount, 1)
        XCTAssertTrue(active.isRestReady)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(active.restCompletionCount, 1)
    }

    func testExpiredPersistedRestBecomesReadyWithoutCompletionEvent() throws {
        let fixture = try makeFixture()
        fixture.workout.restEndDate = Date(timeIntervalSinceNow: -1)
        try fixture.context.save()
        let active = ActiveWorkoutViewModel(workoutVM: fixture.viewModel, modelContext: fixture.context)

        active.restorePersistedRestTimer()

        XCTAssertTrue(active.isRestReady)
        XCTAssertEqual(active.restCompletionCount, 0)
    }

    func testPauseResumeExtendAndCancelDoNotEmitCompletionEvent() throws {
        let fixture = try makeFixture()
        let active = ActiveWorkoutViewModel(workoutVM: fixture.viewModel, modelContext: fixture.context)
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .straight, restSeconds: 60)
        fixture.workout.executionBlocks = [block]
        try fixture.context.save()

        active.startRest(after: block)
        active.pauseTimer()
        active.resumeTimer()
        active.addRestTime(15)
        active.cancelTimer()

        XCTAssertEqual(active.restCompletionCount, 0)
    }

    func testFixtureLoadWithoutPersistedRestIsSilent() throws {
        let fixture = try makeFixture()
        let active = ActiveWorkoutViewModel(workoutVM: fixture.viewModel, modelContext: fixture.context)

        active.restorePersistedRestTimer()

        XCTAssertEqual(active.restCompletionCount, 0)
        XCTAssertFalse(active.isRestReady)
    }

    private func makeFixture() throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = Exercise(name: "Feedback Lift", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 8, weight: 50, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 0, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let workout = Workout(name: "Feedback Workout")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()
        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        return Fixture(context: context, workout: workout, viewModel: viewModel)
    }
}

@MainActor
private struct Fixture {
    let context: ModelContext
    let workout: Workout
    let viewModel: WorkoutViewModel
}
