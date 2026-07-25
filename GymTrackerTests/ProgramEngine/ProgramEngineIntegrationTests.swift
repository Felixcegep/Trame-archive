import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramEngineIntegrationTests: XCTestCase {
    @MainActor
    func testCustomDefinitionSaveAndCompileCreatesVersionedPlan() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Custom Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        context.insert(exercise)

        let definition = ProgramDefinitionPayload(
            templateVersion: 3,
            name: "Custom Recipe",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Build",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Squat day",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "custom-squat",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .fixed(5),
                                                    load: LoadPrescription(reference: .init(kind: .fixedLoad), fixedValue: 100)
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

        let plan = try ProgramDefinitionRepository.saveAndCompile(definition, in: context)
        try context.save()

        let record = try XCTUnwrap(
            context.fetch(FetchDescriptor<ProgramDefinitionRecord>()).first(where: { $0.id == definition.id })
        )
        XCTAssertEqual(record.templateVersion, 3)
        XCTAssertEqual(plan.sourceProgramDefinitionID, definition.id)
        XCTAssertEqual(plan.sourceProgramDefinitionVersion, 3)
        XCTAssertEqual(plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first?.progressionKey, "custom-squat")
    }

    func testCompiledRuleAdvancesTheNextOccurrenceFromCompletedEvidence() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Progressing Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        context.insert(exercise)
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .allRequiredSetsCompleted,
            successAction: .addLoad(2.5),
            failureAction: .repeatPrescription,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let definition = ProgramDefinitionPayload(
            name: "Rule Cycle",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Build",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Squat",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exercise.id,
                                            exposureKey: "squat-progress",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .fixed(5),
                                                    // previousOccurrence reads the run state's
                                                    // current load, so the applied progression
                                                    // reaches the next snapshot; a fixedLoad
                                                    // reference resolves to its constant forever.
                                                    load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "squat-progress"))
                                                )
                                            ],
                                            progressionRules: [rule],
                                            initialLoad: 100
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
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        let completedSet = try XCTUnwrap(entry.orderedSets.first)
        completedSet.weight = 100
        completedSet.repetitions = 5
        completedSet.done = true
        workout.status = .completed
        workout.endTime = .now
        progress.status = .completed
        progress.completedAt = .now
        progress.completedWorkout = workout
        run.updatedAt = .now

        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: workout, run: run, modelContext: context)

        let state = try XCTUnwrap(run.progressionStates.first { $0.progressionKey == "squat-progress" })
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)

        let nextEntry = ExerciseEntry(from: plannedWorkout.orderedPlannedExercises[0], orderIndex: 0, usedMetric: .metric)
        ProgramPrescriptionSnapshotService.apply(
            to: nextEntry,
            plannedExercise: plannedWorkout.orderedPlannedExercises[0],
            run: run,
            unitSystem: .metric
        )
        XCTAssertEqual(nextEntry.orderedSets.first?.prescribedSuggestedLoad ?? 0, 102.5, accuracy: 0.001)

        // The same completion may be retried after a relaunch. The immutable
        // workout ID makes progression application idempotent.
        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: workout, run: run, modelContext: context)
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
        XCTAssertEqual(state.lastAppliedOutcomeID, workout.id)
    }

    func testNextSetRuleUpdatesOnlyIncompletePrescriptionAndIsIdempotent() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Event Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        context.insert(exercise)
        let rule = ProgressionRuleDefinition(
            metric: .totalRepetitions,
            trigger: .totalRepetitionsReached(5),
            successAction: .addLoad(2.5),
            cadence: .nextSet,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let definition = ProgramDefinitionPayload(
            name: "Set event",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(
                orderIndex: 0,
                name: "Build",
                weeks: [ProgramWeekDefinition(
                    weekIndex: 0,
                    workouts: [ProgramWorkoutDefinition(
                        orderIndex: 0,
                        name: "Squat",
                        dayOffset: 0,
                        plannedExercises: [ProgramExerciseDefinition(
                            exerciseID: exercise.id,
                            exposureKey: "event-squat",
                            orderIndex: 0,
                            plannedSets: (0..<2).map { index in
                                SetPrescriptionDefinition(
                                    orderIndex: index,
                                    repetitions: .fixed(5),
                                    load: LoadPrescription(
                                        reference: .init(kind: .previousOccurrence, exposureKey: "event-squat")
                                    )
                                )
                            },
                            progressionRules: [rule],
                            initialLoad: 100
                        )]
                    )]
                )]
            )]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        context.insert(run)
        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: progress, in: run))
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        let first = try XCTUnwrap(entry.orderedSets.first)
        first.weight = 100
        first.repetitions = 5
        first.done = true

        ActiveWorkoutProgressionService.applyAfterCompleting(
            set: first,
            in: entry,
            workout: workout,
            modelContext: context
        )

        let state = try XCTUnwrap(run.progressionStates.first { $0.progressionKey == "event-squat" })
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
        XCTAssertEqual(first.prescribedSuggestedLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(entry.orderedSets[1].prescribedSuggestedLoad ?? 0, 102.5, accuracy: 0.001)

        ActiveWorkoutProgressionService.applyAfterCompleting(
            set: first,
            in: entry,
            workout: workout,
            modelContext: context
        )
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)

        let second = entry.orderedSets[1]
        second.weight = 102.5
        second.repetitions = 5
        second.done = true
        workout.status = .completed
        workout.endTime = .now
        progress.status = .completed
        progress.completedWorkout = workout
        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: workout, run: run)
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
    }

    func testWeekScopedRuleUpdatesOnlyTheNextWeekSnapshot() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Scoped Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        context.insert(exercise)
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .weekCompleted,
            successAction: .addLoad(2.5),
            cadence: .nextWeek,
            scope: .week,
            applicationMode: .automatic
        )
        // Each week needs its own definition instance: identifiers must be
        // unique across the whole payload, so repeating one struct would be
        // rejected as duplicateIdentifier.
        func makeScopedExercise() -> ProgramExerciseDefinition {
            ProgramExerciseDefinition(
                exerciseID: exercise.id,
                exposureKey: "scoped-squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "scoped-squat"))
                )],
                progressionRules: [rule],
                initialLoad: 100
            )
        }
        let definition = ProgramDefinitionPayload(
            name: "Scoped Week",
            durationWeeks: 2,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(
                orderIndex: 0,
                name: "Build",
                weeks: [
                    ProgramWeekDefinition(
                        weekIndex: 0,
                        workouts: [ProgramWorkoutDefinition(
                            orderIndex: 0,
                            name: "Week one",
                            dayOffset: 0,
                            plannedExercises: [makeScopedExercise()]
                        )]
                    ),
                    ProgramWeekDefinition(
                        weekIndex: 1,
                        workouts: [ProgramWorkoutDefinition(
                            orderIndex: 0,
                            name: "Week two",
                            dayOffset: 0,
                            plannedExercises: [makeScopedExercise()]
                        )]
                    )
                ]
            )]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlanned = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let firstWorkout = Workout(plannedWorkout: firstPlanned, planRun: run, unitSystem: .metric)
        let completedSet = try XCTUnwrap(firstWorkout.orderedExercises.first?.orderedSets.first)
        completedSet.weight = 100
        completedSet.repetitions = 5
        completedSet.done = true
        firstWorkout.status = .completed
        firstWorkout.endTime = .now
        firstProgress.status = .completed
        firstProgress.completedWorkout = firstWorkout

        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: firstWorkout, run: run, modelContext: context)

        let base = try XCTUnwrap(run.progressionStates.first {
            $0.progressionKey == "scoped-squat" && $0.scopeRaw == ProgressionScope.exerciseExposure.rawValue
        })
        let nextWeek = try XCTUnwrap(run.progressionStates.first {
            $0.progressionKey == "scoped-squat"
                && $0.scopeRaw == ProgressionScope.week.rawValue
                && $0.scopeOwnerKey == "week:1"
        })
        XCTAssertEqual(base.currentLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(nextWeek.currentLoad ?? 0, 102.5, accuracy: 0.001)

        run.currentWeekIndex = 1
        run.currentWorkoutIndex = 0
        let secondProgress = try XCTUnwrap(run.orderedWorkoutProgress.last)
        let secondPlanned = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: secondProgress, in: run))
        let nextEntry = ExerciseEntry(
            from: try XCTUnwrap(secondPlanned.orderedPlannedExercises.first),
            orderIndex: 0,
            usedMetric: .metric
        )
        ProgramPrescriptionSnapshotService.apply(
            to: nextEntry,
            plannedExercise: try XCTUnwrap(secondPlanned.orderedPlannedExercises.first),
            run: run,
            unitSystem: .metric
        )
        XCTAssertEqual(nextEntry.orderedSets.first?.prescribedSuggestedLoad ?? 0, 102.5, accuracy: 0.001)
    }

    func testWeeklyCadenceStaysDeferredWithinTheSameWeek() throws {
        let context = try makeContext()
        let exercise = Exercise(
            name: "Weekly Squat",
            primaryMuscles: [.quadriceps],
            trackingType: .weightAndReps,
            equipmentType: .barbell
        )
        context.insert(exercise)
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .weekCompleted,
            successAction: .addLoad(2.5),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let definition = ProgramDefinitionPayload(
            name: "Weekly Cadence",
            durationWeeks: 1,
            supportedDaysPerWeek: [2],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Week",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Volume",
                                    dayOffset: 0,
                                    plannedExercises: [ProgramExerciseDefinition(
                                        exerciseID: exercise.id,
                                        exposureKey: "weekly-squat",
                                        orderIndex: 0,
                                        plannedSets: [SetPrescriptionDefinition(
                                            orderIndex: 0,
                                            repetitions: .fixed(5),
                                            load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "weekly-squat"))
                                        )],
                                        progressionRules: [rule],
                                        initialLoad: 100
                                    )]
                                ),
                                ProgramWorkoutDefinition(
                                    orderIndex: 1,
                                    name: "Intensity",
                                    dayOffset: 3,
                                    plannedExercises: [ProgramExerciseDefinition(
                                        exerciseID: exercise.id,
                                        exposureKey: "weekly-squat",
                                        orderIndex: 0,
                                        plannedSets: [SetPrescriptionDefinition(
                                            orderIndex: 0,
                                            repetitions: .fixed(5),
                                            load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "weekly-squat"))
                                        )],
                                        progressionRules: [rule],
                                        initialLoad: 100
                                    )]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlanned = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let firstWorkout = Workout(plannedWorkout: firstPlanned, planRun: run, unitSystem: .metric)
        let firstSet = try XCTUnwrap(firstWorkout.orderedExercises.first?.orderedSets.first)
        firstSet.repetitions = 5
        firstSet.weight = 100
        firstSet.done = true
        firstWorkout.status = .completed
        firstWorkout.endTime = .now

        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: firstWorkout, run: run)
        firstProgress.status = .completed

        let state = try XCTUnwrap(run.progressionStates.first { $0.progressionKey == "weekly-squat" })
        XCTAssertEqual(state.currentLoad ?? 0, 100, accuracy: 0.001)
        // weekCompleted has not fired yet, so nothing is pending mid-week;
        // the rule applies during the week-completing evaluation below.
        XCTAssertNil(state.pendingProgressionData)

        run.currentWeekIndex = 0
        run.currentWorkoutIndex = 1
        let secondProgress = try XCTUnwrap(run.orderedWorkoutProgress[1])
        let secondPlanned = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: secondProgress, in: run))
        let secondEntry = ExerciseEntry(from: try XCTUnwrap(secondPlanned.orderedPlannedExercises.first), orderIndex: 0, usedMetric: .metric)
        ProgramPrescriptionSnapshotService.apply(to: secondEntry, plannedExercise: try XCTUnwrap(secondPlanned.orderedPlannedExercises.first), run: run, unitSystem: .metric)
        XCTAssertEqual(secondEntry.orderedSets.first?.prescribedSuggestedLoad ?? 0, 100, accuracy: 0.001)

        let secondWorkout = Workout(plannedWorkout: secondPlanned, planRun: run, unitSystem: .metric)
        let secondSet = try XCTUnwrap(secondWorkout.orderedExercises.first?.orderedSets.first)
        secondSet.repetitions = 5
        secondSet.weight = 100
        secondSet.done = true
        secondWorkout.status = .completed
        secondWorkout.endTime = .now
        _ = try PlanProgressionEvaluationService.evaluateAndApply(workout: secondWorkout, run: run)
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
    }

    func testRunStartsWithConfiguredVariationAndVelocityBaseline() throws {
        let context = try makeContext()
        let base = Exercise(name: "Pull-up", primaryMuscles: [.latissimusDorsi], trackingType: .repsOnly, equipmentType: .bodyweight)
        let selected = Exercise(name: "Assisted Pull-up", primaryMuscles: [.latissimusDorsi], trackingType: .repsOnly, equipmentType: .machine)
        context.insert(base)
        context.insert(selected)
        let programExercise = ProgramExerciseDefinition(
            exerciseID: base.id,
            exposureKey: "pull",
            orderIndex: 0,
            plannedSets: [SetPrescriptionDefinition(
                orderIndex: 0,
                repetitions: .fixed(5),
                velocity: .init(targetMinimum: 0.5, targetMaximum: 0.7, lossStopPercent: 20, isProbe: true)
            )],
            variationExerciseIDs: [base.id, selected.id],
            initialVariationExerciseID: selected.id,
            initialVelocityBaseline: 0.62
        )
        let definition = ProgramDefinitionPayload(
            name: "Configured Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(orderIndex: 0, name: "Start", weeks: [
                ProgramWeekDefinition(weekIndex: 0, workouts: [
                    ProgramWorkoutDefinition(orderIndex: 0, name: "Day One", dayOffset: 0, plannedExercises: [programExercise])
                ])
            ])]
        )

        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [base.id: base, selected.id: selected])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, using: context))
        let state = try XCTUnwrap(run.progressionStates.first)
        XCTAssertEqual(state.currentVariationExerciseID, selected.id)
        XCTAssertEqual(state.velocityBaseline ?? 0, 0.62, accuracy: 0.0001)
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        XCTAssertEqual(workout.orderedExercises.first?.exercise.id, selected.id)
        XCTAssertEqual(workout.orderedExercises.first?.nameSnapshot, selected.name)
        XCTAssertEqual(workout.orderedExercises.first?.variationSourceExerciseIDSnapshot, base.id)
        XCTAssertEqual(workout.orderedExercises.first?.variationSelectedExerciseIDSnapshot, selected.id)
        let snapshottedSet = try XCTUnwrap(workout.orderedExercises.first?.orderedSets.first)
        XCTAssertEqual(snapshottedSet.prescribedVelocityMinimum, 0.5)
        XCTAssertEqual(snapshottedSet.prescribedVelocityMaximum, 0.7)
        XCTAssertEqual(snapshottedSet.prescribedVelocityLossStopPercent, 20)
        XCTAssertTrue(snapshottedSet.isVelocityProbe)
    }

    private func simpleDefinition(exerciseID: UUID) -> ProgramDefinitionPayload {
        ProgramDefinitionPayload(
            name: "JSON-only Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Build",
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Day One",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: exerciseID,
                                            exposureKey: "json-squat",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    repetitions: .fixed(5)
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
    }

    private func historyDigest(_ workout: Workout) -> [String] {
        workout.orderedExercises.flatMap { entry in
            entry.orderedSets.map { set in
                [
                    entry.nameSnapshot,
                    String(set.orderIndex),
                    String(set.repetitions),
                    String(set.weight),
                    String(describing: set.meanVelocity),
                    String(set.done),
                    String(describing: set.prescribedSetType),
                    String(describing: set.prescribedRepetitions),
                    String(describing: set.prescribedRepRangeMinimum),
                    String(describing: set.prescribedRepRangeMaximum),
                    String(describing: set.prescribedSuggestedLoad),
                    String(describing: set.prescribedRestSeconds),
                    String(describing: set.prescribedVelocityMinimum),
                    String(describing: set.prescribedVelocityMaximum),
                    String(describing: set.prescribedVelocityLossStopPercent),
                    String(set.isVelocityProbe)
                ].joined(separator: "|")
            }
        }
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    // MARK: - Compiler coverage (moved from ProgramEngineTypesTests)

    func testCompilerCreatesNormalPlanAndRunStatePerExposure() throws {
        let squat = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: squat.id,
                exposureKey: "squat-strength",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(
                            reference: LoadReference(kind: .fixedLoad),
                            fixedValue: 100,
                            rounding: .nearestIncrement(2.5)
                        )
                    ),
                    SetPrescriptionDefinition(
                        orderIndex: 1,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(
                            reference: LoadReference(kind: .fixedLoad),
                            fixedValue: 100,
                            rounding: .nearestIncrement(2.5)
                        )
                    )
                ]
            )
        ])

        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let plannedExercise = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first)
        XCTAssertEqual(plan.sourceProgramDefinitionID, definition.id)
        XCTAssertEqual(plan.sourceProgramDefinitionVersion, definition.templateVersion)
        XCTAssertEqual(plannedExercise.progressionKey, "squat-strength")
        XCTAssertEqual(plannedExercise.orderedPlannedSets.count, 2)
        XCTAssertEqual(plannedExercise.orderedPlannedSets.first?.suggestedLoad, 100)
        XCTAssertNotNil(plannedExercise.orderedPlannedSets.first?.definitionData)

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.map(\.progressionKey), ["squat-strength"])
        XCTAssertEqual(run.orderedProgressionStates.first?.currentVariationExerciseID, squat.id)
    }

    func testDefinitionRecordStoresVersionedPayloadMetadata() throws {
        var definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "row",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(10))]
            )
        ])
        definition.programKey = "row-program"
        let record = try ProgramDefinitionRecord(payload: definition, isBuiltIn: true)

        XCTAssertEqual(record.id, definition.id)
        XCTAssertEqual(record.templateVersion, definition.templateVersion)
        XCTAssertTrue(record.isBuiltIn)
        XCTAssertEqual(try record.payload(), definition)
    }

    func testCompiledExposureSeedsItsFirstRunValues() throws {
        let squat = Exercise(name: "Seeded Squat", primaryMuscles: [.quadriceps])
        let definition = ProgramDefinitionPayload(
            name: "Seeded Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(
                orderIndex: 0,
                name: "Main",
                weeks: [ProgramWeekDefinition(
                    weekIndex: 0,
                    workouts: [ProgramWorkoutDefinition(
                        orderIndex: 0,
                        name: "Day",
                        dayOffset: 0,
                        plannedExercises: [ProgramExerciseDefinition(
                            exerciseID: squat.id,
                            exposureKey: "seeded-squat",
                            orderIndex: 0,
                            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "seeded-squat"), percentage: 0.8))],
                            initialTrainingMax: 200,
                            initialActualOneRepMax: 220
                        )]
                    )]
                )]
            )]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.first?.trainingMax, 200)
        XCTAssertEqual(run.orderedProgressionStates.first?.actualOneRepMax, 220)
        XCTAssertNil(run.orderedProgressionStates.first?.currentLoad, "No fixed current load should be invented from a percentage prescription")
    }
}
