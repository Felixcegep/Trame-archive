import Combine
import CoreMotion
import Foundation

/// The phone axis that is being measured. Pitch and roll are gravity
/// referenced; yaw is only valid as a short relative-attitude capture.
enum MobilityInclinometerAxis: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case pitch
    case roll
    case yaw
}

enum MobilityInclinometerCaptureMode: String, Codable, Equatable, Sendable {
    case gravityReferenced
    case relativeRotation
}

enum MobilityInclinometerFallbackReason: String, Codable, Equatable, Sendable {
    case invalidConfiguration
    case deviceMotionUnavailable
    case unsupportedAxis
    case calibrationUnavailable
    case noStableHold
    case timedOut
    case motionError
    case cancelled
}

enum MobilityInclinometerCaptureError: Error, Equatable, Sendable {
    case manualFallbackRequired(MobilityInclinometerFallbackReason)
}

enum InclinometerCaptureState: Equatable, Sendable {
    case idle
    case calibrating
    case measuring(axisDegrees: Double, holdProgress: Double)
    case rejected(reason: MobilityInclinometerSampleRejection)
    case completed(axis: MobilityInclinometerAxis, valueDegrees: Double)
    case unavailable(reason: MobilityInclinometerFallbackReason)
}

/// The small, Foundation-only value passed from Core Motion to the evaluator.
/// Keeping this separate from CMDeviceMotion makes the hold policy deterministic
/// and prevents tests from depending on real hardware or simulator motion.
struct MobilityInclinometerMotionSample: Equatable, Sendable {
    let timestamp: TimeInterval
    let pitchDegrees: Double
    let rollDegrees: Double
    let yawDegrees: Double
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double
    let rotationRateX: Double
    let rotationRateY: Double
    let rotationRateZ: Double
    let userAccelerationX: Double
    let userAccelerationY: Double
    let userAccelerationZ: Double

    nonisolated init(
        timestamp: TimeInterval,
        pitchDegrees: Double,
        rollDegrees: Double,
        yawDegrees: Double,
        gravityX: Double = 0,
        gravityY: Double = 0,
        gravityZ: Double = -1,
        rotationRateX: Double = 0,
        rotationRateY: Double = 0,
        rotationRateZ: Double = 0,
        userAccelerationX: Double = 0,
        userAccelerationY: Double = 0,
        userAccelerationZ: Double = 0
    ) {
        self.timestamp = timestamp
        self.pitchDegrees = pitchDegrees
        self.rollDegrees = rollDegrees
        self.yawDegrees = yawDegrees
        self.gravityX = gravityX
        self.gravityY = gravityY
        self.gravityZ = gravityZ
        self.rotationRateX = rotationRateX
        self.rotationRateY = rotationRateY
        self.rotationRateZ = rotationRateZ
        self.userAccelerationX = userAccelerationX
        self.userAccelerationY = userAccelerationY
        self.userAccelerationZ = userAccelerationZ
    }

    nonisolated init(motion: CMDeviceMotion) {
        self.init(
            timestamp: motion.timestamp,
            pitchDegrees: motion.attitude.pitch.radiansToDegrees,
            rollDegrees: motion.attitude.roll.radiansToDegrees,
            yawDegrees: motion.attitude.yaw.radiansToDegrees,
            gravityX: motion.gravity.x,
            gravityY: motion.gravity.y,
            gravityZ: motion.gravity.z,
            rotationRateX: motion.rotationRate.x,
            rotationRateY: motion.rotationRate.y,
            rotationRateZ: motion.rotationRate.z,
            userAccelerationX: motion.userAcceleration.x,
            userAccelerationY: motion.userAcceleration.y,
            userAccelerationZ: motion.userAcceleration.z
        )
    }

    var rotationRateMagnitude: Double {
        vectorMagnitude(rotationRateX, rotationRateY, rotationRateZ)
    }

    var userAccelerationMagnitude: Double {
        vectorMagnitude(userAccelerationX, userAccelerationY, userAccelerationZ)
    }

    var isFinite: Bool {
        [
            timestamp, pitchDegrees, rollDegrees, yawDegrees,
            gravityX, gravityY, gravityZ,
            rotationRateX, rotationRateY, rotationRateZ,
            userAccelerationX, userAccelerationY, userAccelerationZ
        ].allSatisfy { $0.isFinite }
    }

