import Foundation

/// Joint zones evaluated for exercise movement capacity requirements.
enum JointZone: String, Codable, CaseIterable, Sendable {
    case ankles
    case hips
    case thoracicSpine
    case shoulders
    case wrists
}

/// Structural requirement for a specific exercise seed key.
struct MovementRequirement: Equatable, Sendable {
    let exerciseCatalogueKey: String
    let jointZone: JointZone
    let assessmentCatalogueKey: String
    let minRequiredValue: Double
    let unit: MobilityMeasurementUnit
    let requirementDescription: String
}

/// Verdict after comparing latest assessment evidence to movement demands.
enum MovementCapacityVerdict: Equatable, Sendable {
    case capacitySufficient(headroom: Double)
    case restrictionDetected(gap: Double, requirement: String)
    case insufficientAssessmentData(missingAssessmentKey: String)
}
