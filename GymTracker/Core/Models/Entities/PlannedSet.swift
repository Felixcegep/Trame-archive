import Foundation
import SwiftData

/// One ordered prescribed set. Performed values remain on ExerciseSet; this
/// entity only describes future intent and is snapshotted when a workout starts.
@Model
final class PlannedSet {
    var orderIndex: Int
    var setType: SetType
    var repetitions: Int?
    var repRangeMinimum: Int?
    var repRangeMaximum: Int?
    var suggestedLoad: Double?
    var suggestedLoadType: WeightType?
    var restSeconds: Int?
    var targetRPE: Double?
    var targetRIR: Int?
    var isOptional: Bool
    var notes: String?
    var plannedExercise: PlannedExercise?

    init(
        orderIndex: Int,
        setType: SetType = .normal,
        repetitions: Int? = nil,
        repRangeMinimum: Int? = nil,
        repRangeMaximum: Int? = nil,
        suggestedLoad: Double? = nil,
        suggestedLoadType: WeightType? = nil,
        restSeconds: Int? = nil,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        isOptional: Bool = false,
        notes: String? = nil
    ) {
        self.orderIndex = orderIndex
        self.setType = setType
        self.repetitions = repetitions
        self.repRangeMinimum = repRangeMinimum
        self.repRangeMaximum = repRangeMaximum
        self.suggestedLoad = suggestedLoad
        self.suggestedLoadType = suggestedLoadType
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.isOptional = isOptional
        self.notes = notes
    }
}
