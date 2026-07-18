import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramEngineIntegrationTests: XCTestCase {
    @MainActor
    func testJSONOnlyProgramImportsWithoutEngineRegistration() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "JSON Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)

        var payload = simpleDefinition(exerciseID: exercise.id)
        payload.programKey = "json-only-regression"
        let document = ProgramLibraryDocument(libraryVersion: 1, programDefinitions: [payload])
        let data = try JSONEncoder().encode(document)

        let firstResult = try ProgramLibraryImporter.importData(data, into: context)
        let secondResult = try ProgramLibraryImporter.importData(data, into: context)
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())

        XCTAssertEqual(firstResult.importedProgramKeys, ["json-only-regression"])
        XCTAssertEqual(secondResult.importedProgramKeys, ["json-only-regression"])
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(try XCTUnwrap(records.first).isBuiltIn)
        _ = try ProgramDefinitionRepository.compile(try XCTUnwrap(records.first), using: context)
    }

    @MainActor
    func testProgramLibrarySkipsMissingCapabilitiesAndRejectsNewerSchema() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Capability Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)

        var payload = simpleDefinition(exerciseID: exercise.id)
        payload.programKey = "future-program"
        payload.requiredCapabilities = ["future-capability"]
        let result = try ProgramLibraryImporter.importDocument(
            ProgramLibraryDocument(libraryVersion: 1, programDefinitions: [payload]),
            into: context
        )

        XCTAssertEqual(result.importedProgramKeys, [])
        XCTAssertEqual(result.skippedPrograms, [.init(
            programKey: "future-program",
            missingCapabilities: ["future-capability"]
        )])

        XCTAssertThrowsError(try ProgramLibraryImporter.decode(try JSONEncoder().encode(
            ProgramLibraryDocument(schemaVersion: 2, libraryVersion: 1, programDefinitions: [])
        ))) { error in
            XCTAssertEqual(
                error as? ProgramLibraryImportError,
                .unsupportedSchemaVersion(found: 2, supported: 1)
            )
        }
    }

    func testAuthoringCatalogSeedsIdempotentlyThroughStrictValidation() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Catalog Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        let json = """
        {
          "schemaVersion":1,
          "programDefinitions":[{
            "programKey":"catalog-only","name":"Catalog Only","goal":"generalStrength",
            "experienceLevel":"beginner","durationWeeks":1,"supportedDaysPerWeek":[1],
            "scheduleMode":"fixedWeekdays","blocks":[{
              "name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,"workouts":[{
                "name":"Day","dayOffset":0,"exercises":[{
                  "exercise":"Catalog Squat","exposureKey":"squat","setGroups":[{"count":3,"reps":5}]
                }]
              }]}]
            }]
          }]
        }
        """

        let first = try ProgramLibrarySeedData.seed(Data(json.utf8), in: context)
        let second = try ProgramLibrarySeedData.seed(Data(json.utf8), in: context)
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())

        XCTAssertEqual(first.importedProgramKeys, ["catalog-only"])
        XCTAssertEqual(second.importedProgramKeys, ["catalog-only"])
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(try records[0].payload().programKey, "catalog-only")
    }

    func testAuthoringCatalogSeedingRejectsAnyPlaceholderProgram() throws {
        let context = try makeContext()
        let json = """
        {"schemaVersion":1,"programDefinitions":[{
          "programKey":"placeholder","name":"Placeholder","blocks":[{
            "name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,"workouts":"same as prior"}]
          }]
        }]}
        """

        XCTAssertThrowsError(try ProgramLibrarySeedData.seed(Data(json.utf8), in: context)) { error in
            XCTAssertEqual(error as? ProgramLibraryImportError, .catalogFailures(["placeholder"]))
        }
    }

    @MainActor
    func testProgramRunRestartResetsOrCarriesStateWithoutMutatingPreviousRun() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Restart Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        var definition = simpleDefinition(exerciseID: exercise.id)
        definition.completionPolicy = .offerRestart(carryState: true)
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [exercise.id: exercise])
        context.insert(plan)
        let previous = try XCTUnwrap(PlanCoordinator.startRun(
            for: plan,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            using: context
        ))
        let previousState = try XCTUnwrap(previous.progressionStates.first)
        previousState.currentLoad = 102.5
        previous.status = .completed
        previous.endDate = previous.startDate.addingTimeInterval(86_400)
        try context.save()

        let carried = try XCTUnwrap(ProgramRunLifecycleService.restartRun(
            for: plan,
            from: previous,
            startDate: Date(timeIntervalSince1970: 1_700_100_000),
            carryState: true,
            using: context
        ))
        XCTAssertNotEqual(carried.id, previous.id)
        XCTAssertEqual(carried.progressionStates.first?.currentLoad, 102.5)
        XCTAssertEqual(previousState.currentLoad, 102.5)

        let reset = try XCTUnwrap(ProgramRunLifecycleService.restartRun(
            for: plan,
            from: previous,
            startDate: Date(timeIntervalSince1970: 1_700_200_000),
            carryState: false,
            using: context
        ))
        XCTAssertNotEqual(reset.id, previous.id)
        XCTAssertNil(reset.progressionStates.first?.currentLoad)

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let restoredContext = try makeContext()
        let restored = try JSONDecoder().decode(
            BackupDTO.self,
            from: JSONEncoder().encode(backup)
        )
        try restored.restore(to: restoredContext)
        let restoredPlan = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<WorkoutPlan>()).first)
        XCTAssertEqual(
            try JSONDecoder().decode(CompletionPolicy.self, from: try XCTUnwrap(restoredPlan.completionPolicyData)),
            .offerRestart(carryState: true)
        )
    }

    @MainActor
    func testResumeReanchorsUnfinishedDatesAndPreservesCompletedProgress() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Pause Squat", primaryMuscles: [.quadriceps])
        let weekOneExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            plannedSets: [PlannedSet(orderIndex: 0, repetitions: 5)]
        )
        let weekTwoExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            plannedSets: [PlannedSet(orderIndex: 0, repetitions: 5)]
        )
        let weekOne = PlanWeek(
            weekIndex: 0,
            plannedWorkouts: [PlannedWorkout(
                name: "Day 1",
                orderIndex: 0,
                dayOffset: 0,
                plannedExercises: [weekOneExercise]
            )]
        )
        let weekTwo = PlanWeek(
            weekIndex: 1,
            plannedWorkouts: [PlannedWorkout(
                name: "Day 2",
                orderIndex: 0,
                dayOffset: 0,
                plannedExercises: [weekTwoExercise]
            )]
        )
        let plan = WorkoutPlan(
            name: "Pause Resume",
            daysPerWeek: 1,
            durationWeeks: 2,
            scheduleMode: .sequential,
            blocks: [PlanBlock(name: "Build", phaseType: .strength, orderIndex: 0, weeks: [weekOne, weekTwo])]
        )
        context.insert(exercise)
        context.insert(plan)
        let run = try XCTUnwrap(PlanCoordinator.startRun(
            for: plan,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            using: context
        ))
        let first = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let second = try XCTUnwrap(run.orderedWorkoutProgress.last)
        first.status = .completed
        first.completedAt = first.scheduledDate
        PlanCoordinator.refreshAvailability(for: run)
        let completedDate = try XCTUnwrap(first.scheduledDate)

        PlanCoordinator.pause(run)
        let resumedAt = Date(timeIntervalSince1970: 1_700_900_000)
        PlanCoordinator.resume(run, at: resumedAt)
        let expected = Calendar.current.startOfDay(for: resumedAt)
        XCTAssertEqual(second.scheduledDate, expected)
        XCTAssertEqual(first.scheduledDate, completedDate)
        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(second.status, .available)

        PlanCoordinator.pause(run)
        PlanCoordinator.resume(run, at: resumedAt)
        XCTAssertEqual(second.scheduledDate, expected)
        try context.save()
    }

    func testAutomaticDeloadReducesSetCountAndIntensityForNextSnapshot() throws {
        let context = try makeContext()
        let squat = Exercise(
            name: "Deload Squat",
            primaryMuscles: [.quadriceps],
            equipmentType: .barbell,
            resistanceType: .externalWeight,
            isPlateLoaded: true
        )
        context.insert(squat)
        let plannedExercise = ProgramExerciseDefinition(
            exerciseID: squat.id,
            exposureKey: "deload-squat",
            orderIndex: 0,
            plannedSets: (0..<4).map { index in
                SetPrescriptionDefinition(
                    orderIndex: index,
                    repetitions: .fixed(5),
                    load: LoadPrescription(fixedValue: 100)
                )
            },
            automaticDeload: AutomaticDeloadDefinition(
                volumeReductionPercent: 50,
                intensityReductionPercent: 10
            )
        )
        let definition = ProgramDefinitionPayload(
            name: "Automatic Deload",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(orderIndex: 0, name: "Build", weeks: [
                ProgramWeekDefinition(weekIndex: 0, workouts: [
                    ProgramWorkoutDefinition(orderIndex: 0, name: "Day", dayOffset: 0, plannedExercises: [plannedExercise])
                ])
            ])]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, using: context))
        let state = try XCTUnwrap(run.progressionStates.first)
        state.isDeloading = true

        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)

        XCTAssertEqual(entry.orderedSets.count, 2)
        XCTAssertEqual(entry.orderedSets.map(\.prescribedSuggestedLoad), [90, 90])
        XCTAssertEqual(entry.orderedSets.map(\.prescribedUnroundedLoad), [90, 90])
        XCTAssertFalse(state.isDeloading)
    }

    func testBundledCatalogSeedsValidatesPreviewsAndCompilesAllThirteenPrograms() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() {
            context.insert(exercise)
        }
        try context.save()

        let data = try AuthoringProgramCatalogDecoder.bundledData()
        let decoded = try AuthoringProgramCatalogDecoder.decode(data)
        XCTAssertTrue(decoded.failures.isEmpty, decoded.failures.map { "\($0.programKey): \($0.message)" }.joined(separator: "\n"))
        XCTAssertEqual(decoded.definitions.count, 13)

        let result = try ProgramLibrarySeedData.seed(data, in: context)
        XCTAssertEqual(Set(result.importedProgramKeys).count, 13)
        let secondResult = try ProgramLibrarySeedData.seed(data, in: context)
        XCTAssertEqual(Set(secondResult.importedProgramKeys).count, 13)

        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        XCTAssertEqual(records.count, 13)
        for record in records {
            let payload = try record.payload()
            XCTAssertTrue(
                ProgramDefinitionValidator.validate(payload, isBuiltIn: true).isEmpty,
                "Validation failed for \(payload.programKey)"
            )
            XCTAssertFalse(try ProgramDefinitionPreview.rows(for: payload).isEmpty)
            _ = try ProgramDefinitionRepository.compile(record, using: context)
        }
    }

    func testBundledCatalogMaterializesStageTransitionsAndAdvancedRuleConstructs() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() { context.insert(exercise) }
        try context.save()
        _ = try ProgramLibrarySeedData.seed(try AuthoringProgramCatalogDecoder.bundledData(), in: context)
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        let payloads = try records.map { try $0.payload() }

        let tiered = try XCTUnwrap(payloads.first { $0.programKey == "tiered-stage-ladder" })
        let foundation = try XCTUnwrap(payloads.first { $0.programKey == "foundation-barbell-5x5" })
        XCTAssertEqual(foundation.intakeInputs.filter { $0.isRequired }.count, 5)
        if case .offerRestart(let carryState) = foundation.completionPolicy {
            XCTAssertTrue(carryState)
        } else {
            XCTFail("Foundation catalog policy should offer a carry-state restart")
        }
        let tieredExercises = tiered.blocks
            .flatMap(\.weeks)
            .flatMap(\.workouts)
            .flatMap(\.plannedExercises)
        let stagedExercise = try XCTUnwrap(tieredExercises.first { $0.exposureKey == "t1-squat" })
        XCTAssertEqual(stagedExercise.stages.map(\.stageID), ["5x3+", "6x2+", "10x1+"])

        let transitions = stagedExercise.progressionRules.compactMap { rule -> (String, String)? in
            guard case .changeStage(let destination) = rule.successAction,
                  case .allOf(let triggers) = rule.trigger,
                  let source = triggers.compactMap({ trigger -> String? in
                      guard case .atStage(let stageID) = trigger else { return nil }
                      return stageID
                  }).first
            else { return nil }
            return (source, destination)
        }
        XCTAssertTrue(transitions.contains { $0 == ("5x3+", "6x2+") })
        XCTAssertTrue(transitions.contains { $0 == ("6x2+", "10x1+") })

        let bodyweight = try XCTUnwrap(payloads.first { $0.programKey == "bodyweight-ladder-foundations" })
        let bodyweightRules = bodyweight.blocks
            .flatMap(\.weeks)
            .flatMap(\.workouts)
            .flatMap(\.plannedExercises)
            .flatMap(\.progressionRules)
        func containsTechnicalQuality(_ trigger: ProgressionTrigger) -> Bool {
            switch trigger {
            case .technicalQualityReached:
                return true
            case .allOf(let triggers), .anyOf(let triggers):
                return triggers.contains(where: containsTechnicalQuality)
            default:
                return false
            }
        }
        XCTAssertTrue(bodyweightRules.contains { containsTechnicalQuality($0.trigger) })

        let waveProgram = try XCTUnwrap(payloads.first { $0.programKey == "wave-builder-base-peak" })
        let waveExercises = waveProgram.blocks
            .flatMap(\.weeks)
            .flatMap(\.workouts)
            .flatMap(\.plannedExercises)
        XCTAssertTrue(waveExercises.contains { exercise in
            Set(exercise.waves.map { $0.plannedSets.count }).count > 1
        })
        XCTAssertTrue(ProgramDefinitionValidator.validate(tiered, isBuiltIn: true).isEmpty)
        XCTAssertTrue(ProgramDefinitionValidator.validate(waveProgram, isBuiltIn: true).isEmpty)
        let velocityProgram = try XCTUnwrap(payloads.first { $0.programKey == "velocity-calibrated-strength" })
        XCTAssertTrue(velocityProgram.requiredCapabilities.contains(EngineCapabilities.velocity))
        XCTAssertTrue(velocityProgram.intakeInputs.contains { $0.kind == .probeVelocity })

        let optionalWorkoutPayload = try XCTUnwrap(payloads.first { payload in
            payload.blocks.flatMap(\.weeks).flatMap(\.workouts).contains(where: \.isOptional)
        })
        let optionalRecord = try XCTUnwrap(records.first { record in
            guard let payload = try? record.payload() else { return false }
            return payload.programKey == optionalWorkoutPayload.programKey
        })
        let optionalPlan = try ProgramDefinitionRepository.compile(optionalRecord, using: context)
        XCTAssertTrue(optionalPlan.orderedWeeks.flatMap(\.orderedPlannedWorkouts).contains(where: \.isOptional))
    }

    func testEveryBundledProgramStartsSnapshotsAndKeepsCompletedHistoryImmutable() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() { context.insert(exercise) }
        try context.save()
        let data = try AuthoringProgramCatalogDecoder.bundledData()
        _ = try ProgramLibrarySeedData.seed(data, in: context)
        let fetchedRecords: [ProgramDefinitionRecord] = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        let records = fetchedRecords.sorted(by: { lhs, rhs in lhs.name < rhs.name })
        XCTAssertEqual(records.count, 13)

        for record in records {
            try XCTContext.runActivity(named: record.name) { _ in
                let plan = try ProgramDefinitionRepository.compile(record, using: context)
                context.insert(plan)
                let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000), using: context))
                let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
                let plannedWorkout = try XCTUnwrap(plan.orderedWeeks
                    .flatMap(\.orderedPlannedWorkouts)
                    .first(where: { $0.id == progress.plannedWorkoutID }))
                let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
                context.insert(workout)
                XCTAssertFalse(workout.orderedExercises.isEmpty)
                XCTAssertTrue(workout.orderedExercises.allSatisfy { !$0.orderedSets.isEmpty })

                for entry in workout.orderedExercises {
                    for set in entry.orderedSets {
                        if let reps = set.prescribedRepetitions ?? set.prescribedRepRangeMinimum {
                            set.repetitions = Float(max(1, reps))
                        }
                        if let load = set.prescribedSuggestedLoad {
                            set.weight = Float(load)
                        }
                        if set.isVelocityProbe || set.prescribedVelocityMinimum != nil {
                            set.meanVelocity = set.prescribedVelocityMinimum ?? 0.6
                        }
                        set.done = true
                    }
                }
                workout.status = .completed
                workout.endTime = workout.startTime.addingTimeInterval(3_600)
                progress.status = .completed
                progress.completedWorkout = workout
                let results = try PlanProgressionEvaluationService.evaluateAndApply(
                    workout: workout,
                    run: run,
                    modelContext: context
                )
                XCTAssertFalse(results.isEmpty, "No progression exposures were evaluated for \(record.name)")
                _ = PlanProgressionTransitionService.applyAutomaticTransitions(
                    results,
                    sourceProgress: progress,
                    in: run
                )
                _ = PlanProgressionCadenceService.applyDueStates(in: run)
                try context.save()
                let before = historyDigest(workout)

                for state in run.progressionStates {
                    state.currentLoad = (state.currentLoad ?? 0) + 2.5
                    state.repetitionOffset += 1
                    state.velocityBaseline = (state.velocityBaseline ?? 0.6) + 0.01
                }
                try context.save()
                XCTAssertEqual(historyDigest(workout), before, "Mutable run state rewrote completed history for \(record.name)")
            }
        }

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let restoredContext = try makeContext()
        let roundTrippedBackup = try JSONDecoder().decode(BackupDTO.self, from: JSONEncoder().encode(backup))
        try roundTrippedBackup.restore(to: restoredContext)
        XCTAssertEqual(try restoredContext.fetch(FetchDescriptor<ProgramDefinitionRecord>()).count, 13)
        XCTAssertEqual(try restoredContext.fetch(FetchDescriptor<WorkoutPlan>()).count, 13)
        XCTAssertEqual(try restoredContext.fetch(FetchDescriptor<PlanRun>()).count, 13)
        XCTAssertEqual(try restoredContext.fetch(FetchDescriptor<Workout>()).filter { $0.status == .completed }.count, 13)
        XCTAssertTrue(try restoredContext.fetch(FetchDescriptor<PlanRun>()).allSatisfy { !$0.progressionStates.isEmpty })
    }

    func testFoundationBarbellRunsEndToEnd() throws { try assertBundledProgramStarts("foundation-barbell-5x5") }
    func testDoubleProgressionRunsEndToEnd() throws { try assertBundledProgramStarts("double-progression-builder") }
    func testTieredStageLadderRunsEndToEnd() throws { try assertBundledProgramStarts("tiered-stage-ladder") }
    func testHeavyLightMediumRunsEndToEnd() throws { try assertBundledProgramStarts("heavy-light-medium-5x5") }
    func testPercentCycleRunsEndToEnd() throws { try assertBundledProgramStarts("percent-cycle-4-week") }
    func testWaveBuilderRunsEndToEnd() throws { try assertBundledProgramStarts("wave-builder-base-peak") }
    func testRPEBridgeRunsEndToEnd() throws { try assertBundledProgramStarts("rpe-bridge-block") }
    func testUndulatingUpperLowerRunsEndToEnd() throws { try assertBundledProgramStarts("undulating-upper-lower") }
    func testSixWeekBlockRunsEndToEnd() throws { try assertBundledProgramStarts("six-week-block-strength") }
    func testBenchSpecializationRunsEndToEnd() throws { try assertBundledProgramStarts("bench-specialization-matrix") }
    func testBodyweightLadderRunsEndToEnd() throws { try assertBundledProgramStarts("bodyweight-ladder-foundations") }
    func testAccumulationWaveRunsEndToEnd() throws { try assertBundledProgramStarts("accumulation-wave-upper-lower") }
    func testVelocityCalibratedRunsEndToEnd() throws { try assertBundledProgramStarts("velocity-calibrated-strength") }
    func testScopedWeekStateAppliesOnlyToTargetWeekAndExposure() {
        let squat = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let volume = PlannedExercise(exercise: squat, orderIndex: 0, progressionKey: "squat-volume")
        let strength = PlannedExercise(exercise: squat, orderIndex: 1, progressionKey: "squat-strength")
        let firstWeek = PlanWeek(
            weekIndex: 0,
            plannedWorkouts: [PlannedWorkout(name: "Week one", orderIndex: 0, dayOffset: 0, plannedExercises: [volume, strength])]
        )
        let secondWeek = PlanWeek(
            weekIndex: 1,
            plannedWorkouts: [PlannedWorkout(name: "Week two", orderIndex: 0, dayOffset: 0, plannedExercises: [volume, strength])]
        )
        let plan = WorkoutPlan(
            name: "Scoped",
            daysPerWeek: 1,
            durationWeeks: 2,
            blocks: [PlanBlock(name: "Build", phaseType: .strength, orderIndex: 0, weeks: [firstWeek, secondWeek])]
        )
        let run = PlanRun(plan: plan, startDate: .now)
        let volumeBase = PlanExerciseProgressionState(progressionKey: "squat-volume", currentLoad: 100)
        let strengthBase = PlanExerciseProgressionState(progressionKey: "squat-strength", currentLoad: 90)
        let nextWeekVolume = PlanExerciseProgressionState(
            progressionKey: "squat-volume",
            scopeRaw: ProgressionScope.week.rawValue,
            scopeOwnerKey: "week:1",
            currentLoad: 105
        )
        run.progressionStates = [volumeBase, strengthBase, nextWeekVolume]

        run.currentWeekIndex = 0
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: volume, in: run)?.currentLoad ?? 0,
            100,
            accuracy: 0.001
        )

        run.currentWeekIndex = 1
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: volume, in: run)?.currentLoad ?? 0,
            105,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: strength, in: run)?.currentLoad ?? 0,
            90,
            accuracy: 0.001
        )
    }

    func testWeekScopedNextWeekRuleCreatesASeparateTargetState() {
        let squat = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let planned = PlannedExercise(exercise: squat, orderIndex: 0, progressionKey: "squat")
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Scoped", startDate: .now)
        let source = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Week one", weekIndex: 0, workoutIndex: 0)
        run.progressionStates = [PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)]

        let target = PlanProgressionStateService.stateForEvaluation(
            scope: .week,
            plannedExercise: planned,
            sourceProgress: source,
            sourceBlockIndex: 0,
            cadence: .nextWeek,
            in: run
        )

        XCTAssertEqual(target.scopeRaw, ProgressionScope.week.rawValue)
        XCTAssertEqual(target.scopeOwnerKey, "week:1")
        XCTAssertEqual(target.currentLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(run.progressionStates.count, 2)
    }

    func testAcceptingDeferredRecommendationWaitsForCadenceBeforeStateAndTransition() throws {
        let context = try makeContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Recommendation", startDate: .now)
        let sourceWorkout = Workout(name: "Completed", endTime: .now)
        let source = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Week one",
            weekIndex: 0,
            workoutIndex: 0
        )
        source.status = .completed
        source.completedWorkout = sourceWorkout
        let skippedAtBoundary = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Later this week",
            weekIndex: 0,
            workoutIndex: 1
        )
        let nextWeek = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Next week",
            weekIndex: 1,
            workoutIndex: 0
        )
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        run.workoutProgress = [source, skippedAtBoundary, nextWeek]
        run.progressionStates = [state]
        context.insert(run)
        context.insert(sourceWorkout)

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .advanceWeek,
            cadence: .nextWeek,
            scope: .week,
            reason: "All prescribed sets were completed.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 102.5),
            performance: ProgressionPerformance(weekCompleted: true)
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: sourceWorkout.id
        )
        record.progressionKey = "squat"
        context.insert(record)
        try context.save()

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)

        XCTAssertTrue(record.isResolved)
        XCTAssertEqual(state.currentLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(skippedAtBoundary.status, .upcoming)
        let pending = try XCTUnwrap(state.pendingProgressionData.flatMap {
            try? JSONDecoder().decode([PendingProgressionState].self, from: $0)
        })
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.action, .advanceWeek)
        XCTAssertEqual(pending.first?.state.currentLoad ?? 0, 102.5, accuracy: 0.001)

        run.currentWeekIndex = 1
        run.currentWorkoutIndex = 0
        XCTAssertTrue(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: source,
            in: run
        ))
        XCTAssertEqual(skippedAtBoundary.status, .skipped)
        XCTAssertTrue(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
        XCTAssertNil(state.pendingProgressionData)
    }

    func testAcceptingDueStructuralRecommendationAppliesItOnce() throws {
        let context = try makeContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Recommendation", startDate: .now)
        let sourceWorkout = Workout(name: "Completed", endTime: .now)
        let source = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Upper",
            weekIndex: 0,
            workoutIndex: 0
        )
        source.status = .completed
        source.completedWorkout = sourceWorkout
        let state = PlanExerciseProgressionState(progressionKey: "accessory")
        run.workoutProgress = [source]
        run.progressionStates = [state]
        context.insert(run)
        context.insert(sourceWorkout)

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .endExercise,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            reason: "Exercise target reached.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance()
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: sourceWorkout.id
        )
        record.progressionKey = "accessory"
        context.insert(record)
        try context.save()

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        XCTAssertTrue(record.isResolved)

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)
        let keys = try XCTUnwrap(run.endedProgressionKeysData.flatMap {
            try? JSONDecoder().decode(Set<String>.self, from: $0)
        })
        XCTAssertEqual(keys, ["accessory"])
    }

    func testAutomaticAdvanceWeekSkipsOnlyUnfinishedProgress() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let skippedByRule = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Later this week", weekIndex: 0, workoutIndex: 1)
        let nextWeek = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Next week", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, skippedByRule, nextWeek]

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .advanceWeek,
            cadence: .nextWeek,
            scope: .week,
            reason: "Week target reached.",
            applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance(weekCompleted: true)
        )
        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(skippedByRule.status, .skipped)
        XCTAssertEqual(skippedByRule.skipReason, "Advanced by program rule")
        XCTAssertEqual(nextWeek.status, .available)
    }

    func testAutomaticEndProgramPreservesCompletedProgress() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endProgram, cadence: .nextCycle,
            scope: .programRun, reason: "Testing complete.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance(cycleCompleted: true)
        )

        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "test", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(future.status, .skipped)
        XCTAssertEqual(run.status, .completed)
        XCTAssertNotNil(run.endDate)
    }

    func testOfferTestDayLeavesTestSessionAvailableAndCanBeActivated() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Test Squat", primaryMuscles: [.quadriceps])
        let plannedExercise = PlannedExercise(exercise: exercise, orderIndex: 0)
        let testWorkout = PlannedWorkout(
            name: "Test Day",
            orderIndex: 1,
            dayOffset: 1,
            isTestDay: true,
            plannedExercises: [plannedExercise]
        )
        let week = PlanWeek(weekIndex: 0, plannedWorkouts: [testWorkout])
        let plan = WorkoutPlan(
            name: "Test-Day Program",
            daysPerWeek: 1,
            durationWeeks: 1,
            blocks: [PlanBlock(name: "Peak", phaseType: .strength, orderIndex: 0, weeks: [week])]
        )
        plan.programCompletionPolicy = .offerTestDay
        let run = PlanRun(plan: plan)
        let completed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Final Training",
            weekIndex: 0,
            workoutIndex: 0
        )
        completed.status = .completed
        let testProgress = PlanWorkoutProgress(plannedWorkout: testWorkout, weekIndex: 0, workoutIndex: 1)
        run.workoutProgress = [completed, testProgress]
        context.insert(plan)
        context.insert(run)
        try context.save()

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .endProgram,
            cadence: .nextCycle,
            scope: .programRun,
            reason: "Training cycle complete.",
            applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance(cycleCompleted: true)
        )
        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(run.status, .testDayAvailable)
        XCTAssertEqual(testProgress.status, .available)

        let activated = try XCTUnwrap(ProgramRunLifecycleService.activateTestDay(for: run, using: context))
        XCTAssertEqual(activated.id, testProgress.id)
        XCTAssertEqual(run.status, .active)
        XCTAssertNil(run.endDate)
    }

    func testDeferredStructuralTransitionWaitsForItsCadenceBoundary() throws {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]
        let state = PlanExerciseProgressionState(progressionKey: "accessory")
        state.pendingProgressionData = try JSONEncoder().encode([
            PendingProgressionState(
                ruleID: UUID(),
                sourceWorkoutID: UUID(),
                action: .endExercise,
                cadence: .nextWeek,
                scope: .exerciseExposure,
                state: ProgressionEvaluationState(),
                sourceWeekIndex: 0,
                sourceWorkoutIndex: 0,
                sourceBlockIndex: 0,
                createdAt: .now
            )
        ])
        run.progressionStates = [state]

        XCTAssertFalse(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: completed,
            in: run
        ))
        XCTAssertFalse(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))

        run.currentWeekIndex = 1
        XCTAssertTrue(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: completed,
            in: run
        ))
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        XCTAssertNotNil(state.pendingProgressionData)
        XCTAssertTrue(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertNil(state.pendingProgressionData)
    }

    func testTransitionServiceDoesNotApplyUndueAutomaticRecommendation() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let source = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Current", weekIndex: 0, workoutIndex: 0)
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [source, future]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endProgram, cadence: .nextWeek,
            scope: .programRun, reason: "Wait for next week.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance(weekCompleted: false)
        )

        XCTAssertFalse(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: source,
            in: run
        ))
        XCTAssertEqual(run.status, .active)
        XCTAssertEqual(future.status, .upcoming)
    }

    func testAutomaticEndExerciseOmitsOnlyFutureGeneratedEntries() {
        let exercise = Exercise(name: "Accessory", primaryMuscles: [.bicep])
        let plannedExercise = PlannedExercise(exercise: exercise, orderIndex: 0, progressionKey: "accessory")
        let plannedWorkout = PlannedWorkout(name: "Upper", orderIndex: 0, dayOffset: 0, plannedExercises: [plannedExercise])
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: plannedWorkout.id, plannedWorkoutName: plannedWorkout.name, weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        run.workoutProgress = [completed]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endExercise, cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure, reason: "Exposure complete.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance()
        )

        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "accessory", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        let future = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        XCTAssertTrue(future.exercises.isEmpty)
        XCTAssertEqual(completed.status, .completed)
    }

    func testRepeatWeekCreatesNewFutureOccurrenceWithoutChangingCompletion() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Repeat", startDate: .now)
        let completed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(), plannedWorkoutName: "Week one", weekIndex: 0, workoutIndex: 0,
            scheduledDate: .now
        )
        completed.status = .completed
        let future = PlanWorkoutProgress(
            plannedWorkoutID: UUID(), plannedWorkoutName: "Week two", weekIndex: 1, workoutIndex: 0,
            scheduledDate: .now
        )
        run.workoutProgress = [completed, future]

        XCTAssertTrue(PlanCoordinator.repeatWeek(containing: completed, in: run))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress.count, 3)
        let repeated = run.orderedWorkoutProgress.first {
            $0.weekIndex == 1 && $0.plannedWorkoutID == completed.plannedWorkoutID
        }
        XCTAssertEqual(repeated?.sourceWeekIndex, 0)
        XCTAssertEqual(repeated?.status, .available)
        XCTAssertEqual(future.weekIndex, 2)
    }

    func testRestartBlockCreatesFutureOccurrencesFromEveryBlockWeek() {
        let firstWorkout = PlannedWorkout(name: "First", orderIndex: 0, dayOffset: 0)
        let secondWorkout = PlannedWorkout(name: "Second", orderIndex: 0, dayOffset: 0)
        let block = PlanBlock(
            name: "Build",
            phaseType: .strength,
            orderIndex: 0,
            weeks: [
                PlanWeek(weekIndex: 0, plannedWorkouts: [firstWorkout]),
                PlanWeek(weekIndex: 1, plannedWorkouts: [secondWorkout])
            ]
        )
        let plan = WorkoutPlan(name: "Block", daysPerWeek: 1, durationWeeks: 2, blocks: [block])
        let run = PlanRun(plan: plan, startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkout: firstWorkout, weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkout: secondWorkout, weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]

        XCTAssertTrue(PlanCoordinator.restartBlock(containing: completed, in: run))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress.count, 4)
        XCTAssertNotNil(run.orderedWorkoutProgress.first { $0.weekIndex == 1 && $0.plannedWorkoutID == firstWorkout.id })
        XCTAssertNotNil(run.orderedWorkoutProgress.first { $0.weekIndex == 2 && $0.plannedWorkoutID == secondWorkout.id })
        XCTAssertEqual(future.weekIndex, 3)
    }

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

    func testSignedProgressionOffsetsReduceTheNextPrescriptionWithoutGoingBelowSafeLimits() throws {
        let exercise = Exercise(name: "Reduced Squat", primaryMuscles: [.quadriceps])
        let firstDefinition = SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), restSeconds: 90)
        let secondDefinition = SetPrescriptionDefinition(orderIndex: 1, repetitions: .fixed(5), restSeconds: 90)
        let plannedExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 2,
            repRangeMinimum: 5,
            repRangeMaximum: 5,
            plannedSets: [
                PlannedSet(orderIndex: 0, repetitions: 5, restSeconds: 90, definitionData: try JSONEncoder().encode(firstDefinition)),
                PlannedSet(orderIndex: 1, repetitions: 5, restSeconds: 90, definitionData: try JSONEncoder().encode(secondDefinition))
            ],
            progressionKey: "reduced-squat"
        )
        let entry = ExerciseEntry(from: plannedExercise, orderIndex: 0, usedMetric: .metric)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Reduction", startDate: .now)
        run.progressionStates = [PlanExerciseProgressionState(
            progressionKey: "reduced-squat",
            repetitionOffset: -2,
            setCountOffset: -1,
            restDurationOffset: -120
        )]

        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )

        XCTAssertEqual(entry.orderedSets.count, 1)
        XCTAssertEqual(entry.prescribedSets, 1)
        XCTAssertEqual(entry.orderedSets.first?.prescribedRepetitions, 3)
        XCTAssertEqual(entry.orderedSets.first?.prescribedRestSeconds, 0)
    }

    func testDerivedDailyMaximumLoadDoesNotUseAnUnrelatedTopSet() throws {
        let exercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let dailyMaximum = ExerciseSet(repetitions: 1, weight: 100, done: true, orderIndex: 0, usedMetric: .metric)
        dailyMaximum.prescribedSetType = .dailyMaximum
        dailyMaximum.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 0,
            role: .dailyMaximum,
            repetitions: .fixed(1)
        ))
        let topSet = ExerciseSet(repetitions: 1, weight: 120, done: true, orderIndex: 1, usedMetric: .metric)
        topSet.prescribedSetType = .topSet
        topSet.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 1,
            role: .topSet,
            repetitions: .fixed(1)
        ))
        let backOff = ExerciseSet(repetitions: 2, weight: 0, done: false, orderIndex: 2, usedMetric: .metric)
        backOff.prescribedSetType = .backoff
        backOff.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(2),
            load: LoadPrescription(
                reference: .init(kind: .dailyMaximum, exposureKey: "clean"),
                percentage: 0.85
            )
        ))
        let entry = ExerciseEntry(exercise: exercise, sets: [dailyMaximum, topSet, backOff], usedMetric: .metric)
        entry.progressionKey = "clean"
        let workout = Workout(name: "Olympic")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 85, accuracy: 0.001)
    }

    func testDerivedDailyMaximumLoadUsesAUserAddedTechnicalMaximumAttempt() throws {
        let exercise = Exercise(name: "Clean", primaryMuscles: [.quadriceps])
        let initialMaximum = ExerciseSet(
            repetitions: 1,
            weight: 100,
            setType: .dailyMaximum,
            orderIndex: 0,
            usedMetric: .metric
        )
        initialMaximum.prescribedSetType = .dailyMaximum
        initialMaximum.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 0,
            role: .dailyMaximum,
            repetitions: .fixed(1)
        ))
        initialMaximum.done = true
        let addedMaximum = initialMaximum.copy()
        addedMaximum.weight = 105
        addedMaximum.done = true
        addedMaximum.orderIndex = 1
        let backOff = ExerciseSet(repetitions: 2, weight: 0, done: false, orderIndex: 2, usedMetric: .metric)
        backOff.prescribedSetType = .backoff
        backOff.prescriptionDefinitionData = try JSONEncoder().encode(SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(2),
            load: LoadPrescription(
                reference: .init(kind: .dailyMaximum, exposureKey: "clean"),
                percentage: 0.8
            )
        ))
        let entry = ExerciseEntry(exercise: exercise, sets: [initialMaximum, addedMaximum, backOff], usedMetric: .metric)
        entry.progressionKey = "clean"
        let workout = Workout(name: "Olympic")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 84, accuracy: 0.001)
        XCTAssertEqual(addedMaximum.prescribedSetType, .dailyMaximum)
        XCTAssertNotNil(addedMaximum.prescriptionDefinitionData)

        initialMaximum.isSelectedDailyMaximum = true
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        XCTAssertEqual(backOff.prescribedSuggestedLoad ?? 0, 80, accuracy: 0.001)
    }

    func testDeferredBackOffIsGeneratedFromTopSetAndCompletedValuesRemainFrozen() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = ExerciseSet(
            repetitions: 5,
            weight: 100,
            done: true,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .metric
        )
        topSet.prescribedSetType = .topSet
        topSet.prescriptionDefinitionData = try JSONEncoder().encode(
            SetPrescriptionDefinition(
                orderIndex: 0,
                role: .topSet,
                repetitions: .fixed(5)
            )
        )
        let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .metric)
        entry.progressionKey = "bench-strength"
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([backOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        var generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(entry.orderedSets.count, 2)
        XCTAssertEqual(generated.prescribedSetType, .backoff)
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(generated.prescribedRepetitions, 5)

        topSet.done = false
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        XCTAssertFalse(entry.orderedSets.contains { $0.generatedBackOffDefinitionID == backOff.id })

        topSet.done = true
        topSet.weight = 110
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 99, accuracy: 0.001)

        generated.weight = 99
        generated.done = true
        topSet.weight = 120
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 99, accuracy: 0.001)
        XCTAssertEqual(generated.weight, 99, accuracy: 0.001)
    }

    func testDeferredBackOffRefreshKeepsOneUnfinishedSetPerDefinition() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = ExerciseSet(
            repetitions: 5,
            weight: 100,
            done: true,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .metric
        )
        topSet.prescribedSetType = .topSet
        let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .metric)
        entry.progressionKey = "bench-strength"
        let firstBackOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        let secondBackOff = SetPrescriptionDefinition(
            orderIndex: 2,
            role: .backOff,
            repetitions: .fixed(8),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.8
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([firstBackOff, secondBackOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)
        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter { $0.generatedBackOffDefinitionID != nil }.count,
            2
        )
        XCTAssertEqual(
            Set(entry.orderedSets.compactMap(\.generatedBackOffDefinitionID)),
            Set([firstBackOff.id, secondBackOff.id])
        )

        let firstGenerated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == firstBackOff.id
        })
        let duplicate = firstGenerated.copy()
        duplicate.generatedBackOffDefinitionID = firstBackOff.id
        duplicate.done = false
        duplicate.orderIndex = (entry.sets.map(\.orderIndex).max() ?? -1) + 1
        entry.sets.append(duplicate)

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter {
                $0.generatedBackOffDefinitionID == firstBackOff.id && !$0.done
            }.count,
            1
        )
        XCTAssertEqual(entry.orderedSets.count, 3)

        firstGenerated.done = true
        let staleUnfinished = firstGenerated.copy()
        staleUnfinished.generatedBackOffDefinitionID = firstBackOff.id
        staleUnfinished.done = false
        staleUnfinished.orderIndex = (entry.sets.map(\.orderIndex).max() ?? -1) + 1
        entry.sets.append(staleUnfinished)

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        XCTAssertEqual(
            entry.orderedSets.filter { $0.generatedBackOffDefinitionID == firstBackOff.id }.count,
            1
        )
        XCTAssertTrue(firstGenerated.done)
    }

    func testSnapshotDefersSourceBasedBackOffUntilItsSourceIsCompleted() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = SetPrescriptionDefinition(
            orderIndex: 0,
            role: .topSet,
            repetitions: .fixed(5)
        )
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        let planned = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            targetSets: 2,
            plannedSets: [
                PlannedSet(orderIndex: 0, definitionData: try JSONEncoder().encode(topSet)),
                PlannedSet(orderIndex: 1, definitionData: try JSONEncoder().encode(backOff))
            ],
            progressionKey: "bench-strength"
        )
        let entry = ExerciseEntry(from: planned, orderIndex: 0, usedMetric: .metric)
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Press", startDate: .now)

        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: planned,
            run: run,
            unitSystem: .metric
        )

        XCTAssertEqual(entry.orderedSets.count, 1)
        XCTAssertEqual(entry.orderedSets.first?.prescribedSetType, .topSet)
        let deferred = try XCTUnwrap(entry.deferredBackOffDefinitionsData)
        XCTAssertEqual(try JSONDecoder().decode([SetPrescriptionDefinition].self, from: deferred), [backOff])
    }

    func testDeferredTopSetBackOffPreservesTheWorkoutWeightUnit() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.middleChest])
        let topSet = ExerciseSet(
            repetitions: 5,
            weight: 225,
            done: true,
            setType: .topSet,
            orderIndex: 0,
            usedMetric: .imperial
        )
        topSet.prescribedSetType = .topSet
        let entry = ExerciseEntry(exercise: exercise, sets: [topSet], usedMetric: .imperial)
        entry.progressionKey = "bench-strength"
        let backOff = SetPrescriptionDefinition(
            orderIndex: 1,
            role: .backOff,
            repetitions: .fixed(5),
            load: LoadPrescription(
                reference: .init(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9
            ),
            generatesAfterSourceCompletion: true
        )
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode([backOff])
        let workout = Workout(name: "Press")
        workout.exercises = [entry]

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        let generated = try XCTUnwrap(entry.orderedSets.first {
            $0.generatedBackOffDefinitionID == backOff.id
        })
        XCTAssertEqual(generated.prescribedSuggestedLoad ?? 0, 202.5, accuracy: 0.001)
        XCTAssertEqual(generated.prescribedSuggestedLoadType, .lbs)
    }

    func testFutureOverrideIsInheritedAndConvertedForTheNextOccurrence() throws {
        let exercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
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
        // The active-workout UI stamps the set with the unit the value was
        // entered in before storing it; an imperial override is (lb, .lbs).
        previousSet.weightType = .lbs
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
        XCTAssertEqual(targetSet.prescribedSuggestedLoad ?? 0, 100, accuracy: 0.01)
    }

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

    private func assertBundledProgramStarts(_ programKey: String) throws {
        let context = try makeContext()
        let exerciseTemplates = ExerciseSeedData.templates()
        for exercise in exerciseTemplates { context.insert(exercise) }
        let catalog = try AuthoringProgramCatalogDecoder.decode(AuthoringProgramCatalogDecoder.bundledData())
        let authoring = try XCTUnwrap(catalog.definitions.first(where: { $0.programKey == programKey }))
        let exerciseIDsByName = Dictionary(uniqueKeysWithValues: exerciseTemplates.map { ($0.name, $0.id) })
        let payload = try authoring.expand(exerciseIDsByName: exerciseIDsByName)
        XCTAssertTrue(ProgramDefinitionValidator.validate(payload, isBuiltIn: true).isEmpty)
        let exercisesByID = Dictionary(uniqueKeysWithValues: exerciseTemplates.map { ($0.id, $0) })
        let plan = try ProgramDefinitionCompiler.compile(payload, exercisesByID: exercisesByID)
        context.insert(plan)
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, using: context))
        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let planned = try XCTUnwrap(plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts).first { $0.id == progress.plannedWorkoutID })
        let workout = Workout(plannedWorkout: planned, planRun: run, unitSystem: .metric)
        XCTAssertFalse(workout.orderedExercises.isEmpty)
        XCTAssertTrue(workout.orderedExercises.allSatisfy { !$0.orderedSets.isEmpty })
        XCTAssertTrue(workout.orderedExercises.allSatisfy { entry in
            entry.orderedSets.allSatisfy { $0.prescriptionDefinitionData != nil }
        })

        if payload.requiredCapabilities.contains(EngineCapabilities.velocity) {
            let velocitySets = plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
                .flatMap(\.orderedPlannedExercises).flatMap(\.orderedPlannedSets)
                .compactMap { $0.definitionData.flatMap { try? JSONDecoder().decode(SetPrescriptionDefinition.self, from: $0) } }
                .compactMap(\.velocity)
            XCTAssertFalse(velocitySets.isEmpty)
        }
        if payload.requiredCapabilities.contains(EngineCapabilities.variationLadders) {
            XCTAssertTrue(plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
                .flatMap(\.orderedPlannedExercises).contains { $0.variationLadderData != nil })
        }
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
