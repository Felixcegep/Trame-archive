import Foundation
import SwiftData

@Model
final class PlannedExercise {
    var id = UUID()
    var orderIndex: Int
    /// Membership in a contiguous superset within this planned workout.
    var supersetGroupID: UUID?
    var role: ExerciseRole
    var isOptional: Bool
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var suggestedLoad: Double?
    var suggestedLoadType: WeightType?
    var restSeconds: Int
    var targetRPE: Double?
    var targetRIR: Int?
    var notes: String?
    var progressionRule: ProgressionRule
    // Optional for compatibility with plans persisted before stimulus was added.
    // Callers should use resolvedStimulus when a concrete value is required.
    var stimulus: TrainingStimulus?
    var exercise: Exercise
    var plannedWorkout: PlannedWorkout?
    @Relationship(deleteRule: .cascade, inverse: \PlannedExerciseAlternative.plannedExercise)
    var alternatives: [PlannedExerciseAlternative] = []
    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.plannedExercise)
    var plannedSets: [PlannedSet] = []

    init(
        exercise: Exercise,
        orderIndex: Int,
        role: ExerciseRole = .main,
        isOptional: Bool = false,
        targetSets: Int = 3,
        repRangeMinimum: Int = 8,
        repRangeMaximum: Int = 12,
        suggestedLoad: Double? = nil,
        suggestedLoadType: WeightType? = nil,
        restSeconds: Int = 90,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        notes: String? = nil,
        progressionRule: ProgressionRule = .none,
        stimulus: TrainingStimulus = .strength,
        alternatives: [PlannedExerciseAlternative] = [],
        plannedSets: [PlannedSet] = [],
        supersetGroupID: UUID? = nil
    ) {
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.role = role
        self.isOptional = isOptional
        self.targetSets = targetSets
        self.repRangeMinimum = repRangeMinimum
        self.repRangeMaximum = repRangeMaximum
        self.suggestedLoad = suggestedLoad
        self.suggestedLoadType = suggestedLoadType
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.notes = notes
        self.progressionRule = progressionRule
        self.stimulus = stimulus
        self.alternatives = alternatives
        self.plannedSets = plannedSets
        self.supersetGroupID = supersetGroupID
    }

    var resolvedStimulus: TrainingStimulus {
        stimulus ?? .strength
    }

    var orderedPlannedSets: [PlannedSet] {
        plannedSets.sorted { $0.orderIndex < $1.orderIndex }
    }
}