    /// Gravity provides an absolute, drift-free pitch/roll reference. Yaw is
    /// intentionally not inferred from gravity because gravity has no yaw
    /// information; it is supplied by the fused attitude for relative capture.
    func gravityReferencedAngle(for axis: MobilityInclinometerAxis) -> Double? {
        let denominator: Double
        switch axis {
        case .pitch:
            denominator = hypot(gravityY, gravityZ)
            guard denominator > 0 else { return nil }
            return atan2(-gravityX, denominator).radiansToDegrees
        case .roll:
            denominator = hypot(gravityX, gravityZ)
            guard denominator > 0 else { return nil }
            return atan2(gravityY, denominator).radiansToDegrees
        case .yaw:
            return nil
        }
    }

    func attitudeAngle(for axis: MobilityInclinometerAxis) -> Double {
        switch axis {
        case .pitch: return pitchDegrees
        case .roll: return rollDegrees
        case .yaw: return yawDegrees
        }
    }

    private func vectorMagnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt((x * x) + (y * y) + (z * z))
    }
}

private extension Double {
    nonisolated var radiansToDegrees: Double { self * 180 / .pi }
}

struct MobilityInclinometerCaptureConfiguration: Equatable, Sendable {
    let axis: MobilityInclinometerAxis
    let mode: MobilityInclinometerCaptureMode
    let stableWindow: TimeInterval
    let holdToleranceDegrees: Double
    let offAxisToleranceDegrees: Double
    let userAccelerationToleranceG: Double
    let rotationRateToleranceRadiansPerSecond: Double
    let timeout: TimeInterval
    let updateInterval: TimeInterval

    init(
        axis: MobilityInclinometerAxis,
        mode: MobilityInclinometerCaptureMode,
        stableWindow: TimeInterval = 3,
        holdToleranceDegrees: Double = 2.5,
        offAxisToleranceDegrees: Double = 12,
        userAccelerationToleranceG: Double = 0.08,
        rotationRateToleranceRadiansPerSecond: Double = 0.15,
        timeout: TimeInterval = 15,
        updateInterval: TimeInterval = 1.0 / 50.0
    ) {
        self.axis = axis
        self.mode = mode
        self.stableWindow = stableWindow
        self.holdToleranceDegrees = holdToleranceDegrees
        self.offAxisToleranceDegrees = offAxisToleranceDegrees
        self.userAccelerationToleranceG = userAccelerationToleranceG
        self.rotationRateToleranceRadiansPerSecond = rotationRateToleranceRadiansPerSecond
        self.timeout = timeout
        self.updateInterval = updateInterval
    }

    var validationError: MobilityInclinometerFallbackReason? {
        switch (mode, axis) {
        case (.gravityReferenced, .yaw), (.relativeRotation, .pitch), (.relativeRotation, .roll):
            return .unsupportedAxis
        default:
            break
        }

        let numericValues = [
            stableWindow,
            holdToleranceDegrees,
            offAxisToleranceDegrees,
            userAccelerationToleranceG,
            rotationRateToleranceRadiansPerSecond,
            timeout,
            updateInterval
        ]
        guard numericValues.allSatisfy(\.isFinite),
              stableWindow > 0,
              holdToleranceDegrees > 0,
              offAxisToleranceDegrees >= 0,
              userAccelerationToleranceG >= 0,
              rotationRateToleranceRadiansPerSecond >= 0,
              timeout >= stableWindow,
              timeout <= (Double(UInt64.max) / 1_000_000_000),
              updateInterval > 0
        else {
            return .invalidConfiguration
        }
        return nil
    }
}

struct MobilityInclinometerBaseline: Equatable, Sendable {
    let pitchDegrees: Double
    let rollDegrees: Double
    let yawDegrees: Double

    init?(sample: MobilityInclinometerMotionSample) {
        // Calibration and measurement must use the same gravity-derived
        // coordinate system. Fused attitude pitch/roll may contain a frame
        // offset that would make a non-level baseline inconsistent.
        guard let pitch = sample.gravityReferencedAngle(for: .pitch),
              let roll = sample.gravityReferencedAngle(for: .roll)
        else { return nil }
        pitchDegrees = pitch
        rollDegrees = roll
        yawDegrees = sample.attitudeAngle(for: .yaw)
    }

