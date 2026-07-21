import Foundation
import SwiftData

/// An ordered internal effort within one parent `ExerciseSet`. Segments are
/// never standalone working sets, so dropsets and clusters retain their true
/// historical structure and cannot accidentally inflate set counts.
@Model
final class ExerciseSetSegment {
    var id = UUID()
    var orderIndex: Int
    var repetitions: Float
    var weight: Float
    var weightType: WeightType
    var duration: TimeInterval?
    var restAfterSeconds: Int?
    var done: Bool
    var variationNote: String?
    var rpe: Int?
    var rir: Int?
    var exerciseSet: ExerciseSet?

    init(
        orderIndex: Int,
        repetitions: Float = 0,
        weight: Float = 0,
        weightType: WeightType = .kg,
        duration: TimeInterval? = nil,
        restAfterSeconds: Int? = nil,
        done: Bool = false,
        variationNote: String? = nil,
        rpe: Int? = nil,
        rir: Int? = nil
    ) {
        self.orderIndex = orderIndex
        self.repetitions = repetitions
        self.weight = weight
        self.weightType = weightType
        self.duration = duration
        self.restAfterSeconds = restAfterSeconds
        self.done = done
        self.variationNote = variationNote
        self.rpe = rpe
        self.rir = rir
    }
}
