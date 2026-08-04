import Foundation

/// Stable persistence vocabulary for the mobility-assessment domain.
///
/// Display copy is resolved separately. Raw values may appear in SwiftData and
/// portable backups, so they must not be renamed after shipping.
enum MobilityAssessmentZone: String, Codable, CaseIterable, Hashable, Sendable {
    case shoulders
    case overhead
    case thorax
    case hips
    case posteriorChain
    case ankles
}

enum MobilityMeasurementMode: String, Codable, CaseIterable, Hashable, Sendable {
    case inclinometer
    case axialRotation
    case twoSegmentAngle
    case dynamicRange
    case manualAngle
    case manualLinear
    case manualCriteria
    /// Reserved for a later Vision-based phase. 3c validation rejects it.
    case cameraPose

    var isManual: Bool {
        switch self {
        case .manualAngle, .manualLinear, .manualCriteria:
            return true
        case .inclinometer, .axialRotation, .twoSegmentAngle, .dynamicRange, .cameraPose:
            return false
        }
    }
}

enum MobilityMeasurementUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case degrees
    case centimetres
    case criteria
}

enum MobilityMeasurementSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case deviceMotion
    case imported
}

enum MobilityMeasurementConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    case high
    case moderate
    case low
    case unknown

    var rank: Int {
        switch self {
        case .high: 3
        case .moderate: 2
        case .low: 1
        case .unknown: 0
        }
    }
}

enum MobilityAssessmentSide: String, Codable, CaseIterable, Hashable, Sendable {
    case left
    case right
    case combined
}

enum MobilityAssessmentSessionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case completed
    case stopped
}

/// Wall-squat and future authored criteria observations remain evidence, not a
/// pass/fail judgement.
enum MobilityAssessmentCriteriaObservation: String, Codable, CaseIterable, Hashable, Sendable {
    case allCriteriaObserved
    case someCriteriaObserved
    case criteriaNotObserved
}

enum MobilityAssessmentConditionDifference: String, Codable, CaseIterable, Hashable, Sendable {
    case definition
    case side
    case setup
    case method
    case unit
    case activePassive
    case warmCold
}

enum MobilityAssessmentComparability: String, Codable, Hashable, Sendable {
    case direct
    case notDirect
}

struct MobilityAssessmentResultInput: Equatable, Sendable {
    let numericValue: Double?
    let criteria: MobilityAssessmentCriteriaObservation?
    let side: MobilityAssessmentSide
    let isWarm: Bool
    let setupKey: String
    let method: MobilityMeasurementMode
    let unit: MobilityMeasurementUnit
    let isActiveRange: Bool
    let day: LocalDay
    let source: MobilityMeasurementSource
    let confidence: MobilityMeasurementConfidence
    let trials: [Double]?

    init(
        numericValue: Double? = nil,
        criteria: MobilityAssessmentCriteriaObservation? = nil,
        side: MobilityAssessmentSide,
        isWarm: Bool,
        setupKey: String,
        method: MobilityMeasurementMode,
        unit: MobilityMeasurementUnit,
        isActiveRange: Bool,
        day: LocalDay,
        source: MobilityMeasurementSource = .manual,
        confidence: MobilityMeasurementConfidence = .moderate,
        trials: [Double]? = nil
    ) {
        self.numericValue = numericValue
        self.criteria = criteria
        self.side = side
        self.isWarm = isWarm
        self.setupKey = setupKey
        self.method = method
        self.unit = unit
        self.isActiveRange = isActiveRange
        self.day = day
        self.source = source
        self.confidence = confidence
        self.trials = trials
    }
}

enum MobilityAssessmentValidationError: LocalizedError, Equatable {
    case nonFiniteValue
    case missingNumericValue
    case unexpectedNumericValue
    case missingCriteriaObservation
    case unexpectedCriteriaObservation
    case unsupportedSide
    case unsupportedSetup
    case unsupportedMethod
    case incompatibleUnit
    case unsupportedCameraPose
    case manualSourceRequiresManualMethod
    case manualConfidenceTooHigh
    case invalidDefinition

    var errorDescription: String? {
        switch self {
        case .nonFiniteValue: "The entered value must be finite."
        case .missingNumericValue: "This assessment requires a numeric value."
        case .unexpectedNumericValue: "This assessment records criteria instead of a numeric value."
        case .missingCriteriaObservation: "This assessment requires a criteria observation."
        case .unexpectedCriteriaObservation: "This assessment records a numeric value instead of criteria."
        case .unsupportedSide: "The selected side is not supported by this assessment."
        case .unsupportedSetup: "The selected setup is not supported by this assessment."
        case .unsupportedMethod: "The selected method is not supported by this assessment."
        case .incompatibleUnit: "The selected unit does not match this assessment."
        case .unsupportedCameraPose: "Camera-based measurement is not available in this version."
        case .manualSourceRequiresManualMethod: "A manually entered result must use an approved manual method."
        case .manualConfidenceTooHigh: "A manually entered result cannot have high confidence."
        case .invalidDefinition: "The assessment definition is incomplete."
        }
    }
}
