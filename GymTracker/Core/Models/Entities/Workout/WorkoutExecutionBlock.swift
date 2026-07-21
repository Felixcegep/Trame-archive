import Foundation
import SwiftData

/// Snapshot-local execution metadata for a contiguous group of exercise
/// entries. Entries retain their own exercise identity and progression key;
/// this record owns only the shared execution, clock, and score context.
@Model
final class WorkoutExecutionBlock {
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
    var status: WorkoutBlockStatus
    var completedRounds: Int
    var additionalRepetitions: Int
    var scoreValue: Double?
    var scoreTiebreakValue: Double?
    var accumulatedElapsedDuration: TimeInterval
    var elapsedStartedAt: Date?
    /// These identifiers are copied at workout start and never point to live
    /// templates or plans after the snapshot boundary.
    var sourceTemplateBlockID: UUID?
    var sourcePlannedBlockID: UUID?
    var sourceDefinitionBlockKey: String?
    var workout: Workout?

    init(
        orderIndex: Int,
        kind: ExerciseBlockKind = .straight,
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
        self.status = .notStarted
        self.completedRounds = 0
        self.additionalRepetitions = 0
        self.scoreValue = nil
        self.scoreTiebreakValue = nil
        self.accumulatedElapsedDuration = 0
        self.elapsedStartedAt = nil
        self.sourceTemplateBlockID = nil
        self.sourcePlannedBlockID = nil
        self.sourceDefinitionBlockKey = nil
    }

    func elapsedDuration(at date: Date = .now) -> TimeInterval {
        accumulatedElapsedDuration + max(0, elapsedStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    /// One-based work interval for EMOM and other repeating formats. This is
    /// derived from the persisted elapsed clock so it remains correct after a
    /// pause or relaunch.
    func currentInterval(at date: Date = .now) -> Int? {
        guard clockMode == .repeatingInterval, let intervalSeconds, intervalSeconds > 0 else {
            return nil
        }
        return Int(elapsedDuration(at: date) / Double(intervalSeconds)) + 1
    }

    func start(at date: Date = .now) {
        guard elapsedStartedAt == nil else { return }
        status = .inProgress
        elapsedStartedAt = date
    }

    func pause(at date: Date = .now) {
        guard let elapsedStartedAt else { return }
        accumulatedElapsedDuration += max(0, date.timeIntervalSince(elapsedStartedAt))
        self.elapsedStartedAt = nil
    }
}
