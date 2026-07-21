import Foundation
import SwiftData

/// Plan-local within-workout block prescription. It is copied into a
/// `WorkoutExecutionBlock` at workout start and never owns progression state.
@Model
final class PlannedExerciseBlock {
    var id = UUID()
    var orderIndex: Int
    var kind: ExerciseBlockKind
    var name: String?
    var targetRounds: Int?
    var isSharedLoad: Bool
    var restSeconds: Int?
    var clockMode: BlockClockMode
    var prescribedDurationSeconds: Int?
    var timeCapSeconds: Int?
    var intervalSeconds: Int?
    var scoreKind: BlockScoreKind
    var repetitionScheme: BlockRepetitionScheme
    var repetitionStart: Int?
    var repetitionEnd: Int?
    var repetitionStep: Int?
    var sourceTemplateBlockID: UUID?
    var definitionBlockKey: String?
    var plannedWorkout: PlannedWorkout?

    init(
        orderIndex: Int,
        kind: ExerciseBlockKind,
        name: String? = nil,
        targetRounds: Int? = nil,
        isSharedLoad: Bool = false,
        restSeconds: Int? = nil,
        clockMode: BlockClockMode = .none,
        prescribedDurationSeconds: Int? = nil,
        timeCapSeconds: Int? = nil,
        intervalSeconds: Int? = nil,
        scoreKind: BlockScoreKind = .none,
        repetitionScheme: BlockRepetitionScheme = .fixed,
        repetitionStart: Int? = nil,
        repetitionEnd: Int? = nil,
        repetitionStep: Int? = nil,
        sourceTemplateBlockID: UUID? = nil,
        definitionBlockKey: String? = nil
    ) {
        self.orderIndex = orderIndex
        self.kind = kind
        self.name = name
        self.targetRounds = targetRounds
        self.isSharedLoad = isSharedLoad
        self.restSeconds = restSeconds
        self.clockMode = clockMode
        self.prescribedDurationSeconds = prescribedDurationSeconds
        self.timeCapSeconds = timeCapSeconds
        self.intervalSeconds = intervalSeconds
        self.scoreKind = scoreKind
        self.repetitionScheme = repetitionScheme
        self.repetitionStart = repetitionStart
        self.repetitionEnd = repetitionEnd
        self.repetitionStep = repetitionStep
        self.sourceTemplateBlockID = sourceTemplateBlockID
        self.definitionBlockKey = definitionBlockKey
    }
}
