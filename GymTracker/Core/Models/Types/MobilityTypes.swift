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

    /// Routed through the canonical `UnitConversion.weight` conversion so
    /// this can never silently disagree with the constant every other
    /// weight conversion in the app uses. `UnitConversion.weight` works in
    /// `Float`; the narrowing round-trip only affects precision far beyond
    /// what a load value needs, and the public `Double` signature here is
    /// unchanged.
    func convert(_ value: Double, to targetUnit: MobilityLoadUnit) -> Double {
        guard self != targetUnit else { return value }
        let source: WeightType = self == .kilograms ? .kg : .lbs
        let target: WeightType = targetUnit == .kilograms ? .kg : .lbs
        return Double(UnitConversion.weight(Float(value), from: source, to: target))
    }
}

enum MobilityResistanceMode: String, Codable, CaseIterable, Hashable {
    case bodyweight
    case externalLoad
    case bandResistance
    case bandAssistance
}

/// Typed vocabulary for evidence recorded by a mobility result. Assessment
/// measurements intentionally keep their separate measurement/unit domain.
nonisolated enum MobilityMetric: String, Codable, CaseIterable, Hashable, Sendable {
    case duration
    case repetitions
    case cycles
    case load
    case rangeDistance
    case jointAngle
    case reach
    case breathingCycles
    case contractionDuration
    case assistanceLevel
    case supportLevel
    case movementQuality
    case perceivedStretch

    /// Metrics the current mobility execution surface can record directly.
    static let completionWritable: Set<MobilityMetric> = [
        .duration, .repetitions, .cycles, .load, .breathingCycles, .contractionDuration,
        .assistanceLevel, .supportLevel, .movementQuality, .perceivedStretch
    ]
}

nonisolated enum MobilityCompletionRule: Codable, Hashable, Sendable {
    case all(Set<MobilityMetric>)
    case any(Set<MobilityMetric>)
    case prescribedTargets
    case phaseSequenceCompleted
}

nonisolated struct MobilityMetricProfile: Codable, Hashable, Sendable {
    var supportedMetrics: Set<MobilityMetric>
    var defaultCompletionRule: MobilityCompletionRule
    var primaryProgressMetric: MobilityMetric?

    var completionWritableMetrics: Set<MobilityMetric> {
        supportedMetrics.intersection(MobilityMetric.completionWritable)
    }
}

/// Executable integer targets are deliberately bounded value types rather
/// than stored formulas.
nonisolated enum MobilityIntTarget: Codable, Hashable, Sendable {
    case exact(Int)
    case range(Int, Int)
    case minimum(Int)
    case maximum(Int)
    case open

    var isValid: Bool {
        switch self {
        case .exact(let value), .minimum(let value), .maximum(let value): value > 0
        case .range(let minimum, let maximum): minimum > 0 && maximum >= minimum
        case .open: true
        }
    }
}

nonisolated enum MobilityDoubleTarget: Codable, Hashable, Sendable {
    case exact(Double)
    case range(Double, Double)
    case minimum(Double)
    case maximum(Double)
    case open

    var isValid: Bool {
        switch self {
        case .exact(let value), .minimum(let value), .maximum(let value):
            value.isFinite && value > 0
        case .range(let minimum, let maximum):
            minimum.isFinite && maximum.isFinite && minimum > 0 && maximum >= minimum
        case .open: true
        }
    }
}

