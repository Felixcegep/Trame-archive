import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutOrderingAndMutationTests: XCTestCase {
    func testOrderedViewsUsePersistedIndicesAcrossTemplateWorkoutAndSets() throws {
        let context = try makeContext()
        let first = Exercise(name: "First", primaryMuscles: [.upperChest])
        let second = Exercise(name: "Second", primaryMuscles: [.latissimusDorsi])
        let third = Exercise(name: "Third", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(
            name: "Ordered Template",
            exercises: [first, second, third],
            templateExercises: [
                TemplateExercise(exercise: first, order: 2),
                TemplateExercise(exercise: second, order: 0),
                TemplateExercise(exercise: third, order: 1)
            ]
        )

        XCTAssertEqual(template.orderedTemplateExercises.map { $0.exercise.name }, ["Second", "Third", "First"])
        XCTAssertEqual(template.exercises.map(\.name), ["Second", "Third", "First"])

        let workout = Workout(template: template, unitSystem: .metric)
        XCTAssertEqual(workout.orderedExercises.map { $0.exercise.name }, ["Second", "Third", "First"])

        let entry = try XCTUnwrap(workout.orderedExercises.first)
        let late = ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 2, usedMetric: .metric)
        let early = ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric)
        let middle = ExerciseSet(repetitions: 10, weight: 50, done: true, orderIndex: 1, usedMetric: .metric)
        entry.sets = [late, early, middle]

        context.insert(first)
        context.insert(second)
        context.insert(third)
        context.insert(template)
        context.insert(workout)
        try context.save()

        XCTAssertEqual(entry.orderedSets.map(\.repetitions), [8, 10, 12])
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2])
    }

    func testAddingCopyingAndDeletingSetsKeepsContiguousOrderIndices() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 8, weight: 40, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 10, weight: 50, done: true, orderIndex: 1, usedMetric: .metric),
            ExerciseSet(repetitions: 12, weight: 60, done: true, orderIndex: 2, usedMetric: .metric)
        ]
        let workout = Workout(name: "Set Ordering")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        entry.copyLastSet()
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertEqual(entry.orderedSets.last?.repetitions, 12)
        XCTAssertFalse(entry.orderedSets.last?.done == true)

        entry.addEmptySet()
        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3, 4])

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        let activeViewModel = ActiveWorkoutViewModel(workoutVM: viewModel, modelContext: context)
        let middle = try XCTUnwrap(entry.orderedSets[1])
        activeViewModel.removeSet(entry, middle)

        XCTAssertEqual(entry.orderedSets.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertEqual(entry.orderedSets.map(\.repetitions), [8, 12, 12, 0])
    }

    func testSwappingUnstartedExerciseResetsSetsAndRefreshesSnapshots() throws {
        let context = try makeContext()
        let source = Exercise(name: "Barbell Bench Press", primaryMuscles: [.middleChest])
        let replacement = Exercise(
            name: "Row Ergometer",
            primaryMuscles: [.latissimusDorsi],
            trackingType: .durationAndDistance,
            equipmentType: .cardioMachine
        )
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        entry.recommendedDecision = .increase
        entry.recommendedLoad = 80
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        let didSwap = ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .swapExercise(entry, with: replacement)

        XCTAssertTrue(didSwap)
        XCTAssertEqual(entry.exercise.name, "Row Ergometer")
        XCTAssertEqual(entry.nameSnapshot, "Row Ergometer")
        XCTAssertEqual(entry.trackingTypeSnapshot, .durationAndDistance)
        XCTAssertEqual(entry.orderedSets.count, 3)
        XCTAssertTrue(entry.orderedSets.allSatisfy { $0.duration == 0 && $0.distance == 0 })
        XCTAssertNil(entry.recommendedDecision)
        XCTAssertNil(entry.recommendedLoad)
    }

    func testSwappingCompletedExerciseIsRejected() throws {
        let context = try makeContext()
        let source = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let replacement = Exercise(name: "Dumbbell Bench Press", primaryMuscles: [.middleChest])
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        entry.orderedSets[0].done = true
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        let workoutViewModel = WorkoutViewModel()
        workoutViewModel.activeWorkout = workout
        let didSwap = ActiveWorkoutViewModel(workoutVM: workoutViewModel, modelContext: context)
            .swapExercise(entry, with: replacement)

        XCTAssertFalse(didSwap)
        XCTAssertEqual(entry.exercise.name, "Bench Press")
    }

    func testDuplicateLegacyIndicesNormalizeToUniqueContiguousValues() throws {
        let exercise = makeExercise()
        let first = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        let second = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
        first.sets = [
            ExerciseSet(repetitions: 8, weight: 40, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 10, weight: 50, orderIndex: 0, usedMetric: .metric)
        ]
        let workout = Workout(name: "Legacy Ordering")
        workout.exercises = [first, second]

        workout.normalizeExerciseOrder()

        XCTAssertEqual(Set(workout.exercises.map(\.orderIndex)), Set([0, 1]))
        XCTAssertEqual(Set(first.orderedSets.map(\.orderIndex)), Set([0, 1]))
    }


    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
