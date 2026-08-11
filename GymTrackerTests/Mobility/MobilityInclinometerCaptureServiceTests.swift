import CoreMotion
import XCTest
@testable import GymTracker

final class MobilityInclinometerStableHoldEvaluatorTests: XCTestCase {
    func testGravityReferencedPitchRequiresStableThreeSecondMedian() {
        let configuration = MobilityInclinometerCaptureConfiguration(
            axis: .pitch,
            mode: .gravityReferenced
        )
        var evaluator = MobilityInclinometerStableHoldEvaluator(
            configuration: configuration,
            baseline: try! XCTUnwrap(MobilityInclinometerBaseline(sample: sample(at: 0)))
        )

        for (index, pitch) in [29.0, 31.0, 30.0, 29.5, 30.5, 30.0, 30.0].enumerated() {
            let result = evaluator.consume(sample(at: Double(index) * 0.5, pitch: pitch))
            if index == 6 {
                guard case let .accepted(valueDegrees, holdProgress) = result else {
                    return XCTFail("Expected an accepted stable hold")
                }
                XCTAssertEqual(valueDegrees, 30, accuracy: 0.001)
                XCTAssertEqual(holdProgress, 1, accuracy: 0.001)
            }
        }

        XCTAssertEqual(evaluator.bestValueDegrees ?? .nan, 30, accuracy: 0.001)
    }

    func testGravityReferencedPitchUsesANonZeroGravityBaseline() {
        let configuration = MobilityInclinometerCaptureConfiguration(
            axis: .pitch,
            mode: .gravityReferenced,
            stableWindow: 1
        )
        var evaluator = MobilityInclinometerStableHoldEvaluator(
            configuration: configuration,
            baseline: try! XCTUnwrap(MobilityInclinometerBaseline(sample: sample(at: 0, pitch: 10)))
        )

        _ = evaluator.consume(sample(at: 0.1, pitch: 40))
        let result = evaluator.consume(sample(at: 1.1, pitch: 40))

        XCTAssertEqual(result, .accepted(valueDegrees: 30, holdProgress: 1))
        XCTAssertEqual(evaluator.bestValueDegrees ?? .nan, 30, accuracy: 0.001)
    }

    func testRejectedMotionClearsTheCurrentHold() {
        let configuration = MobilityInclinometerCaptureConfiguration(
            axis: .pitch,
            mode: .gravityReferenced
        )
        var evaluator = MobilityInclinometerStableHoldEvaluator(
            configuration: configuration,
            baseline: try! XCTUnwrap(MobilityInclinometerBaseline(sample: sample(at: 0)))
        )

        _ = evaluator.consume(sample(at: 0.1, pitch: 25))
        XCTAssertEqual(
            evaluator.consume(sample(at: 0.2, pitch: 25, roll: 15)),
            .rejected(.offAxis)
        )
        XCTAssertEqual(
            evaluator.consume(sample(at: 0.3, pitch: 25, userAcceleration: 0.2)),
            .rejected(.userAcceleration)
        )
        XCTAssertEqual(
            evaluator.consume(sample(at: 0.4, pitch: 25, rotationRate: 0.2)),
            .rejected(.rotationRate)
        )
        XCTAssertNil(evaluator.bestValueDegrees)
    }

    func testBestQualifyingMedianIsRetainedAcrossMultipleHolds() {
        let configuration = MobilityInclinometerCaptureConfiguration(
            axis: .pitch,
            mode: .gravityReferenced,
            stableWindow: 1
        )
        var evaluator = MobilityInclinometerStableHoldEvaluator(
            configuration: configuration,
            baseline: try! XCTUnwrap(MobilityInclinometerBaseline(sample: sample(at: 0)))
        )

        _ = evaluator.consume(sample(at: 0, pitch: 20))
        _ = evaluator.consume(sample(at: 1, pitch: 20))
        _ = evaluator.consume(sample(at: 2, pitch: 30))
        _ = evaluator.consume(sample(at: 3, pitch: 30))

        XCTAssertEqual(evaluator.bestValueDegrees ?? .nan, 30, accuracy: 0.001)
    }

