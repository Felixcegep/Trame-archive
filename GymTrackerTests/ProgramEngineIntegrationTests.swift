import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramEngineIntegrationTests: XCTestCase {
    func testPlannedWorkoutStartupResolvesUniversalPrescriptionIntoSnapshot() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Interval Bike",
            primaryMuscles: [.quadriceps],
            category: .cardio,
            trackingType: .calories,
            equipmentType: .cardioMachine
        )
        let definition = ProgramDefinitionPayload(
            name: "Conditioning Snapshot",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Base",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Intervals",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "interval-bike",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .calories(420),
                                                    restSeconds: 60
                                                )
                                            ]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: progress, in: run))

        context.insert(exercise)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let viewModel = WorkoutViewModel()
        XCTAssertTrue(viewModel.startWorkout(
            from: plannedWorkout,
            progress: progress,
            in: run,
            using: context
        ))

        let entry = try XCTUnwrap(viewModel.activeWorkout?.orderedExercises.first)
        let set = try XCTUnwrap(entry.orderedSets.first)
        XCTAssertEqual(set.calories, 420)
        XCTAssertEqual(set.prescribedCalories, 420)
        XCTAssertEqual(set.prescribedRestSeconds, 60)
        XCTAssertNotNil(set.prescriptionDefinitionData)
        XCTAssertEqual(progress.status, .inProgress)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            ProgramDefinitionRecord.self,
            PlanProgressionRecommendationRecord.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseAlternative.self,
            PlannedSet.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
