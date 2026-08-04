import Foundation
import SwiftData

// MARK: - Measurement policy

/// A versioned, in-memory catalogue of how strict a retest has to be before
/// a change in a `MobilityAssessmentResult` pair is worth naming out loud.
///
/// This is deliberately not persisted. `MobilityAssessmentDefinition` (the
/// `@Model` catalogue entity) already snapshots onto every `Result` at
/// capture time, so a policy edit here never needs a migration and never
/// rewrites history — it only changes how *future* comparisons are judged.
/// If this ever needs to become part of a portable backup or a synced
/// catalogue, that is a schema decision for a different change, not this
/// one.
struct MobilityAssessmentMeasurementPolicy: Codable, Hashable, Sendable {
    /// Bumped whenever the policy's *shape* or *meaning* changes (a field is
    /// added, or an existing field's semantics shift) — not when a value in
    /// the catalogue below is retuned. Nothing reads this yet; it exists so
    /// a future stored interpretation (if one is ever added) can record
    /// which policy produced it, the same way `definitionVersionSnapshot`
    /// lets a result outlive a catalogue edit.
    let policyVersion: Int

    /// How many trials `MobilityAssessmentSample.sampleCount` must reach
    /// before a result counts as more than a single guess. Below this, the
    /// result is `.insufficientTrials` regardless of how big the apparent
    /// change is — a sample size of one has no way to distinguish a real
    /// change from the trial-to-trial wobble every repeated-measurement
    /// protocol has.
    let requiredTrialCount: Int

    /// Practice reps intended to happen before the counted trials, so the
    /// person isn't still learning the setup while being measured. Not
    /// currently consulted by `MobilityAssessmentChangeInterpreter`:
    /// `MobilityAssessmentSample` has no field distinguishing a
    /// familiarization rep from a counted one, so there is nothing here yet
    /// to check it against. Kept on the policy so that distinction has
    /// somewhere to land the day 3d's capture flow adds it, instead of a
    /// second policy type appearing later.
    let familiarizationTrialCount: Int

    /// The most that `sample.maximum - sample.minimum` may spread within one
    /// sitting before the sample itself is called `.unstable` rather than
    /// `.acceptable`. Left `nil` in every catalogue entry below — see the
    /// catalogue's own comment for why an absent bound here is a decision,
    /// not an oversight, and why `.unstable` still cannot be reached by an
    /// invented number.
    let maximumWithinSessionSpread: Double?

    /// A sourced device/method error figure (e.g. an inclinometer's
    /// published resolution), for a future policy that wants to reason about
    /// instrument error independently of within-session spread. This
    /// repository has no such sourced figure for any seeded definition, so
    /// every catalogue entry leaves it `nil`. Nothing currently reads it —
    /// `MobilityAssessmentChangeInterpreter` derives its actual comparison
    /// threshold from `minimumMeaningfulChange`, described below.
    let expectedMeasurementError: Double?

    /// The delta, in the definition's own unit, below which a change must
    /// not be reported as real. When this is `nil` (every catalogue entry
    /// below), the interpreter does **not** fall back to treating any change
    /// as meaningful — it derives a threshold from the two results' own
    /// recorded `MobilityAssessmentSample` spread instead, or returns
    /// `.measurementUncertain` when even that isn't available. A policy
    /// author who later sources a real clinical minimal-detectable-change
    /// figure can set this field directly and it takes priority over the
    /// derived value — see `MobilityAssessmentChangeInterpreter
    /// .meaningfulChangeThreshold(current:previous:policy:)`.
    let minimumMeaningfulChange: Double?

    /// The lowest `MobilityMeasurementConfidence` either side of a
    /// comparison may have before the interpreter will consider a threshold
    /// crossing meaningful. A manually entered result can never exceed
    /// `.moderate` — `MobilityAssessmentValidationService.validate` already
    /// rejects `.manualConfidenceTooHigh` at save time, so this policy field
    /// does not need to special-case `source == .manual` itself; it only
    /// needs to state the bar, and manual entries either clear it at
    /// `.moderate` or never existed to be compared.
    let requiredConfidence: MobilityMeasurementConfidence

