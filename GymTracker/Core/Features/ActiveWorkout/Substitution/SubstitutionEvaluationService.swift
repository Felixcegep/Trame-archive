import Foundation

/// One evaluated option, ready to rank and render.
struct SubstitutionEvaluation: Equatable {
    let exercise: Exercise
    let snapshot: SubstitutionEvaluationSnapshot

    var suitability: SubstitutionSuitability { snapshot.suitability }
    var comparability: SubstitutionComparability { snapshot.comparability }
    var confidence: SubstitutionEvidenceConfidence { snapshot.confidence }
    var isSelectable: Bool { suitability.isSelectable }

    static func == (lhs: SubstitutionEvaluation, rhs: SubstitutionEvaluation) -> Bool {
        lhs.exercise.id == rhs.exercise.id && lhs.snapshot == rhs.snapshot
    }
}

/// Stable localization keys for the evidence a verdict is built from. These are
/// persisted inside `SubstitutionEvaluationSnapshot`, so they must never change
/// once shipped — a snapshot written today has to render years from now.
enum SubstitutionFactorCode {
    static let movementPattern = "substitution.factor.movementPattern"
    static let primaryMuscles = "substitution.factor.primaryMuscles"
    static let secondaryMuscles = "substitution.factor.secondaryMuscles"
    static let variationFamily = "substitution.factor.variationFamily"
    static let equipment = "substitution.factor.equipment"
    static let resistance = "substitution.factor.resistance"
    static let mechanics = "substitution.factor.mechanics"
    static let rangeOfMotion = "substitution.factor.rangeOfMotion"
    static let grip = "substitution.factor.grip"
    static let stance = "substitution.factor.stance"
    static let laterality = "substitution.factor.laterality"
    static let tracking = "substitution.factor.tracking"
    static let loadInterpretation = "substitution.factor.loadInterpretation"
    static let difficulty = "substitution.factor.difficulty"
    static let stimulus = "substitution.factor.stimulus"
    static let goal = "substitution.factor.goal"
    static let curatedRationale = "substitution.factor.curatedRationale"
    static let unreviewedLink = "substitution.factor.unreviewedLink"

    // Hard-filter failures.
    static let equipmentUnavailable = "substitution.filter.equipmentUnavailable"
    static let incompatibleTracking = "substitution.filter.incompatibleTracking"
    static let uncomfortablePosition = "substitution.filter.uncomfortablePosition"
    static let skillInappropriate = "substitution.filter.skillInappropriate"
}

/// Ranks and explains **known** substitution candidates.
///
/// Pure and synchronous by design — no `ModelContext`, no I/O, no `@MainActor`
/// — so it is deterministic and testable without a store fixture.
///
/// The two verdicts it produces are computed independently and never merged.
/// Suitability asks whether today's purpose survives; comparability asks
/// whether load history transfers. A dumbbell press can be an excellent
/// hypertrophy substitute for a barbell press *and* have completely separate
/// load history, and this service says both things.
///
/// Missing evidence is reported as missing. There is no optimistic default
/// anywhere in this file: an absent field yields
/// `insufficientInformation`/`unknown`, never a middling guess.
enum SubstitutionEvaluationService {
    /// Versioned product rules, not scientific constants. The weights below
    /// encode a coaching opinion that a plan's goal should shift which
    /// differences matter; they are validated by review, not by literature.
    /// Bump this whenever a rule changes so old snapshots stay interpretable
    /// under the rules that actually produced them.
    static let ruleVersion = 1
    static let ruleID = "substitution.rules.v1"

    // MARK: - Entry points

    static func rankedEvaluations(
        for source: Exercise,
        candidates: [SubstitutionCandidate],
        context: SubstitutionContext
    ) -> [SubstitutionEvaluation] {
        candidates
            .map { evaluate(source: source, candidate: $0, context: context) }
            .sorted { isOrderedBefore($0, $1) }
    }

