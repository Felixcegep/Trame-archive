import XCTest
@testable import GymTracker

final class MobilityReferenceBandTests: XCTestCase {
    func testBandRequiresAtLeastOneBound() {
        XCTAssertEqual(
            makeBand(lowerBound: nil, upperBound: nil).validate(),
            .missingBounds
        )
    }

    func testBandRejectsInvertedBounds() {
        XCTAssertEqual(
            makeBand(lowerBound: 50, upperBound: 40).validate(),
            .invertedBounds
        )
    }

    func testBandMustMatchExactProtocolIdentityAndUnit() {
        let protocolValue = makeProtocol()
        XCTAssertEqual(
            makeBand(protocolID: "hip-ir-prone-v1").validate(against: protocolValue),
            .protocolMismatch
        )
        XCTAssertEqual(
            makeBand(unit: .centimetres).validate(against: protocolValue),
            .unitMismatch
        )
        XCTAssertNil(makeBand().validate(against: protocolValue))
    }

    func testClassificationUsesOpenEndedBoundsWithoutInventingAZero() {
        let band = makeBand(lowerBound: 40, upperBound: nil)
        XCTAssertEqual(band.classify(39.9), .below)
        XCTAssertEqual(band.classify(40), .within)
        XCTAssertEqual(band.classify(100), .within)
        XCTAssertNil(band.classify(nil))
        XCTAssertNil(band.classify(.nan))
    }

    func testClassificationUsesNeutralAboveAndBelowPositions() {
        let band = makeBand(lowerBound: 40, upperBound: 60)
        XCTAssertEqual(band.classify(39), .below)
        XCTAssertEqual(band.classify(50), .within)
        XCTAssertEqual(band.classify(61), .above)
    }

    private func makeProtocol() -> MobilityAssessmentProtocol {
        MobilityAssessmentProtocol(
            protocolID: "hip-ir-seated-v1",
            protocolVersion: 1,
            measurement: "Hip internal rotation range",
            testName: "Hip internal rotation, seated",
            position: "Seated",
            side: .left,
            unit: .degrees,
            activePassive: .passive,
            recordsWarmCold: true,
            preferredMethod: .manual,
            manualFallback: true,
            reliabilitySource: "Evidence review pending",
            limitations: "This observation does not diagnose a condition."
        )
    }

    private func makeBand(
        protocolID: String = "hip-ir-seated-v1",
        unit: MobilityMeasurementUnit = .degrees,
        lowerBound: Double? = 40,
        upperBound: Double? = 60
    ) -> MobilityReferenceBand {
        MobilityReferenceBand(
            protocolID: protocolID,
            protocolVersion: 1,
            unit: unit,
            lowerBound: lowerBound,
            upperBound: upperBound,
            sourceCitation: "Evidence review pending",
            populationDescription: "Population context required before release",
            rulesetVersion: 1,
            limitations: "This comparison range is not a diagnosis or universal target."
        )
    }
}
