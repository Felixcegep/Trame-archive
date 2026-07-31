import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class CompletedWorkoutPreparationTests: XCTestCase {
    func testInvalidWorkoutReturnsNilAndLeavesGraphUntouched() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Draft Lift", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        let set = ExerciseSet(orderIndex: 0, usedMetric: .metric)
        entry.sets = [set]
        let workout = Workout(name: "  Draft  ", endTime: nil)
        workout.notes = "  Keep this  "
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let originalEndTime = workout.endTime
        let originalStatus = workout.status
        let result = CompletedWorkoutPreparationService.prepare(workout, using: context)

        XCTAssertNil(result)
        XCTAssertEqual(workout.status, originalStatus)
        XCTAssertEqual(workout.endTime, originalEndTime)
        XCTAssertEqual(workout.name, "  Draft  ")
        XCTAssertEqual(workout.notes, "  Keep this  ")
        XCTAssertEqual(workout.orderedExercises.count, 1)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertFalse(set.done)

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertFalse(viewModel.saveWorkout(using: context))
        XCTAssertNil(viewModel.lastSavedSummary)
    }

    func testSummaryCountsPruningNormalizationAndExecutionBlockRetention() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Working Lift", primaryMuscles: [.upperChest])
        let emptyExercise = Exercise(name: "Never Started", primaryMuscles: [.latissimusDorsi])
        let blockedExercise = Exercise(name: "Block Member", primaryMuscles: [.quadriceps])

        let workingEntry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        workingEntry.sets = [
            ExerciseSet(repetitions: 8, weight: 100, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 0, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let emptyEntry = ExerciseEntry(exercise: emptyExercise, usedMetric: .metric)
        let blockedEntry = ExerciseEntry(exercise: blockedExercise, usedMetric: .metric)
        let keptBlock = WorkoutExecutionBlock(orderIndex: 0, kind: .circuit, restSeconds: 30)
        blockedEntry.executionBlockID = keptBlock.id
        blockedEntry.executionBlockComponentOrder = 0
        let emptyBlock = WorkoutExecutionBlock(orderIndex: 1, kind: .circuit, restSeconds: 30)

        let workout = Workout(name: "  Session Name  ", endTime: nil)
        workout.notes = "  Session notes  "
        workout.exercises = [workingEntry, emptyEntry, blockedEntry]
        workout.executionBlocks = [keptBlock, emptyBlock]
        context.insert(exercise)
        context.insert(emptyExercise)
        context.insert(blockedExercise)
        context.insert(workout)
        try context.save()

        let endTime = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = try XCTUnwrap(
            CompletedWorkoutPreparationService.prepare(workout, at: endTime, using: context)
        )

        XCTAssertEqual(summary.savedExerciseCount, 2)
        XCTAssertEqual(summary.savedSetCount, 1)
        XCTAssertEqual(summary.removedIncompleteSetCount, 1)
        XCTAssertEqual(summary.removedEmptyExerciseCount, 1)
        XCTAssertEqual(summary.removedEmptyBlockCount, 1)
        XCTAssertEqual(workout.name, "Session Name")
        XCTAssertEqual(workout.notes, "Session notes")
        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(workout.endTime, endTime)
        XCTAssertEqual(workout.orderedExecutionBlocks.count, 1)
        XCTAssertTrue(workout.orderedExercises.contains { $0 === blockedEntry })
        XCTAssertEqual(workingEntry.orderedSets.count, 1)
    }

    func testViewModelPublishesSummaryOnlyAfterSuccessfulSave() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Saved Lift", primaryMuscles: [.upperChest])
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 5, weight: 60, done: true, orderIndex: 0, usedMetric: .metric)
        ]
        let workout = Workout(name: "Saved", endTime: nil)
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertNil(viewModel.lastSavedSummary)
        XCTAssertTrue(viewModel.saveWorkout(using: context))
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(viewModel.lastSavedSummary?.savedExerciseCount, 1)
        XCTAssertEqual(viewModel.lastSavedSummary?.savedSetCount, 1)
    }
}