    /// Total order: better suitability first, then better comparability, then
    /// higher confidence, then localized name. Fully deterministic — identical
    /// inputs always produce an identical list.
    private static func isOrderedBefore(
        _ lhs: SubstitutionEvaluation,
        _ rhs: SubstitutionEvaluation
    ) -> Bool {
        if lhs.suitability.rankValue != rhs.suitability.rankValue {
            return lhs.suitability.rankValue > rhs.suitability.rankValue
        }
        if comparabilityRank(lhs.comparability) != comparabilityRank(rhs.comparability) {
            return comparabilityRank(lhs.comparability) > comparabilityRank(rhs.comparability)
        }
        if confidenceRank(lhs.confidence) != confidenceRank(rhs.confidence) {
            return confidenceRank(lhs.confidence) > confidenceRank(rhs.confidence)
        }
        let comparison = lhs.exercise.name.localizedCaseInsensitiveCompare(rhs.exercise.name)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        // Final tiebreak on stable identity so equal names cannot reorder
        // between runs.
        return lhs.exercise.id.uuidString < rhs.exercise.id.uuidString
    }

    private static func comparabilityRank(_ value: SubstitutionComparability) -> Int {
        switch value {
        case .direct: return 3
        case .limited: return 2
        case .notDirect: return 1
        case .unknown: return 0
        }
    }

    private static func confidenceRank(_ value: SubstitutionEvidenceConfidence) -> Int {
        switch value {
        case .high: return 3
        case .moderate: return 2
        case .low: return 1
        case .insufficient: return 0
        }
    }

    // MARK: - Evaluation

    static func evaluate(
        source: Exercise,
        candidate: SubstitutionCandidate,
        context: SubstitutionContext
    ) -> SubstitutionEvaluation {
        let comparability = comparability(source: source, candidate: candidate.exercise, context: context)

        // Hard filters run first and short-circuit. The option is still
        // returned — shown disabled with its reason — never silently dropped,
        // so the lifter can tell "no good option" from "option hidden".
        let filterFailures = hardFilterFailures(
            source: source,
            candidate: candidate.exercise,
            context: context
        )
        if !filterFailures.isEmpty {
            return SubstitutionEvaluation(
                exercise: candidate.exercise,
                snapshot: SubstitutionEvaluationSnapshot(
                    version: ruleVersion,
                    ruleID: ruleID,
                    sourceExerciseID: source.id,
                    candidateExerciseID: candidate.exercise.id,
                    reason: context.reason,
                    suitability: .notRecommended,
                    comparability: comparability.verdict,
                    confidence: .high, // We are confident it is unsuitable.
                    matchedFactorCodes: [],
                    differingFactorCodes: [],
                    missingEvidenceCodes: comparability.missing,
                    hardFilterFailureCodes: filterFailures,
                    candidateProvenance: candidate.provenance
                )
            )
        }

        let suitability = suitability(
            source: source,
            candidate: candidate,
            context: context
        )

        return SubstitutionEvaluation(
            exercise: candidate.exercise,
            snapshot: SubstitutionEvaluationSnapshot(
                version: ruleVersion,
                ruleID: ruleID,
                sourceExerciseID: source.id,
                candidateExerciseID: candidate.exercise.id,
                reason: context.reason,
                suitability: suitability.verdict,
                comparability: comparability.verdict,
                confidence: suitability.confidence,
                matchedFactorCodes: suitability.matched,
                differingFactorCodes: suitability.differing,
                missingEvidenceCodes: Array(
                    Set(suitability.missing).union(comparability.missing)
                ).sorted(),
                hardFilterFailureCodes: [],
                candidateProvenance: candidate.provenance
            )
        )
    }

    // MARK: - Hard filters

