import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var order: Int
    var orderIndex: Int = 0
    var targetSets: Int
    var repRangeMinimum: Int
    var repRangeMaximum: Int
    var restSeconds: Int
    var targetRPE: Double?
    var targetRIR: Int?
    var notes: String?
    var exercise: ExerciceTemplate

    init(
        exercise: ExerciceTemplate,
        order: Int,
        targetSets: Int = 3,
        repRangeMinimum: Int = 8,
        repRangeMaximum: Int = 12,
        restSeconds: Int = 90,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        notes: String? = nil
    ) {
        self.exercise = exercise
        self.order = order
        self.orderIndex = order
        self.targetSets = targetSets
        self.repRangeMinimum = repRangeMinimum
        self.repRangeMaximum = repRangeMaximum
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.notes = notes
    }
}
