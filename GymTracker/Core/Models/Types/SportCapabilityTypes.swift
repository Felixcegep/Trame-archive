import Foundation

/// Stable identifiers stored on `SportCapabilityProfile.analyticsPolicyIdentifier`
/// and used by `SportAnalyticsPolicyResolver` to pick a concrete policy. Kept
/// as raw strings — not the policy type itself — so a persisted/snapshotted
/// capability profile never holds a reference to unavailable code across an
/// app/extension boundary.
nonisolated enum SportAnalyticsPolicyIdentifier {
    static let standardStrength = "standardStrength"
    static let olympicAttempt = "olympicAttempt"
    static let strongmanEvent = "strongmanEvent"
    static let strongmanCarry = "strongmanCarry"
    static let strongmanHold = "strongmanHold"
    static let fitnessSimulation = "fitnessSimulation"
    static let ergDistance = "ergDistance"
}

/// The broad training context an exercise or planned effort belongs to.
/// Disciplines describe what evidence CAN be captured and how it is
/// interpreted for records and completion surfaces — they never change how
/// weight/reps progress. An exercise that never authored a discipline
/// resolves from its `TrackingType`/`ExerciseCategory` alone
/// (`Exercise.resolvedSportDiscipline`), so every exercise created before
/// this slice keeps behaving exactly as it already did.
nonisolated enum SportDiscipline: String, Codable, CaseIterable, Hashable, Sendable {
    case generalStrength
    case bodybuilding
    case powerlifting
    case olympicWeightlifting
    case strongman
    case fitnessRacing
    case generalCardio
    case mixed

    var title: String {
        switch self {
        case .generalStrength: String(localized: "General strength", comment: "Sport discipline")
        case .bodybuilding: String(localized: "Bodybuilding", comment: "Sport discipline")
        case .powerlifting: String(localized: "Powerlifting", comment: "Sport discipline")
        case .olympicWeightlifting: String(localized: "Olympic weightlifting", comment: "Sport discipline")
        case .strongman: String(localized: "Strongman", comment: "Sport discipline")
        case .fitnessRacing: String(localized: "Fitness racing", comment: "Sport discipline")
        case .generalCardio: String(localized: "Cardio", comment: "Sport discipline")
        case .mixed: String(localized: "Mixed", comment: "Sport discipline")
        }
    }
}

/// Declares what a discipline CAN represent — not what it must use, and never
/// how it progresses. Every exercise resolves to exactly one profile so
/// completion surfaces and record detection read one authored place instead
/// of scattering `if discipline == ...` checks through the app.
nonisolated struct SportCapabilityProfile: Codable, Hashable, Sendable {
    var discipline: SportDiscipline
    var allowedBlockKinds: Set<ExerciseBlockKind>
    var allowedMetrics: Set<TrackingMetric>
    var supportsAttemptOutcomes: Bool
    var supportsImplementProfiles: Bool
    var supportsSplitTracking: Bool
    var analyticsPolicyIdentifier: String
}

