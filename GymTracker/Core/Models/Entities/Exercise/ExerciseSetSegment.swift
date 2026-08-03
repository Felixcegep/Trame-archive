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
    var rpe: Double?
    var rir: Int?
    /// Present only when this segment is a workout split (a run leg, a
    /// station, a transition, or a recovery interval inside a fitness
    /// simulation or medley event) rather than a strength-method internal
    /// effort (dropset/cluster/rest-pause). `nil` preserves every existing
    /// segment's exact prior meaning.
    var splitKindRaw: String?
    var startedAt: Date?
    var endedAt: Date?
    var distanceMeters: Double?
    var heartRateBPM: Int?
    var perceivedExertion: Double?
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
        rpe: Double? = nil,
        rir: Int? = nil,
        splitKind: WorkoutSplitKind? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        distanceMeters: Double? = nil,
        heartRateBPM: Int? = nil,
        perceivedExertion: Double? = nil
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
        self.splitKindRaw = splitKind?.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.heartRateBPM = heartRateBPM
        self.perceivedExertion = perceivedExertion
    }

    var splitKind: WorkoutSplitKind? {
        get { splitKindRaw.flatMap(WorkoutSplitKind.init(rawValue:)) }
        set { splitKindRaw = newValue?.rawValue }
    }

    /// The split's duration, preferring explicit start/end timestamps (live
    /// capture) and falling back to the pre-existing `duration` field so a
    /// split recorded without wall-clock timestamps still reports one.
    var splitDuration: TimeInterval? {
        if let startedAt, let endedAt { return max(0, endedAt.timeIntervalSince(startedAt)) }
        return duration
    }

    /// The prescribed entry this split belongs to, resolved transitively
    /// through the parent set rather than a duplicated relationship — this
    /// mirrors how every other internal-effort field on this model already
    /// only makes sense in the context of its `exerciseSet`.
    var exerciseEntry: ExerciseEntry? { exerciseSet?.exerciseEntry }

    /// The execution block this split's entry belongs to, if any. Blocks are
    /// resolved by ID against the owning workout (see
    /// `WorkoutExecutionBlockService`), the same snapshot-ID pattern
    /// `ExerciseEntry.executionBlockID` already uses everywhere else, rather
    /// than a second live relationship duplicating that link.
    var executionBlockID: UUID? { exerciseEntry?.executionBlockID }
}
