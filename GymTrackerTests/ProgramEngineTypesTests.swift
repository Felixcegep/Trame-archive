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