extension SportCapabilityProfile {
    /// The one place a discipline's representable shape is authored. Adding a
    /// discipline means adding one case here; nothing else in the app should
    /// hardcode a per-discipline capability list.
    static func profile(for discipline: SportDiscipline, trackingType: TrackingType) -> SportCapabilityProfile {
        let trackingMetrics = trackingType.capabilityProfile.supportedMetrics
        switch discipline {
        case .generalStrength:
            return SportCapabilityProfile(
                discipline: .generalStrength,
                allowedBlockKinds: Set(ExerciseBlockKind.allCases),
                allowedMetrics: trackingMetrics,
                supportsAttemptOutcomes: false,
                supportsImplementProfiles: false,
                supportsSplitTracking: false,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.standardStrength
            )
        case .bodybuilding:
            return SportCapabilityProfile(
                discipline: .bodybuilding,
                allowedBlockKinds: Set(ExerciseBlockKind.allCases),
                allowedMetrics: trackingMetrics,
                supportsAttemptOutcomes: false,
                supportsImplementProfiles: false,
                supportsSplitTracking: false,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.standardStrength
            )
        case .powerlifting:
            return SportCapabilityProfile(
                discipline: .powerlifting,
                allowedBlockKinds: [.straight, .amrap],
                allowedMetrics: trackingMetrics,
                supportsAttemptOutcomes: true,
                supportsImplementProfiles: false,
                supportsSplitTracking: false,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.standardStrength
            )
        case .olympicWeightlifting:
            return SportCapabilityProfile(
                discipline: .olympicWeightlifting,
                allowedBlockKinds: [.straight, .olympicComplex],
                allowedMetrics: trackingMetrics.union([.load]),
                supportsAttemptOutcomes: true,
                supportsImplementProfiles: false,
                supportsSplitTracking: false,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.olympicAttempt
            )
        case .strongman:
            return SportCapabilityProfile(
                discipline: .strongman,
                allowedBlockKinds: [.straight, .forTime, .medley, .interval],
                allowedMetrics: trackingMetrics.union([.load, .duration, .distance, .throwDistance]),
                supportsAttemptOutcomes: true,
                supportsImplementProfiles: true,
                supportsSplitTracking: false,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.strongmanEvent
            )
        case .fitnessRacing:
            return SportCapabilityProfile(
                discipline: .fitnessRacing,
                allowedBlockKinds: [.forTime, .interval, .medley, .chipper, .amrap],
                allowedMetrics: trackingMetrics.union([.duration, .distance, .cadence]),
                supportsAttemptOutcomes: false,
                supportsImplementProfiles: false,
                supportsSplitTracking: true,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.fitnessSimulation
            )
        case .generalCardio:
            return SportCapabilityProfile(
                discipline: .generalCardio,
                allowedBlockKinds: [.straight, .interval, .forTime],
                allowedMetrics: [.duration, .distance, .calories, .cadence],
                supportsAttemptOutcomes: false,
                supportsImplementProfiles: false,
                supportsSplitTracking: true,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.ergDistance
            )
        case .mixed:
            return SportCapabilityProfile(
                discipline: .mixed,
                allowedBlockKinds: Set(ExerciseBlockKind.allCases),
                allowedMetrics: Set(TrackingMetric.allCases),
                supportsAttemptOutcomes: true,
                supportsImplementProfiles: true,
                supportsSplitTracking: true,
                analyticsPolicyIdentifier: SportAnalyticsPolicyIdentifier.standardStrength
            )
        }
    }

    /// The non-regression default: an exercise that never authored a sport
    /// discipline resolves purely from its `TrackingType`/`ExerciseCategory`,
    /// matching today's unconditional behavior for every existing exercise.
    static func deriving(from trackingType: TrackingType, category: ExerciseCategory?) -> SportCapabilityProfile {
        let discipline: SportDiscipline = (category == .cardio) ? .generalCardio : .generalStrength
        return profile(for: discipline, trackingType: trackingType)
    }
}

extension Exercise {
    var sportDiscipline: SportDiscipline? {
        get { sportDisciplineRaw.flatMap(SportDiscipline.init(rawValue:)) }
        set { sportDisciplineRaw = newValue?.rawValue }
    }

    /// Absent capability profile derives from the existing `TrackingType`,
    /// per the non-regression requirement: a plain strength exercise must
    /// behave identically whether or not this slice ever ran.
    var resolvedSportDiscipline: SportDiscipline {
        sportDiscipline ?? (displayCategory == .cardio ? .generalCardio : .generalStrength)
    }

    var sportCapabilityProfile: SportCapabilityProfile {
        SportCapabilityProfile.profile(for: resolvedSportDiscipline, trackingType: trackingType)
    }

    var strongmanEventFamily: StrongmanEventFamily? {
        get { strongmanEventFamilyRaw.flatMap(StrongmanEventFamily.init(rawValue:)) }
        set { strongmanEventFamilyRaw = newValue?.rawValue }
    }

    /// Catalog-level default implement. Performed sets keep their own
    /// snapshot (`ExerciseSet.strongmanImplementProfile`) captured at the
    /// moment they were logged; this value is only ever a starting point for
    /// a new set, never a substitute for the snapshot in history.
    var strongmanImplementProfile: StrongmanImplementProfile? {
        get {
            strongmanImplementProfileData.flatMap {
                try? JSONDecoder().decode(StrongmanImplementProfile.self, from: $0)
            }
        }
        set {
            strongmanImplementProfileData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}
