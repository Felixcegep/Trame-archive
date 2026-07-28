import Foundation

/// The immutable evidence behind one substitution decision, snapshotted onto
/// the performed `ExerciseEntry` at the moment the lifter confirms it.
///
/// Snapshot-safe by construction: it carries **codes, identifiers, and
/// versions only** — no live object references and no localized sentences.
/// The mistake this deliberately avoids is the one made by
/// `PlanProgressionRecommendationRecord.reason`, which persisted hard-coded
/// English literals that can never be retroactively localized and therefore
/// cannot be displayed. Every code here is a localization key resolved at
/// render time, so a snapshot written today still renders correctly in a
/// language the app did not support when it was written.
///
/// `version` and `ruleID` identify the rule set that produced the verdict, so
/// a later rule change never retroactively reinterprets an old decision.
struct SubstitutionEvaluationSnapshot: Codable, Equatable, Sendable {
    let version: Int
    let ruleID: String
    let sourceExerciseID: UUID
    let candidateExerciseID: UUID
    let reason: SubstitutionReason
    let suitability: SubstitutionSuitability
    let comparability: SubstitutionComparability
    let confidence: SubstitutionEvidenceConfidence
    /// Fields that agreed between the two exercises.
    let matchedFactorCodes: [String]
    /// Fields that differ and that the lifter should know about.
    let differingFactorCodes: [String]
    /// Fields absent on one or both exercises. A non-empty list is why a
    /// verdict is `insufficientInformation` / `unknown`, and the UI names them
    /// rather than hiding the gap.
    let missingEvidenceCodes: [String]
    /// Non-empty only when a hard filter rejected the candidate outright.
    let hardFilterFailureCodes: [String]
    let candidateProvenance: SubstitutionProvenance

    init(
        version: Int,
        ruleID: String,
        sourceExerciseID: UUID,
        candidateExerciseID: UUID,
        reason: SubstitutionReason,
        suitability: SubstitutionSuitability,
        comparability: SubstitutionComparability,
        confidence: SubstitutionEvidenceConfidence,
        matchedFactorCodes: [String],
        differingFactorCodes: [String],
        missingEvidenceCodes: [String],
        hardFilterFailureCodes: [String],
        candidateProvenance: SubstitutionProvenance
    ) {
        self.version = version
        self.ruleID = ruleID
        self.sourceExerciseID = sourceExerciseID
        self.candidateExerciseID = candidateExerciseID
        self.reason = reason
        self.suitability = suitability
        self.comparability = comparability
        self.confidence = confidence
        self.matchedFactorCodes = matchedFactorCodes
        self.differingFactorCodes = differingFactorCodes
        self.missingEvidenceCodes = missingEvidenceCodes
        self.hardFilterFailureCodes = hardFilterFailureCodes
        self.candidateProvenance = candidateProvenance
    }

    // MARK: - Persistence

    /// Encoded with a deterministic key order so a round trip is byte-stable
    /// and diffable in a backup file.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    func encoded() -> Data? {
        try? Self.encoder().encode(self)
    }

    /// Decoding never throws outward: a snapshot written by a newer build with
    /// an unrecognized enum case must degrade to "no evidence available"
    /// rather than break History.
    static func decoded(from data: Data?) -> SubstitutionEvaluationSnapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(SubstitutionEvaluationSnapshot.self, from: data)
    }
}
