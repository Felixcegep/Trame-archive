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