/// Targets currently executable by the mobility session domain. Range,
/// angle, and reach remain assessment-owned until performed training evidence
/// for those metrics has its own typed fields.
nonisolated struct MobilityMetricTargets: Codable, Hashable, Sendable {
    var durationSeconds: MobilityIntTarget?
    var repetitions: MobilityIntTarget?
    var cycles: MobilityIntTarget?
    var load: MobilityDoubleTarget?
    var breathingCycles: MobilityIntTarget?

    init(
        durationSeconds: MobilityIntTarget? = nil,
        repetitions: MobilityIntTarget? = nil,
        cycles: MobilityIntTarget? = nil,
        load: MobilityDoubleTarget? = nil,
        breathingCycles: MobilityIntTarget? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.repetitions = repetitions
        self.cycles = cycles
        self.load = load
        self.breathingCycles = breathingCycles
    }

    var prescribedMetrics: Set<MobilityMetric> {
        var metrics = Set<MobilityMetric>()
        if durationSeconds != nil { metrics.insert(.duration) }
        if repetitions != nil { metrics.insert(.repetitions) }
        if cycles != nil { metrics.insert(.cycles) }
        if load != nil { metrics.insert(.load) }
        if breathingCycles != nil { metrics.insert(.breathingCycles) }
        return metrics
    }

    var isValid: Bool {
        (durationSeconds.map(\.isValid) ?? true)
            && (repetitions.map(\.isValid) ?? true)
            && (cycles.map(\.isValid) ?? true)
            && (load.map(\.isValid) ?? true)
            && (breathingCycles.map(\.isValid) ?? true)
    }
}

extension MobilityTrackingType {
    nonisolated var legacyMetricProfile: MobilityMetricProfile {
        switch self {
        case .duration:
            MobilityMetricProfile(
                supportedMetrics: [.duration],
                defaultCompletionRule: .all([.duration]),
                primaryProgressMetric: .duration
            )
        case .repetitions:
            MobilityMetricProfile(
                supportedMetrics: [.repetitions],
                defaultCompletionRule: .all([.repetitions]),
                primaryProgressMetric: .repetitions
            )
        }
    }

    /// The single source of truth for a metric profile fallback when no
    /// authored profile exists. Both the session-start authoring path and the
    /// legacy-entry completion path route through this function so a
    /// breath-led item is never accepted at start and then silently
    /// unrecognized (or the reverse) at completion. `hasPhases` mirrors
    /// `MobilityRoutineItem.orderedPhases.isEmpty == false` /
    /// `MobilityEntry.isPhaseDriven`.
    nonisolated static func derivedMetricProfile(
        trackingType: MobilityTrackingType,
        hasPhases: Bool,
        targets: MobilityMetricTargets,
        authored: MobilityMetricProfile?
    ) -> MobilityMetricProfile {
        if let authored { return authored }
        if hasPhases {
            return MobilityMetricProfile(
                supportedMetrics: [.duration, .contractionDuration, .cycles],
                defaultCompletionRule: .phaseSequenceCompleted,
                primaryProgressMetric: .cycles
            )
        }
        let base = trackingType.legacyMetricProfile
        var supported = base.supportedMetrics
        if targets.load != nil { supported.insert(.load) }
        if targets.breathingCycles != nil { supported.insert(.breathingCycles) }
        var required: Set<MobilityMetric> = trackingType == .duration
            ? [.duration] : [.repetitions]
        if targets.load != nil { required.insert(.load) }
        return MobilityMetricProfile(
            supportedMetrics: supported,
            defaultCompletionRule: .all(required),
            primaryProgressMetric: base.primaryProgressMetric
        )
    }
}

/// How a movement's left/right execution is sequenced and targeted. This is
/// distinct from `MobilitySide`, which names a single execution node's side;
/// a strategy describes the policy across the whole prescription. Sides are
/// never averaged before saving regardless of strategy.
nonisolated enum MobilitySideStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    case noSide
    case leftOnly
    case rightOnly
    case sameTargetBothSides
    case independentTargets
    case alternateEachRepetition
    case completeSideThenSwitch
    case oneCycleContainsBothSides
    case userSelectedSide

    var displayName: String {
        switch self {
        case .noSide: String(localized: "No side")
        case .leftOnly: String(localized: "Left only")
        case .rightOnly: String(localized: "Right only")
        case .sameTargetBothSides: String(localized: "Same target, both sides")
        case .independentTargets: String(localized: "Independent targets per side")
        case .alternateEachRepetition: String(localized: "Alternate each repetition")
        case .completeSideThenSwitch: String(localized: "Complete side, then switch")
        case .oneCycleContainsBothSides: String(localized: "One cycle contains both sides")
        case .userSelectedSide: String(localized: "User selects side")
        }
    }
}

