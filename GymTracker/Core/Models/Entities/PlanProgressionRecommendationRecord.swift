import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
@Model
final class PlanProgressionRecommendationRecord {
    var id = UUID()
    var planRunID: UUID
    var workoutID: UUID
    var progressionKey: String
    var ruleID: UUID
    var actionData: Data
    var cadence: ProgressionCadence
    var scope: ProgressionScope
    var reason: String
    var applicationMode: ProgressionApplicationMode
    var performanceData: Data?
    var proposedLoad: Double?
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

    init(
        recommendation: ProgressionRecommendation,
        planRunID: UUID,
        workoutID: UUID,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        self.planRunID = planRunID
        self.workoutID = workoutID
        progressionKey = ""
        ruleID = recommendation.ruleID
        actionData = try encoder.encode(recommendation.action)
        cadence = recommendation.cadence
        scope = recommendation.scope
        reason = recommendation.reason
        applicationMode = recommendation.applicationMode
        performanceData = try encoder.encode(recommendation.performance)
        proposedLoad = recommendation.proposedState.currentLoad
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
        isResolved = recommendation.applicationMode == .automatic
        resolvedAt = isResolved ? .now : nil
    }

    func action(decoder: JSONDecoder = JSONDecoder()) throws -> ProgressionAction {
        try decoder.decode(ProgressionAction.self, from: actionData)
    }
}
#endif