    func testRelativeYawUsesAttitudeBaselineAndRejectsOffAxisMovement() {
        let configuration = MobilityInclinometerCaptureConfiguration(
            axis: .yaw,
            mode: .relativeRotation,
            stableWindow: 1
        )
        let baselineSample = sample(at: 0, yaw: 10)
        var evaluator = MobilityInclinometerStableHoldEvaluator(
            configuration: configuration,
            baseline: try! XCTUnwrap(MobilityInclinometerBaseline(sample: baselineSample))
        )

        XCTAssertEqual(
            evaluator.consume(sample(at: 0.5, yaw: 40)),
            .accepted(valueDegrees: 30, holdProgress: 0)
        )
        XCTAssertEqual(
            evaluator.consume(sample(at: 1.5, yaw: 40)),
            .accepted(valueDegrees: 30, holdProgress: 1)
        )
        XCTAssertEqual(
            evaluator.consume(sample(at: 1.6, pitch: 13, yaw: 40)),
            .rejected(.offAxis)
        )
    }

    private func sample(
        at timestamp: TimeInterval,
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0,
        userAcceleration: Double = 0,
        rotationRate: Double = 0
    ) -> MobilityInclinometerMotionSample {
        let pitchRadians = pitch * .pi / 180
        let rollRadians = roll * .pi / 180
        return MobilityInclinometerMotionSample(
            timestamp: timestamp,
            pitchDegrees: pitch,
            rollDegrees: roll,
            yawDegrees: yaw,
            gravityX: -sin(pitchRadians),
            gravityY: sin(rollRadians),
            gravityZ: -cos(pitchRadians) * cos(rollRadians),
            rotationRateX: rotationRate,
            userAccelerationX: userAcceleration
        )
    }
}

@MainActor
final class MobilityInclinometerCaptureServiceTests: XCTestCase {
    func testUnavailableHardwareImmediatelyRequiresManualFallbackAndStopsUpdates() {
        let manager = FakeMotionManager(deviceMotionAvailable: false, gyroAvailable: false)
        let service = MobilityInclinometerCaptureService(motionManager: manager)

        service.startMeasurement(configuration: gravityConfiguration)

        XCTAssertEqual(service.state, .unavailable(reason: .deviceMotionUnavailable))
        XCTAssertEqual(
            service.lastError,
            .manualFallbackRequired(.deviceMotionUnavailable)
        )
        XCTAssertEqual(manager.stopCount, 1)
        XCTAssertFalse(manager.didStart)
    }

    func testGravityModeDoesNotRequireGyroscopeAvailability() {
        let manager = FakeMotionManager(gyroAvailable: false)
        let service = MobilityInclinometerCaptureService(motionManager: manager)

        service.startMeasurement(configuration: gravityConfiguration)

        XCTAssertEqual(service.state, .calibrating)
        XCTAssertTrue(manager.didStart)
        service.cancelMeasurement()
    }

    func testStopAfterAStableHoldPublishesResultAndStopsUpdates() {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)

        service.consume(sample(at: 0))
        service.consume(sample(at: 0.1, pitch: 25))
        service.consume(sample(at: 3.1, pitch: 25))
        service.stopMeasurement()

