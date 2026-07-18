import Foundation
import XCTest
@testable import GymTracker

final class ProgramEngineTypesTests: XCTestCase {
    func testProgramDefinitionRoundTripsComposedFormulaAndRules() throws {
        let exerciseID = UUID()
        let formula = ProgressionFormula.round(
            .multiply(
                .source(.trainingMax(exposureKey: "squat-strength")),
                .source(.constant(0.85))
            ),
            rule: .nearestIncrement(2.5)
        )
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .allRequiredSetsCompleted,
            successAction: .addLoad(2.5),
            failureAction: .repeatPrescription,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            formula: formula,
            applicationMode: .automatic
        )
        let definition = makeDefinition(
            exercises: [
                ProgramExerciseDefinition(
                    exerciseID: exerciseID,
                    exposureKey: "squat-strength",
                    orderIndex: 0,
                    plannedSets: [
                        SetPrescriptionDefinition(
                            orderIndex: 0,
                            repetitions: .range(minimum: 3, maximum: 5),
                            load: LoadPrescription(
                                reference: LoadReference(kind: .trainingMax, exposureKey: "squat-strength"),
                                percentage: 0.85,
                                rounding: .nearestIncrement(2.5)
                            )
                        )
                    ],
                    progressionRules: [rule]
                )
            ]
        )