    func relativeAngle(for axis: MobilityInclinometerAxis, in sample: MobilityInclinometerMotionSample) -> Double {
        let raw = sample.attitudeAngle(for: axis)
        let reference: Double
        switch axis {
        case .pitch: reference = pitchDegrees
        case .roll: reference = rollDegrees
        case .yaw: reference = yawDegrees
        }
        return Self.wrappedDegrees(raw - reference)
    }

    static func wrappedDegrees(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result
    }
}

enum MobilityInclinometerSampleRejection: Equatable, Sendable {
    case nonFinite
    case userAcceleration
    case rotationRate
    case offAxis
    case unavailableAngle
}

enum MobilityInclinometerEvaluation: Equatable, Sendable {
    case accepted(valueDegrees: Double, holdProgress: Double)
    case rejected(MobilityInclinometerSampleRejection)
}

/// Pure stable-hold policy. Invalid samples clear the current hold; a noisy
/// peak can therefore never become the recorded value. The best qualifying
/// median is retained so a caller can stop after several valid holds.
struct MobilityInclinometerStableHoldEvaluator: Sendable {
    private struct Value: Sendable {
        let timestamp: TimeInterval
        let degrees: Double
    }

    let configuration: MobilityInclinometerCaptureConfiguration
    let baseline: MobilityInclinometerBaseline
    private(set) var bestValueDegrees: Double?
    private var values: [Value] = []

    init(
        configuration: MobilityInclinometerCaptureConfiguration,
        baseline: MobilityInclinometerBaseline
    ) {
        self.configuration = configuration
        self.baseline = baseline
        bestValueDegrees = nil
    }

    mutating func consume(_ sample: MobilityInclinometerMotionSample) -> MobilityInclinometerEvaluation {
        guard sample.isFinite else {
            values.removeAll(keepingCapacity: true)
            return .rejected(.nonFinite)
        }
        guard sample.userAccelerationMagnitude <= configuration.userAccelerationToleranceG else {
            values.removeAll(keepingCapacity: true)
            return .rejected(.userAcceleration)
        }
        guard sample.rotationRateMagnitude <= configuration.rotationRateToleranceRadiansPerSecond else {
            values.removeAll(keepingCapacity: true)
            return .rejected(.rotationRate)
        }

        guard let angle = measuredAngle(for: sample), angle.isFinite else {
            values.removeAll(keepingCapacity: true)
            return .rejected(.unavailableAngle)
        }
        guard offAxisDegrees(for: sample) <= configuration.offAxisToleranceDegrees else {
            values.removeAll(keepingCapacity: true)
            return .rejected(.offAxis)
        }

        values.append(Value(timestamp: sample.timestamp, degrees: angle))
        let cutoff = sample.timestamp - configuration.stableWindow
        // Preserve an exact boundary sample despite floating-point subtraction
        // noise (for example 1.1 - 1.0 becoming 0.10000000000000009).
        values.removeAll { $0.timestamp < cutoff - 1e-9 }

        guard let first = values.first else {
            return .accepted(valueDegrees: angle, holdProgress: 0)
        }

        let elapsed = max(0, sample.timestamp - first.timestamp)
        let progress = min(1, elapsed / configuration.stableWindow)
        guard elapsed >= configuration.stableWindow else {
            return .accepted(valueDegrees: angle, holdProgress: progress)
        }

        let sorted = values.map(\.degrees).sorted()
        guard let low = sorted.first, let high = sorted.last,
              high - low <= configuration.holdToleranceDegrees * 2
        else {
            // Start a new candidate hold at the current sample. Retaining the
            // old noisy values could prevent a later stable hold qualifying.
            values = [Value(timestamp: sample.timestamp, degrees: angle)]
            return .accepted(valueDegrees: angle, holdProgress: 0)
        }

        let median = Self.median(sorted)
        if bestValueDegrees == nil || median > bestValueDegrees! {
            bestValueDegrees = median
        }
        return .accepted(valueDegrees: median, holdProgress: 1)
    }

    /// The signed device angle relative to this capture's calibrated baseline.
    /// This is intentionally available before hold acceptance so the UI can
    /// track the phone directly while the evaluator independently decides
    /// whether the sample is stable enough to record.
    func measuredAngle(for sample: MobilityInclinometerMotionSample) -> Double? {
        switch configuration.mode {
        case .gravityReferenced:
            guard let raw = sample.gravityReferencedAngle(for: configuration.axis) else { return nil }
            let baselineAngle: Double
            switch configuration.axis {
            case .pitch: baselineAngle = baseline.pitchDegrees
            case .roll: baselineAngle = baseline.rollDegrees
            case .yaw: return nil
            }
            return MobilityInclinometerBaseline.wrappedDegrees(raw - baselineAngle)
        case .relativeRotation:
            return baseline.relativeAngle(for: configuration.axis, in: sample)
        }
    }

