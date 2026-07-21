import Foundation
import SwiftData

@Model
final class PlannedExercise {
    var id = UUID()
    /// Stable identity for this exposure across repeated plan weeks.
    var progressionKey: String
    var orderIndex: Int
    /// Membership in a contiguous superset within this planned workout.
    var supersetGroupID: UUID?
    var executionBlockID: UUID?
    var executionBlockComponentOrder: Int?
    var role: ExerciseRole
    var isOptional: Bool
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var suggestedLoad: Double?
    var suggestedLoadType: WeightType?
    var initialTrainingMax: Double?
    var initialEstimatedOneRepMax: Double?
    var initialActualOneRepMax: Double?
    var automaticDeloadVolumeReductionPercent: Int?
    var automaticDeloadIntensityReductionPercent: Int?
    var warmupSchemeData: Data?
    var restSeconds: Int
    var targetRPE: Double?
    var targetRIR: Int?
    var notes: String?
    var progressionRule: ProgressionRule
    /// Encoded composable progression rules for generated program plans.
    var progressionRulesData: Data?
    /// Encoded structured wave prescriptions. The first wave remains mirrored
    /// into `plannedSets` for legacy editors and snapshots.
    var progressionWavesData: Data?
    /// Encoded stage definitions and initial-stage identity for generated programs.
    var progressionStagesData: Data?
    /// Ordered exercise identities used by advance/regress variation actions.
    var variationLadderData: Data?
    var initialVariationExerciseID: UUID?
    var initialVelocityBaseline: Double?
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
        supersetGroupID: UUID? = nil,
        progressionKey: String? = nil,
        progressionRulesData: Data? = nil,
        progressionWavesData: Data? = nil,
        progressionStagesData: Data? = nil,
        variationLadderData: Data? = nil,
        initialVariationExerciseID: UUID? = nil,
        initialVelocityBaseline: Double? = nil,
        initialTrainingMax: Double? = nil,
        initialEstimatedOneRepMax: Double? = nil,
        initialActualOneRepMax: Double? = nil,
        automaticDeloadVolumeReductionPercent: Int? = nil,
        automaticDeloadIntensityReductionPercent: Int? = nil,
        warmupSchemeData: Data? = nil
    ) {
        self.progressionKey = progressionKey ?? UUID().uuidString
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.role = role
        self.isOptional = isOptional
        self.targetSets = targetSets
        self.repRangeMinimum = repRangeMinimum
        self.repRangeMaximum = repRangeMaximum
        self.suggestedLoad = suggestedLoad
        self.suggestedLoadType = suggestedLoadType
        self.initialTrainingMax = initialTrainingMax
        self.initialEstimatedOneRepMax = initialEstimatedOneRepMax
        self.initialActualOneRepMax = initialActualOneRepMax
        self.automaticDeloadVolumeReductionPercent = automaticDeloadVolumeReductionPercent
        self.automaticDeloadIntensityReductionPercent = automaticDeloadIntensityReductionPercent
        self.warmupSchemeData = warmupSchemeData
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.notes = notes
        self.progressionRule = progressionRule
        self.progressionRulesData = progressionRulesData
        self.progressionWavesData = progressionWavesData
        self.progressionStagesData = progressionStagesData
        self.variationLadderData = variationLadderData
        self.initialVariationExerciseID = initialVariationExerciseID
        self.initialVelocityBaseline = initialVelocityBaseline
        self.stimulus = stimulus
        self.alternatives = alternatives
        self.plannedSets = plannedSets
        self.supersetGroupID = supersetGroupID
        self.executionBlockID = nil
        self.executionBlockComponentOrder = nil
    }

    var resolvedStimulus: TrainingStimulus {
        stimulus ?? .strength
    }

    var orderedPlannedSets: [PlannedSet] {
        plannedSets.sorted { $0.orderIndex < $1.orderIndex }
    }
}
