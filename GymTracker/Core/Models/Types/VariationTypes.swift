import Foundation

/// Optional exercise-definition metadata that distinguishes variants without
/// claiming that they are interchangeable in a workout or plan.
enum GripStyle: String, Codable, CaseIterable {
    case pronated = "Pronated"
    case supinated = "Supinated"
    case neutral = "Neutral"
    case mixed = "Mixed"
}

enum ExerciseStance: String, Codable, CaseIterable {
    case standing = "Standing"
    case seated = "Seated"
    case kneeling = "Kneeling"
    case split = "Split"
    case staggered = "Staggered"
    case supine = "Supine"
    case prone = "Prone"
}

enum RangeOfMotion: String, Codable, CaseIterable {
    case full = "Full"
    case partial = "Partial"
    case extended = "Extended"
}

enum ExerciseRelationshipType: String, Codable, CaseIterable, Identifiable {
    case substitution = "Substitution"
    case progression = "Progression"
    case regression = "Regression"

    var id: Self { self }

    var actionTitle: String {
        switch self {
        case .substitution:
            "Substitution"
        case .progression:
            "Progression"
        case .regression:
            "Regression"
        }
    }
}
