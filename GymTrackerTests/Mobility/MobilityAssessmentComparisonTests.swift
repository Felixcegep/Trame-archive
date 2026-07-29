import XCTest
@testable import GymTracker

@MainActor
final class MobilityAssessmentComparisonTests: XCTestCase {
    func testMatchingConditionsProduceANeutralNumericDelta() {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let previous = makeResult(definition: definition, value: 41, createdAt: Date(timeIntervalSince1970: 1))
        let current = makeResult(definition: definition, value: 47, createdAt: Date(timeIntervalSince1970: 2))

        let comparison = MobilityAssessmentComparisonService.compare(
            current: current,
            previous: previous
        )
        XCTAssertEqual(comparison.comparability, .direct)
        XCTAssertEqual(comparison.numericDelta, 6)
        XCTAssertTrue(comparison.differingConditions.isEmpty)
    }

    func testEveryConditionIndependentlyPreventsDirectComparison() {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let baseline = makeResult(definition: definition)
        let cases: [(MobilityAssessmentConditionDifference, (MobilityAssessmentResult) -> Void)] = [
            (.definition, { $0.definitionCatalogueKeySnapshot = "different" }),
            (.side, { $0.side = .right }),
            (.setup, { $0.setupKey = "different" }),
            (.method, { $0.method = .manualLinear }),
            (.unit, { $0.unit = .centimetres }),
            (.activePassive, { $0.isActiveRange.toggle() }),
            (.warmCold, { $0.isWarm.toggle() })
        ]

        for (expected, mutate) in cases {
            let candidate = makeResult(definition: definition)
            mutate(candidate)
            let comparison = MobilityAssessmentComparisonService.compare(
                current: baseline,
                previous: candidate
            )
            XCTAssertEqual(comparison.comparability, .notDirect)
            XCTAssertNil(comparison.numericDelta)
            XCTAssertEqual(comparison.differingConditions, [expected])
        }
    }

    func testLatestComparisonSkipsNewerNonComparableObservation() {
        let definition = MobilityAssessmentSeedData.definitions[0].makeDefinition()
        let comparable = makeResult(
            definition: definition,
            value: 30,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newerWarm = makeResult(
            definition: definition,
            value: 35,
            isWarm: true,
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let current = makeResult(
            definition: definition,
            value: 40,
            createdAt: Date(timeIntervalSince1970: 3)
        )

        let comparison = MobilityAssessmentComparisonService.latestComparison(
            for: current,
            among: [newerWarm, comparable, current]
        )
        XCTAssertEqual(comparison.previousResultID, comparable.id)
        XCTAssertEqual(comparison.numericDelta, 10)
    }

    private func makeResult(
        definition: MobilityAssessmentDefinition,
        value: Double = 42,
        isWarm: Bool = false,
        createdAt: Date = .now
    ) -> MobilityAssessmentResult {
        MobilityAssessmentResult(
            definition: definition,
            input: MobilityAssessmentResultInput(
                numericValue: value,
                side: .left,
                isWarm: isWarm,
                setupKey: definition.defaultSetupKey,
                method: definition.manualMode,
                unit: definition.unit,
                isActiveRange: definition.defaultIsActiveRange,
                day: LocalDay(rawValue: "2026-07-29")
            ),
            orderIndex: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
