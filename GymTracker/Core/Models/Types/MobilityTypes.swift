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

/// How a mobility prescription is intended to create or control range.
/// Unknown future raw values remain stored by evidence records and resolve to
/// `nil` rather than being silently reinterpreted by an older build.
enum MobilityMethod: String, Codable, CaseIterable, Hashable, Identifiable {
    case staticPassive
    case staticActive
    case dynamic
    case activeRange
    case controlledRotation
    case endRangeIsometric
    case contractRelax
    case holdRelax
    case loadedFlexibility
    case eccentricLengthening
    case activeAssisted
    case flow
    case ballistic
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .staticPassive: String(localized: "Static passive")
        case .staticActive: String(localized: "Static active")
        case .dynamic: String(localized: "Dynamic")
        case .activeRange: String(localized: "Active range")
        case .controlledRotation: String(localized: "Controlled rotation")
        case .endRangeIsometric: String(localized: "End-range isometric")
        case .contractRelax: String(localized: "Contract-relax")
        case .holdRelax: String(localized: "Hold-relax")
        case .loadedFlexibility: String(localized: "Loaded flexibility")
        case .eccentricLengthening: String(localized: "Eccentric lengthening")
        case .activeAssisted: String(localized: "Active assisted")
        case .flow: String(localized: "Flow")
        case .ballistic: String(localized: "Ballistic")
        case .recovery: String(localized: "Recovery")
        }
    }
}

enum MobilityTrainingPurpose: String, Codable, CaseIterable, Hashable, Identifiable {
    case preparation
    case flexibilityDevelopment
    case activeControl
    case jointControl
    case strengthAtLength
    case recovery
    case cooldown
    case assessmentPreparation
    case maintenance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preparation: String(localized: "Preparation")
        case .flexibilityDevelopment: String(localized: "Flexibility development")
        case .activeControl: String(localized: "Active control")
        case .jointControl: String(localized: "Joint control")
        case .strengthAtLength: String(localized: "Strength at length")
        case .recovery: String(localized: "Recovery")
        case .cooldown: String(localized: "Cooldown")
        case .assessmentPreparation: String(localized: "Assessment preparation")
        case .maintenance: String(localized: "Maintenance")
        }
    }
}

enum MobilityMovementQuality: String, Codable, CaseIterable, Hashable, Identifiable {
    case controlled
    case mostlyControlled
    case compensationObserved
    case unableToAssess

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .controlled: String(localized: "Controlled")
        case .mostlyControlled: String(localized: "Mostly controlled")
        case .compensationObserved: String(localized: "Compensation observed")
        case .unableToAssess: String(localized: "Unable to assess")
        }
    }
}

/// Neutral observations only. These labels intentionally make no diagnosis.
enum MobilityCompensationKey: String, Codable, CaseIterable, Hashable, Identifiable {
    case heelLift
    case pelvisRotation
    case spinalFlexion
    case shoulderElevation
    case supportLost
    case balanceLost
    case rangeReduced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heelLift: String(localized: "Heel lifted")
        case .pelvisRotation: String(localized: "Pelvis rotated")
        case .spinalFlexion: String(localized: "Spine flexed")
        case .shoulderElevation: String(localized: "Shoulder elevated")
        case .supportLost: String(localized: "Support lost")
        case .balanceLost: String(localized: "Balance lost")
        case .rangeReduced: String(localized: "Range reduced")
        }
    }
}

enum MobilitySensation: String, Codable, CaseIterable, Hashable, Identifiable {
    case none
    case mildStretch
    case moderateStretch
    case strongControlledStretch
    case discomfort
    case jointPressure
    case cramping
    case pain
    case numbness
    case tingling

    var id: String { rawValue }

    var isStopSignal: Bool {
        self == .pain || self == .numbness || self == .tingling
    }

    var displayName: String {
        switch self {
        case .none: String(localized: "None")
        case .mildStretch: String(localized: "Mild stretch")
        case .moderateStretch: String(localized: "Moderate stretch")
        case .strongControlledStretch: String(localized: "Strong controlled stretch")
        case .discomfort: String(localized: "Discomfort")
        case .jointPressure: String(localized: "Joint pressure")
        case .cramping: String(localized: "Cramping")
        case .pain: String(localized: "Pain")
        case .numbness: String(localized: "Numbness")
        case .tingling: String(localized: "Tingling")
        }
    }
}
