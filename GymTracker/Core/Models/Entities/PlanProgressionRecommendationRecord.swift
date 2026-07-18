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
    var proposedLoad: Double?
    var proposedStageID: String?
    var proposedVariationExerciseID: UUID?
    var proposedRepetitionOffset: Int
    var proposedSetCountOffset: Int
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
        proposedLoad = recommendation.proposedState.currentLoad
        proposedStageID = recommendation.proposedState.currentStageID
        proposedVariationExerciseID = recommendation.proposedState.currentVariationExerciseID
        proposedRepetitionOffset = recommendation.proposedState.repetitionOffset
        proposedSetCountOffset = recommendation.proposedState.setCountOffset
        createdAt = .now
        isResolved = recommendation.applicationMode == .automatic
        resolvedAt = isResolved ? .now : nil
    }

    func action(decoder: JSONDecoder = JSONDecoder()) throws -> ProgressionAction {
        try decoder.decode(ProgressionAction.self, from: actionData)
    }
}
#endif
