import Foundation

enum WorkoutExecutionBlockError: LocalizedError, Equatable {
    case completedWorkoutMutation(WorkoutMutationOperation)
    case emptyBlock
    case duplicateEntry
    case entryAlreadyBelongsToBlock
    case invalidConfiguration(String)
    case invalidComponentCount(kind: ExerciseBlockKind, count: Int)
    case entryDoesNotBelongToWorkout

    var errorDescription: String? {
        switch self {
        case .completedWorkoutMutation(let operation):
            return WorkoutMutationError.completedWorkoutMutation(operation).errorDescription
        case .emptyBlock:
            return "An execution block needs at least one exercise."
        case .duplicateEntry:
            return "An exercise can appear only once in an execution block."
        case .entryAlreadyBelongsToBlock:
            return "Remove the exercise from its current execution block before assigning it to another one."
        case .invalidConfiguration(let message):
            return message
        case .invalidComponentCount(let kind, let count):
            return "\(kind.rawValue) requires a different number of exercises (received \(count))."
        case .entryDoesNotBelongToWorkout:
            return "Every block exercise must belong to this workout."
        }
    }
}

struct WorkoutExecutionBlockConfiguration {
    let kind: ExerciseBlockKind
    let name: String?
    let targetRounds: Int?
    let isSharedLoad: Bool
    let restSeconds: Int?
    let clockMode: BlockClockMode
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: BlockScoreKind
    let repetitionScheme: BlockRepetitionScheme
    let repetitionStart: Int?
    let repetitionEnd: Int?
    let repetitionStep: Int?
}

/// Domain mutations for within-workout execution blocks. The service leaves
/// set completion and progression ownership on `ExerciseEntry` / `ExerciseSet`;
/// it owns shared block state only.
enum WorkoutExecutionBlockService {
    @discardableResult
    static func create(
        kind: ExerciseBlockKind,
        entries: [ExerciseEntry],
        in workout: Workout,
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
    ) throws -> WorkoutExecutionBlock {
        try create(
            configuration: WorkoutExecutionBlockConfiguration(
                kind: kind,
                name: name,
                targetRounds: targetRounds,
                isSharedLoad: isSharedLoad,
                restSeconds: restSeconds,
                clockMode: clockMode,
                prescribedDurationSeconds: prescribedDurationSeconds,
                timeCapSeconds: timeCapSeconds,
                intervalSeconds: intervalSeconds,
                scoreKind: scoreKind,
                repetitionScheme: repetitionScheme,
                repetitionStart: repetitionStart,
                repetitionEnd: repetitionEnd,
                repetitionStep: repetitionStep
            ),
            entries: entries,
            in: workout
        )
    }

    @discardableResult
    static func create(
        configuration: WorkoutExecutionBlockConfiguration,
        entries: [ExerciseEntry],
        in workout: Workout
    ) throws -> WorkoutExecutionBlock {
        try validate(configuration: configuration, entries: entries, in: workout, allowing: nil)
        let block = WorkoutExecutionBlock(
            orderIndex: workout.orderedExecutionBlocks.count,
            kind: configuration.kind,
            name: configuration.name,
            targetRounds: configuration.targetRounds,
            isSharedLoad: configuration.isSharedLoad,
            restSeconds: configuration.restSeconds,
            clockMode: configuration.clockMode,
            prescribedDurationSeconds: configuration.prescribedDurationSeconds,
            timeCapSeconds: configuration.timeCapSeconds,
            intervalSeconds: configuration.intervalSeconds,
            scoreKind: configuration.scoreKind,
            repetitionScheme: configuration.repetitionScheme,
            repetitionStart: configuration.repetitionStart,
            repetitionEnd: configuration.repetitionEnd,
            repetitionStep: configuration.repetitionStep
        )
        workout.executionBlocks.append(block)
        _ = assign(entries: entries, to: block)
        return block
    }