    /// A recommended window, in days, for a retest to be considered a fair
    /// comparison (too soon: not enough time for a real change; too long:
    /// too many confounds). Not currently enforced —
    /// `MobilityAssessmentChangeInterpretation` has no "too soon to compare"
    /// or "too stale to compare" case, and inventing one was not part of
    /// this change's scope. Carried on the policy so that decision has a
    /// place to land without a second policy type, the same reasoning as
    /// `familiarizationTrialCount` above.
    let retestIntervalDays: ClosedRange<Int>?
}

/// The catalogue `MobilityAssessmentChangeInterpreter` consults, keyed by
/// `MobilityAssessmentDefinition.catalogueKey`.
enum MobilityAssessmentMeasurementPolicyCatalogue {
    static let currentVersion = 1

    /// Every definition seeded today (`MobilityAssessmentSeedData
    /// .definitions`) records only manual entries — `MobilityAssessmentSample`
    /// is written by nothing yet in this codebase; 3c's `saveResult` always
    /// sets `sample = nil`. There is therefore no repeated-trial evidence
    /// anywhere yet to justify *differentiating* one definition's required
    /// trial count or spread bound from another's, and inventing per-test
    /// numbers now, before 3d's capture flow exists to validate them against
    /// real data, would be exactly the fabricated-threshold mistake this
    /// type is designed to avoid. So every seeded key gets the same
    /// deliberately plain policy below rather than 10 hand-tuned ones.
    ///
    /// `maximumWithinSessionSpread` and `expectedMeasurementError` stay
    /// `nil` for the same reason stated on
    /// `MobilityAssessmentMeasurementPolicy` itself: no sourced figure
    /// exists. This does mean `MobilityMeasurementQuality.unstable` is not
    /// reachable through the spread check today (only through
    /// `.insufficientTrials`) — an honest consequence of not inventing a
    /// spread bound, not a bug to paper over with a guessed number.
    private static let standard = MobilityAssessmentMeasurementPolicy(
        policyVersion: currentVersion,
        requiredTrialCount: 3,
        familiarizationTrialCount: 1,
        maximumWithinSessionSpread: nil,
        expectedMeasurementError: nil,
        minimumMeaningfulChange: nil,
        requiredConfidence: .moderate,
        retestIntervalDays: nil
    )

    /// Derived from the seed list itself — never a second, hand-copied list
    /// of the same ten keys — so this catalogue cannot silently drift out of
    /// sync with `MobilityAssessmentSeedData.definitions` the way two
    /// independently maintained key lists eventually do.
    private static let known: [String: MobilityAssessmentMeasurementPolicy] = Dictionary(
        uniqueKeysWithValues: MobilityAssessmentSeedData.definitions.map { ($0.key, standard) }
    )

    /// The policy for any catalogue key `known` has never heard of — most
    /// importantly, any definition added to the seed catalogue after this
    /// file was last updated to match it. `requiredTrialCount` is set to a
    /// value no real `MobilityAssessmentSample.sampleCount` can ever reach,
    /// and `requiredConfidence` is pinned to `.high`, a bar
    /// `MobilityAssessmentValidationService` never lets a manually entered
    /// result clear. Both exist so this default can only ever route a
    /// comparison to `.measurementUncertain` — never to `.noClearChange` or
    /// `.clearIncrease`/`.clearDecrease`. An unrecognised definition must
    /// degrade to "cannot judge," not license a confident claim by
    /// accident.
    static let conservativeDefault = MobilityAssessmentMeasurementPolicy(
        policyVersion: currentVersion,
        requiredTrialCount: .max,
        familiarizationTrialCount: 0,
        maximumWithinSessionSpread: nil,
        expectedMeasurementError: nil,
        minimumMeaningfulChange: nil,
        requiredConfidence: .high,
        retestIntervalDays: nil
    )

    static func policy(for catalogueKey: String) -> MobilityAssessmentMeasurementPolicy {
        known[catalogueKey] ?? conservativeDefault
    }
}

