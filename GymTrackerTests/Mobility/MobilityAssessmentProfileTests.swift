import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentProfileTests: XCTestCase {
    func testProjectionPreservesRawValuesAndReportsMissingCoverage() {
        let leftProtocol = makeProtocol(side: .left)
        let rightProtocol = makeProtocol(side: .right)
        let left = makeResult(side: .left, value: 48)

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [leftProtocol, rightProtocol],
            results: [left]
        )

        XCTAssertEqual(profile.coverage.expectedCount, 2)
        XCTAssertEqual(profile.coverage.measuredCount, 1)
        XCTAssertEqual(profile.coverage.missingProtocolIDs, [rightProtocol.protocolID])
        XCTAssertEqual(profile.measurements.count, 2)
        XCTAssertEqual(
            profile.measurements.first(where: { $0.side == .left })?.value,
            .numeric(value: 48, unit: .degrees)
        )
        XCTAssertEqual(
            profile.measurements.first(where: { $0.side == .right })?.value,
            .missing(unit: .degrees)
        )
        XCTAssertEqual(
            profile.measurements.first(where: { $0.side == .right })?.band,
            .notMeasured
        )
        XCTAssertFalse(profile.coverage.isComplete)
    }

    func testSideGapRequiresBothNumericValuesWithMatchingUnits() {
        let leftProtocol = makeProtocol(side: .left)
        let rightProtocol = makeProtocol(side: .right)
        let left = makeResult(side: .left, value: 48)
        let right = makeResult(side: .right, value: 42)

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [leftProtocol, rightProtocol],
            results: [left, right]
        )

        XCTAssertEqual(profile.sideGaps.count, 1)
        XCTAssertEqual(
            profile.sideGaps[0].difference,
            .available(gap: 6, unit: .degrees)
        )
    }

    func testHistoryUsesOnlyDirectComparableResultsFromSameProtocolVersion() {
        let protocolValue = makeProtocol()
        let baseline = makeResult(
            value: 40,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let changedSetup = makeResult(
            value: 44,
            version: 1,
            setupKey: "different-setup",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let current = makeResult(
            value: 48,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 3)
        )

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [protocolValue],
            results: [baseline, changedSetup, current]
        )
        XCTAssertEqual(
            profile.measurements[0].history,
            .directlyComparableDelta(8)
        )
    }

    func testNewProtocolVersionDoesNotCreateCrossVersionHistoryDelta() {
        let protocolValue = makeProtocol(version: 2)
        let old = makeResult(
            value: 40,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let current = makeResult(
            value: 48,
            version: 2,
            createdAt: Date(timeIntervalSince1970: 2)
        )

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [protocolValue],
            results: [old, current]
        )
        XCTAssertEqual(profile.measurements[0].history, .noPriorObservation)
    }

    func testBandPositionRequiresExactProtocolAndResultConditions() {
        let protocolValue = makeProtocol()
        let band = makeBand()
        let result = makeResult(value: 35)

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [protocolValue],
            results: [result],
            bands: [band]
        )
        XCTAssertEqual(profile.measurements[0].band, .positioned(makeEvidence(position: .below)))
        XCTAssertEqual(profile.measurements[0].bandEvidence?.sourceCitation, "Evidence review pending")
        XCTAssertEqual(profile.measurements[0].bandEvidence?.populationDescription, "Population context required before release")
        XCTAssertEqual(profile.measurements[0].bandEvidence?.rulesetVersion, 1)
        XCTAssertEqual(profile.measurements[0].bandEvidence?.lowerBound, 40)
        XCTAssertEqual(profile.measurements[0].bandEvidence?.upperBound, 60)
        XCTAssertEqual(
            profile.measurements[0].bandEvidence?.limitations,
            "This comparison range is not a diagnosis or universal target."
        )

        let changedSetup = makeResult(value: 35, setupKey: "different-setup")
        let incompatible = MobilityAssessmentProfileProjectionService.project(
            protocols: [protocolValue],
            results: [changedSetup],
            bands: [band]
        )
        XCTAssertEqual(incompatible.measurements[0].band, .incompatibleProtocol)
    }

    func testCriteriaEvidenceDoesNotAcquireANumericBandPosition() {
        let protocolValue = makeProtocol(unit: .criteria)
        let result = makeResult(
            value: nil,
            criteria: .allCriteriaObserved,
            unit: .criteria
        )
        let band = makeBand(unit: .criteria, lowerBound: nil, upperBound: 1)

        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [protocolValue],
            results: [result],
            bands: [band]
        )
        XCTAssertEqual(profile.measurements[0].band, .notNumeric)
        XCTAssertEqual(
            profile.measurements[0].value,
            .criteria(value: .allCriteriaObserved, unit: .criteria)
        )
    }

    func testProjectionHasNoGlobalScoreOrZoneAggregate() {
        let profile = MobilityAssessmentProfileProjectionService.project(
            protocols: [makeProtocol()],
            results: []
        )
        XCTAssertEqual(profile.measurements.count, 1)
        XCTAssertEqual(profile.sideGaps.count, 0)
        XCTAssertEqual(profile.coverage.expectedCount, 1)
    }

    private func makeProtocol(
        protocolID: String = "hip-ir-seated-v1",
        version: Int = 1,
        side: MobilityAssessmentSide = .left,
        unit: MobilityMeasurementUnit = .degrees
    ) -> MobilityAssessmentProtocol {
        MobilityAssessmentProtocol(
            protocolID: protocolID,
            protocolVersion: version,
            measurement: "Hip internal rotation range",
            testName: "Hip internal rotation, seated",
            position: "Seated",
            setupKey: "seated-90-90",
            side: side,
            unit: unit,
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
        version: Int = 1,
        unit: MobilityMeasurementUnit = .degrees,
        lowerBound: Double? = 40,
        upperBound: Double? = 60
    ) -> MobilityReferenceBand {
        MobilityReferenceBand(
            protocolID: protocolID,
            protocolVersion: version,
            unit: unit,
            lowerBound: lowerBound,
            upperBound: upperBound,
            sourceCitation: "Evidence review pending",
            populationDescription: "Population context required before release",
            rulesetVersion: 1,
            limitations: "This comparison range is not a diagnosis or universal target."
        )
    }

    private func makeResult(
        side: MobilityAssessmentSide = .left,
        value: Double? = 42,
        criteria: MobilityAssessmentCriteriaObservation? = nil,
        unit: MobilityMeasurementUnit = .degrees,
        version: Int = 1,
        setupKey: String = "seated-90-90",
        createdAt: Date = .now
    ) -> MobilityAssessmentResult {
        let definition = MobilityAssessmentSeedData.definitions[5].makeDefinition()
        let input = MobilityAssessmentResultInput(
            numericValue: value,
            criteria: criteria,
            side: side,
            isWarm: false,
            setupKey: setupKey,
            method: unit == .criteria ? .manualCriteria : .manualAngle,
            unit: unit,
            isActiveRange: false,
            day: LocalDay(rawValue: "2026-08-09"),
            source: .manual,
            confidence: .moderate
        )
        let result = MobilityAssessmentResult(
            definition: definition,
            input: input,
            orderIndex: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        result.definitionCatalogueKeySnapshot = "hip-ir-seated-v1"
        result.definitionVersionSnapshot = version
        return result
    }

    private func makeEvidence(
        position: MobilityReferenceBandPosition,
        unit: MobilityMeasurementUnit = .degrees,
        lowerBound: Double? = 40,
        upperBound: Double? = 60
    ) -> MobilityAssessmentProfileBandEvidence {
        MobilityAssessmentProfileBandEvidence(
            position: position,
            lowerBound: lowerBound,
            upperBound: upperBound,
            unit: unit,
            rulesetVersion: 1,
            sourceCitation: "Evidence review pending",
            populationDescription: "Population context required before release",
            limitations: "This comparison range is not a diagnosis or universal target."
        )
    }
}