    static func update(
        _ block: WorkoutExecutionBlock,
        configuration: WorkoutExecutionBlockConfiguration,
        entries: [ExerciseEntry],
        in workout: Workout
    ) throws {
        guard !workout.isCompleted, !block.isCompleted else {
            throw WorkoutExecutionBlockError.completedWorkoutMutation(.updateExecutionBlock)
        }
        try validate(configuration: configuration, entries: entries, in: workout, allowing: block)
        for entry in self.entries(in: block, workout: workout) {
            entry.executionBlockID = nil
            entry.executionBlockComponentOrder = nil
        }
        block.kind = configuration.kind
        block.name = configuration.name
        block.targetRounds = configuration.targetRounds
        block.isSharedLoad = configuration.isSharedLoad
        block.restSeconds = configuration.restSeconds
        block.clockMode = configuration.clockMode
        block.prescribedDurationSeconds = configuration.prescribedDurationSeconds
        block.timeCapSeconds = configuration.timeCapSeconds
        block.intervalSeconds = configuration.intervalSeconds
        block.scoreKind = configuration.scoreKind
        block.repetitionScheme = configuration.repetitionScheme
        block.repetitionStart = configuration.repetitionStart
        block.repetitionEnd = configuration.repetitionEnd
        block.repetitionStep = configuration.repetitionStep
        _ = assign(entries: entries, to: block)
    }

