import XCTest
@testable import GymTracker

final class MobilityInclinometerDefinitionRegistryTests: XCTestCase {
    func testRegistryMapsOnlyAuthoredDegreeBasedDefinitions() {
        let thoracic = MobilityInclinometerDefinitionRegistry.definition(
            catalogueKey: "mobility-assessment.thoracic-rotation-seated",
            unit: .degrees,
            preferredMode: .axialRotation
        )
        XCTAssertEqual(thoracic?.axis, .yaw)
        XCTAssertEqual(thoracic?.mode, .relativeRotation)
        XCTAssertFalse(thoracic?.placementGuidance.isEmpty ?? true)
        XCTAssertEqual(thoracic?.resultDegrees(from: -42.5), 42.5)
        XCTAssertEqual(thoracic?.resultDegrees(from: 220), 180)

        let legRaise = MobilityInclinometerDefinitionRegistry.definition(
            catalogueKey: "mobility-assessment.active-straight-leg-raise",
            unit: .degrees,
            preferredMode: .inclinometer
        )
        XCTAssertEqual(legRaise?.axis, .pitch)
        XCTAssertEqual(legRaise?.mode, .gravityReferenced)
    }

    func testRegistryLeavesLinearAndUncertainDefinitionsManual() {
        XCTAssertNil(
            MobilityInclinometerDefinitionRegistry.definition(
                catalogueKey: "mobility-assessment.knee-to-wall-dorsiflexion",
                unit: .centimetres,
                preferredMode: .inclinometer
            )
        )
        XCTAssertNil(
            MobilityInclinometerDefinitionRegistry.definition(
                catalogueKey: "mobility-assessment.90-90-hip-rotation",
                unit: .degrees,
                preferredMode: .inclinometer
            )
        )
        XCTAssertNil(
            MobilityInclinometerDefinitionRegistry.definition(
                catalogueKey: "unknown",
                unit: .degrees,
                preferredMode: .inclinometer
            )
        )
    }
}
