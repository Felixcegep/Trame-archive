import Foundation
import SwiftData

@Model
final class PlannedExercise {
    var id = UUID()
    var orderIndex: Int
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
    var stimulus: TrainingStimulus = TrainingStimulus.strength
    var exercise: Exercise
    var plannedWorkout: PlannedWorkout?
    @Relationship(deleteRule: .cascade, inverse: \PlannedExerciseAlternative.plannedExercise)
    var alternatives: [PlannedExerciseAlternative] = []

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
        alternatives: [PlannedExerciseAlternative] = []
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
    }
}