    @discardableResult
    static func assign(
        entries: [ExerciseEntry],
        to block: WorkoutExecutionBlock
    ) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted || entries.contains(where: \.isCompleted),
            operation: .updateExecutionBlock
        ) { return rejection }
        for (index, entry) in entries.enumerated() {
            entry.executionBlockID = block.id
            entry.executionBlockComponentOrder = index
        }
        return .applied
    }

    @discardableResult
    static func remove(
        _ block: WorkoutExecutionBlock,
        from workout: Workout
    ) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            workout.isCompleted || block.isCompleted,
            operation: .removeExecutionBlock
        ) { return rejection }
        for entry in entries(in: block, workout: workout) {
            entry.executionBlockID = nil
            entry.executionBlockComponentOrder = nil
        }
        workout.executionBlocks.removeAll { $0 === block }
        for (index, remaining) in workout.orderedExecutionBlocks.enumerated() {
            remaining.orderIndex = index
        }
        return .applied
    }

    static func entries(in block: WorkoutExecutionBlock, workout: Workout) -> [ExerciseEntry] {
        workout.orderedExercises
            .filter { $0.executionBlockID == block.id }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.executionBlockComponentOrder ?? .max
                let rhsOrder = rhs.executionBlockComponentOrder ?? .max
                return lhsOrder == rhsOrder ? lhs.orderIndex < rhs.orderIndex : lhsOrder < rhsOrder
            }
    }

    @discardableResult
    static func start(_ block: WorkoutExecutionBlock, at date: Date = .now) -> WorkoutMutationResult {
        block.start(at: date)
    }

    @discardableResult
    static func pause(_ block: WorkoutExecutionBlock, at date: Date = .now) -> WorkoutMutationResult {
        block.pause(at: date)
    }

    @discardableResult
    static func completeRound(in block: WorkoutExecutionBlock) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .completeExecutionBlock
        ) { return rejection }
        guard block.status == .inProgress else { return .applied }
        block.completedRounds += 1
        if let targetRounds = block.targetRounds, block.completedRounds >= targetRounds {
            return complete(block, at: .now)
        }
        return .applied
    }

    @discardableResult
    static func recordAdditionalRepetitions(
        _ repetitions: Int,
        in block: WorkoutExecutionBlock
    ) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .updateExecutionBlockScore
        ) { return rejection }
        block.additionalRepetitions = max(0, repetitions)
        return .applied
    }

    @discardableResult
    static func complete(_ block: WorkoutExecutionBlock, at date: Date = .now) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .completeExecutionBlock
        ) { return rejection }
        _ = block.pause(at: date)
        block.status = .completed
        if block.scoreKind == .duration {
            block.scoreValue = block.accumulatedElapsedDuration
        }
        return .applied
    }

    @discardableResult
    static func cap(_ block: WorkoutExecutionBlock, at date: Date = .now) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .capExecutionBlock
        ) { return rejection }
        _ = block.pause(at: date)
        block.status = .capped
        if block.scoreKind == .duration {
            block.scoreValue = block.accumulatedElapsedDuration
        }
        return .applied
    }

    @discardableResult
    static func stop(_ block: WorkoutExecutionBlock, at date: Date = .now) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .stopExecutionBlock
        ) { return rejection }
        _ = block.pause(at: date)
        block.status = .stopped
        return .applied
    }

    /// A completed workout cannot retain an active shared context. A started
    /// but unfinished block is preserved as partial evidence; an untouched
    /// prescribed block is explicitly skipped rather than silently erased.
    @discardableResult
    static func finalizeForWorkoutSave(
        _ block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .completeExecutionBlock
        ) { return rejection }
        switch block.status {
        case .inProgress:
            _ = block.pause(at: date)
            block.status = .partial
        case .notStarted:
            block.status = .skipped
        case .completed, .capped, .partial, .stopped, .skipped:
            break
        }
        return .applied
    }

    @discardableResult
    static func updateScore(
        _ block: WorkoutExecutionBlock,
        completedRounds: Int? = nil,
        additionalRepetitions: Int? = nil,
        scoreValue: Double? = nil,
        scoreTiebreakValue: Double? = nil
    ) -> WorkoutMutationResult {
        if let rejection = WorkoutMutationGuard.rejectionIfCompleted(
            block.isCompleted,
            operation: .updateExecutionBlockScore
        ) { return rejection }
        if let completedRounds {
            block.completedRounds = max(0, completedRounds)
        }
        if let additionalRepetitions {
            block.additionalRepetitions = max(0, additionalRepetitions)
        }
        if block.scoreKind != .none {
            block.scoreValue = scoreValue
            block.scoreTiebreakValue = scoreTiebreakValue
        }
        return .applied
    }

    /// Applies deterministic clock terminal states whenever an active block is
    /// observed. A time-capped score is retained as capped; a countdown with
    /// no separate cap completes at zero.
    @discardableResult
    static func enforceClock(_ block: WorkoutExecutionBlock, at date: Date = .now) -> Bool {
        guard block.status == .inProgress else { return false }
        let elapsed = block.elapsedDuration(at: date)
        if let timeCapSeconds = block.timeCapSeconds, elapsed >= Double(timeCapSeconds) {
            cap(block, at: date)
            return true
        }
        if block.clockMode == .countdown,
           let prescribedDurationSeconds = block.prescribedDurationSeconds,
           elapsed >= Double(prescribedDurationSeconds) {
            complete(block, at: date)
            return true
        }
        return false
    }

    private static func validate(
        configuration: WorkoutExecutionBlockConfiguration,
        entries: [ExerciseEntry],
        in workout: Workout,
        allowing currentBlock: WorkoutExecutionBlock?
    ) throws {
        guard !workout.isCompleted else {
            throw WorkoutExecutionBlockError.completedWorkoutMutation(.updateExecutionBlock)
        }
        guard !entries.isEmpty else { throw WorkoutExecutionBlockError.emptyBlock }
        guard Set(entries.map(ObjectIdentifier.init)).count == entries.count else {
            throw WorkoutExecutionBlockError.duplicateEntry
        }
        let workoutEntries = Set(workout.exercises.map(ObjectIdentifier.init))
        guard entries.allSatisfy({ workoutEntries.contains(ObjectIdentifier($0)) }) else {
            throw WorkoutExecutionBlockError.entryDoesNotBelongToWorkout
        }
        guard entries.allSatisfy({ $0.executionBlockID == nil || $0.executionBlockID == currentBlock?.id }) else {
            throw WorkoutExecutionBlockError.entryAlreadyBelongsToBlock
        }
        guard configuration.targetRounds.map({ $0 > 0 }) ?? true,
              configuration.restSeconds.map({ $0 >= 0 }) ?? true else {
            throw WorkoutExecutionBlockError.invalidConfiguration("Rounds must be positive and rest cannot be negative.")
        }
        if let message = ExecutionBlockConfigurationValidator.message(
            kind: configuration.kind,
            clockMode: configuration.clockMode,
            prescribedDurationSeconds: configuration.prescribedDurationSeconds,
            timeCapSeconds: configuration.timeCapSeconds,
            intervalSeconds: configuration.intervalSeconds,
            repetitionScheme: configuration.repetitionScheme,
            repetitionStart: configuration.repetitionStart,
            repetitionEnd: configuration.repetitionEnd,
            repetitionStep: configuration.repetitionStep
        ) {
            throw WorkoutExecutionBlockError.invalidConfiguration(message)
        }
        switch configuration.kind {
        case .pairedSet where entries.count != 2:
            throw WorkoutExecutionBlockError.invalidComponentCount(kind: configuration.kind, count: entries.count)
        case .triset where entries.count != 3:
            throw WorkoutExecutionBlockError.invalidComponentCount(kind: configuration.kind, count: entries.count)
        case .giantSet where entries.count < 4:
            throw WorkoutExecutionBlockError.invalidComponentCount(kind: configuration.kind, count: entries.count)
        case .straight where entries.count != 1:
            throw WorkoutExecutionBlockError.invalidComponentCount(kind: configuration.kind, count: entries.count)
        default:
            break
        }
    }
}