    private static func hardFilterFailures(
        source: Exercise,
        candidate: Exercise,
        context: SubstitutionContext
    ) -> [String] {
        var failures: [String] = []

        // Unknown availability never filters. Only an explicitly stated
        // equipment set can rule an option out.
        if let available = context.availableEquipment,
           let required = candidate.equipmentType,
           !available.contains(required) {
            failures.append(SubstitutionFactorCode.equipmentUnavailable)
        }

        if !isTrackingCompatible(context.prescribedTracking, candidate.trackingType) {
            failures.append(SubstitutionFactorCode.incompatibleTracking)
        }

        if context.reason == .discomfort,
           let pattern = candidate.movementPattern,
           context.uncomfortablePositions.contains(pattern) {
            failures.append(SubstitutionFactorCode.uncomfortablePosition)
        }

        // Only applies when the lifter said skill is the problem: offering a
        // harder movement then defeats the purpose of the swap.
        if context.reason == .skillOrConfidence,
           let sourceDifficulty = source.difficulty,
           let candidateDifficulty = candidate.difficulty,
           difficultyRank(candidateDifficulty) > difficultyRank(sourceDifficulty) {
            failures.append(SubstitutionFactorCode.skillInappropriate)
        }

        return failures
    }

    /// A substitute must be loggable against the same prescription. Weighted
    /// and bodyweight-assisted variants stay mutually compatible because the
    /// prescription structure (sets and reps against a load) survives; a
    /// duration or calorie exercise cannot stand in for a rep-based one.
    private static func isTrackingCompatible(_ prescribed: TrackingType, _ candidate: TrackingType) -> Bool {
        if prescribed == candidate { return true }
        let repBased: Set<TrackingType> = [
            .weightAndReps, .repsOnly, .weightedBodyweight, .assistedBodyweight
        ]
        if repBased.contains(prescribed) && repBased.contains(candidate) { return true }
        let timeBased: Set<TrackingType> = [.duration, .durationAndDistance]
        return timeBased.contains(prescribed) && timeBased.contains(candidate)
    }

    private static func difficultyRank(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }

    // MARK: - Suitability

    private struct SuitabilityResult {
        let verdict: SubstitutionSuitability
        let confidence: SubstitutionEvidenceConfidence
        let matched: [String]
        let differing: [String]
        let missing: [String]
    }

