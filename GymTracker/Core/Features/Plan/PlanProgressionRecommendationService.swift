import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
@MainActor
enum PlanProgressionRecommendationService {
    static func accept(
        _ recommendation: PlanProgressionRecommendationRecord,
        in run: PlanRun,
        context: ModelContext
    ) throws {
        guard !recommendation.isResolved else { return }
        guard let state = run.progressionStates.first(where: { $0.progressionKey == recommendation.progressionKey }) else { return }
        apply(proposedState: recommendation, to: state)
        recommendation.isResolved = true
        recommendation.resolvedAt = .now
        try context.save()
    }

    static func accept(
        _ recommendation: PlanProgressionRecommendationRecord,
        withLoad load: Double,
        in run: PlanRun,
        context: ModelContext
    ) throws {
        guard !recommendation.isResolved else { return }
        guard let state = run.progressionStates.first(where: { $0.progressionKey == recommendation.progressionKey }) else { return }
        state.currentLoad = load
        recommendation.isResolved = true
        recommendation.resolvedAt = .now
        try context.save()
    }

    static func decline(_ recommendation: PlanProgressionRecommendationRecord, context: ModelContext) throws {
        recommendation.isResolved = true
        recommendation.resolvedAt = .now
        try context.save()
    }

    private static func apply(
        proposedState recommendation: PlanProgressionRecommendationRecord,
        to state: PlanExerciseProgressionState
    ) {
        state.currentLoad = recommendation.proposedLoad
        state.trainingMax = recommendation.proposedTrainingMax
        state.estimatedOneRepMax = recommendation.proposedEstimatedOneRepMax
        state.currentStageID = recommendation.proposedStageID
        state.currentVariationExerciseID = recommendation.proposedVariationExerciseID
        state.repetitionOffset = recommendation.proposedRepetitionOffset
        state.setCountOffset = recommendation.proposedSetCountOffset
        state.durationOffset = recommendation.proposedDurationOffset
        state.distanceOffset = recommendation.proposedDistanceOffset
        state.restDurationOffset = recommendation.proposedRestDurationOffset
        state.currentWaveIndex = recommendation.proposedWaveIndex
        state.currentBlockIndex = recommendation.proposedBlockIndex
        state.isDeloading = recommendation.proposedIsDeloading
    }
}
#endif