// MARK: - Direction

/// Whether a larger raw stored value means more range for a given
/// assessment. Most of the ten seeded assessments record an angle that
/// opens up as range improves, but that is not universal — a linear
/// distance-to-floor style test can just as easily shrink as range
/// improves — and `MobilityAssessmentDefinition` has no field anywhere that
/// records which convention a given test follows. Recalling from memory how
/// each test is "usually" scored — e.g. assuming the knee-to-wall
/// centimetre distance rises with dorsiflexion because that is the common
/// clinical convention — is exactly the unsourced assumption this
/// interpreter exists to refuse: nothing in this repository states it, the
/// next centimetre-unit test added to the catalogue might not share the
/// convention, and there would be nothing here to catch the mismatch.
///
/// `known` is populated below strictly from each definition's own recorded
/// `measurementDescriptionLocalizationKey` / `instructionsLocalizationKey`
/// English text in `Localizable.xcstrings`
/// (`mobility.assessment.<stem>.measures` / `.instructions`) — never from
/// outside clinical knowledge of how a test is "usually" scored. A
/// definition whose own text does not settle the direction is left absent
/// rather than guessed; an absent key degrades safely to
/// `.measurementUncertain` in `MobilityAssessmentChangeInterpreter`, while a
/// wrong entry would silently report a lifter's decline as an improvement
/// (or vice versa), which is the one failure mode this type exists to rule
/// out.
///
/// `.criteria`-unit definitions (currently only the wall squat) are
/// deliberately never given an entry: they have no numeric value for a
/// polarity to apply to, and `MobilityAssessmentChangeInterpreter` already
/// refuses a numeric claim for them at the `comparison.numericDelta == nil`
/// guard before `MobilityAssessmentValuePolarity.of` is ever consulted for
/// that key.
enum MobilityAssessmentValuePolarity: Sendable {
    case increasesWithRange
    case decreasesWithRange

    private static let known: [String: MobilityAssessmentValuePolarity] = [
        // "How far your upper back turns to each side while your hips stay
        // square." (mobility.assessment.thoracic.rotation.seated.measures)
        // — a bigger recorded angle is a further turn, i.e. more range.
        "mobility-assessment.thoracic-rotation-seated": .increasesWithRange,

        // "How far your chest opens toward the floor while your knees stay
        // stacked." (mobility.assessment.open.book.rotation.measures) — the
        // instructions record "the angle your chest reached"; a bigger angle
        // is a further open, i.e. more range.
        "mobility-assessment.open-book-rotation": .increasesWithRange,

        // "How high you can raise one straight leg using your own effort."
        // (mobility.assessment.active.straight.leg.raise.measures) — a
        // bigger recorded angle is a higher raise, i.e. more range.
        "mobility-assessment.active-straight-leg-raise": .increasesWithRange,

        // "The distance from your toe to the wall at the furthest point
        // where your knee still touches with your heel down."
        // (mobility.assessment.knee.to.wall.dorsiflexion.measures), read
        // together with the instructions: "Slide your foot back until your
        // knee just touches the wall with your heel staying down. Measure
        // the distance from your big toe to the wall." This is the
        // maximal-distance toe-to-wall protocol, not a knee-to-wall gap: the
        // foot is walked *back* from the wall and the furthest distance at
        // which the knee can still reach the wall is recorded, so a bigger
        // centimetre value means the foot could be placed further away
        // while still reaching full dorsiflexion, i.e. more range. This is
        // the one entry the task flagged as needing real care — it is
        // recorded here only because the definition's own "furthest point"
        // and "slide your foot back" wording settles it, not by assuming
        // the common clinical convention.
        "mobility-assessment.knee-to-wall-dorsiflexion": .increasesWithRange,

        // "How far your shin travels forward over your foot with the knee
        // bent and the heel down." (mobility.assessment.soleus.wall.stretch
        // .measures) — a bigger recorded angle is more forward shin travel,
        // i.e. more range.
        "mobility-assessment.soleus-wall-stretch": .increasesWithRange,

        // "How far each hip turns in this seated position using your own
        // effort." (mobility.assessment.90.90.hip.rotation.measures) — a
        // bigger recorded angle is a further turn, i.e. more range.
        "mobility-assessment.90-90-hip-rotation": .increasesWithRange,

        // "The angle between your two thighs at the widest position you can
        // hold." (mobility.assessment.straddle.frog.abduction.measures) — a
        // bigger recorded angle is a wider straddle, i.e. more range.
        "mobility-assessment.straddle-frog-abduction": .increasesWithRange,

        // "How far your shoulder rotates inward with your shoulder blade
        // held still." (mobility.assessment.sleeper.shoulder.rotation
        // .measures) — a bigger recorded angle is more inward rotation,
        // i.e. more range.
        "mobility-assessment.sleeper-shoulder-rotation": .increasesWithRange,

        // "How far your arm rises with your back and ribs kept against the
        // wall." (mobility.assessment.wall.slide.arm.elevation.measures) —
        // the instructions record "the angle of your forearm at the highest
        // position you can hold"; a bigger angle is a higher slide, i.e.
        // more range.
        "mobility-assessment.wall-slide-arm-elevation": .increasesWithRange

        // "mobility-assessment.wall-squat" is intentionally absent: its unit
        // is `.criteria` ("Whether you can reach a full squat... while
        // keeping your heels down and staying off the wall"), not a
        // numeric range value, so no polarity claim applies to it.
    ]

