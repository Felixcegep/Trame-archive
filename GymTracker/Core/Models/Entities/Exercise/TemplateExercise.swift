import Foundation
import SwiftData

@Model
final class TemplateExercise {
    /// Stable identity for an exercise exposure copied into future plans.
    var progressionKey: String
    var orderIndex: Int = 0
    /// Membership in a contiguous superset. This identifier belongs to this
    /// prescription only; each workout snapshot receives fresh identifiers.
    var supersetGroupID: UUID?
    var executionBlockID: UUID?
    var executionBlockComponentOrder: Int?
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var restSeconds: Int
    var targetRPE: Double?
    var targetRIR: Int?
    var notes: String?
    var progressionRule: ProgressionRule = ProgressionRule.doubleProgression
    var exercise: Exercise
    var workoutTemplate: WorkoutTemplate?

    init(
        exercise: Exercise,
        order: Int,
        targetSets: Int = 3,
        repRangeMinimum: Int = 8,
        repRangeMaximum: Int = 12,
        restSeconds: Int = 90,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        notes: String? = nil,
        progressionRule: ProgressionRule = .doubleProgression,
        supersetGroupID: UUID? = nil,
        progressionKey: String? = nil
    ) {
        self.progressionKey = progressionKey ?? UUID().uuidString
        self.exercise = exercise
        self.orderIndex = order
        self.targetSets = targetSets
        self.repRangeMinimum = repRangeMinimum
        self.repRangeMaximum = repRangeMaximum
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.notes = notes
        self.progressionRule = progressionRule
        self.supersetGroupID = supersetGroupID
        self.executionBlockID = nil
        self.executionBlockComponentOrder = nil
    }
}
