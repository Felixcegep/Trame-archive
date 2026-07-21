import Foundation
import SwiftData

/// Reusable within-workout block prescription. `PlanBlock` remains reserved for
/// program periodization; this entity only structures one workout template.
@Model
final class TemplateExerciseBlock {
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
    var workoutTemplate: WorkoutTemplate?

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
        repetitionStep: Int? = nil
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
    }
}