    private func offAxisDegrees(for sample: MobilityInclinometerMotionSample) -> Double {
        let pitch = MobilityInclinometerBaseline.wrappedDegrees(
            (sample.gravityReferencedAngle(for: .pitch) ?? sample.pitchDegrees) - baseline.pitchDegrees
        )
        let roll = MobilityInclinometerBaseline.wrappedDegrees(
            (sample.gravityReferencedAngle(for: .roll) ?? sample.rollDegrees) - baseline.rollDegrees
        )
        let yaw = MobilityInclinometerBaseline.wrappedDegrees(sample.yawDegrees - baseline.yawDegrees)

        switch configuration.axis {
        case .pitch:
            return hypot(roll, yaw)
        case .roll:
            return hypot(pitch, yaw)
        case .yaw:
            return hypot(pitch, roll)
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }
}

/// Protocol boundary around CMMotionManager. It keeps the single shared
/// production manager injectable without making tests construct CMDeviceMotion.
protocol MobilityDeviceMotionManaging: AnyObject {
    var isDeviceMotionAvailable: Bool { get }
    var isAccelerometerAvailable: Bool { get }
    var isGyroAvailable: Bool { get }
    var deviceMotionUpdateInterval: TimeInterval { get set }

    func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler)
    func stopDeviceMotionUpdates()
}

final class MobilityCoreMotionManager: MobilityDeviceMotionManaging {
    static let shared = MobilityCoreMotionManager()

    private let manager: CMMotionManager

    init(manager: CMMotionManager = CMMotionManager()) {
        self.manager = manager
    }

    var isDeviceMotionAvailable: Bool { manager.isDeviceMotionAvailable }
    var isAccelerometerAvailable: Bool { manager.isAccelerometerAvailable }
    var isGyroAvailable: Bool { manager.isGyroAvailable }
    var deviceMotionUpdateInterval: TimeInterval {
        get { manager.deviceMotionUpdateInterval }
        set { manager.deviceMotionUpdateInterval = newValue }
    }

    func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {
        // Yaw is used only as a short relative rotation. Pinning the reference
        // frame makes that contract explicit and avoids magnetometer-dependent
        // headings in a gym environment.
        manager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: queue,
            withHandler: handler
        )
    }

    func stopDeviceMotionUpdates() {
        manager.stopDeviceMotionUpdates()
    }
}

@MainActor
final class MobilityInclinometerCaptureService: ObservableObject {
    @Published private(set) var state: InclinometerCaptureState = .idle
    @Published private(set) var lastError: MobilityInclinometerCaptureError?
    /// Live signed device rotation for visual feedback only. Persisted results
    /// still come exclusively from the stable-hold evaluator.
    @Published private(set) var liveAngleDegrees: Double?

    private let motionManager: MobilityDeviceMotionManaging
    private var evaluator: MobilityInclinometerStableHoldEvaluator?
    private var configuration: MobilityInclinometerCaptureConfiguration?
    private var timeoutTask: Task<Void, Never>?
    private var captureStartedAt: TimeInterval?
    private var isUpdating = false
    private var captureGeneration: UInt64 = 0

    init(motionManager: MobilityDeviceMotionManaging? = nil) {
        self.motionManager = motionManager ?? MobilityCoreMotionManager.shared
    }

    func startMeasurement(configuration: MobilityInclinometerCaptureConfiguration) {
        captureGeneration &+= 1
        let generation = captureGeneration
        stopUpdates()
        timeoutTask?.cancel()
        timeoutTask = nil
        evaluator = nil
        self.configuration = configuration
        captureStartedAt = nil
        lastError = nil
        liveAngleDegrees = nil
        state = .idle

        let requiredHardwareAvailable: Bool
        switch configuration.mode {
        case .gravityReferenced:
            requiredHardwareAvailable = motionManager.isDeviceMotionAvailable
                && motionManager.isAccelerometerAvailable
        case .relativeRotation:
            requiredHardwareAvailable = motionManager.isDeviceMotionAvailable
                && motionManager.isGyroAvailable
        }
        guard configuration.validationError == nil, requiredHardwareAvailable
        else {
            finishWithFallback(
                configuration.validationError ?? .deviceMotionUnavailable
            )
            return
        }

        state = .calibrating
        motionManager.deviceMotionUpdateInterval = configuration.updateInterval
        isUpdating = true
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            // CMDeviceMotion is not Sendable. Convert it on the Core Motion
            // callback queue before crossing into the main actor.
            let sample = motion.map(MobilityInclinometerMotionSample.init)
            let hasError = error != nil
            Task { @MainActor [weak self] in
                guard let self,
                      self.captureGeneration == generation,
                      self.isCaptureActive
                else { return }
                if hasError {
                    self.finishWithFallback(.motionError)
                } else if let sample {
                    self.consume(sample)
                }
            }
        }

