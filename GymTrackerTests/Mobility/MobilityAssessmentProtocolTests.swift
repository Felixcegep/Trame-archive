import XCTest
@testable import GymTracker

final class MobilityAssessmentProtocolTests: XCTestCase {
    func testExactManualProtocolIsValid() {
        XCTAssertNil(makeProtocol().validate())
        XCTAssertEqual(makeProtocol().id, "hip-ir-seated-v1")
    }

    func testProtocolRejectsAlternativeSetupsInOneIdentity() {
        let protocolValue = makeProtocol(protocolID: "hip-ir-prone-or-seated-v1")
        XCTAssertEqual(protocolValue.validate(), .protocolIDContainsAlternativeSetup)
    }

    func testDeviceProtocolRequiresPlacement() {
        let protocolValue = makeProtocol(preferredMethod: .deviceMotion, placement: nil)
        XCTAssertEqual(protocolValue.validate(), .missingPlacementForDeviceMethod)
    }

    func testProtocolRejectsInvalidMeasurementError() {
        let protocolValue = makeProtocol(
            measurementError: MobilityAssessmentMeasurementError(
                standardErrorOfMeasurement: -.infinity
            )
        )
        XCTAssertEqual(protocolValue.validate(), .invalidMeasurementError)
    }

    func testProtocolIdentityIncludesConditionsThatChangeMeaning() {
        let manual = makeProtocol()
        let device = makeProtocol(preferredMethod: .deviceMotion, placement: "shin")
        XCTAssertNotEqual(
            MobilityAssessmentProtocolIdentity(manual),
            MobilityAssessmentProtocolIdentity(device)
        )
    }

    private func makeProtocol(
        protocolID: String = "hip-ir-seated-v1",
        preferredMethod: MobilityAssessmentProtocol.Method = .manual,
        placement: String? = "",
        measurementError: MobilityAssessmentMeasurementError? = nil
    ) -> MobilityAssessmentProtocol {
        MobilityAssessmentProtocol(
            protocolID: protocolID,
            protocolVersion: 1,
            measurement: "Hip internal rotation range",
            testName: "Hip internal rotation, seated",
            position: "Seated",
            jointPosition: "Hip and knee at 90 degrees",
            side: .left,
            unit: .degrees,
            activePassive: .passive,
            recordsWarmCold: true,
            preferredMethod: preferredMethod,
            manualFallback: true,
            placement: placement,
            reliabilitySource: "Evidence review pending",
            measurementError: measurementError,
            limitations: "This observation does not diagnose a condition."
        )
    }
}
