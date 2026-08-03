import Foundation

/// The vocabulary of record types a discipline-specific policy can declare.
/// Deliberately broader than any one policy uses, so a new policy can pick
/// existing cases instead of inventing near-duplicates.
nonisolated enum SportRecordKind: String, Codable, CaseIterable, Hashable, Sendable {
    case load
    case repetition
    case estimatedOneRepMax
    case volume
    case bestSuccessfulLift
    case attemptSuccessRate
    case complexResult
    case loadDistance
    case loadDuration
    case distance
    case time
    case pace
    case totalTime
    case runSplit
    case stationSplit
    case transitionSplit
}

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

/// Centralizes what one discipline or event counts as a record, and whether
/// one performed set feeds e1RM or strength-volume totals.
///
/// This does not introduce a second analytics path: the existing e1RM,
/// PR-detection, and volume computations keep running exactly as before and
/// now ask a policy first at the same call sites, so a discipline that must
/// never contribute (Snatch → no e1RM; Yoke → no e1RM) is excluded there
/// instead of through a parallel figure. `StandardStrengthAnalyticsPolicy`
/// (the default for every exercise without an authored discipline) always
/// answers exactly as the pre-existing unconditional logic did, so ordinary
/// strength behavior is unchanged.
protocol SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind>
    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool
    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool
}

/// General strength, bodybuilding, and powerlifting. This is the exact
/// pre-existing behavior of `StrengthAnalyticsPolicy`/`ExerciseDetailAnalyticsService`:
/// every completed, non-warmup, non-segmented, non-complex working set
/// contributes to load/repetition records, e1RM, and volume. A normal bench
/// press set never has `complexComponents`, so the guard below is inert for
/// it — it only starts to matter for a set that was logged as part of an
/// Olympic complex, which was never eligible for a traditional PR either
/// (`StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord` already
/// excludes non-empty `complexComponents`).
nonisolated struct StandardStrengthAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        var kinds: Set<SportRecordKind> = []
        if entry.trackingTypeSnapshot.usesWeight {
            kinds.formUnion([.load, .estimatedOneRepMax, .volume])
        }
        if entry.trackingTypeSnapshot.usesReps {
            kinds.insert(.repetition)
        }
        return kinds
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        set.complexComponents.isEmpty
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        true
    }
}

/// Snatch and other Olympic-lifting attempts logged as a structured complex.
/// A single shared attempt is scored made/partial/missed
/// (`ExerciseSet.olympicAttemptOutcome`), so it is never comparable to a
/// traditional top-set load and must never inflate e1RM.
nonisolated struct OlympicAttemptAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.bestSuccessfulLift, .attemptSuccessRate, .complexResult]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    /// Only a made attempt is trained load worth counting; a missed or
    /// partial attempt is not a record and is not volume, exactly like a
    /// failed traditional set never becomes a PR.
    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        guard let outcome = set.olympicAttemptOutcome else { return true }
        return outcome == .made
    }
}

/// Yoke and other loaded-carry events. The record is a load moved over a
/// distance, not a rep-and-load volume figure, and the load is never
/// comparable to a differently-conventioned load
/// (`StrongmanLoadComparability`) — so it never contributes to e1RM.
nonisolated struct YokeCarryAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.loadDistance]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }
}

/// Farmer's Hold and other static loaded holds. The record is a load held
/// for a duration, not a load-distance figure and not e1RM.
nonisolated struct FarmersHoldAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.loadDuration]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }
}

/// Overhead, deadlift, loading, throwing, pulling, pushing, and medley
/// strongman events that are neither a loaded carry nor a static hold. Loads
/// still compete for a record within their event, but strongman implement
/// loading rarely maps onto a clean submaximal-rep e1RM formula, so this
/// stays conservative and excludes e1RM by default — matching the two
/// concrete examples the spec gives (Yoke, Farmer's Hold), neither of which
/// contributes e1RM.
nonisolated struct StrongmanGeneralEventAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.load, .volume]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        true
    }
}

/// SkiErg and other single-modality erg/distance cardio work.
nonisolated struct ErgDistanceAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.distance, .time, .pace]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }
}

/// Multi-modal fitness-racing simulations (DEKA/HYROX-style events). The
/// record lives at the level of the overall event and its internal splits
/// (`WorkoutSplitKind`, `ExerciseSetSegment`), not at the individual set.
nonisolated struct FitnessSimulationAnalyticsPolicy: SportAnalyticsPolicy {
    func supportedRecords(for entry: ExerciseEntry) -> Set<SportRecordKind> {
        [.totalTime, .runSplit, .stationSplit, .transitionSplit]
    }

    func contributesToE1RM(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }

    func contributesToStrengthVolume(set: ExerciseSet, entry: ExerciseEntry) -> Bool {
        false
    }
}

/// Resolves the concrete policy for a discipline/event-family pair, an
/// exercise, or a performed entry. This is the one dispatch point — nothing
/// else in the app should switch on `SportDiscipline`/`StrongmanEventFamily`
/// to decide analytics behavior.
enum SportAnalyticsPolicyResolver {
    static func policy(discipline: SportDiscipline, strongmanEventFamily: StrongmanEventFamily?) -> SportAnalyticsPolicy {
        switch discipline {
        case .generalStrength, .bodybuilding, .powerlifting, .mixed:
            return StandardStrengthAnalyticsPolicy()
        case .olympicWeightlifting:
            return OlympicAttemptAnalyticsPolicy()
        case .strongman:
            switch strongmanEventFamily {
            case .carry: return YokeCarryAnalyticsPolicy()
            case .hold: return FarmersHoldAnalyticsPolicy()
            default: return StrongmanGeneralEventAnalyticsPolicy()
            }
        case .fitnessRacing:
            return FitnessSimulationAnalyticsPolicy()
        case .generalCardio:
            return ErgDistanceAnalyticsPolicy()
        }
    }

    /// Live-catalog resolution. Only appropriate for a not-yet-performed
    /// context (authoring, catalog browsing) — anything reading completed
    /// history must use the `ExerciseEntry` overload below instead.
    static func policy(for exercise: Exercise) -> SportAnalyticsPolicy {
        policy(discipline: exercise.resolvedSportDiscipline, strongmanEventFamily: exercise.strongmanEventFamily)
    }

    /// Historical resolution. Reads the discipline/event-family **snapshot**
    /// frozen on the entry at performance time
    /// (`ExerciseEntry.sportDisciplineSnapshot`), never the live `exercise`
    /// relationship — a later catalog reclassification must never
    /// retroactively change what an already-completed set counted toward.
    static func policy(for entry: ExerciseEntry) -> SportAnalyticsPolicy {
        policy(discipline: entry.sportDisciplineSnapshot, strongmanEventFamily: entry.strongmanEventFamilySnapshot)
    }
}