        let timeout = configuration.timeout
        timeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            } catch {
                return
            }
            guard let self,
                  self.captureGeneration == generation,
                  self.isCaptureActive
            else { return }
            self.finishWithFallback(.timedOut)
        }
    }

    /// Feeds a processed sample into the same path used by the Core Motion
    /// callback. This is intentionally public and UI-neutral for deterministic
    /// tests and future sensor diagnostics.
    func consume(_ sample: MobilityInclinometerMotionSample) {
        guard let configuration, isCaptureActive else { return }
        if captureStartedAt == nil { captureStartedAt = sample.timestamp }
        if sample.timestamp - (captureStartedAt ?? sample.timestamp) >= configuration.timeout {
            finishWithFallback(.timedOut)
            return
        }

        guard let currentEvaluator = evaluator else {
            guard sample.isFinite,
                  sample.userAccelerationMagnitude <= configuration.userAccelerationToleranceG,
                  sample.rotationRateMagnitude <= configuration.rotationRateToleranceRadiansPerSecond
            else { return }
            guard let baseline = MobilityInclinometerBaseline(sample: sample) else {
                finishWithFallback(.calibrationUnavailable)
                return
            }
            self.evaluator = MobilityInclinometerStableHoldEvaluator(
                configuration: configuration,
                baseline: baseline
            )
            liveAngleDegrees = 0
            state = .measuring(axisDegrees: 0, holdProgress: 0)
            return
        }

        var updatedEvaluator = currentEvaluator
        if let liveAngle = updatedEvaluator.measuredAngle(for: sample), liveAngle.isFinite {
            liveAngleDegrees = liveAngle
        }
        let result = updatedEvaluator.consume(sample)
        self.evaluator = updatedEvaluator
        switch result {
        case let .accepted(valueDegrees, holdProgress):
            state = .measuring(axisDegrees: valueDegrees, holdProgress: holdProgress)
        case let .rejected(reason):
            state = .rejected(reason: reason)
        }
    }

    func stopMeasurement() {
        guard isCaptureActive else { return }
        defer { stopUpdates() }
        guard let configuration, let value = evaluator?.bestValueDegrees else {
            finishWithFallback(.noStableHold)
            return
        }
        captureGeneration &+= 1
        liveAngleDegrees = value
        state = .completed(axis: configuration.axis, valueDegrees: value)
    }

    func cancelMeasurement() {
        finishWithFallback(.cancelled)
    }

    func reset() {
        captureGeneration &+= 1
        stopUpdates()
        evaluator = nil
        configuration = nil
        captureStartedAt = nil
        lastError = nil
        liveAngleDegrees = nil
        state = .idle
    }

    private func finishWithFallback(_ reason: MobilityInclinometerFallbackReason) {
        guard isCaptureActive || state == .idle else { return }
        captureGeneration &+= 1
        if !isUpdating {
            // A hardware/configuration failure can occur before updates start;
            // still issue the defensive stop promised by the capture contract.
            motionManager.stopDeviceMotionUpdates()
        }
        stopUpdates()
        lastError = .manualFallbackRequired(reason)
        liveAngleDegrees = nil
        state = .unavailable(reason: reason)
    }

    private func stopUpdates() {
        if isUpdating {
            motionManager.stopDeviceMotionUpdates()
            isUpdating = false
        }
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private var isCaptureActive: Bool {
        switch state {
        case .calibrating, .measuring, .rejected:
            return true
        case .idle, .completed, .unavailable:
            return false
        }
    }

    deinit {
        MainActor.assumeIsolated {
            motionManager.stopDeviceMotionUpdates()
            timeoutTask?.cancel()
        }
    }
}
