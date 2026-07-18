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

    func testFutureOverrideIsInheritedAndConvertedForTheNextOccurrence() throws {
        let exercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.chest],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        let definition = ProgramDefinitionPayload(
            name: "Override Carry Forward",
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
                                    name: "Press",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "bench-strength",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .fixed(5),
                                                    load: LoadPrescription(
                                                        reference: .init(kind: .fixedLoad),
                                                        fixedValue: 100
                                                    )
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
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)

        let previousWorkout = Workout(name: "Previous", endTime: .now)
        let previousEntry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .imperial)
        let previousSet = try XCTUnwrap(previousEntry.orderedSets.first)
        previousSet.weight = 220.4623
        previousSet.done = true
        previousSet.userOverrideAffectsFuture = true
        previousSet.isUserOverridden = true
        previousSet.userOverrideReason = "Heavier than the generated target"
        previousWorkout.exercises = [previousEntry]

        let previousProgress = PlanWorkoutProgress(plannedWorkout: plannedWorkout, weekIndex: 0, workoutIndex: 0)
        previousProgress.status = .completed
        previousProgress.completedAt = .now
        previousProgress.completedWorkout = previousWorkout
        run.workoutProgress.append(previousProgress)

        let targetEntry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .metric)
        ProgramPrescriptionSnapshotService.apply(
            to: targetEntry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )

        let targetSet = try XCTUnwrap(targetEntry.orderedSets.first)
        XCTAssertEqual(targetSet.weight, 100, accuracy: 0.01)
        XCTAssertTrue(targetSet.isUserOverridden)
        XCTAssertTrue(targetSet.userOverrideAffectsFuture)
        XCTAssertEqual(targetSet.userOverrideReason, "Heavier than the generated target")
        XCTAssertEqual(targetSet.prescribedSuggestedLoad, 100, accuracy: 0.01)
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
