import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// A mobility-owned recommendation receipt, reusing the shared resolution
/// vocabulary (`ProgressionApplicationMode`, `ProgressionDecisionOutcome`)
/// but not the workout `PlanProgressionRecommendationRecord` model itself.
///
/// Audit (per spec §5.4, which requires proving reuse is unsafe before
/// adding a mobility-owned table): `PlanProgressionRecommendationRecord`
/// cannot safely represent mobility evidence for two independent reasons.
/// First, its typed accessor `action(decoder:) -> ProgressionAction` is
/// fixed to the workout engine's `ProgressionAction` enum, which has no
/// case for `.addCycle`, `.reduceSupport`, `.advanceVariation`,
/// `.regressVariation`, or `.maintain` — encoding a
/// `MobilityProgressionAction` into `actionData` would either silently
/// misdecode as one of those unrelated workout cases or fail every read.
/// Second, most of its proposed-state columns
/// (`proposedTrainingMax`/`proposedStageID`/`proposedVariationExerciseID`/
/// `proposedWaveIndex`/`proposedBlockIndex`/`proposedIsDeloading`) encode
/// workout-only structural concepts — training max, stage, a
/// catalog-exercise variation ladder, waves, blocks, deload — that this
/// slice's mobility domain has no equivalent for. Widening the workout
/// record to carry both vocabularies would blur exactly the "mobility runs
/// are mobility-owned" boundary this slice must not cross. This record
/// carries only the fields mobility progression actually produces.
@Model
final class MobilityProgressionRecommendationRecord {
    var id: UUID
    var runID: UUID
    var sessionProgressID: UUID
    var progressionKey: String
    var sideRaw: String
    var ruleID: UUID
    var actionData: Data
    var reason: String
    var reasonKey: String?
    var applicationMode: ProgressionApplicationMode
    var performanceData: Data?
    var proposedDurationOffsetSeconds: Int
    var proposedRepetitionOffset: Int
    var proposedCycleOffset: Int
    var proposedLoadOffset: Double
    var proposedAssistanceLevelOffset: Int
    var proposedSupportLevelStepOffset: Int
    var proposedVariationStepOffset: Int
    var createdAt: Date
    var isResolved: Bool
    var resolvedAt: Date?
    var decisionOutcome: ProgressionDecisionOutcome?

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    init(
        runID: UUID,
        sessionProgressID: UUID,
        progressionKey: String,
        side: MobilitySide,
        proposal: MobilityProgressionProposal,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.id = proposal.id
        self.runID = runID
        self.sessionProgressID = sessionProgressID
        self.progressionKey = progressionKey
        self.sideRaw = side.rawValue
        self.ruleID = proposal.ruleID
        self.actionData = try encoder.encode(proposal.action)
        self.reason = proposal.reason
        self.reasonKey = proposal.reasonKey
        self.applicationMode = proposal.applicationMode
        self.performanceData = try? encoder.encode(proposal.performance)
        self.proposedDurationOffsetSeconds = proposal.proposedState.durationOffsetSeconds
        self.proposedRepetitionOffset = proposal.proposedState.repetitionOffset
        self.proposedCycleOffset = proposal.proposedState.cycleOffset
        self.proposedLoadOffset = proposal.proposedState.loadOffset
        self.proposedAssistanceLevelOffset = proposal.proposedState.assistanceLevelOffset
        self.proposedSupportLevelStepOffset = proposal.proposedState.supportLevelStepOffset
        self.proposedVariationStepOffset = proposal.proposedState.variationStepOffset
        self.createdAt = .now
        // Automatic-mode application at creation time is a system default,
        // not a user decision. In practice no mobility rule authored by
        // this slice's coordinator ever uses `.automatic`, but the field
        // mirrors `PlanProgressionRecommendationRecord`'s own rule for it.
        self.isResolved = proposal.applicationMode == .automatic
        self.resolvedAt = isResolved ? .now : nil
        self.decisionOutcome = nil
    }

    func action(decoder: JSONDecoder = JSONDecoder()) throws -> MobilityProgressionAction {
        try decoder.decode(MobilityProgressionAction.self, from: actionData)
    }

    var proposedState: MobilityProgressionProposedState {
        MobilityProgressionProposedState(
            durationOffsetSeconds: proposedDurationOffsetSeconds,
            repetitionOffset: proposedRepetitionOffset,
            cycleOffset: proposedCycleOffset,
            loadOffset: proposedLoadOffset,
            assistanceLevelOffset: proposedAssistanceLevelOffset,
            supportLevelStepOffset: proposedSupportLevelStepOffset,
            variationStepOffset: proposedVariationStepOffset
        )
    }

    func performance(decoder: JSONDecoder = JSONDecoder()) -> MobilityProgressionPerformance? {
        performanceData.flatMap { try? decoder.decode(MobilityProgressionPerformance.self, from: $0) }
    }
}

#endif
