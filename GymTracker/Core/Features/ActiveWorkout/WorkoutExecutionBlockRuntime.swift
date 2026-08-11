import Foundation

/// One value-only command for the shared execution-block runtime. Views and
/// external surfaces dispatch through the same command boundary instead of
/// reproducing format-specific mutations.
enum WorkoutExecutionBlockRuntimeAction: Equatable, Sendable {
    case start(at: Date)
    case pause(at: Date)
    case resume(at: Date)
    case advanceRound(at: Date)
    case checkpointClock(at: Date)
    case score(
        completedRounds: Int?,
        additionalRepetitions: Int?,
        scoreValue: Double?,
        scoreTiebreakValue: Double?
    )
    case complete(at: Date)
    case cap(at: Date)
}

struct WorkoutExecutionBlockRuntimeState: Equatable, Sendable {
    let blockID: UUID
    let kind: ExerciseBlockKind
    let status: WorkoutBlockStatus
    let completedRounds: Int
    let additionalRepetitions: Int
    let elapsedDuration: TimeInterval
    let currentInterval: Int?
    let scoreValue: Double?
    let scoreTiebreakValue: Double?

    var isPartial: Bool { status == .partial }
    var isCapped: Bool { status == .capped }
}

struct WorkoutExecutionBlockRuntimeReceipt: Equatable, Sendable {
    let action: WorkoutExecutionBlockRuntimeAction
    let result: WorkoutMutationResult
    let before: WorkoutExecutionBlockRuntimeState
    let after: WorkoutExecutionBlockRuntimeState
}

/// Central format-aware workflow for shared execution blocks.
///
/// Existing block fields remain the durable summary truth: elapsed clock,
/// completed rounds, score, and terminal status. Component-level advancement
/// and persisted split evidence are owned by
/// `WorkoutExecutionBlockSplitService`, whose V3 records are keyed to this
/// block without changing the frozen V1/V2 model inventories. This value-only
/// runtime remains useful for surfaces that intentionally mutate only the
/// format-level summary. Partial and capped states remain distinct and are
/// never promoted to completed history by this service.
extension WorkoutExecutionBlockService {
    @discardableResult
    static func apply(
        _ action: WorkoutExecutionBlockRuntimeAction,
        to block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutExecutionBlockRuntimeReceipt {
        let before = runtimeState(of: block, at: date)
        let result: WorkoutMutationResult
        switch action {
        case let .start(at):
            result = start(block, at: at)
        case let .pause(at):
            result = pause(block, at: at)
        case let .resume(at):
            result = resume(block, at: at)
        case let .advanceRound(at):
            result = advanceRound(block, at: at)
        case let .checkpointClock(at):
            result = checkpointClock(block, at: at)
        case let .score(completedRounds, additionalRepetitions, scoreValue, scoreTiebreakValue):
            result = updateScore(
                block,
                completedRounds: completedRounds,
                additionalRepetitions: additionalRepetitions,
                scoreValue: scoreValue,
                scoreTiebreakValue: scoreTiebreakValue
            )
        case let .complete(at):
            result = complete(block, at: at)
        case let .cap(at):
            result = cap(block, at: at)
        }
        let after = runtimeState(of: block, at: date)
        return WorkoutExecutionBlockRuntimeReceipt(
            action: action,
            result: result,
            before: before,
            after: after
        )
    }

    @discardableResult
    static func resume(
        _ block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutMutationResult {
        start(block, at: date)
    }

    /// Advances one format-level round without recording a component split.
    /// Eyes-up execution must use `WorkoutExecutionBlockSplitService.advance`
    /// so its component cursor and idempotent event survive relaunch.
    @discardableResult
    static func advanceRound(
        _ block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutMutationResult {
        guard block.status == .inProgress else { return .applied }
        switch block.kind {
        case .straight, .forTime, .chipper:
            return complete(block, at: date)
        case .amrap, .emom, .circuit, .pairedSet, .triset, .giantSet,
             .olympicComplex, .ladder, .interval, .medley:
            return completeRound(in: block)
        }
    }

    /// Commits elapsed clock time and immediately resumes the same block. This
    /// summary-only path does not persist a split event; eyes-up execution uses
    /// `WorkoutExecutionBlockSplitService.recordCheckpoint`.
    @discardableResult
    static func checkpointClock(
        _ block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutMutationResult {
        guard block.status == .inProgress else { return .applied }
        let paused = pause(block, at: date)
        guard paused.isApplied else { return paused }
        return resume(block, at: date)
    }

    static func runtimeState(
        of block: WorkoutExecutionBlock,
        at date: Date = .now
    ) -> WorkoutExecutionBlockRuntimeState {
        return WorkoutExecutionBlockRuntimeState(
            blockID: block.id,
            kind: block.kind,
            status: block.status,
            completedRounds: block.completedRounds,
            additionalRepetitions: block.additionalRepetitions,
            elapsedDuration: block.elapsedDuration(at: date),
            currentInterval: block.currentInterval(at: date),
            scoreValue: block.scoreValue,
            scoreTiebreakValue: block.scoreTiebreakValue
        )
    }
}