/// Groups routine items under one authored container. Blocks are exactly one
/// nesting level deep: a block contains items, and a block never contains
/// another block. There is deliberately no block-of-blocks field anywhere in
/// this vocabulary, so deeper nesting cannot be authored in-app; portable
/// backup restore rejects any payload that tries to reference a block from
/// another block's identity.
nonisolated enum MobilityBlockKind: String, Codable, CaseIterable, Hashable, Sendable {
    case straightSequence
    case alternatingSides
    case dynamicWarmup
    case mobilityCircuit
    case flexibilityCircuit
    case continuousFlow
    case contractRelax
    case loadedFlexibility
    case jointPreparation
    case recovery
    case timedFlow

    var displayName: String {
        switch self {
        case .straightSequence: String(localized: "Straight sequence")
        case .alternatingSides: String(localized: "Alternating sides")
        case .dynamicWarmup: String(localized: "Dynamic warm-up")
        case .mobilityCircuit: String(localized: "Mobility circuit")
        case .flexibilityCircuit: String(localized: "Flexibility circuit")
        case .continuousFlow: String(localized: "Continuous flow")
        case .contractRelax: String(localized: "Contract-relax")
        case .loadedFlexibility: String(localized: "Loaded flexibility")
        case .jointPreparation: String(localized: "Joint preparation")
        case .recovery: String(localized: "Recovery")
        case .timedFlow: String(localized: "Timed flow")
        }
    }

    /// Blocks of this kind repeat their full item sequence for
    /// `targetRounds`, resting only at `.betweenRounds`.
    var isRoundBased: Bool {
        self == .mobilityCircuit || self == .flexibilityCircuit
    }

    /// Blocks of this kind never rest between member items; the whole block
    /// runs as one uninterrupted flow.
    var isContinuous: Bool {
        self == .continuousFlow || self == .timedFlow
    }
}

/// A breath-led target remains part of the movement prescription. The
/// performed result records only the breaths actually completed; it never
/// turns an unperformed target into evidence.
nonisolated struct MobilityBreathingPrescription: Codable, Hashable, Sendable {
    var targetBreaths: Int?
    var inhaleSeconds: Int?
    var exhaleSeconds: Int?
    var instructionKey: String?

    var isEmpty: Bool {
        targetBreaths == nil && inhaleSeconds == nil && exhaleSeconds == nil
            && instructionKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
    }
}

nonisolated struct MobilityTempoPrescription: Codable, Hashable, Sendable {
    var moveIntoRangeSeconds: Int?
    var holdSeconds: Int?
    var returnSeconds: Int?
    var pauseSeconds: Int?

    var isEmpty: Bool {
        moveIntoRangeSeconds == nil && holdSeconds == nil
            && returnSeconds == nil && pauseSeconds == nil
    }
}

nonisolated enum MobilityAssistanceType: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case blocks
    case strap
    case band
    case wall
    case partner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blocks: String(localized: "Blocks")
        case .strap: String(localized: "Strap")
        case .band: String(localized: "Band")
        case .wall: String(localized: "Wall")
        case .partner: String(localized: "Partner")
        }
    }
}

/// Optional external help used to perform a mobility prescription. `level`
/// is an authored ordinal within the named assistance type, not a score that
/// can be compared across equipment or movements.
nonisolated struct MobilityAssistancePrescription: Codable, Hashable, Sendable {
    var assistanceTypeRaw: String
    var level: Int?
    var equipmentRaw: String?

    var assistanceType: MobilityAssistanceType? {
        MobilityAssistanceType(rawValue: assistanceTypeRaw)
    }
}

/// Concrete setup context used by support ladders. These cases are deliberately
/// descriptive rather than clinical and are never averaged into a score.
enum MobilitySupportLevel: String, Codable, CaseIterable, Hashable, Identifiable {
    case highBlocks
    case mediumBlocks
    case lowBlocks
    case fingertipSupport
    case unsupported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highBlocks: String(localized: "High blocks")
        case .mediumBlocks: String(localized: "Medium blocks")
        case .lowBlocks: String(localized: "Low blocks")
        case .fingertipSupport: String(localized: "Fingertip support")
        case .unsupported: String(localized: "Unsupported")
        }
    }
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

nonisolated enum MobilitySensation: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
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
