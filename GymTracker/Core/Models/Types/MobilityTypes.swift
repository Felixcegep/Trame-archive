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

enum MobilitySide: String, Codable, CaseIterable, Hashable {
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

enum MobilityResultStatus: String, Codable, CaseIterable, Hashable {
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
