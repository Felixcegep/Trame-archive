import Foundation
import SwiftData

struct ProgressionSnapshotService {
    let modelContext: ModelContext

    /// Pairs the template prescription with its newly created workout entry and
    /// captures an explainable recommendation. This is deliberately show-only:
    /// performed set weights remain untouched until the user applies it.
    func applyRecommendations(to workout: Workout, from template: WorkoutTemplate) {
        for (templateExercise, entry) in zip(
            template.orderedTemplateExercises,
            workout.orderedExercises
        ) {
            guard entry.exercice.persistentModelID == templateExercise.exercise.persistentModelID else {
                continue
            }

            guard let recommendation = recommendation(
                for: templateExercise.exercise,
                rule: templateExercise.progressionRule,
                requiredSets: templateExercise.targetSets,
                repCeiling: templateExercise.repRangeMaximum,
                startedAt: workout.startTime
            ) else {
                continue
            }

            entry.recommendedDecision = recommendation.decision
            entry.recommendedLoad = recommendation.recommendedLoad
            entry.recommendedUnit = recommendation.unit
            entry.recommendationPriorLoad = recommendation.evidence.priorLoad
            entry.recommendationRequiredSets = recommendation.evidence.requiredSets
            entry.recommendationRepCeiling = recommendation.evidence.repCeiling
            entry.recommendationCompletedSets = recommendation.evidence.completedSets
            entry.recommendationPriorWorkoutDate = recommendation.evidence.workoutDate
        }
    }

    /// Source-agnostic core reused by template workouts now and planned workouts
    /// later. Evidence remains in its historical unit; conversion happens only
    /// when a user applies the recommendation to an active set.
    func recommendation(
        for exercise: ExerciceTemplate,
        rule: ProgressionRule,
        requiredSets: Int,
        repCeiling: Int,
        startedAt: Date
    ) -> DoubleProgressionRecommendation? {
        guard
            rule == .doubleProgression,
            exercise.trackingType.usesWeight,
            exercise.trackingType != .assistedBodyweight,
            requiredSets > 0,
            repCeiling > 0,
            let performance = try? ExerciseHistoryService(modelContext: modelContext)
                .mostRecentPerformance(for: exercise, before: startedAt)
        else {
            return nil
        }

        let workingSets = performance.sets
            .filter { $0.setType != .warmup }
            .sorted { $0.orderIndex < $1.orderIndex }
        let requiredEvidence = workingSets.prefix(requiredSets)
        guard requiredEvidence.count == requiredSets, let latest = requiredEvidence.last else {
            return nil
        }

        // Mixed units inside one prior workout are rare. The last prescribed
        // evidence set is authoritative, matching the engine's load basis.
        let filteredPerformance = PreviousExercisePerformance(
            workoutDate: performance.workoutDate,
            sets: workingSets
        )
        return DoubleProgressionEngine.recommend(
            from: filteredPerformance,
            requiredSets: requiredSets,
            repCeiling: repCeiling,
            increment: Constants.Progression.increment(for: latest.weightType)
        )
    }
}