    private static func suitability(
        source: Exercise,
        candidate: SubstitutionCandidate,
        context: SubstitutionContext
    ) -> SuitabilityResult {
        var matched: [String] = []
        var differing: [String] = []
        var missing: [String] = []
        var score = 0
        var maximumScore = 0

        /// Records one comparison. A field absent on either side is recorded as
        /// missing evidence and contributes to neither the numerator nor the
        /// denominator — an unknown must not read as a match.
        func compare<T: Equatable>(
            _ lhs: T?,
            _ rhs: T?,
            code: String,
            weight: Int
        ) {
            guard let lhs, let rhs else {
                missing.append(code)
                return
            }
            maximumScore += weight
            if lhs == rhs {
                score += weight
                matched.append(code)
            } else {
                differing.append(code)
            }
        }

        let weights = weighting(for: context)

        compare(source.movementPattern, candidate.exercise.movementPattern,
                code: SubstitutionFactorCode.movementPattern, weight: weights.movementPattern)
        compare(source.mechanics, candidate.exercise.mechanics,
                code: SubstitutionFactorCode.mechanics, weight: weights.mechanics)
        compare(source.rangeOfMotion, candidate.exercise.rangeOfMotion,
                code: SubstitutionFactorCode.rangeOfMotion, weight: weights.rangeOfMotion)
        compare(source.resistanceType, candidate.exercise.resistanceType,
                code: SubstitutionFactorCode.resistance, weight: weights.resistance)
        compare(source.equipmentType, candidate.exercise.equipmentType,
                code: SubstitutionFactorCode.equipment, weight: weights.equipment)
        compare(source.gripStyle, candidate.exercise.gripStyle,
                code: SubstitutionFactorCode.grip, weight: weights.grip)
        compare(source.stance, candidate.exercise.stance,
                code: SubstitutionFactorCode.stance, weight: weights.stance)

        // Muscle coverage is always present as an array, but an empty array is
        // absence of evidence, not a mismatch.
        if source.primaryMuscles.isEmpty || candidate.exercise.primaryMuscles.isEmpty {
            missing.append(SubstitutionFactorCode.primaryMuscles)
        } else {
            maximumScore += weights.primaryMuscles
            let shared = Set(source.primaryMuscles).intersection(candidate.exercise.primaryMuscles)
            if !shared.isEmpty {
                let coverage = Double(shared.count) / Double(Set(source.primaryMuscles).count)
                score += Int((Double(weights.primaryMuscles) * coverage).rounded())
                matched.append(SubstitutionFactorCode.primaryMuscles)
            } else {
                differing.append(SubstitutionFactorCode.primaryMuscles)
            }
        }

        compare(source.laterality, candidate.exercise.laterality,
                code: SubstitutionFactorCode.laterality, weight: weights.laterality)

        if source.variationFamilyID?.isEmpty == false || candidate.exercise.variationFamilyID?.isEmpty == false {
            maximumScore += weights.variationFamily
            if let sourceFamily = source.variationFamilyID,
               !sourceFamily.isEmpty,
               sourceFamily == candidate.exercise.variationFamilyID {
                score += weights.variationFamily
                matched.append(SubstitutionFactorCode.variationFamily)
            } else {
                differing.append(SubstitutionFactorCode.variationFamily)
            }
        } else {
            missing.append(SubstitutionFactorCode.variationFamily)
        }

        // Curated provenance is evidence in its own right, and its absence is
        // recorded rather than assumed away.
        if candidate.rationaleCode != nil, candidate.provenance.supportsHighConfidence {
            matched.append(SubstitutionFactorCode.curatedRationale)
        } else if !candidate.provenance.supportsHighConfidence {
            missing.append(SubstitutionFactorCode.unreviewedLink)
        }

        if !context.hasSufficientIntent {
            missing.append(SubstitutionFactorCode.goal)
        }

        let confidence = confidence(
            missingCount: missing.count,
            comparedCount: matched.count + differing.count,
            provenance: candidate.provenance,
            hasIntent: context.hasSufficientIntent
        )

        // Too little was actually compared to grade the option at all.
        guard maximumScore > 0, confidence != .insufficient else {
            return SuitabilityResult(
                verdict: .insufficientInformation,
                confidence: .insufficient,
                matched: matched,
                differing: differing,
                missing: missing
            )
        }

        let ratio = Double(score) / Double(maximumScore)
        let verdict: SubstitutionSuitability
        switch ratio {
        case 0.85...: verdict = .excellent
        case 0.65..<0.85: verdict = .good
        case 0.45..<0.65: verdict = .acceptable
        default: verdict = .poor
        }

        return SuitabilityResult(
            verdict: verdict,
            confidence: confidence,
            matched: matched,
            differing: differing,
            missing: missing
        )
    }

    // MARK: - Goal-dependent weighting (versioned product rules)

    private struct FactorWeights {
        var movementPattern = 3
        var primaryMuscles = 3
        var mechanics = 2
        var rangeOfMotion = 2
        var resistance = 2
        var equipment = 1
        var grip = 1
        var stance = 1
        var laterality = 2
        var variationFamily = 3
    }

