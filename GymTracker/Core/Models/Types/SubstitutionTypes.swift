import Foundation

/// Decision-aware substitution vocabulary.
///
/// Two results are reported **independently** and are never collapsed into a
/// single equivalence score: `SubstitutionSuitability` answers "does this
/// preserve today's training purpose?" and `SubstitutionComparability`
/// answers "can load and progression history be read across the two
/// exercises?". A good hypertrophy substitute can legitimately have entirely
/// separate history, and the UI must be able to say exactly that.
///
/// Raw values are stable persistence keys and must not change once shipped.
/// Display titles are localized separately; nothing here is user-facing text.

/// Why the lifter is replacing the exercise. Structured, never free text, so
/// the reason can drive evaluation, survive a backup round trip, and be
/// localized after the fact.
enum SubstitutionReason: String, Codable, CaseIterable, Sendable {
    case equipmentUnavailable
    case discomfort
    case fatigue
    case skillOrConfidence
    case preference
    case timeConstraint
    case homeEquipment
    case permanentPlanChange
    /// Chosen explicitly by the lifter when intent is genuinely unclear. It is
    /// never inferred on their behalf and never treated as a neutral default.
    case notSure
}

/// Does the candidate preserve today's training purpose?
enum SubstitutionSuitability: String, Codable, CaseIterable, Sendable {
    case excellent
    case good
    case acceptable
    case poor
    case notRecommended
    /// Evidence is missing, not neutral. Never produced as an optimistic
    /// fallback for a candidate that simply scored low.
    case insufficientInformation

    /// Ordering for ranking only. `insufficientInformation` deliberately sorts
    /// below every graded outcome instead of somewhere in the middle: an
    /// unknown option must never outrank a known-acceptable one.
    var rankValue: Int {
        switch self {
        case .excellent: return 5
        case .good: return 4
        case .acceptable: return 3
        case .poor: return 2
        case .insufficientInformation: return 1
        case .notRecommended: return 0
        }
    }

    /// Hard-filtered and not-recommended options stay visible but unselectable
    /// so the lifter can see *why* an option is unavailable.
    var isSelectable: Bool { self != .notRecommended }
}

/// Can load and progression history be read across the two exercises?
///
/// Deliberately strict. `direct` requires the same exercise configuration,
/// resistance implementation, range-of-motion and technique standard, tracking
/// semantics, load interpretation, and relevant assistance. Anything less is
/// `limited` or `notDirect`; anything unproven is `unknown`.
enum SubstitutionComparability: String, Codable, CaseIterable, Sendable {
    case direct
    case limited
    case notDirect
    /// At least one field needed to judge comparability is absent on one of
    /// the two exercises. Not a synonym for `notDirect` — it means the app
    /// does not know, and it must say so.
    case unknown

    /// The single gate on offering shared progression state. Only a `direct`
    /// match may even present the option; the lifter still has to choose it.
    var allowsSharedProgression: Bool { self == .direct }
}

/// What happens to progression state after the substitution.
///
/// This replaces a Boolean that conflated "we do not know" with "no". The
/// Boolean `ExerciseEntry.substitutionSharesProgressionState` remains the
/// persisted value the progression services read; this enum is the
/// explainable decision behind it, and the two are kept in lockstep by
/// `ExerciseEntry.applySubstitutionDecision(_:)`.
enum ProgressionTransferPolicy: String, Codable, CaseIterable, Sendable {
    /// Default. The substitute starts its own progression state.
    case separate
    /// Explicitly chosen by the lifter, and only offerable when comparability
    /// is `direct`.
    case continueShared
    /// Evidence was missing, so no decision could be made. Behaves exactly
    /// like `separate` at runtime but stays distinguishable in history.
    case undetermined

    /// The authority for the persisted Boolean. `undetermined` must resolve to
    /// `false`: unknown never silently becomes yes.
    var sharesProgressionState: Bool { self == .continueShared }
}

/// How far the substitution decision reaches. Today-only is always the
/// default; replacing the exercise in the plan is a separate previewed action.
enum SubstitutionScope: String, Codable, CaseIterable, Sendable {
    case todayOnly
    case futurePlan
}

/// A coarse qualifier on the evidence behind an evaluation. Never a numeric
/// score and never presented as a percentage.
enum SubstitutionEvidenceConfidence: String, Codable, CaseIterable, Sendable {
    case high
    case moderate
    case low
    /// Too little evidence to grade at all; pairs with
    /// `SubstitutionSuitability.insufficientInformation`.
    case insufficient
}

/// Where a curated substitution link came from. Legacy rows persisted before
/// this field existed read as `systemUnreviewed`.
enum SubstitutionProvenance: String, Codable, CaseIterable, Sendable {
    /// A coach-reviewed curated link.
    case systemReviewed
    /// Shipped in seed data but not yet through curation review. Treated as
    /// evidence-limited so the app never overstates what it knows.
    case systemUnreviewed
    case userAuthored
    case importedProgram

    /// Only a reviewed or deliberately user-authored link can support a
    /// high-confidence claim.
    var supportsHighConfidence: Bool {
        self == .systemReviewed || self == .userAuthored
    }
}

/// The complete decision the lifter confirmed, passed as one value into the
/// mutation path so no call site can set half of it.
struct SubstitutionDecision: Equatable, Sendable {
    let reason: SubstitutionReason
    let scope: SubstitutionScope
    let progressionPolicy: ProgressionTransferPolicy
    let evaluation: SubstitutionEvaluationSnapshot

    init(
        reason: SubstitutionReason,
        scope: SubstitutionScope,
        progressionPolicy: ProgressionTransferPolicy,
        evaluation: SubstitutionEvaluationSnapshot
    ) {
        self.reason = reason
        self.scope = scope
        // A policy the evaluation cannot support is downgraded here rather
        // than trusted from the caller. This is the last line of defense for
        // the invariant that `unknown` comparability never shares state.
        self.progressionPolicy = evaluation.comparability.allowsSharedProgression
            ? progressionPolicy
            : (progressionPolicy == .continueShared ? .separate : progressionPolicy)
        self.evaluation = evaluation
    }
}
