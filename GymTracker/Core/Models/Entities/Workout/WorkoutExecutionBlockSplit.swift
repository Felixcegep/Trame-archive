import Foundation
import SwiftData

enum WorkoutExecutionBlockSplitKind: String, Codable, CaseIterable, Sendable {
    case componentAdvanced
    case roundCompleted
    case clockCheckpoint
    case completed
    case capped
}
/// Immutable runtime evidence for a shared execution block.
///
/// The parent is identified by its workout-local snapshot UUID rather than a
/// SwiftData relationship so the frozen V1/V2 block schemas remain unchanged.
/// Deletion and restore services remove/rebuild these records by `blockID`.
@Model
final class WorkoutExecutionBlockSplit {
    var id = UUID()
    var blockID: UUID
    var workoutID: UUID
    var sequenceIndex: Int
    var kind: WorkoutExecutionBlockSplitKind
    var roundIndex: Int
    var componentOrder: Int
    var elapsedDuration: TimeInterval
    var recordedAt: Date

    init(
        blockID: UUID,
        workoutID: UUID,
        sequenceIndex: Int,
        kind: WorkoutExecutionBlockSplitKind,
        roundIndex: Int,
        componentOrder: Int,
        elapsedDuration: TimeInterval,
        recordedAt: Date
    ) {
        self.blockID = blockID
        self.workoutID = workoutID
        self.sequenceIndex = sequenceIndex
        self.kind = kind
        self.roundIndex = max(0, roundIndex)
        self.componentOrder = max(0, componentOrder)
        self.elapsedDuration = max(0, elapsedDuration)
        self.recordedAt = recordedAt
    }
}
