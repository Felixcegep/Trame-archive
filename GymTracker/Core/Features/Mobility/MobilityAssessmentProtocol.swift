import Foundation

/// The authored conditions for one mobility observation.
///
/// A protocol is intentionally a value contract rather than a SwiftData
/// entity in this phase. The existing assessment definition's catalogue key
/// and version can adopt this identity when a persisted protocol snapshot is
/// eventually introduced, without adding a second source of truth today.
struct MobilityAssessmentProtocol: Codable, Equatable, Hashable, Identifiable, Sendable {
    enum Method: String, Codable, CaseIterable, Hashable, Sendable {
        case manual
        case inclinometer
        case deviceMotion
    }

    enum RangeCondition: String, Codable, CaseIterable, Hashable, Sendable {
        case active
        case passive
    }

    let protocolID: String
    let protocolVersion: Int
    let measurement: String
    let testName: String
    let position: String
    /// Optional bridge to the existing assessment definition's authored setup
    /// key. When present, a result must carry this exact setup key before a
    /// band can be applied.
    let setupKey: String?
    let jointPosition: String?
    let side: MobilityAssessmentSide
    let unit: MobilityMeasurementUnit
    let activePassive: RangeCondition
    let recordsWarmCold: Bool
    let preferredMethod: Method
    let manualFallback: Bool
    let placement: String?
    let reliabilitySource: String
    let measurementError: MobilityAssessmentMeasurementError?
    let limitations: String

    var id: String { protocolID }

    init(
        protocolID: String,
        protocolVersion: Int,
        measurement: String,
        testName: String,
        position: String,
        setupKey: String? = nil,
        jointPosition: String? = nil,
        side: MobilityAssessmentSide,
        unit: MobilityMeasurementUnit,
        activePassive: RangeCondition,
        recordsWarmCold: Bool,
        preferredMethod: Method,
        manualFallback: Bool,
        placement: String? = nil,
        reliabilitySource: String,
        measurementError: MobilityAssessmentMeasurementError? = nil,
        limitations: String
    ) {
        self.protocolID = protocolID
        self.protocolVersion = protocolVersion
        self.measurement = measurement
        self.testName = testName
        self.position = position
        self.setupKey = setupKey
        self.jointPosition = jointPosition
        self.side = side
        self.unit = unit
        self.activePassive = activePassive
        self.recordsWarmCold = recordsWarmCold
        self.preferredMethod = preferredMethod
        self.manualFallback = manualFallback
        self.placement = placement
        self.reliabilitySource = reliabilitySource
        self.measurementError = measurementError
        self.limitations = limitations
    }
}

/// Optional method-error context. Values are expressed in the protocol's
/// typed unit; no conversion or scientific estimate is supplied here.
struct MobilityAssessmentMeasurementError: Codable, Equatable, Hashable, Sendable {
    let standardErrorOfMeasurement: Double?
    let minimalDetectableChange: Double?

    init(standardErrorOfMeasurement: Double? = nil, minimalDetectableChange: Double? = nil) {
        self.standardErrorOfMeasurement = standardErrorOfMeasurement
        self.minimalDetectableChange = minimalDetectableChange
    }
}

enum MobilityAssessmentProtocolValidationError: Error, Equatable, Sendable {
    case emptyProtocolID
    case protocolIDContainsAlternativeSetup
    case invalidProtocolVersion
    case emptyMeasurement
    case emptyTestName
    case emptyPosition
    case emptyReliabilitySource
    case emptyLimitations
    case missingPlacementForDeviceMethod
    case invalidMeasurementError
}

extension MobilityAssessmentProtocol {
    /// Validates structure only. It intentionally does not claim that a
    /// protocol is scientifically appropriate; that remains an evidence and
    /// human-review decision.
    func validate() -> MobilityAssessmentProtocolValidationError? {
        guard protocolID.isEmpty == false else { return .emptyProtocolID }

        let loweredID = protocolID.lowercased()
        let identityTokens = loweredID.split { character in
            character == "-" || character == "_" || character.isWhitespace
        }
        guard protocolID.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              identityTokens.contains("or") == false,
              loweredID.contains("/") == false,
              loweredID.contains("|") == false
        else {
            return .protocolIDContainsAlternativeSetup
        }

        guard protocolVersion > 0 else { return .invalidProtocolVersion }
        guard measurement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyMeasurement
        }
        guard testName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyTestName
        }
        guard position.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyPosition
        }
        guard reliabilitySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyReliabilitySource
        }
        guard limitations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .emptyLimitations
        }

        if preferredMethod != .manual {
            guard placement?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return .missingPlacementForDeviceMethod
            }
        }

        if let measurementError {
            let values = [
                measurementError.standardErrorOfMeasurement,
                measurementError.minimalDetectableChange
            ]
            guard values.contains(where: { $0 != nil }),
                  values.allSatisfy({ value in
                      guard let value else { return true }
                      return value.isFinite && value >= 0
                  })
            else {
                return .invalidMeasurementError
            }
        }

        return nil
    }
}

/// A protocol identity is exact when all authored measurement conditions that
/// can change the meaning of a result match. This is deliberately stricter
/// than matching a friendly test name.
struct MobilityAssessmentProtocolIdentity: Equatable, Hashable, Sendable {
    let protocolID: String
    let protocolVersion: Int
    let unit: MobilityMeasurementUnit
    let side: MobilityAssessmentSide
    let setupKey: String?
    let activePassive: MobilityAssessmentProtocol.RangeCondition
    let preferredMethod: MobilityAssessmentProtocol.Method

    init(_ protocol: MobilityAssessmentProtocol) {
        protocolID = `protocol`.protocolID
        protocolVersion = `protocol`.protocolVersion
        unit = `protocol`.unit
        side = `protocol`.side
        setupKey = `protocol`.setupKey
        activePassive = `protocol`.activePassive
        preferredMethod = `protocol`.preferredMethod
    }
}