    /// Product judgment, reviewed rather than derived: a powerlifting or
    /// strength context cares more about movement specificity and loading
    /// implementation, while hypertrophy cares more about muscle coverage and
    /// tolerates a different implement. Changing any of these requires a
    /// `ruleVersion` bump.
    private static func weighting(for context: SubstitutionContext) -> FactorWeights {
        var weights = FactorWeights()

        switch (context.goal, context.stimulus) {
        case (.powerlifting, _), (_, .strength), (.generalStrength, _):
            weights.movementPattern = 4
            weights.variationFamily = 4
            weights.resistance = 3
            weights.mechanics = 3
            weights.primaryMuscles = 2
        case (.hypertrophy, _), (_, .hypertrophy):
            weights.primaryMuscles = 4
            weights.rangeOfMotion = 3
            weights.equipment = 1
            weights.variationFamily = 2
        case (_, .power):
            weights.movementPattern = 4
            weights.mechanics = 3
        case (_, .endurance):
            weights.primaryMuscles = 3
            weights.equipment = 1
            weights.variationFamily = 1
        default:
            break
        }

        // The lifter's stated reason is context too: if the implement is the
        // problem, matching it cannot be what we reward.
        switch context.reason {
        case .equipmentUnavailable, .homeEquipment:
            weights.equipment = 0
            weights.resistance = max(weights.resistance - 1, 0)
        case .discomfort:
            weights.rangeOfMotion = max(weights.rangeOfMotion, 3)
            weights.grip = max(weights.grip, 2)
            weights.stance = max(weights.stance, 2)
        case .timeConstraint, .fatigue, .preference, .skillOrConfidence,
             .permanentPlanChange, .notSure:
            break
        }

        return weights
    }

    // MARK: - Comparability (computed independently of suitability)

    private struct ComparabilityResult {
        let verdict: SubstitutionComparability
        let missing: [String]
    }

    /// Deliberately strict. `direct` requires every one of: same variation
    /// family, same tracking semantics, same laterality, same weight-entry
    /// style, same load-unit count, and same resistance implementation.
    /// Dropping any single one of those six downgrades the verdict — this is
    /// what stops the app from silently reading one exercise's load history as
    /// another's.
    private static func comparability(
        source: Exercise,
        candidate: Exercise,
        context: SubstitutionContext
    ) -> ComparabilityResult {
        var missing: [String] = []

        // Any field we cannot see makes the answer unknown, not "close
        // enough". Absence of evidence is never evidence of equivalence.
        guard let sourceFamily = source.variationFamilyID, !sourceFamily.isEmpty,
              let candidateFamily = candidate.variationFamilyID, !candidateFamily.isEmpty else {
            missing.append(SubstitutionFactorCode.variationFamily)
            return ComparabilityResult(verdict: .unknown, missing: missing)
        }
        guard let sourceResistance = source.resistanceType,
              let candidateResistance = candidate.resistanceType else {
            missing.append(SubstitutionFactorCode.resistance)
            return ComparabilityResult(verdict: .unknown, missing: missing)
        }

        let sameFamily = sourceFamily == candidateFamily
        let sameTracking = source.trackingType == candidate.trackingType
        let sameLaterality = source.laterality == candidate.laterality
        let sameWeightEntry = source.weightEntryStyle == candidate.weightEntryStyle
        let sameLoadUnits = source.loadUnitCount == candidate.loadUnitCount
        let sameResistance = sourceResistance == candidateResistance

        if sameFamily && sameTracking && sameLaterality
            && sameWeightEntry && sameLoadUnits && sameResistance {
            return ComparabilityResult(verdict: .direct, missing: missing)
        }

        // Load *interpretation* differing (per-side vs total, one implement vs
        // two) is the sharpest break: the same number means a different amount
        // of work, so history cannot be read across it even loosely.
        if !sameWeightEntry || !sameLoadUnits || !sameLaterality || !sameTracking {
            return ComparabilityResult(verdict: .notDirect, missing: missing)
        }

        // Same family and same load interpretation, different implementation:
        // trends remain readable, absolute loads do not.
        if sameFamily {
            return ComparabilityResult(verdict: .limited, missing: missing)
        }

        return ComparabilityResult(verdict: .notDirect, missing: missing)
    }

    // MARK: - Confidence

    private static func confidence(
        missingCount: Int,
        comparedCount: Int,
        provenance: SubstitutionProvenance,
        hasIntent: Bool
    ) -> SubstitutionEvidenceConfidence {
        if comparedCount < 3 || missingCount > comparedCount {
            return .insufficient
        }
        if missingCount == 0 && provenance.supportsHighConfidence && hasIntent {
            return .high
        }
        if missingCount <= 2 && hasIntent {
            return .moderate
        }
        return .low
    }
}
