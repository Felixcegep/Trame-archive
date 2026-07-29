import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentValidationTests: XCTestCase {
    func testEverySeedHasAValidManualPathAndCameraPoseIsNotExecutable() {
        XCTAssertEqual(MobilityAssessmentSeedData.definitions.count, 10)
        for spec in MobilityAssessmentSeedData.definitions {
            let definition = spec.makeDefinition()
            XCTAssertNil(
                MobilityAssessmentValidationService.validateDefinition(definition),
                spec.key
            )
            XCTAssertTrue(definition.manualMode.isManual)
            XCTAssertNotEqual(definition.manualMode, .cameraPose)
        }

        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let input = makeInput(
            for: definition,
            method: .cameraPose,
            unit: .criteria
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(input, for: definition),
            .unsupportedCameraPose
        )
    }

    func testNumericAndCriteriaValuesRemainTypedAndFinite() {
        let angle = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: angle, numericValue: nil),
                for: angle
            ),
            .missingNumericValue
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: angle, numericValue: .infinity),
                for: angle
            ),
            .nonFiniteValue
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(
                    for: angle,
                    numericValue: 42,
                    criteria: .someCriteriaObserved
                ),
                for: angle
            ),
            .unexpectedCriteriaObservation
        )

        let criteria = MobilityAssessmentSeedData.definitions[9].makeDefinition()
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: criteria, numericValue: 1),
                for: criteria
            ),
            .unexpectedNumericValue
        )
        XCTAssertNil(
            MobilityAssessmentValidationService.validate(
                makeInput(
                    for: criteria,
                    numericValue: nil,
                    criteria: .allCriteriaObserved
                ),
                for: criteria
            )
        )
    }

    func testManualEntryRejectsUnsupportedConditionsAndHighConfidence() {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: definition, side: .combined),
                for: definition
            ),
            .unsupportedSide
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: definition, setupKey: "different-setup"),
                for: definition
            ),
            .unsupportedSetup
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: definition, method: .inclinometer),
                for: definition
            ),
            .unsupportedMethod
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: definition, unit: .centimetres),
                for: definition
            ),
            .incompatibleUnit
        )
        XCTAssertEqual(
            MobilityAssessmentValidationService.validate(
                makeInput(for: definition, confidence: .high),
                for: definition
            ),
            .manualConfidenceTooHigh
        )
    }

    private func makeInput(
        for definition: MobilityAssessmentDefinition,
        numericValue: Double? = 42,
        criteria: MobilityAssessmentCriteriaObservation? = nil,
        side: MobilityAssessmentSide? = nil,
        setupKey: String? = nil,
        method: MobilityMeasurementMode? = nil,
        unit: MobilityMeasurementUnit? = nil,
        confidence: MobilityMeasurementConfidence = .moderate
    ) -> MobilityAssessmentResultInput {
        MobilityAssessmentResultInput(
            numericValue: numericValue,
            criteria: criteria,
            side: side ?? definition.supportedSides[0],
            isWarm: false,
            setupKey: setupKey ?? definition.defaultSetupKey,
            method: method ?? definition.manualMode,
            unit: unit ?? definition.unit,
            isActiveRange: definition.defaultIsActiveRange,
            day: LocalDay(rawValue: "2026-07-29"),
            source: .manual,
            confidence: confidence
        )
    }
}