        XCTAssertEqual(
            service.state,
            .completed(axis: .pitch, valueDegrees: 25)
        )
        XCTAssertEqual(manager.stopCount, 1)
    }

    func testCancelRequiresManualFallbackAndStopsUpdates() {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)
        service.cancelMeasurement()

        XCTAssertEqual(service.state, .unavailable(reason: .cancelled))
        XCTAssertEqual(manager.stopCount, 1)
    }

    func testFiniteConfigurationIsRejectedWithAStableReason() {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        let invalid = MobilityInclinometerCaptureConfiguration(
            axis: .pitch,
            mode: .gravityReferenced,
            timeout: .infinity
        )

        service.startMeasurement(configuration: invalid)

        XCTAssertEqual(service.state, .unavailable(reason: .invalidConfiguration))
        XCTAssertEqual(service.lastError, .manualFallbackRequired(.invalidConfiguration))
        XCTAssertFalse(manager.didStart)
    }

    func testCalibrationRequiresGravitySourceAndDoesNotUseAttitudeFallback() {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)

        service.consume(
            MobilityInclinometerMotionSample(
                timestamp: 0,
                pitchDegrees: 20,
                rollDegrees: 10,
                yawDegrees: 0,
                gravityX: 0,
                gravityY: 0,
                gravityZ: 0
            )
        )

        XCTAssertEqual(service.state, .unavailable(reason: .calibrationUnavailable))
        XCTAssertEqual(service.lastError, .manualFallbackRequired(.calibrationUnavailable))
    }

    func testRejectedSampleIsExposedWithoutAZeroAngleSentinel() {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)

        service.consume(sample(at: 0))
        service.consume(sample(at: 0.1, pitch: 25, roll: 15))

        XCTAssertEqual(service.state, .rejected(reason: .offAxis))
    }

    func testTerminalFallbackReasonIsIdempotent() {
        let manager = FakeMotionManager(deviceMotionAvailable: false, gyroAvailable: false)
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)

        service.cancelMeasurement()

        XCTAssertEqual(service.state, .unavailable(reason: .deviceMotionUnavailable))
        XCTAssertEqual(
            service.lastError,
            .manualFallbackRequired(.deviceMotionUnavailable)
        )
    }

    func testStaleCallbackCannotTerminateANewGeneration() async {
        let manager = FakeMotionManager()
        let service = MobilityInclinometerCaptureService(motionManager: manager)
        service.startMeasurement(configuration: gravityConfiguration)
        let staleHandler = try! XCTUnwrap(manager.handlers.first)

        service.startMeasurement(configuration: gravityConfiguration)
        staleHandler(nil, NSError(domain: "stale", code: 1))
        await Task.yield()

        XCTAssertEqual(service.state, .calibrating)
        XCTAssertNil(service.lastError)
    }

    private var gravityConfiguration: MobilityInclinometerCaptureConfiguration {
        MobilityInclinometerCaptureConfiguration(axis: .pitch, mode: .gravityReferenced)
    }

    private func sample(
        at timestamp: TimeInterval,
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0
    ) -> MobilityInclinometerMotionSample {
        let pitchRadians = pitch * .pi / 180
        let rollRadians = roll * .pi / 180
        return MobilityInclinometerMotionSample(
            timestamp: timestamp,
            pitchDegrees: pitch,
            rollDegrees: roll,
            yawDegrees: yaw,
            gravityX: -sin(pitchRadians),
            gravityY: sin(rollRadians),
            gravityZ: -cos(pitchRadians) * cos(rollRadians)
        )
    }
}

private final class FakeMotionManager: MobilityDeviceMotionManaging {
    let isDeviceMotionAvailable: Bool
    let isAccelerometerAvailable: Bool
    let isGyroAvailable: Bool
    var deviceMotionUpdateInterval: TimeInterval = 0
    private(set) var didStart = false
    private(set) var stopCount = 0
    private(set) var handlers: [CMDeviceMotionHandler] = []

    init(
        deviceMotionAvailable: Bool = true,
        accelerometerAvailable: Bool = true,
        gyroAvailable: Bool = true
    ) {
        isDeviceMotionAvailable = deviceMotionAvailable
        isAccelerometerAvailable = accelerometerAvailable
        isGyroAvailable = gyroAvailable
    }

    func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {
        didStart = true
        handlers.append(handler)
    }

    func stopDeviceMotionUpdates() {
        stopCount += 1
    }
}
