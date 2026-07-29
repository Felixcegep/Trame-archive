import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
/// Distinguishes how a `PlanProgressionRecommendationRecord` was resolved.
/// Persisted as an additive optional field: existing rows written before this
/// case existed decode as `nil`, which reads as "resolved without a recorded
/// outcome" and must never be back-filled or inferred as any specific
/// decision (see `PlanProgressionRecommendationService`).
///
/// When a template's double-progression card and a program-engine
/// recommendation both target the same exercise, the program-engine
/// recommendation (this record) wins; the double-progression card is the
/// older, unversioned path and any suppression between the two is a
/// presentation-layer concern, not a data concern for this type.
nonisolated enum ProgressionDecisionOutcome: String, Codable, CaseIterable, Hashable {
    /// The proposed state was applied exactly as recommended.
    case accepted
    /// The user applied a different value than the one proposed. The
    /// original proposal remains on `proposedLoad`; the value actually
    /// applied is retained on `appliedLoad`.
    case acceptedWithModifiedValue
    /// The user declined the recommendation. Declining is a legitimate,
    /// ordinary choice and must never be presented as failure or
    /// noncompliance.
    case declined
}

@Model
final class PlanProgressionRecommendationRecord {
    var id = UUID()
    var planRunID: UUID
    var workoutID: UUID
    var progressionKey: String
    var ruleID: UUID
    /// The progression rule definition's `version` at the moment this
    /// recommendation was built, so a receipt can name e.g. "Double
    /// Progression v2". `nil` means the version was not captured (for
    /// example rows written before this field existed); it is never
    /// back-filled or inferred to a fabricated default such as `1`.
    var ruleVersion: Int?
    var actionData: Data
    var cadence: ProgressionCadence
    var scope: ProgressionScope
    /// The scoped state owner that produced this recommendation. Empty keeps
    /// legacy recommendation records bound to their exposure state.
    var scopeOwnerKey: String = ""
    var reason: String
    /// Localizable reason key snapshotted at evaluation time. `nil` means this
    /// is a legacy row whose English `reason` remains provenance only.
    var reasonKey: String?
    var applicationMode: ProgressionApplicationMode
    var performanceData: Data?
    var proposedLoad: Double?
    /// The unit paired with the proposed/applied load when this receipt was
    /// created. Never derive it from a plan that may subsequently be edited.
    var proposedLoadUnit: WeightType?
    var proposedTrainingMax: Double?
    var proposedEstimatedOneRepMax: Double?
    var proposedActualOneRepMax: Double?
    var proposedStageID: String?
    var proposedVariationExerciseID: UUID?
    var proposedRepetitionOffset: Int
    var proposedSetCountOffset: Int
    var proposedDurationOffset: TimeInterval
    var proposedDistanceOffset: Double
    var proposedRestDurationOffset: Int
    var proposedCaloriesOffset: Double
    var proposedWaveIndex: Int
    var proposedBlockIndex: Int
    var proposedIsDeloading: Bool
    var createdAt: Date
    var isResolved: Bool
    var resolvedAt: Date?
    /// How this recommendation was resolved. `nil` for rows resolved before
    /// this field existed (and for automatic-mode rows resolved at creation,
    /// which were never a user decision) — see `ProgressionDecisionOutcome`.
    /// Only `PlanProgressionRecommendationService`'s three resolution methods
    /// may set this; it is never inferred from `isResolved` alone.
    var decisionOutcome: ProgressionDecisionOutcome?
    /// The load actually applied, when it differs from `proposedLoad`. Set
    /// only alongside `.acceptedWithModifiedValue`. A plain accept leaves this
    /// `nil` because the applied value is `proposedLoad` itself; this field
    /// never overwrites `proposedLoad`, so the original proposal and the
    /// chosen result both survive.
    var appliedLoad: Double?

    init(
        recommendation: ProgressionRecommendation,
        planRunID: UUID,
        workoutID: UUID,
        scopeOwnerKey: String = "",
        proposedLoadUnit: WeightType? = nil,
        isResolvedOverride: Bool? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.planRunID = planRunID
        self.workoutID = workoutID
        progressionKey = ""
        ruleID = recommendation.ruleID
        ruleVersion = recommendation.ruleVersion
        actionData = try encoder.encode(recommendation.action)
        cadence = recommendation.cadence
        scope = recommendation.scope
        self.scopeOwnerKey = scopeOwnerKey
        reason = recommendation.reason
        reasonKey = recommendation.reasonKey
        applicationMode = recommendation.applicationMode
        performanceData = try encoder.encode(recommendation.performance)
        proposedLoad = recommendation.proposedState.currentLoad
        self.proposedLoadUnit = proposedLoadUnit
        proposedTrainingMax = recommendation.proposedState.trainingMax
        proposedEstimatedOneRepMax = recommendation.proposedState.estimatedOneRepMax
        proposedActualOneRepMax = recommendation.proposedState.actualOneRepMax
        proposedStageID = recommendation.proposedState.currentStageID
        proposedVariationExerciseID = recommendation.proposedState.currentVariationExerciseID
        proposedRepetitionOffset = recommendation.proposedState.repetitionOffset
        proposedSetCountOffset = recommendation.proposedState.setCountOffset
        proposedDurationOffset = recommendation.proposedState.durationOffset
        proposedDistanceOffset = recommendation.proposedState.distanceOffset
        proposedRestDurationOffset = recommendation.proposedState.restDurationOffset
        proposedCaloriesOffset = recommendation.proposedState.caloriesOffset
        proposedWaveIndex = recommendation.proposedState.currentWaveIndex
        proposedBlockIndex = recommendation.proposedState.currentBlockIndex
        proposedIsDeloading = recommendation.proposedState.isDeloading
        createdAt = .now
        isResolved = isResolvedOverride ?? (recommendation.applicationMode == .automatic)
        resolvedAt = isResolved ? .now : nil
        // Automatic-mode application at creation time is a system default,
        // not a user decision, so it must not be recorded as `.accepted`.
        // Only `PlanProgressionRecommendationService`'s resolution methods
        // set an outcome.
        decisionOutcome = nil
        appliedLoad = nil
    }

    func action(decoder: JSONDecoder = JSONDecoder()) throws -> ProgressionAction {
        try decoder.decode(ProgressionAction.self, from: actionData)
    }

    func performance(decoder: JSONDecoder = JSONDecoder()) -> ProgressionPerformance? {
        performanceData.flatMap { try? decoder.decode(ProgressionPerformance.self, from: $0) }
    }
}
#endif
