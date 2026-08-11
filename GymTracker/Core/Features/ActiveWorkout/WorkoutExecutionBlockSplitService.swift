import Foundation
import SwiftData

struct WorkoutExecutionBlockCursorState: Equatable, Sendable {
    let componentOrder: Int
    let roundIndex: Int
    let splitCount: Int
    let latestElapsedDuration: TimeInterval?
}

enum WorkoutExecutionBlockSplitError: Error, Equatable {
    case missingWorkout
    case emptyComponentList
    case invalidComponentOrder
}

/// Durable cursor/split boundary. A repeated command UUID is idempotent and
/// returns the existing evidence without advancing twice.
enum WorkoutExecutionBlockSplitService {
    static func splits(
        for blockID: UUID,
        using context: ModelContext
    ) throws -> [WorkoutExecutionBlockSplit] {
        let descriptor = FetchDescriptor<WorkoutExecutionBlockSplit>(
            predicate: #Predicate { $0.blockID == blockID },
            sortBy: [
                SortDescriptor(\.sequenceIndex),
                SortDescriptor(\.recordedAt)
            ]
        )
        return try context.fetch(descriptor)
    }

    static func cursor(
        for blockID: UUID,
        componentCount: Int,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockCursorState {
        guard componentCount > 0 else { throw WorkoutExecutionBlockSplitError.emptyComponentList }
        let records = try splits(for: blockID, using: context)
        let latest = records.last
        let order: Int
        switch latest?.kind {
        case .completed, .capped:
            order = max(0, componentCount - 1)
        case .componentAdvanced, .roundCompleted, .clockCheckpoint:
            order = min(max(0, latest?.componentOrder ?? 0), componentCount - 1)
        case nil:
            order = 0
        }
        return WorkoutExecutionBlockCursorState(
            componentOrder: order,
            roundIndex: max(0, latest?.roundIndex ?? 0),
            splitCount: records.count,
            latestElapsedDuration: latest?.elapsedDuration
        )
    }

    @discardableResult
    static func advance(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        commandID: UUID,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        guard let workout = block.workout else { throw WorkoutExecutionBlockSplitError.missingWorkout }
        guard componentCount > 0 else { throw WorkoutExecutionBlockSplitError.emptyComponentList }
        if let existing = try split(id: commandID, using: context) { return existing }

        let current = try cursor(for: block.id, componentCount: componentCount, using: context)
        let isLastComponent = current.componentOrder >= componentCount - 1
        let nextOrder: Int
        let kind: WorkoutExecutionBlockSplitKind
        let result: WorkoutMutationResult
        if isLastComponent {
            result = WorkoutExecutionBlockService.advanceRound(block, at: date)
            nextOrder = block.status == .completed ? componentCount - 1 : 0
            kind = block.status == .completed ? .completed : .roundCompleted
        } else {
            result = .applied
            nextOrder = current.componentOrder + 1
            kind = .componentAdvanced
        }
        guard result.isApplied else {
            throw WorkoutMutationError.completedWorkoutMutation(.completeExecutionBlock)
        }

        return try insert(
            id: commandID,
            block: block,
            workoutID: workout.id,
            kind: kind,
            roundIndex: block.completedRounds,
            componentOrder: nextOrder,
            at: date,
            using: context
        )
    }

    @discardableResult
    static func checkpoint(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        commandID: UUID,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        guard let workout = block.workout else { throw WorkoutExecutionBlockSplitError.missingWorkout }
        if let existing = try split(id: commandID, using: context) { return existing }
        let current = try cursor(for: block.id, componentCount: componentCount, using: context)
        let result = WorkoutExecutionBlockService.checkpointClock(block, at: date)
        guard result.isApplied else {
            throw WorkoutMutationError.completedWorkoutMutation(.pauseExecutionBlock)
        }
        return try insert(
            id: commandID,
            block: block,
            workoutID: workout.id,
            kind: .clockCheckpoint,
            roundIndex: block.completedRounds,
            componentOrder: current.componentOrder,
            at: date,
            using: context
        )
    }

    @discardableResult
    static func complete(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        commandID: UUID,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        if let existing = try split(id: commandID, using: context) { return existing }
        let result = WorkoutExecutionBlockService.complete(block, at: date)
        guard result.isApplied else {
            throw WorkoutMutationError.completedWorkoutMutation(.completeExecutionBlock)
        }
        return try recordTerminal(
            block: block,
            componentCount: componentCount,
            commandID: commandID,
            kind: .completed,
            at: date,
            using: context
        )
    }

    @discardableResult
    static func cap(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        commandID: UUID,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        if let existing = try split(id: commandID, using: context) { return existing }
        let result = WorkoutExecutionBlockService.cap(block, at: date)
        guard result.isApplied else {
            throw WorkoutMutationError.completedWorkoutMutation(.capExecutionBlock)
        }
        return try recordTerminal(
            block: block,
            componentCount: componentCount,
            commandID: commandID,
            kind: .capped,
            at: date,
            using: context
        )
    }

    /// Records a clock-enforced terminal state after `enforceClock` has
    /// already applied it. Duplicate observations at the same terminal state
    /// are collapsed so a periodic TimelineView cannot create extra evidence.
    static func recordEnforcedTerminalIfNeeded(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        at date: Date,
        using context: ModelContext
    ) throws {
        let kind: WorkoutExecutionBlockSplitKind
        switch block.status {
        case .completed: kind = .completed
        case .capped: kind = .capped
        default: return
        }
        if try splits(for: block.id, using: context).last?.kind == kind { return }
        _ = try recordTerminal(
            block: block,
            componentCount: componentCount,
            commandID: UUID(),
            kind: kind,
            at: date,
            using: context
        )
    }

    static func deleteEvidence(
        for blockID: UUID,
        using context: ModelContext
    ) throws {
        for split in try splits(for: blockID, using: context) {
            context.delete(split)
        }
    }

    static func deleteWorkoutEvidence(
        for workoutID: UUID,
        using context: ModelContext
    ) throws {
        let descriptor = FetchDescriptor<WorkoutExecutionBlockSplit>(
            predicate: #Predicate { $0.workoutID == workoutID }
        )
        for split in try context.fetch(descriptor) {
            context.delete(split)
        }
    }

    private static func insert(
        id: UUID,
        block: WorkoutExecutionBlock,
        workoutID: UUID,
        kind: WorkoutExecutionBlockSplitKind,
        roundIndex: Int,
        componentOrder: Int,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        let existing = try splits(for: block.id, using: context)
        let split = WorkoutExecutionBlockSplit(
            blockID: block.id,
            workoutID: workoutID,
            sequenceIndex: (existing.map(\.sequenceIndex).max() ?? -1) + 1,
            kind: kind,
            roundIndex: roundIndex,
            componentOrder: componentOrder,
            elapsedDuration: block.elapsedDuration(at: date),
            recordedAt: date
        )
        split.id = id
        context.insert(split)
        return split
    }

    private static func recordTerminal(
        block: WorkoutExecutionBlock,
        componentCount: Int,
        commandID: UUID,
        kind: WorkoutExecutionBlockSplitKind,
        at date: Date,
        using context: ModelContext
    ) throws -> WorkoutExecutionBlockSplit {
        guard let workout = block.workout else { throw WorkoutExecutionBlockSplitError.missingWorkout }
        guard componentCount > 0 else { throw WorkoutExecutionBlockSplitError.emptyComponentList }
        let current = try cursor(for: block.id, componentCount: componentCount, using: context)
        return try insert(
            id: commandID,
            block: block,
            workoutID: workout.id,
            kind: kind,
            roundIndex: block.completedRounds,
            componentOrder: current.componentOrder,
            at: date,
            using: context
        )
    }

    private static func split(id: UUID, using context: ModelContext) throws -> WorkoutExecutionBlockSplit? {
        var descriptor = FetchDescriptor<WorkoutExecutionBlockSplit>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
