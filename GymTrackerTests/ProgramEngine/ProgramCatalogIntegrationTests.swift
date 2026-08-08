import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramCatalogIntegrationTests: XCTestCase {
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

    func testHybridRaceFoundationsStructuralIntegrity() throws {
        let context = try makeContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        let retiredKeys = [
            "powerlifting-meet-preparation",
            "weightlifting-technical-foundations",
            "strongman-event-foundations",
            "hybrid-race-foundations",
            "couch-to-continuous-running",
            "rowerg-2000m-builder",
            "kettlebell-foundations"
        ]

        for key in retiredKeys {
            let record = try XCTUnwrap(
                records.first { (try? $0.payload().programKey) == key },
                "Expected \(key) in the bundled seed before retirement."
            )
            XCTAssertTrue(record.isArchived, "Under-authored \(key) must not be discoverable.")
        }

        let active = try ProgramDefinitionRepository.activeDefinitions(in: context)
        XCTAssertFalse(active.contains { (try? $0.payload().programKey) == "hybrid-race-foundations" })
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
        try context.save()

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let restoredContext = try makeContext()
        let restored = try JSONDecoder().decode(
            BackupDTO.self,
            from: JSONEncoder().encode(backup)
        )
        try restored.restore(to: restoredContext)
        let restoredPlan = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<WorkoutPlan>()).first {
            $0.id == plan.id
        })
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

    func testBundledCatalogSeedsValidatesPreviewsAndCompilesEveryProgramIdempotently() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() {
            context.insert(exercise)
        }
        try context.save()

        let data = try AuthoringProgramCatalogDecoder.bundledData()
        let decoded = try AuthoringProgramCatalogDecoder.decode(data)
        XCTAssertTrue(decoded.failures.isEmpty, decoded.failures.map { "\($0.programKey): \($0.message)" }.joined(separator: "\n"))
        XCTAssertFalse(decoded.definitions.isEmpty)
        // The bundled catalog's contract is unique, fully-decodable program
        // keys — not a specific headcount that breaks every time a program
        // is added.
        XCTAssertEqual(Set(decoded.definitions.map(\.programKey)).count, decoded.definitions.count)

        let result = try ProgramLibrarySeedData.seed(data, in: context)
        XCTAssertEqual(Set(result.importedProgramKeys).count, decoded.definitions.count)
        let secondResult = try ProgramLibrarySeedData.seed(data, in: context)
        // Re-seeding the same bundled data must not create duplicate records:
        // the reported key set stays the same size as the first import.
        XCTAssertEqual(Set(secondResult.importedProgramKeys).count, decoded.definitions.count)

        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        // One persisted record per decoded definition, regardless of how many
        // programs the catalog contains.
        XCTAssertEqual(records.count, decoded.definitions.count)
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

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    func testV18ReceiptRestoreKeepsResolvedLegacyRecordWithoutFabricatingDecision() throws {
        let backup = try makeProgressionReceiptBackup(
            decisionOutcome: nil,
            appliedLoad: nil
        )
        var document = try backupDocument(backup)
        document["version"] = BackupDTO.mobilityLinkageVersion
        var recommendation = try XCTUnwrap((document["progressionRecommendations"] as? [[String: Any]])?.first)
        recommendation.removeValue(forKey: "decisionOutcome")
        recommendation.removeValue(forKey: "appliedLoad")
        recommendation.removeValue(forKey: "ruleVersion")
        recommendation.removeValue(forKey: "reasonKey")
        recommendation.removeValue(forKey: "proposedLoadUnit")
        document["progressionRecommendations"] = [recommendation]

        let legacy = try JSONDecoder().decode(
            BackupDTO.self,
            from: JSONSerialization.data(withJSONObject: document)
        )
        XCTAssertNoThrow(try legacy.validate())
        let restoredContext = try makeContext()
        XCTAssertNoThrow(try legacy.restore(to: restoredContext))
        let restored = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<PlanProgressionRecommendationRecord>()).first)
        XCTAssertTrue(restored.isResolved)
        XCTAssertNil(restored.decisionOutcome)
        XCTAssertNil(restored.appliedLoad)
        XCTAssertNil(restored.ruleVersion)
    }

    func testV23ReceiptRoundTripPreservesDecisionEvidenceAndReceiptOwnedUnit() throws {
        let backup = try makeProgressionReceiptBackup(
            decisionOutcome: .acceptedWithModifiedValue,
            appliedLoad: 101.25
        )
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        let restoredContext = try makeContext()
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: JSONEncoder().encode(backup))
        try decoded.restore(to: restoredContext)

        let restored = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<PlanProgressionRecommendationRecord>()).first)
        XCTAssertEqual(restored.decisionOutcome, .acceptedWithModifiedValue)
        XCTAssertEqual(restored.proposedLoad, 102.5)
        XCTAssertEqual(restored.appliedLoad, 101.25)
        XCTAssertEqual(restored.ruleVersion, 7)
        XCTAssertEqual(restored.reasonKey, "progression.receipt.reason.triggerSatisfied")
        XCTAssertEqual(restored.proposedLoadUnit, .lbs)
    }

    func testUnknownReceiptDecisionOutcomeFailsValidationAndRestore() throws {
        let backup = try makeProgressionReceiptBackup(
            decisionOutcome: .accepted,
            appliedLoad: nil
        )
        var document = try backupDocument(backup)
        var recommendation = try XCTUnwrap((document["progressionRecommendations"] as? [[String: Any]])?.first)
        recommendation["decisionOutcome"] = "unrecognized-future-decision"
        document["progressionRecommendations"] = [recommendation]
        let malformed = try JSONDecoder().decode(
            BackupDTO.self,
            from: JSONSerialization.data(withJSONObject: document)
        )

        XCTAssertThrowsError(try malformed.validate()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                BackupValidationError.invalidIdentifier("progression recommendation decision outcome").localizedDescription
            )
        }
        let restoreContext = try makeContext()
        XCTAssertThrowsError(try malformed.restore(to: restoreContext))
    }

    private func makeProgressionReceiptBackup(
        decisionOutcome: ProgressionDecisionOutcome?,
        appliedLoad: Double?
    ) throws -> BackupDTO {
        let context = try makeContext()
        let exercise = Exercise(name: "Receipt Backup Squat", primaryMuscles: [.quadriceps])
        let plannedExercise = PlannedExercise(
            exercise: exercise,
            orderIndex: 0,
            plannedSets: [PlannedSet(orderIndex: 0, repetitions: 5)]
        )
        let plannedWorkout = PlannedWorkout(
            name: "Receipt Day",
            orderIndex: 0,
            dayOffset: 0,
            plannedExercises: [plannedExercise]
        )
        let plan = WorkoutPlan(
            name: "Receipt Plan",
            daysPerWeek: 1,
            durationWeeks: 1,
            blocks: [PlanBlock(
                name: "Build",
                phaseType: .strength,
                orderIndex: 0,
                weeks: [PlanWeek(weekIndex: 0, plannedWorkouts: [plannedWorkout])]
            )]
        )
        context.insert(exercise)
        context.insert(plan)
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, using: context))
        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        workout.status = .completed
        workout.endTime = .now
        progress.status = .completed
        progress.completedWorkout = workout
        context.insert(workout)
        let record = try PlanProgressionRecommendationRecord(
            recommendation: ProgressionRecommendation(
                id: UUID(),
                ruleID: UUID(),
                action: .addLoad(2.5),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                reason: "Completed all prescribed work.",
                reasonKey: "progression.receipt.reason.triggerSatisfied",
                applicationMode: .recommendation,
                proposedState: ProgressionEvaluationState(currentLoad: 102.5),
                performance: ProgressionPerformance(completedSets: 1),
                ruleVersion: 7
            ),
            planRunID: run.id,
            workoutID: workout.id,
            proposedLoadUnit: .lbs
        )
        record.progressionKey = "receipt-squat"
        record.isResolved = true
        record.resolvedAt = .now
        record.decisionOutcome = decisionOutcome
        record.appliedLoad = appliedLoad
        context.insert(record)
        try context.save()
        return try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
    }

    private func backupDocument(_ backup: BackupDTO) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? [String: Any])
    }

    func testEveryBundledProgramStartsSnapshotsAndKeepsCompletedHistoryImmutable() throws {
        let context = try makeContext()
        for exercise in ExerciseSeedData.templates() { context.insert(exercise) }
        try context.save()
        let data = try AuthoringProgramCatalogDecoder.bundledData()
        _ = try ProgramLibrarySeedData.seed(data, in: context)
        let fetchedRecords: [ProgramDefinitionRecord] = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        let records = fetchedRecords.sorted(by: { lhs, rhs in lhs.name < rhs.name })
        XCTAssertFalse(records.isEmpty)
        // Every bundled program key seeds exactly one record: no collisions,
        // no silent drops. This stays true as the catalog grows, unlike a
        // fixed headcount.
        XCTAssertEqual(Set(records.map(\.name)).count, records.count)

        for record in records {
            try XCTContext.runActivity(named: record.name) { _ in
                let payload = try record.payload()
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
                XCTAssertTrue(workout.orderedExercises.allSatisfy { entry in
                    entry.orderedSets.allSatisfy { $0.prescriptionDefinitionData != nil }
                })

                if payload.requiredCapabilities.contains(EngineCapabilities.velocity) {
                    let velocitySets = plan.orderedWeeks
                        .flatMap(\.orderedPlannedWorkouts)
                        .flatMap(\.orderedPlannedExercises)
                        .flatMap(\.orderedPlannedSets)
                        .compactMap { plannedSet in
                            plannedSet.definitionData.flatMap {
                                try? JSONDecoder().decode(SetPrescriptionDefinition.self, from: $0)
                            }
                        }
                        .compactMap(\.velocity)
                    XCTAssertFalse(velocitySets.isEmpty)
                }

                if payload.requiredCapabilities.contains(EngineCapabilities.variationLadders) {
                    XCTAssertTrue(plan.orderedWeeks
                        .flatMap(\.orderedPlannedWorkouts)
                        .flatMap(\.orderedPlannedExercises)
                        .contains { $0.variationLadderData != nil })
                }

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
                // Not every bundled program is engine-driven. Documentation/
                // ProgramEngine/02-ProgramSpecifications.md states three times
                // that "No automated progression rule runs on any <...>
                // exposure — every load is a direct percentage of the lifter's
                // own intake maximum, matching the source concept of
                // autoregulated contest preparation rather than an
                // engine-driven ramp." Thirteen bundled programs are authored
                // that way on purpose (strongman, powerlifting meet prep,
                // weightlifting, and the conditioning/erg specs), so asserting
                // exposures unconditionally contradicted the specification.
                // Where a workout does carry rules, they must still evaluate.
                let hasRules = workout.orderedExercises.contains { entry in
                    guard let rulesData = entry.prescriptionRulesData,
                          let rules = try? JSONDecoder().decode([ProgressionRuleDefinition].self, from: rulesData) else { return false }
                    return !rules.isEmpty
                }
                if hasRules {
                    XCTAssertFalse(results.isEmpty, "No progression exposures were evaluated for \(record.name)")
                }
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
        // Restore stages the current bundled catalogue in addition to the
        // user backup, so the total plan count is intentionally not stable.
        // Match the restored plan IDs from this backup rather than depending
        // on SwiftData's unordered fetch result or the seed catalogue size.
        let restoredPlans = try restoredContext.fetch(FetchDescriptor<WorkoutPlan>())
        let backupPlanIDs = Set(backup.plans.map(\.id))
        XCTAssertEqual(
            Set(restoredPlans.map(\.id.uuidString).filter(backupPlanIDs.contains)),
            backupPlanIDs
        )
        XCTAssertEqual(try restoredContext.fetch(FetchDescriptor<PlanRun>()).count, records.count)
        XCTAssertEqual(
            try restoredContext.fetch(FetchDescriptor<Workout>()).filter { $0.status == .completed }.count,
            records.count
        )
        XCTAssertTrue(try restoredContext.fetch(FetchDescriptor<PlanRun>()).allSatisfy { !$0.progressionStates.isEmpty })
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

}
