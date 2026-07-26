import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanProgressionTests: XCTestCase {
    func testExpectedStartUsesLatestCompletedExerciseEvidence() throws {
        let fixture = try makeFixture()
        let olderDate = Date.now.addingTimeInterval(-172_800)
        let latestDate = Date.now.addingTimeInterval(-86_400)
        try insertCompletedWorkout(
            exercise: fixture.exercise,
            reps: 8,
            weight: 80,
            startedAt: olderDate,
            in: fixture.context
        )
        try insertCompletedWorkout(
            exercise: fixture.exercise,
            reps: 8,
            weight: 100,
            startedAt: latestDate,
            in: fixture.context
        )

        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))

        let entry = try XCTUnwrap(viewModel.activeWorkout?.orderedExercises.first)
        XCTAssertEqual(entry.recommendedDecision, .increase)
        XCTAssertEqual(entry.recommendedLoad, 102.5)
        XCTAssertEqual(entry.recommendedUnit, .kg)
        XCTAssertEqual(entry.recommendationPriorLoad, 100)
        XCTAssertEqual(entry.recommendationCompletedSets, 2)
        XCTAssertEqual(entry.recommendationRequiredSets, 2)
        XCTAssertEqual(entry.recommendationPriorWorkoutDate, latestDate)
    }

    func testRepeatAndAlternateStartsDoNotDuplicateOccurrenceEvidence() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        let sourceDate = Date.now.addingTimeInterval(-60)

        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let sourceWorkout = try XCTUnwrap(viewModel.activeWorkout)
        sourceWorkout.startTime = sourceDate
        completeAllSets(in: sourceWorkout, reps: 8, weight: 100)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))

        XCTAssertTrue(viewModel.startWorkout(
            from: fixture.run,
            command: .repeatLast,
            using: fixture.context
        ))
        let repeatWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let repeatEntry = try XCTUnwrap(repeatWorkout.orderedExercises.first)
        XCTAssertEqual(repeatEntry.recommendationPriorWorkoutDate, sourceDate)
        XCTAssertEqual(repeatEntry.recommendationPriorLoad, 100)
        XCTAssertEqual(repeatEntry.recommendedLoad, 102.5)
        XCTAssertEqual(completedWorkoutCount(in: fixture.context), 1)
        XCTAssertEqual(
            fixture.run.orderedOccurrences.filter { $0.status == .completed }.count,
            1
        )
        XCTAssertEqual(
            fixture.run.orderedOccurrences.filter { $0.status == .inProgress }.count,
            1
        )

        viewModel.discardActiveWorkout(using: fixture.context)
        XCTAssertTrue(viewModel.startWorkout(
            from: fixture.run,
            command: .alternate(
                slotIndex: 0,
                continuationMode: .keepExpected
            ),
            using: fixture.context
        ))

        let alternateWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let alternateEntry = try XCTUnwrap(alternateWorkout.orderedExercises.first)
        XCTAssertEqual(alternateEntry.recommendationPriorWorkoutDate, sourceDate)
        XCTAssertEqual(alternateEntry.recommendationPriorLoad, 100)
        XCTAssertEqual(alternateEntry.recommendedLoad, 102.5)
        XCTAssertEqual(completedWorkoutCount(in: fixture.context), 1)
        XCTAssertEqual(
            fixture.run.orderedOccurrences.filter { $0.status == .completed }.count,
            1
        )
        XCTAssertEqual(
            fixture.run.orderedOccurrences.filter { $0.status == .inProgress }.count,
            1
        )
    }

    func testRecommendationIsOptionalOverridableAndLeavesHistoryImmutable() throws {
        let fixture = try makeFixture()
        let viewModel = WorkoutViewModel()
        let historyDate = Date.now.addingTimeInterval(-60)

        XCTAssertTrue(viewModel.startWorkout(from: fixture.run, using: fixture.context))
        let completedWorkout = try XCTUnwrap(viewModel.activeWorkout)
        completedWorkout.startTime = historyDate
        completeAllSets(in: completedWorkout, reps: 8, weight: 100)
        XCTAssertTrue(viewModel.saveWorkout(using: fixture.context))
        let historicalEntry = try XCTUnwrap(completedWorkout.orderedExercises.first)
        let historicalValues = historicalEntry.orderedSets.map {
            ($0.repetitions, $0.weight, $0.weightType, $0.done)
        }

        XCTAssertTrue(viewModel.startWorkout(
            from: fixture.run,
            command: .repeatLast,
            using: fixture.context
        ))
        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeEntry = try XCTUnwrap(activeWorkout.orderedExercises.first)
        XCTAssertEqual(activeEntry.recommendedLoad, 102.5)
        XCTAssertTrue(activeEntry.orderedSets.allSatisfy { $0.weight == 0 })

        let activeViewModel = ActiveWorkoutViewModel(
            workoutVM: viewModel,
            modelContext: fixture.context
        )
        activeViewModel.applyRecommendation(to: activeEntry)

        for set in activeEntry.orderedSets {
            XCTAssertEqual(
                set.weight,
                UnitConversion.weight(102.5, from: .kg, to: set.weightType),
                accuracy: 0.001
            )
        }
        assertHistory(
            historicalEntry,
            stillEquals: historicalValues
        )

        let overriddenSet = try XCTUnwrap(activeEntry.orderedSets.first)
        activeViewModel.commitTypedValue(
            "97.5",
            field: .weight,
            in: overriddenSet
        )

        XCTAssertEqual(overriddenSet.weight, 97.5, accuracy: 0.001)
        XCTAssertEqual(activeEntry.recommendedLoad, 102.5)
        XCTAssertEqual(activeEntry.recommendationPriorLoad, 100)
        assertHistory(
            historicalEntry,
            stillEquals: historicalValues
        )
    }

    private func makeFixture() throws -> Fixture {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let exercise = WorkoutTestFixture.makeExercise()
        let templates = ["A", "B"].map { name -> WorkoutTemplate in
            let template = WorkoutTestFixture.makeTemplate(
                exercise: exercise,
                targetSets: 2
            )
            template.name = name
            return template
        }
        let plan = RepeatingPlan(
            name: "Progression Rotation",
            slots: templates.enumerated().map {
                RepeatingPlanSlot(
                    orderIndex: $0.offset,
                    workoutTemplate: $0.element
                )
            }
        )

        context.insert(exercise)
        templates.forEach(context.insert)
        context.insert(plan)
        try context.save()

        let run = try RepeatingPlanCoordinator.activate(plan)
        context.insert(run)
        try context.save()
        return Fixture(
            container: container,
            context: context,
            exercise: exercise,
            run: run
        )
    }

    private func insertCompletedWorkout(
        exercise: Exercise,
        reps: Float,
        weight: Float,
        startedAt: Date,
        in context: ModelContext
    ) throws {
        let workout = Workout(name: "Historical", endTime: startedAt.addingTimeInterval(3_600))
        workout.startTime = startedAt
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = (0..<2).map {
            ExerciseSet(
                repetitions: reps,
                weight: weight,
                done: true,
                orderIndex: $0,
                usedMetric: .metric
            )
        }
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
    }

    private func completeAllSets(
        in workout: Workout,
        reps: Float,
        weight: Float
    ) {
        guard let entry = workout.orderedExercises.first else {
            return XCTFail("Expected a snapshotted exercise")
        }
        for set in entry.orderedSets {
            set.repetitions = reps
            set.weight = weight
            set.weightType = .kg
            set.done = true
        }
    }

    private func completedWorkoutCount(in context: ModelContext) -> Int {
        ((try? context.fetch(FetchDescriptor<Workout>())) ?? [])
            .filter { $0.status == .completed }
            .count
    }

    private func assertHistory(
        _ entry: ExerciseEntry,
        stillEquals expected: [(Float, Float, WeightType, Bool)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = entry.orderedSets.map {
            ($0.repetitions, $0.weight, $0.weightType, $0.done)
        }
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualSet, expectedSet) in zip(actual, expected) {
            XCTAssertEqual(actualSet.0, expectedSet.0, file: file, line: line)
            XCTAssertEqual(actualSet.1, expectedSet.1, file: file, line: line)
            XCTAssertEqual(actualSet.2, expectedSet.2, file: file, line: line)
            XCTAssertEqual(actualSet.3, expectedSet.3, file: file, line: line)
        }
    }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let context: ModelContext
    let exercise: Exercise
    let run: RepeatingPlanRun
}
