import Foundation
import XCTest
@testable import GymTracker

final class ProgramDefinitionValidationTests: XCTestCase {
    func testEveryActionCanBeStoredAsAFailurePolicy() throws {
        let formula = ProgressionFormula.source(.constant(100))
        let actions: [ProgressionAction] = [
            .addLoad(2.5), .reduceLoad(2.5), .addLoadPercentage(0.025), .reduceLoadPercentage(0.025),
            .addAssistance(5), .reduceAssistance(5), .addRepetitions(1), .reduceRepetitions(1),
            .addSets(1), .reduceSets(1), .addDuration(30), .reduceDuration(30), .addDistance(50),
            .reduceDistance(50), .addRestDuration(15), .reduceRestDuration(15), .addCalories(10),
            .reduceCalories(10), .updateTrainingMax(formula), .updateEstimatedOneRepMax(formula),
            .updateActualOneRepMax(formula), .repeatPrescription, .changeStage("second"),
            .advanceExerciseVariation, .regressExerciseVariation, .advanceWeek, .repeatWeek,
            .advanceWave, .advanceBlock, .restartBlock, .startDeload, .resetFailureCount,
            .resetProgressionOffsets, .endExercise, .endProgram, .generateRecommendation, .noChange
        ]
        let rules = actions.enumerated().map { index, action in
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .repeatPrescription,
                failureAction: action,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                priority: index
            )
        }
        let data = try JSONEncoder().encode(rules)
        XCTAssertEqual(try JSONDecoder().decode([ProgressionRuleDefinition].self, from: data), rules)
    }

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
        let definition = ProgramDefinitionFixture.make(
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

    func testProgramDefinitionDecodesLegacyPayloadWithoutScheduleFields() throws {
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "legacy-squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let encoded = try JSONEncoder().encode(definition)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "scheduleMode")
        object.removeValue(forKey: "scheduleIntervalDays")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: legacyData)
        XCTAssertEqual(decoded.scheduleMode, .fixedWeekdays)
        XCTAssertEqual(decoded.scheduleIntervalDays, 1)
    }

    func testProgramDefinitionDecodesLegacyPayloadWithoutExtensibilityMetadata() throws {
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "legacy-squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(definition)) as? [String: Any])
        [
            "programKey", "prerequisites", "warnings", "isExperimental", "intakeInputs",
            "missedWorkoutPolicy", "completionPolicy", "requiredCapabilities"
        ].forEach { object.removeValue(forKey: $0) }
        var blocks = try XCTUnwrap(object["blocks"] as? [[String: Any]])
        var weeks = try XCTUnwrap(blocks[0]["weeks"] as? [[String: Any]])
        var workouts = try XCTUnwrap(weeks[0]["workouts"] as? [[String: Any]])
        workouts[0].removeValue(forKey: "isOptional")
        weeks[0]["workouts"] = workouts
        blocks[0]["weeks"] = weeks
        object["blocks"] = blocks

        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.programKey, "")
        XCTAssertEqual(decoded.prerequisites, [])
        XCTAssertEqual(decoded.warnings, [])
        XCTAssertFalse(decoded.isExperimental)
        XCTAssertEqual(decoded.intakeInputs, [])
        XCTAssertEqual(decoded.missedWorkoutPolicy, .shiftSequence)
        XCTAssertEqual(decoded.completionPolicy, .end)
        XCTAssertEqual(decoded.requiredCapabilities, [])
        XCTAssertFalse(try XCTUnwrap(decoded.blocks.first?.weeks.first?.workouts.first).isOptional)
    }

    func testProgramMetadataAndPoliciesRoundTrip() throws {
        var definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        definition.programKey = "strength-cycle"
        definition.prerequisites = ["Know your one-rep max"]
        definition.warnings = ["Advanced loading"]
        definition.isExperimental = true
        definition.intakeInputs = [.init(exposureKey: "squat", kind: .trainingMax, defaultPercentOfMax: 0.9)]
        definition.missedWorkoutPolicy = .skipAndContinue
        definition.completionPolicy = .offerRestart(carryState: true)
        definition.requiredCapabilities = ["stages", "velocity"]
        definition.blocks[0].weeks[0].workouts[0].isOptional = true

        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: JSONEncoder().encode(definition))

        XCTAssertEqual(decoded, definition)
        XCTAssertEqual(EngineCapabilities.missing(from: decoded.requiredCapabilities), [])
        XCTAssertEqual(EngineCapabilities.missing(from: ["stages", "future-capability"]), ["future-capability"])
    }

    func testBuiltInValidationRequiresProgramKeyAndValidIntakeExposure() {
        var definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        definition.intakeInputs = [.init(exposureKey: "missing", kind: .startingLoad)]

        XCTAssertFalse(ProgramDefinitionValidator.validate(definition).contains { $0.code == .emptyProgramKey })
        let invalidIssues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertTrue(invalidIssues.contains { $0.code == .emptyProgramKey })
        XCTAssertTrue(invalidIssues.contains { $0.code == .invalidIntakeExposure })

        definition.programKey = "squat-cycle"
        definition.intakeInputs = [.init(exposureKey: "squat", kind: .startingLoad)]
        XCTAssertTrue(ProgramDefinitionValidator.validate(definition, isBuiltIn: true).isEmpty)

        definition.intakeInputs = [.init(exposureKey: "*", kind: .startingLoad)]
        XCTAssertTrue(ProgramDefinitionValidator.validate(definition, isBuiltIn: true).isEmpty)
    }

    func testCompositeTriggersSupportNestingAndStageState() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allOf([
                .atStage("volume"),
                .anyOf([.firstSetReachedUpperRepBound, .manualApproval])
            ]),
            successAction: .addRepetitions(1),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let matching = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(firstSetReachedUpperBound: true),
            state: ProgressionEvaluationState(currentStageID: "volume")
        )
        XCTAssertEqual(matching.state.repetitionOffset, 1)
        XCTAssertTrue(matching.recommendations.first?.reason.contains("first set") == true)

        let wrongStage = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(firstSetReachedUpperBound: true),
            state: ProgressionEvaluationState(currentStageID: "strength")
        )
        XCTAssertEqual(wrongStage.state.repetitionOffset, 0)
        XCTAssertTrue(wrongStage.recommendations.isEmpty)
    }

    func testAnyOfMatchesOnlyOneBranchAndReportsTheMatchedReason() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .anyOf([.manualApproval, .workoutCompleted]),
            successAction: .addRepetitions(1),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(workoutCompleted: true),
            state: ProgressionEvaluationState()
        )

        XCTAssertEqual(result.state.repetitionOffset, 1)
        XCTAssertEqual(result.recommendations.first?.reason, "The workout was completed.")
    }

    func testValidatorRejectsEmptyAndMalformedCompositeTriggers() {
        var definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
                progressionRules: [
                    ProgressionRuleDefinition(
                        metric: .repetitions,
                        trigger: .allOf([.anyOf([]), .atStage(" ")]),
                        successAction: .addRepetitions(1),
                        cadence: .nextExerciseOccurrence,
                        scope: .exerciseExposure
                    )
                ]
            )
        ])
        definition.programKey = "invalid-composite"

        let issues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertEqual(issues.filter { $0.code == .invalidPrescriptionValue }.count, 2)
    }

    // MARK: - Validator-cycle coverage (moved from ProgramEngineTypesTests)

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
                    targetRPE: 11,
                    restSeconds: -1
                )
            ]
        )
        let second = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "bench",
            orderIndex: 1,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
        )
        let issues = ProgramDefinitionValidator.validate(ProgramDefinitionFixture.make(exercises: [first, second]))

        XCTAssertTrue(issues.contains { $0.code == .invalidRepRange })
        XCTAssertTrue(issues.contains { $0.code == .invalidPercentage })
        XCTAssertTrue(issues.contains { $0.code == .invalidRest })
        XCTAssertTrue(issues.contains { $0.code == .invalidRPE })
        XCTAssertTrue(issues.contains { $0.code == .duplicateExposureKey })
    }

    func testValidatorRejectsCrossExerciseLoadReferenceCycles() {
        let first = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "volume",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(reference: .init(kind: .anotherPlannedExercise, exposureKey: "intensity"), percentage: 0.8)
                )
            ]
        )
        let second = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "intensity",
            orderIndex: 1,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(reference: .init(kind: .anotherPlannedExercise, exposureKey: "volume"), percentage: 0.8)
                )
            ]
        )
        let issues = ProgramDefinitionValidator.validate(ProgramDefinitionFixture.make(exercises: [first, second]))
        XCTAssertTrue(issues.contains { $0.code == .referenceCycle })
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
        let issues = ProgramDefinitionValidator.validate(ProgramDefinitionFixture.make(exercises: [exercise]))
        XCTAssertTrue(issues.contains { $0.code == .invalidPrescriptionValue })
        XCTAssertTrue(issues.contains { $0.code == .invalidLoadReference })
    }

    func testValidatorRejectsUnknownExposureReferencesBeforeActivation() {
        let loadExercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(
                        reference: .init(kind: .anotherPlannedExercise, exposureKey: "missing-bench"),
                        percentage: 0.8
                    )
                )
            ]
        )
        let formulaExercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "press",
            orderIndex: 1,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
            progressionRules: [
                ProgressionRuleDefinition(
                    metric: .trainingMax,
                    trigger: .cycleCompleted,
                    successAction: .updateTrainingMax(.add(
                        .source(.anotherExposure(exposureKey: "missing-squat")),
                        .source(.completedMetric(exposureKey: "missing-volume", metric: .totalVolume))
                    )),
                    cadence: .nextCycle,
                    scope: .cycle
                )
            ]
        )

        let issues = ProgramDefinitionValidator.validate(ProgramDefinitionFixture.make(exercises: [loadExercise, formulaExercise]))

        XCTAssertTrue(issues.contains { $0.code == .invalidLoadReference && $0.message.contains("missing-bench") })
        XCTAssertTrue(issues.contains { $0.code == .invalidFormula && $0.message.contains("missing-squat") })
        XCTAssertTrue(issues.contains { $0.code == .invalidFormula && $0.message.contains("missing-volume") })
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
        let issues = ProgramDefinitionValidator.validate(ProgramDefinitionFixture.make(exercises: [exercise]))
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
        let definition = ProgramDefinitionFixture.make(exercises: [
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

    func testValidatorChecksFormulaReferencesInsideTrainingMaxActions() {
        let ruleA = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(.source(.anotherExposure(exposureKey: "b"))),
            cadence: .nextCycle,
            scope: .cycle
        )
        let ruleB = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(.source(.anotherExposure(exposureKey: "a"))),
            cadence: .nextCycle,
            scope: .cycle
        )
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(), exposureKey: "a", orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleA]
            ),
            ProgramExerciseDefinition(
                exerciseID: UUID(), exposureKey: "b", orderIndex: 1,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleB]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(definition).contains { $0.code == .formulaCycle })
    }

}
