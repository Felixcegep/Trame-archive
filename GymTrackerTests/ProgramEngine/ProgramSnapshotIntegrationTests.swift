import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramSnapshotIntegrationTests: XCTestCase {
    func testStructuredComplexPrescriptionCompilesWithoutLosingComponents() throws {
        let clean = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let jerk = Exercise(name: "Jerk", primaryMuscles: [.frontDeltoid])
        let complex = Exercise(name: "Clean + Jerk", primaryMuscles: [.quadriceps])
        let prescription = SetPrescriptionDefinition(
            orderIndex: 0,
            repetitions: .sequence([
                RepComponent(exerciseID: clean.id, repetitions: 1),
                RepComponent(exerciseID: jerk.id, repetitions: 1)
            ]),
            load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 80)
        )
        let definition = ProgramDefinitionPayload(
            name: "Complex",
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
                                    name: "Olympic",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: complex.id,
                                            exposureKey: "clean-jerk",
                                            orderIndex: 0,
                                            plannedSets: [prescription]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let plan = try ProgramDefinitionCompiler.compile(
            definition,
            exercisesByID: [clean.id: clean, jerk.id: jerk, complex.id: complex]
        )
        let data = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first?.orderedPlannedSets.first?.definitionData)
        let decoded = try JSONDecoder().decode(SetPrescriptionDefinition.self, from: data)
        guard case .sequence(let components) = decoded.repetitions else {
            return XCTFail("Expected a structured complex")
        }
        XCTAssertEqual(components, [
            RepComponent(exerciseID: clean.id, repetitions: 1),
            RepComponent(exerciseID: jerk.id, repetitions: 1)
        ])
    }

    func testProgramCompilationRejectsMissingNestedExerciseReferences() {
        let mainExercise = Exercise(name: "Main", primaryMuscles: [.quadriceps])
        let missingComponentID = UUID()
        let missingReferenceLiftID = UUID()
        let definition = ProgramDefinitionPayload(
            name: "Invalid nested reference",
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
                                    name: "Session",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: mainExercise.id,
                                            exposureKey: "main",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .sequence([
                                                        RepComponent(exerciseID: missingComponentID, repetitions: 1)
                                                    ]),
                                                    load: LoadPrescription(
                                                        reference: .init(
                                                            kind: .referenceExercise,
                                                            exerciseID: missingReferenceLiftID
                                                        ),
                                                        percentage: 0.8
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

        XCTAssertThrowsError(try ProgramDefinitionCompiler.compile(
            definition,
            exercisesByID: [mainExercise.id: mainExercise]
        )) { error in
            XCTAssertEqual(error as? ProgramDefinitionStoreError, .missingExercise(missingReferenceLiftID))
        }
    }

    func testDeferredCadencePromotesExactlyOnceAtTheRunBoundary() throws {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Cadence", startDate: .now)
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        state.pendingProgressionData = try JSONEncoder().encode([
            PendingProgressionState(
                ruleID: UUID(),
                sourceWorkoutID: UUID(),
                cadence: .nextWeek,
                scope: .exerciseExposure,
                state: ProgressionEvaluationState(currentLoad: 102.5),
                sourceWeekIndex: 0,
                sourceWorkoutIndex: 2,
                sourceBlockIndex: 0,
                createdAt: .now
            )
        ])
        run.progressionStates = [state]
        run.currentWeekIndex = 1

        XCTAssertTrue(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
        XCTAssertNil(state.pendingProgressionData)
        XCTAssertFalse(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
    }

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
                                                    restSeconds: 60,
                                                    tempo: "controlled",
                                                    progressionEligible: false
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
        XCTAssertEqual(set.prescribedTempo, "controlled")
        XCTAssertEqual(set.prescribedProgressionEligible, false)
        XCTAssertNotNil(set.prescriptionDefinitionData)
        XCTAssertEqual(progress.status, .inProgress)
    }

    func testGeneratedWarmupsSnapshotBeforeWorkingSetsWithoutChangingWorkingTarget() throws {
        let defaults = UserDefaults.standard
        let priorUnitSystem = defaults.object(forKey: DefaultsKey.useMetric)
        defaults.set(UnitSystem.metric.rawValue, forKey: DefaultsKey.useMetric)
        defer {
            if let priorUnitSystem {
                defaults.set(priorUnitSystem, forKey: DefaultsKey.useMetric)
            } else {
                defaults.removeObject(forKey: DefaultsKey.useMetric)
            }
        }

        let context = try makeContext()
        let exercise = Exercise(
            name: "Warm-up Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        let definition = ProgramDefinitionPayload(
            name: "Warm-up Snapshot",
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
                                    name: "Strength",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "warmup-squat",
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
                                            ],
                                            warmupScheme: WarmupSchemeDefinition(steps: [
                                                WarmupStepDefinition(percentage: 0.4, repetitions: 5, restSeconds: 45),
                                                WarmupStepDefinition(percentage: 0.6, repetitions: 3, restSeconds: 60)
                                            ])
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
        XCTAssertTrue(viewModel.startWorkout(from: plannedWorkout, progress: progress, in: run, using: context))

        let sets = try XCTUnwrap(viewModel.activeWorkout?.orderedExercises.first?.orderedSets)
        XCTAssertEqual(sets.compactMap(\.prescribedSetType), [.warmup, .warmup, .normal])
        XCTAssertEqual(sets.compactMap(\.prescribedSuggestedLoad), [40, 60, 100])
        XCTAssertEqual(sets.compactMap(\.prescribedUnroundedLoad), [40, 60, 100])
        XCTAssertTrue(sets.allSatisfy { $0.prescriptionLoadExplanation != nil })
        XCTAssertEqual(sets.prefix(2).compactMap(\.prescribedRepetitions), [5, 3])
        XCTAssertEqual(sets.prefix(2).compactMap(\.prescribedRestSeconds), [45, 60])
        XCTAssertTrue(sets.prefix(2).allSatisfy { $0.prescriptionNotes == "Generated warm-up" })
    }


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