        let data = try JSONEncoder().encode(definition)
        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: data)

        XCTAssertEqual(decoded, definition)
        XCTAssertTrue(ProgramDefinitionValidator.validate(decoded).isEmpty)
    }

    func testProgramDefinitionCodecRejectsInvalidImportedRecipes() throws {
        let valid = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let data = try ProgramDefinitionCodec.encode(valid)
        XCTAssertEqual(try ProgramDefinitionCodec.decode(data), valid)

        var invalid = valid
        invalid.name = ""
        XCTAssertThrowsError(try ProgramDefinitionCodec.encode(invalid)) { error in
            guard let codecError = error as? ProgramDefinitionCodecError,
                  case .validation(let issues) = codecError else {
                return XCTFail("Expected validation error")
            }
            XCTAssertTrue(issues.contains { $0.code == .emptyName })
        }
        XCTAssertThrowsError(try ProgramDefinitionCodec.decode(Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? ProgramDefinitionCodecError, .malformed)
        }
    }

    func testProgramDefinitionBuilderCreatesAndReordersAValidRecipe() throws {
        var builder = ProgramDefinitionBuilder(name: "Builder Test", durationWeeks: 1)
        let block = builder.addBlock(name: "Strength", phaseType: .strength)
        let week = try builder.addWeek(toBlock: block, name: "Week 1")
        let workout = try builder.addWorkout(toBlock: block, week: week, name: "Day 1", dayOffset: 0)
        let first = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "squat")
        _ = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "bench")
        try builder.addSet(toBlock: block, week: week, workout: workout, exercise: first, prescription: SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5)))
        try builder.moveExercise(fromBlock: block, week: week, workout: workout, from: 0, to: 2)

        let definition = try builder.build()
        let exercises = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises)
        XCTAssertEqual(exercises.map(\.exposureKey), ["bench", "squat"])
        XCTAssertEqual(exercises.map(\.orderIndex), [0, 1])
        XCTAssertEqual(exercises.last?.plannedSets.count, 1)
    }

    func testValidatorReportsInvalidPrescriptionAndDuplicateExposure() {
        let first = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "bench",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .range(minimum: 12, maximum: 8),
                    load: LoadPrescription(percentage: 3.5),
                    restSeconds: -1,
                    targetRPE: 11
                )
            ]
        )
        let second = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "bench",
            orderIndex: 1,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [first, second]))

        XCTAssertTrue(issues.contains { $0.code == .invalidRepRange })
        XCTAssertTrue(issues.contains { $0.code == .invalidPercentage })
        XCTAssertTrue(issues.contains { $0.code == .invalidRest })
        XCTAssertTrue(issues.contains { $0.code == .invalidRPE })
        XCTAssertTrue(issues.contains { $0.code == .duplicateExposureKey })
    }

    func testValidatorRejectsInvalidConditioningValuesAndReferences() {
        let exercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "conditioning",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .duration(seconds: -1),
                    load: LoadPrescription(reference: .init(kind: .trainingMax))
                )
            ]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [exercise]))
        XCTAssertTrue(issues.contains { $0.code == .invalidPrescriptionValue })
        XCTAssertTrue(issues.contains { $0.code == .invalidLoadReference })
    }

    func testValidatorRejectsDuplicateSetOrder() {
        let exercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5)),
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))
            ]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [exercise]))
        XCTAssertTrue(issues.contains { $0.code == .invalidSetOrder })
    }

    func testValidatorRejectsCrossExposureFormulaCycles() {
        let ruleA = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .noChange,
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            formula: .source(.anotherExposure(exposureKey: "b"))
        )
        let ruleB = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .noChange,
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            formula: .source(.anotherExposure(exposureKey: "a"))
        )
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "a",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleA]
            ),
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "b",
                orderIndex: 1,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleB]
            )
        ])

        XCTAssertTrue(ProgramDefinitionValidator.validate(definition).contains { $0.code == .formulaCycle })
    }

    func testCompilerCreatesNormalPlanAndRunStatePerExposure() throws {
        let squat = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let definition = makeDefinition(exercises: [
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
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "row",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(10))]
            )
        ])
        let record = try ProgramDefinitionRecord(payload: definition, isBuiltIn: true)

        XCTAssertEqual(record.id, definition.id)
        XCTAssertEqual(record.templateVersion, definition.templateVersion)
        XCTAssertTrue(record.isBuiltIn)
        XCTAssertEqual(try record.payload(), definition)
    }

    func testProgramDefinitionBackupDTORoundTripsAndValidates() throws {
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench-strength",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let definitionData = try JSONEncoder().encode(definition)
        let definitionDTO = ProgramDefinitionDTO(
            id: definition.id.uuidString,
            schemaVersion: definition.schemaVersion,
            templateVersion: definition.templateVersion,
            name: definition.name,
            summary: definition.description,
            goal: definition.goal.rawValue,
            experienceLevel: definition.experienceLevel.rawValue,
            durationWeeks: definition.durationWeeks,
            supportedDaysPerWeek: definition.supportedDaysPerWeek,
            isBuiltIn: false,
            isArchived: false,
            createdAt: .now,
            updatedAt: .now,
            definitionData: definitionData
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            programDefinitions: [definitionDTO]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupDTO.self, from: encoder.encode(backup))

        XCTAssertEqual(decoded.programDefinitions.count, 1)
        XCTAssertNoThrow(try decoded.validate())
        XCTAssertEqual(decoded.programDefinitions.first?.definitionData, definitionData)
    }

    func testLoadResolverExplainsTrainingMaxAndRoundsForEquipment() throws {
        var context = LoadResolutionContext()
        context.trainingMaxByExposure["squat"] = 108
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .trainingMax, exposureKey: "squat"),
                percentage: 0.85,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )

        XCTAssertEqual(result.referenceValue, 108)
        XCTAssertEqual(result.unroundedLoad ?? 0, 91.8, accuracy: 0.0001)
        XCTAssertEqual(result.prescribedLoad ?? 0, 92.5, accuracy: 0.0001)
        XCTAssertTrue(result.explanation.contains("85%"))
        XCTAssertTrue(result.explanation.contains("92.5"))
    }

    func testLoadResolverSupportsTopSetBackOffAndMissingReferences() throws {
        var context = LoadResolutionContext()
        context.completedTopSetByExposure["bench-strength"] = 150
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        XCTAssertEqual(result.prescribedLoad ?? 0, 135, accuracy: 0.0001)

        XCTAssertThrowsError(try ProgramLoadResolver.resolve(
            LoadPrescription(reference: LoadReference(kind: .trainingMax, exposureKey: "deadlift"), percentage: 0.8),
            context: context
        )) { error in
            XCTAssertEqual(error as? LoadResolutionError, .missingReference(.trainingMax))
        }
    }

    func testLoadResolverSupportsActualOneRepMaxReference() throws {
        var context = LoadResolutionContext()
        context.actualOneRepMaxByExposure["clean"] = 120
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: .init(kind: .exerciseOneRepMax, exposureKey: "clean"),
                percentage: 1.1,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        XCTAssertEqual(result.prescribedLoad, 132)
    }

    func testFormulaResolverSupportsCrossExposureAndSafeDivision() throws {
        var context = FormulaResolutionContext()
        context.trainingMaxByExposure["squat"] = 200
        context.valuesByExposure["offset"] = 5
        let formula: ProgressionFormula = .round(
            .add(
                .multiply(.source(.trainingMax(exposureKey: "squat")), .source(.constant(0.85))),
                .source(.anotherExposure(exposureKey: "offset"))
            ),
            rule: .nearestIncrement(2.5)
        )
        XCTAssertEqual(try ProgramFormulaResolver.resolve(formula, context: context), 175)
        XCTAssertThrowsError(try ProgramFormulaResolver.resolve(
            .divide(.source(.constant(10)), .source(.constant(0))),
            context: context
        )) { error in
            XCTAssertEqual(error as? FormulaResolutionError, .divisionByZero)
        }
    }

    func testProgressionEvaluatorAppliesLinearSuccessAndFailureActions() throws {
        let rules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]
        let state = ProgressionEvaluationState(currentLoad: 100)
        let success = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: state
        )
        XCTAssertEqual(success.state.currentLoad, 102.5)
        XCTAssertEqual(success.recommendations.count, 1)
        XCTAssertEqual(success.recommendations.first?.applicationMode, .automatic)

        let failure = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 2, didFail: true),
            state: state
        )
        XCTAssertEqual(failure.state.currentLoad, 100)
        XCTAssertEqual(failure.recommendations.first?.action, .repeatPrescription)
    }

    func testProgressionEvaluatorSupportsDoubleProgressionRecommendationAndVariationLadder() throws {
        let increaseRule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allSetsReachedUpperRepBound,
            successAction: .addLoad(5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .recommendation
        )
        let variationRule = ProgressionRuleDefinition(
            metric: .exerciseVariation,
            trigger: .technicalQualityReached,
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [increaseRule, variationRule],
            performance: ProgressionPerformance(requiredSets: 3, upperBoundSets: 3, technicalQualityReached: true),
            state: ProgressionEvaluationState(currentLoad: 30, currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentLoad, 30)
        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertEqual(result.recommendations.first?.applicationMode, .recommendation)
        XCTAssertTrue(result.recommendations.contains { $0.action == .addLoad(5) })
    }

    func testProgressionEvaluatorSupportsTechnicalQualityRatio() throws {
        let rule = ProgressionRuleDefinition(
            metric: .technicalQuality,
            trigger: .successfulAttemptRatioReached(0.9),
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 0.9),
            state: ProgressionEvaluationState(currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.first?.action, .advanceExerciseVariation)
    }

    func testProgressionEvaluatorSupportsDurationDistanceAndRestProgression() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .duration, trigger: .allRequiredSetsCompleted, successAction: .addDuration(10), cadence: .nextExerciseOccurrence, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .distance, trigger: .allRequiredSetsCompleted, successAction: .addDistance(100), cadence: .nextExerciseOccurrence, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .restDuration, trigger: .allRequiredSetsCompleted, successAction: .reduceRestDuration(5), cadence: .nextExerciseOccurrence, scope: .exerciseExposure)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 1, completedSets: 1),
            state: ProgressionEvaluationState(durationOffset: 30, distanceOffset: 500, restDurationOffset: 10)
        )

        XCTAssertEqual(result.state.durationOffset, 40)
        XCTAssertEqual(result.state.distanceOffset, 600)
        XCTAssertEqual(result.state.restDurationOffset, 5)
    }

    func testProgressionEvaluatorResetsFailureAndOffsets() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetFailureCount, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetProgressionOffsets, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(manualApproval: true),
            state: ProgressionEvaluationState(repetitionOffset: 2, setCountOffset: 1, durationOffset: 30, distanceOffset: 100, restDurationOffset: 5, failureCount: 3)
        )
        XCTAssertEqual(result.state.failureCount, 0)
        XCTAssertEqual(result.state.repetitionOffset, 0)
        XCTAssertEqual(result.state.distanceOffset, 0)
    }

    func testRequiredProgramFixturesValidateWithoutProgramSpecificLogic() {
        let ids = Dictionary(uniqueKeysWithValues: [
            "squat", "bench", "row", "press", "deadlift", "upper", "assisted", "band", "bodyweight", "weighted",
            "snatch", "pull", "complex", "clean", "jerk", "plank", "carry"
        ].map { ($0, UUID()) })
        let fixtures = [
            ProgramFixtureCatalog.beginnerFiveByFive(exerciseIDs: ids),
            ProgramFixtureCatalog.doubleProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.stageProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.trainingMaxCycle(exerciseIDs: ids),
            ProgramFixtureCatalog.topSetBackOff(exerciseIDs: ids),
            ProgramFixtureCatalog.bodyweightVariation(exerciseIDs: ids),
            ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: ids),
            ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: ids),
            ProgramFixtureCatalog.weeklyHeavyLightMedium(exerciseIDs: ids),
            ProgramFixtureCatalog.amrapWave(exerciseIDs: ids),
            ProgramFixtureCatalog.blockPeriodized(exerciseIDs: ids),
            ProgramFixtureCatalog.conditioningProgression(exerciseIDs: ids)
        ]
        for fixture in fixtures {
            let issues = ProgramDefinitionValidator.validate(fixture)
            XCTAssertTrue(issues.isEmpty, "\(fixture.name): \(issues.map(\.message).joined(separator: " | "))")
        }
    }

    func testProgressionEvaluatorPersistsRepAndSetVolumeOffsets() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .weekCompleted,
            successAction: .addRepetitions(2),
            failureAction: .addSets(1),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let state = ProgressionEvaluationState()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(weekCompleted: true),
            state: state
        )
        XCTAssertEqual(result.state.repetitionOffset, 2)
        XCTAssertEqual(result.state.setCountOffset, 0)
    }

    func testProgressionEvaluatorAdvancesWaveAndBlockState() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .waveCompleted, successAction: .advanceWave, cadence: .nextWave, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .load, trigger: .blockCompleted, successAction: .advanceBlock, cadence: .nextBlock, scope: .exerciseExposure)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(waveCompleted: true, blockCompleted: true),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(result.state.currentWaveIndex, 1)
        XCTAssertEqual(result.state.currentBlockIndex, 1)
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

    func testProgressionRecommendationBackupPreservesExplainableAction() throws {
        let actionData = try JSONEncoder().encode(ProgressionAction.addLoad(2.5))
        let dto = ProgressionRecommendationDTO(
            id: UUID().uuidString,
            planRunID: UUID().uuidString,
            workoutID: UUID().uuidString,
            progressionKey: "bench-strength",
            ruleID: UUID().uuidString,
            actionData: actionData,
            cadence: ProgressionCadence.nextExerciseOccurrence.rawValue,
            scope: ProgressionScope.exerciseExposure.rawValue,
            reason: "All required sets reached the upper rep bound.",
            applicationMode: ProgressionApplicationMode.recommendation.rawValue,
            proposedLoad: 82.5,
            proposedStageID: nil,
            proposedVariationExerciseID: nil,
            proposedRepetitionOffset: 0,
            proposedSetCountOffset: 0,
            createdAt: .now,
            isResolved: false,
            resolvedAt: nil
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            progressionRecommendations: [dto]
        )
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)
        XCTAssertEqual(decoded.progressionRecommendations.first?.actionData, actionData)
        XCTAssertEqual(try JSONDecoder().decode(ProgressionAction.self, from: decoded.progressionRecommendations[0].actionData), .addLoad(2.5))
    }

    func testProgressionStateBackupPreservesConditioningOffsets() throws {
        let state = ProgressionStateDTO(
            id: UUID().uuidString,
            progressionKey: "conditioning",
            currentLoad: nil,
            currentLoadType: nil,
            repetitionOffset: 0,
            setCountOffset: 0,
            durationOffset: 60,
            distanceOffset: 250,
            restDurationOffset: 5,
            currentStageID: nil,
            currentVariationExerciseID: nil,
            trainingMax: nil,
            estimatedOneRepMax: nil,
            failureCount: 0,
            successCount: 1,
            currentWaveIndex: 0,
            currentBlockIndex: 0,
            previousAMRAPRepetitions: nil,
            previousActualRPE: nil,
            previousActualRIR: nil,
            lastCompletedOccurrence: nil,
            lastSuccessfulLoad: nil,
            isDeloading: false,
            lastAppliedOutcomeID: nil
        )
        let decoded = try JSONDecoder().decode(ProgressionStateDTO.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.durationOffset, 60)
        XCTAssertEqual(decoded.distanceOffset, 250)
        XCTAssertEqual(decoded.restDurationOffset, 5)
    }

    private func makeDefinition(exercises: [ProgramExerciseDefinition]) -> ProgramDefinitionPayload {
        let workout = ProgramWorkoutDefinition(
            orderIndex: 0,
            name: "Training Day",
            dayOffset: 0,
            plannedExercises: exercises
        )
        let week = ProgramWeekDefinition(weekIndex: 0, workouts: [workout])
        let block = ProgramBlockDefinition(orderIndex: 0, name: "Accumulation", weeks: [week])
        return ProgramDefinitionPayload(
            name: "Test Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [block]
        )
    }
}