    static func of(_ catalogueKey: String) -> MobilityAssessmentValuePolarity? {
        known[catalogueKey]
    }
}

// MARK: - Measurement quality

/// Describes the *measurement*, never the person. `MobilityAssessmentCopy`'s
/// header rule — no word here may imply "poor mobility" — applies just as
/// much to this type as it does to any user-facing string: this is a
/// statement about how trustworthy the recorded evidence is, not about what
/// the evidence shows.
enum MobilityMeasurementQuality: String, Codable, Sendable {
    /// Includes every manual, single-entry result — `sample == nil` — not
    /// only device captures that fell short of the trial count. A hand-typed
    /// number has exactly one trial by construction; treating it as
    /// automatically `.acceptable` would be indistinguishable from claiming
    /// a single guess is as trustworthy as a repeated, sampled measurement.
    case insufficientTrials
    case unstable
    case acceptable

    /// `sampleCount` and the recorded spread come from the concrete
    /// evidence already stored on `result.sample` — no new sampling logic,
    /// only a read of what 3c/3d already persist.
    static func evaluate(
        _ result: MobilityAssessmentResult,
        against policy: MobilityAssessmentMeasurementPolicy
    ) -> MobilityMeasurementQuality {
        guard let sample = result.sample else {
            return .insufficientTrials
        }
        guard sample.sampleCount >= policy.requiredTrialCount else {
            return .insufficientTrials
        }
        if let maximumSpread = policy.maximumWithinSessionSpread,
           (sample.maximum - sample.minimum) > maximumSpread {
            return .unstable
        }
        return .acceptable
    }
}

// MARK: - Interpretation

/// The result of asking "does this pair of results show a real change,"
/// never "is this person more or less mobile." Every case names a fact
/// about the *comparison*; none of them renders to copy that grades the
/// person, matching the rule `MobilityAssessmentCopy`'s header already
/// states for this domain.
enum MobilityAssessmentChangeInterpretation: Equatable, Sendable {
    /// There is no earlier result for this definition at all — not even one
    /// with different conditions. First time seeing this assessment.
    case noComparableHistory

    /// An earlier result exists, but at least one recorded condition
    /// differs (side, setup, method, unit, active/passive, or warm/cold —
    /// `MobilityAssessmentComparisonService.conditionDifferences` is the
    /// single source for which). A number could still be computed by
    /// subtracting the two, but it would compare two different questions,
    /// not the same question asked twice, so no delta is reported.
    case notDirectlyComparable([MobilityAssessmentConditionDifference])

