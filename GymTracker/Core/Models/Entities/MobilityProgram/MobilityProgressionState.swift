import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// Mutable progression state inside one `MobilityProgramRun`, keyed by
/// `(progressionKey, side)` — mirroring `PlanExerciseProgressionState`'s own
/// `(progressionKey, scopeOwnerKey)` composite key, which exists for exactly
/// this reason: the same occurrence needs independent state per owner. Here
/// the owner is a side, never averaged with its counterpart. A sideless
/// occurrence (`MobilitySide.none`) uses `.none` as its single row.
@Model
final class MobilityProgressionState {
    var id: UUID
    var progressionKey: String
    var sideRaw: String
    var durationOffsetSeconds: Int
    var repetitionOffset: Int
    var cycleOffset: Int
    var loadOffset: Double
    var assistanceLevelOffset: Int
    var supportLevelStepOffset: Int
    var variationStepOffset: Int
    /// Consecutive sessions (most recent streak, reset on a miss) where this
    /// side's targets were fully met. Backs
    /// `MobilityProgressionTrigger.targetCompletedForSessions`.
    var consecutiveTargetMetSessionCount: Int
    var lastAppliedRecommendationID: UUID?
    var updatedAt: Date
    var run: MobilityProgramRun?

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    init(
        progressionKey: String,
        side: MobilitySide,
        durationOffsetSeconds: Int = 0,
        repetitionOffset: Int = 0,
        cycleOffset: Int = 0,
        loadOffset: Double = 0,
        assistanceLevelOffset: Int = 0,
        supportLevelStepOffset: Int = 0,
        variationStepOffset: Int = 0,
        consecutiveTargetMetSessionCount: Int = 0,
        lastAppliedRecommendationID: UUID? = nil,
        id: UUID = UUID(),
        updatedAt: Date = .now
    ) {
        self.id = id
        self.progressionKey = progressionKey
        self.sideRaw = side.rawValue
        self.durationOffsetSeconds = durationOffsetSeconds
        self.repetitionOffset = repetitionOffset
        self.cycleOffset = cycleOffset
        self.loadOffset = loadOffset
        self.assistanceLevelOffset = assistanceLevelOffset
        self.supportLevelStepOffset = supportLevelStepOffset
        self.variationStepOffset = variationStepOffset
        self.consecutiveTargetMetSessionCount = consecutiveTargetMetSessionCount
        self.lastAppliedRecommendationID = lastAppliedRecommendationID
        self.updatedAt = updatedAt
    }

    var proposedState: MobilityProgressionProposedState {
        MobilityProgressionProposedState(
            durationOffsetSeconds: durationOffsetSeconds,
            repetitionOffset: repetitionOffset,
            cycleOffset: cycleOffset,
            loadOffset: loadOffset,
            assistanceLevelOffset: assistanceLevelOffset,
            supportLevelStepOffset: supportLevelStepOffset,
            variationStepOffset: variationStepOffset
        )
    }

    func apply(_ proposed: MobilityProgressionProposedState, recommendationID: UUID?) {
        durationOffsetSeconds = proposed.durationOffsetSeconds
        repetitionOffset = proposed.repetitionOffset
        cycleOffset = proposed.cycleOffset
        loadOffset = proposed.loadOffset
        assistanceLevelOffset = proposed.assistanceLevelOffset
        supportLevelStepOffset = proposed.supportLevelStepOffset
        variationStepOffset = proposed.variationStepOffset
        lastAppliedRecommendationID = recommendationID
        updatedAt = .now
    }
}

#endif
