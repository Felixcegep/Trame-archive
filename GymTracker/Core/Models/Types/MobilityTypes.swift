import Foundation

enum MobilityTrackingType: String, Codable, CaseIterable, Hashable {
    case duration
    case repetitions

    var displayName: String {
        switch self {
        case .duration: "Duration"
        case .repetitions: "Repetitions"
        }
    }
}

nonisolated enum MobilitySide: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case left
    case right
    case bilateral
    case alternating

    var displayName: String {
        switch self {
        case .none: "No side"
        case .left: "Left"
        case .right: "Right"
        case .bilateral: "Both sides"
        case .alternating: "Alternate sides"
        }
    }

    var resultSides: [MobilitySide] {
        switch self {
        case .bilateral, .alternating: [.left, .right]
        default: [self]
        }
    }
}

enum MobilitySessionStatus: String, Codable, CaseIterable, Hashable {
    case active
    case completed
    case stopped
}

nonisolated enum MobilityResultStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case notStarted
    case inProgress
    case completed
    case partial
    case skipped
    case stopped
}

enum MobilitySessionContext: String, Codable, CaseIterable, Hashable {
    case standalone
    case warmup
    case cooldown

    var displayName: String {
        switch self {
        case .standalone: "Standalone"
        case .warmup: "Warm-up"
        case .cooldown: "Cooldown"
        }
    }
}

enum MobilityLoadUnit: String, Codable, CaseIterable, Hashable {
    case kilograms
    case pounds

    var abbreviation: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lbs"
        }
    }

    func convert(_ value: Double, to targetUnit: MobilityLoadUnit) -> Double {
        switch (self, targetUnit) {
        case (.kilograms, .kilograms), (.pounds, .pounds):
            return value
        case (.kilograms, .pounds):
            return value * 2.20462
        case (.pounds, .kilograms):
            return value / 2.20462
        }
    }
}

enum MobilityResistanceMode: String, Codable, CaseIterable, Hashable {
    case bodyweight
    case externalLoad
    case bandResistance
    case bandAssistance
}