    /// Conditions match, but the evidence isn't strong enough to say
    /// anything about the size of the change: too few trials, too unstable
    /// a sample, confidence below what the policy requires, or no
    /// meaningful-change threshold could be established at all (no sourced
    /// policy value and no recorded within-session spread to derive one
    /// from). This is also where an unrecognised catalogue key and an
    /// unestablished value polarity both land.
    case measurementUncertain

    /// The delta is smaller than the meaningful-change threshold. This is
    /// the case the whole type exists to make reachable: a small delta must
    /// resolve *here*, never to `.clearIncrease`, no matter how it would
    /// look plotted on its own.
    case noClearChange(delta: Double, threshold: Double)

    /// The raw stored value rose by at least the threshold. This states the
    /// *direction of the number*, not "this person's mobility improved" —
    /// whether a rising number means more range for this specific
    /// assessment is exactly the polarity question `MobilityAssessmentValuePolarity`
    /// documents, and this case is only reached once that polarity is known.
    case clearIncrease(delta: Double, threshold: Double)

    /// The raw stored value fell by at least the threshold. Same caveat as
    /// `.clearIncrease` in reverse.
    case clearDecrease(delta: Double, threshold: Double)
}

// MARK: - Interpreter

/// Turns a `MobilityAssessmentResult` plus its history into one of the
/// cases above. This is pure value logic: it reads `MobilityAssessmentResult`
/// / `MobilityAssessmentSample` fields that already exist and delegates
/// every comparability question to the already-shipped
/// `MobilityAssessmentComparisonService` — it does not re-decide side,
/// setup, method, unit, active/passive, or warm/cold agreement itself, and
/// must never grow a second opinion about that. Its only job is what
/// happens *after* two results are already known to be directly comparable:
/// deciding whether their numeric difference is worth naming.
@MainActor
enum MobilityAssessmentChangeInterpreter {
    /// - Parameters:
    ///   - current: The result being evaluated.
    ///   - history: Every other result available for this definition (any
    ///     order; `MobilityAssessmentComparisonService.latestComparison`
    ///     does the sorting and nearest-comparable-match search). Pass
    ///     `MobilityAssessmentHistoryQuery.results(definitionCatalogueKey:side:)`
    ///     for a real call site.
    ///   - policy: Overrides the catalogue lookup. Left `nil` in normal use;
    ///     exists so a caller (or a test) can pin an exact policy without
    ///     depending on `MobilityAssessmentMeasurementPolicyCatalogue`'s
    ///     current contents.
    static func interpret(
        current: MobilityAssessmentResult,
        among history: [MobilityAssessmentResult],
        policy: MobilityAssessmentMeasurementPolicy? = nil
    ) -> MobilityAssessmentChangeInterpretation {
        let comparison = MobilityAssessmentComparisonService.latestComparison(for: current, among: history)

        // Order step 1: `latestComparison` returns a nil `previousResultID`
        // only when `history` contained no earlier result at all — not even
        // one with mismatched conditions. That is a genuinely different
        // situation from step 2 below and must not be folded into it: "no
        // history" and "history exists but doesn't match" read very
        // differently to a caller deciding what to show.
        guard let previousResultID = comparison.previousResultID else {
            return .noComparableHistory
        }

        // Order step 2: delegate entirely to the existing comparability
        // verdict. `differingConditions` is already exactly the list this
        // case needs — recomputing it here would be the parallel matcher
        // this change is explicitly forbidden from creating.
        guard comparison.comparability == .direct else {
            return .notDirectlyComparable(comparison.differingConditions)
        }

        guard let previous = history.first(where: { $0.id == previousResultID }) else {
            // `latestComparison` named a previous result ID that isn't
            // actually present in the `history` slice this call was given
            // (a caller passed a partial/stale list). There is no result
            // object here to check quality or confidence against, so this
            // cannot honestly be more than "no comparable result was
            // actually available" — never a fabricated delta.
            return .noComparableHistory
        }

        let effectivePolicy = policy
            ?? MobilityAssessmentMeasurementPolicyCatalogue.policy(for: current.definitionCatalogueKeySnapshot)

        // Order step 3a: either side's evidence quality.
        guard MobilityMeasurementQuality.evaluate(current, against: effectivePolicy) == .acceptable,
              MobilityMeasurementQuality.evaluate(previous, against: effectivePolicy) == .acceptable else {
            return .measurementUncertain
        }

        // Order step 3b: either side's confidence. Manual entries are
        // already capped at `.moderate` by `MobilityAssessmentValidationService
        // .validate` (`.manualConfidenceTooHigh`) before a result can ever
        // be saved, so this does not need to special-case `source == .manual`
        // itself — it only needs to compare the stored rank to what the
        // policy requires, and a manual result either clears `.moderate` or
        // was never persisted.
        guard current.confidence.rank >= effectivePolicy.requiredConfidence.rank,
              previous.confidence.rank >= effectivePolicy.requiredConfidence.rank else {
            return .measurementUncertain
        }

        // Criteria-based assessments (currently only the wall squat) have no
        // numeric value at all, so `compare(current:previous:)` leaves
        // `numericDelta` `nil` even when the conditions match perfectly.
        // There is no signed change to threshold-test, so this can only
        // ever be "uncertain," never "no change" — "no change" would wrongly
        // imply a number was actually compared.
        guard let delta = comparison.numericDelta else {
            return .measurementUncertain
        }

        // Order step 3c: no meaningful-change threshold could be
        // established at all.
        guard let threshold = meaningfulChangeThreshold(current: current, previous: previous, policy: effectivePolicy) else {
            return .measurementUncertain
        }

        // Order step 4, checked strictly before step 5 below: a delta
        // inside expected measurement variability is `.noClearChange`,
        // full stop. This guard is what makes it structurally impossible
        // for a sub-threshold delta to reach the `.clearIncrease` return
        // beneath it — the single rule this type exists to enforce.
        guard abs(delta) >= threshold else {
            return .noClearChange(delta: delta, threshold: threshold)
        }

        // The delta clears the threshold, but naming it "increase" or
        // "decrease" only means something if a larger raw value is known to
        // mean more (or less) range for this specific definition.
        // `MobilityAssessmentValuePolarity.of` returns `nil` for the wall
        // squat (`.criteria` unit, no numeric direction to record) and for
        // any future catalogue key added without a sourced polarity entry —
        // this guard is what keeps a beyond-threshold delta at
        // `.measurementUncertain` for those instead of asserting a direction
        // nobody has actually confirmed. See that type's header for how the
        // nine numeric seeded definitions were each sourced.
        guard MobilityAssessmentValuePolarity.of(current.definitionCatalogueKeySnapshot) != nil else {
            return .measurementUncertain
        }

        return delta > 0
            ? .clearIncrease(delta: delta, threshold: threshold)
            : .clearDecrease(delta: delta, threshold: threshold)
    }

    /// A sourced policy value always wins when present. Otherwise, derives
    /// a threshold from the two results' own recorded
    /// `MobilityAssessmentSample` spread — the largest within-session swing
    /// either sitting actually produced — rather than inventing a clinical
    /// minimal-detectable-change figure this repository has no source for.
    /// The reasoning: a between-session delta smaller than the noise
    /// already observed *within* a single sitting cannot be told apart from
    /// that same noise, so the noise already on record is the only honest
    /// floor available. When neither value is sourced and no sample exists
    /// on both sides to derive one from, this returns `nil` and the caller
    /// reports `.measurementUncertain` rather than silently treating "no
    /// threshold" as "any change is real."
    private static func meaningfulChangeThreshold(
        current: MobilityAssessmentResult,
        previous: MobilityAssessmentResult,
        policy: MobilityAssessmentMeasurementPolicy
    ) -> Double? {
        if let sourced = policy.minimumMeaningfulChange {
            return sourced
        }
        guard let currentSample = current.sample, let previousSample = previous.sample else {
            return nil
        }
        let currentSpread = currentSample.maximum - currentSample.minimum
        let previousSpread = previousSample.maximum - previousSample.minimum
        return max(currentSpread, previousSpread)
    }
}
