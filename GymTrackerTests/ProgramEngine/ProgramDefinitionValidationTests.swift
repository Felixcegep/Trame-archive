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

}
