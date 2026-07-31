import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class DuplicateWorkoutCompletionTests: XCTestCase {
    func testSecondSaveIsRejectedWithoutAdvancingOrDuplicatingHistory() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)
        completeFirstSet(in: workout)

        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        let cursorAfterFirstSave = fixture.run.currentSlotIndex
        let completedOccurrences = try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>())
            .filter { $0.status == .completed }
        let completedWorkouts = try fixture.context.fetch(FetchDescriptor<Workout>())
            .filter { $0.status == .completed }

        XCTAssertFalse(viewModel.saveWorkout(using: fixture.context))
        XCTAssertEqual(fixture.run.currentSlotIndex, cursorAfterFirstSave)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<RepeatingPlanOccurrence>())
                .filter { $0.status == .completed }.count,
            completedOccurrences.count
        )
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<Workout>())
                .filter { $0.status == .completed }.count,
            completedWorkouts.count
        )
        XCTAssertEqual(occurrence.status, .completed)
    }

    func testCompletedWorkoutIsNotRestoredAsActiveAfterRelaunch() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        completeFirstSet(in: workout)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))

        let relaunchContext = ModelContext(fixture.container)
        let relaunchedViewModel = WorkoutViewModel()
        XCTAssertFalse(relaunchedViewModel.restoreActiveWorkout(using: relaunchContext))
        XCTAssertNil(relaunchedViewModel.activeWorkout)
        XCTAssertEqual(
            try relaunchContext.fetch(FetchDescriptor<Workout>())
                .filter { $0.status == .completed }.count,
            1
        )
    }

    func testInvalidSaveLeavesActiveWorkoutAndProgressionUntouched() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let workout = try XCTUnwrap(viewModel.activeWorkout)
        let occurrence = try XCTUnwrap(fixture.run.orderedOccurrences.first)

        XCTAssertFalse(viewModel.saveWorkout(using: fixture.context))
        XCTAssertTrue(viewModel.activeWorkout === workout)
        XCTAssertEqual(workout.status, .active)
        XCTAssertEqual(occurrence.status, .inProgress)
        XCTAssertEqual(fixture.run.currentSlotIndex, 0)
        XCTAssertEqual(fixture.run.completedCycleCount, 0)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<Workout>())
                .filter { $0.status == .active }.count,
            1
        )
    }

    private func makeFixture() throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        let plan = RepeatingPlan(
            name: "Duplicate Completion Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        let run = try RepeatingPlanCoordinator.activate(plan)
        context.insert(run)
        try context.save()
        return Fixture(container: container, context: context, run: run)
    }

    private func completeFirstSet(in workout: Workout) {
        guard let set = workout.orderedExercises.first?.orderedSets.first else {
            XCTFail("Expected a snapshotted set")
            return
        }
        set.repetitions = 8
        set.weight = 50
        set.done = true
    }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let context: ModelContext
    let run: RepeatingPlanRun
}
