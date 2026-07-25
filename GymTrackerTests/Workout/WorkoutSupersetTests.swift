import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutSupersetTests: XCTestCase {
    func testSupersetSelectorAlternatesUnevenSetsAndStartsRestAfterRounds() throws {
        let exerciseA = makeExercise()
        let exerciseB = Exercise(name: "Cable Row", primaryMuscles: [.latissimusDorsi])
        let groupID = UUID()
        let entryA = ExerciseEntry(
            exercise: exerciseA,
            sets: [
                ExerciseSet(repetitions: 8, usedMetric: .metric),
                ExerciseSet(repetitions: 8, usedMetric: .metric),
                ExerciseSet(repetitions: 8, usedMetric: .metric)
            ],
            orderIndex: 0,
            usedMetric: .metric,
            supersetGroupID: groupID
        )
        entryA.prescribedRestSeconds = 60
        let entryB = ExerciseEntry(
            exercise: exerciseB,
            sets: [
                ExerciseSet(repetitions: 10, usedMetric: .metric),
                ExerciseSet(repetitions: 10, usedMetric: .metric)
            ],
            orderIndex: 1,
            usedMetric: .metric,
            supersetGroupID: groupID
        )
        entryB.prescribedRestSeconds = 90
        let workout = Workout(name: "Superset")
        workout.exercises = [entryA, entryB]

        XCTAssertTrue(WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry === entryA)
        entryA.orderedSets[0].done = true
        XCTAssertTrue(WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry === entryB)
        XCTAssertNil(WorkoutSetSelector.restSeconds(afterCompleting: entryA, in: workout, defaultSeconds: 30))

        entryB.orderedSets[0].done = true
        XCTAssertTrue(WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry === entryA)
        XCTAssertEqual(
            WorkoutSetSelector.restSeconds(afterCompleting: entryB, in: workout, defaultSeconds: 30),
            90
        )

        entryA.orderedSets[1].done = true
        XCTAssertTrue(WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry === entryB)
        XCTAssertNil(WorkoutSetSelector.restSeconds(afterCompleting: entryA, in: workout, defaultSeconds: 30))

        entryB.orderedSets[1].done = true
        XCTAssertTrue(WorkoutSetSelector.nextIncompleteSet(in: workout)?.entry === entryA)
        XCTAssertEqual(
            WorkoutSetSelector.restSeconds(afterCompleting: entryB, in: workout, defaultSeconds: 30),
            90
        )

        entryA.orderedSets[2].done = true
        XCTAssertNil(WorkoutSetSelector.nextIncompleteSet(in: workout))
        XCTAssertNil(WorkoutSetSelector.restSeconds(afterCompleting: entryA, in: workout, defaultSeconds: 30))
    }

    func testActiveWorkoutViewModelOnlyOffersTheSelectorCurrentSupersetSet() throws {
        let context = try makeContext()
        let exerciseA = makeExercise()
        let exerciseB = Exercise(name: "Cable Row", primaryMuscles: [.latissimusDorsi])
        let groupID = UUID()
        let entryA = ExerciseEntry(
            exercise: exerciseA,
            sets: [ExerciseSet(repetitions: 8, weight: 50, usedMetric: .metric)],
            orderIndex: 0,
            usedMetric: .metric,
            supersetGroupID: groupID
        )
        let entryB = ExerciseEntry(
            exercise: exerciseB,
            sets: [ExerciseSet(repetitions: 8, weight: 50, usedMetric: .metric)],
            orderIndex: 1,
            usedMetric: .metric,
            supersetGroupID: groupID
        )
        let workout = Workout(name: "Superset")
        workout.exercises = [entryA, entryB]
        context.insert(exerciseA)
        context.insert(exerciseB)
        context.insert(workout)
        try context.save()
        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        let viewModel = ActiveWorkoutViewModel(
            workoutVM: workoutViewModel,
            modelContext: context
        )

        XCTAssertTrue(viewModel.getNextSet(in: entryA) === entryA.orderedSets.first)
        XCTAssertNil(viewModel.getNextSet(in: entryB))

        entryA.orderedSets.first?.done = true

        XCTAssertNil(viewModel.getNextSet(in: entryA))
        XCTAssertTrue(viewModel.getNextSet(in: entryB) === entryB.orderedSets.first)
    }

    func testSupersetNormalizationDissolvesSingletonAndNonContiguousGroups() {
        let exercise = makeExercise()
        let groupID = UUID()
        let first = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric, supersetGroupID: groupID)
        let middle = ExerciseEntry(exercise: exercise, orderIndex: 1, usedMetric: .metric)
        let last = ExerciseEntry(exercise: exercise, orderIndex: 2, usedMetric: .metric, supersetGroupID: groupID)
        let workout = Workout(name: "Invalid superset")
        workout.exercises = [first, middle, last]

        workout.normalizeExerciseOrder()

        XCTAssertNil(first.supersetGroupID)
        XCTAssertNil(last.supersetGroupID)
    }

    func testRemovingSupersetMemberDissolvesTheRemainingSingleton() {
        let exercise = makeExercise()
        let groupID = UUID()
        let first = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric, supersetGroupID: groupID)
        let second = ExerciseEntry(exercise: exercise, orderIndex: 1, usedMetric: .metric, supersetGroupID: groupID)
        let workout = Workout(name: "Superset")
        workout.exercises = [first, second]

        second.supersetGroupID = nil
        workout.normalizeExerciseOrder()

        XCTAssertNil(first.supersetGroupID)
        XCTAssertNil(second.supersetGroupID)
    }

    func testTemplateWorkoutSnapshotUsesFreshSupersetIdentity() throws {
        let exerciseA = makeExercise()
        let exerciseB = Exercise(name: "Cable Row", primaryMuscles: [.latissimusDorsi])
        let templateGroupID = UUID()
        let template = WorkoutTemplate(
            name: "Template superset",
            exercises: [exerciseA, exerciseB],
            templateExercises: [
                TemplateExercise(exercise: exerciseA, order: 0, supersetGroupID: templateGroupID),
                TemplateExercise(exercise: exerciseB, order: 1, supersetGroupID: templateGroupID)
            ]
        )

        let firstWorkout = Workout(template: template, unitSystem: .metric)
        let secondWorkout = Workout(template: template, unitSystem: .metric)
        let firstGroupID = try XCTUnwrap(firstWorkout.orderedExercises.first?.supersetGroupID)
        let secondGroupID = try XCTUnwrap(secondWorkout.orderedExercises.first?.supersetGroupID)

        XCTAssertEqual(firstWorkout.orderedExercises.map(\.supersetGroupID), [firstGroupID, firstGroupID])
        XCTAssertNotEqual(firstGroupID, templateGroupID)
        XCTAssertNotEqual(firstGroupID, secondGroupID)
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    private func makeExercise() -> Exercise {
        WorkoutTestFixture.makeExercise()
    }
}
