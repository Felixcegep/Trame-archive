import Foundation

/// The reason a previous block cannot be used as a personal benchmark.
///
/// These cases intentionally describe evidence, rather than guessing at a
/// substitute comparison. A missing value is different from a zero score.
enum ExecutionBlockBenchmarkUnavailabilityReason: Equatable {
    case noPreviousResult
    case currentResultUnavailable
    case previousResultUnavailable
    case blockKindMismatch
    case scoreKindMismatch
    case exerciseIdentityMismatch
    case clockConfigurationMismatch
    case targetRoundsMismatch
    case repetitionSchemeMismatch
    case timeScoreWasCapped
    case scoreValueMissing
}

/// The source identity copied onto an execution-block snapshot. This is only
/// a lookup identity for personal benchmark surfacing; it is not a second
/// persisted result store.
struct ExecutionBlockBenchmarkSourceIdentity: Equatable {
    let templateBlockID: UUID?
    let plannedBlockID: UUID?
    let definitionBlockKey: String?
    let programDefinitionID: UUID?

    var stableKey: String? {
        if let definitionBlockKey, !definitionBlockKey.isEmpty {
            return "definition:\(definitionBlockKey)"
        }
        if let plannedBlockID {
            return "planned:\(plannedBlockID.uuidString)"
        }
        if let templateBlockID {
            return "template:\(templateBlockID.uuidString)"
        }
        if let programDefinitionID {
            return "program:\(programDefinitionID.uuidString)"
        }
        return nil
    }
}

struct ExecutionBlockBenchmarkSignature: Equatable {
    let kind: ExerciseBlockKind
    let clockMode: BlockClockMode
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let targetRounds: Int?
    let repetitionScheme: BlockRepetitionScheme
    let repetitionStart: Int?
    let repetitionEnd: Int?
    let repetitionStep: Int?
}

/// A read-only projection of the values already stored on a completed block.
struct ExecutionBlockBenchmarkResult: Equatable {
    let blockID: UUID
    let workoutID: UUID
    let performedAt: Date
    let scoreKind: BlockScoreKind
    let scoreValue: Double
    let scoreTiebreakValue: Double?
    let completedRounds: Int
    let additionalRepetitions: Int
    let orderedExerciseIdentities: [UUID]
    let sourceIdentity: ExecutionBlockBenchmarkSourceIdentity
    let signature: ExecutionBlockBenchmarkSignature
    let status: WorkoutBlockStatus

    /// Duration is lower-is-better. All other currently supported block score
    /// kinds are higher-is-better and remain typed by `scoreKind`.
    var isLowerBetter: Bool { scoreKind == .duration }
}

/// Configuration and frozen exercise order are available while a block is
/// active, before a current score exists.
struct ExecutionBlockBenchmarkConfiguration: Equatable {
    let signature: ExecutionBlockBenchmarkSignature
    let orderedExerciseIdentities: [UUID]
    let sourceIdentity: ExecutionBlockBenchmarkSourceIdentity
}

/// The outcome of asking whether a block has a strictly comparable personal
/// benchmark. No value here is written back to SwiftData.
struct ExecutionBlockBenchmarkProjection: Equatable {
    let currentConfiguration: ExecutionBlockBenchmarkConfiguration
    let current: ExecutionBlockBenchmarkResult?
    /// A current block may be validly in progress. This reason is separate
    /// from `unavailableReason`, which describes why the previous result did
    /// not compare, so a UI can show the previous benchmark before completion.
    let currentResultUnavailableReason: ExecutionBlockBenchmarkUnavailabilityReason?
    let previous: ExecutionBlockBenchmarkResult?
    let unavailableReason: ExecutionBlockBenchmarkUnavailabilityReason?

    var hasComparablePreviousResult: Bool { previous != nil && unavailableReason == nil }
    var isComparable: Bool { current != nil && hasComparablePreviousResult }

    var scoreDelta: Double? {
        guard isComparable, let current, let previous else { return nil }
        return current.scoreValue - previous.scoreValue
    }
}

/// Deterministic CE-05 comparison policy. Callers supply already-fetched
/// workouts so this policy stays independent of SwiftData query/UI concerns.
enum ExecutionBlockBenchmarkProjectionPolicy {
    static func project(
        currentBlock: WorkoutExecutionBlock,
        in currentWorkout: Workout,
        previousWorkouts: [Workout]
    ) -> ExecutionBlockBenchmarkProjection {
        let configuration = configuration(for: currentBlock, in: currentWorkout)
        if currentBlock.scoreKind == .duration, currentBlock.status == .capped {
            return ExecutionBlockBenchmarkProjection(
                currentConfiguration: configuration,
                current: result(for: currentBlock, in: currentWorkout, requireCompletedWorkout: false),
                currentResultUnavailableReason: nil,
                previous: nil,
                unavailableReason: .timeScoreWasCapped
            )
        }

        let current = result(for: currentBlock, in: currentWorkout, requireCompletedWorkout: false)

        let candidates: [(result: ExecutionBlockBenchmarkResult, rank: Int)] = previousWorkouts
            .filter { $0.id != currentWorkout.id && $0.status == .completed }
            .flatMap { workout -> [(result: ExecutionBlockBenchmarkResult, rank: Int)] in
                workout.orderedExecutionBlocks.compactMap { block -> (result: ExecutionBlockBenchmarkResult, rank: Int)? in
                    guard let result = result(for: block, in: workout, requireCompletedWorkout: true) else { return nil }
                    return (
                        result: result,
                        rank: sourceMatchRank(configuration.sourceIdentity, result.sourceIdentity)
                    )
                }
            }
            .sorted {
                if $0.rank != $1.rank { return $0.rank > $1.rank }
                if $0.result.performedAt != $1.result.performedAt {
                    return $0.result.performedAt > $1.result.performedAt
                }
                return $0.result.blockID.uuidString < $1.result.blockID.uuidString
            }

        guard !candidates.isEmpty else {
            let hasMissingScore = previousWorkouts.contains { workout in
                workout.status == .completed && workout.orderedExecutionBlocks.contains { block in
                    guard block.status == .completed || block.status == .capped else { return false }
                    guard block.scoreKind != .none && block.scoreKind != .roundsAndRepetitions else { return false }
                    return block.scoreValue == nil || !(block.scoreValue?.isFinite ?? false)
                }
            }
            return ExecutionBlockBenchmarkProjection(
                currentConfiguration: configuration,
                current: current,
                currentResultUnavailableReason: current == nil ? .currentResultUnavailable : nil,
                previous: nil,
                unavailableReason: hasMissingScore ? .scoreValueMissing : .noPreviousResult
            )
        }

        var firstMismatch: ExecutionBlockBenchmarkUnavailabilityReason?
        for (candidate, _) in candidates {
            if let mismatch = mismatch(
                current: currentBlock,
                in: currentWorkout,
                candidate: candidate
            ) {
                firstMismatch = firstMismatch ?? mismatch
                continue
            }
            return ExecutionBlockBenchmarkProjection(
                currentConfiguration: configuration,
                current: current,
                currentResultUnavailableReason: current == nil ? .currentResultUnavailable : nil,
                previous: candidate,
                unavailableReason: nil
            )
        }

        return ExecutionBlockBenchmarkProjection(
            currentConfiguration: configuration,
            current: current,
            currentResultUnavailableReason: current == nil ? .currentResultUnavailable : nil,
            previous: nil,
            unavailableReason: firstMismatch ?? .previousResultUnavailable
        )
    }

    private static func result(
        for block: WorkoutExecutionBlock,
        in workout: Workout,
        requireCompletedWorkout: Bool
    ) -> ExecutionBlockBenchmarkResult? {
        if requireCompletedWorkout {
            guard workout.status == .completed,
                  block.status == .completed || block.status == .capped else { return nil }
        } else {
            guard block.status != .notStarted, block.status != .skipped else { return nil }
        }
        guard block.scoreKind != .none else { return nil }
        if !requireCompletedWorkout,
           block.status == .inProgress,
           block.scoreKind == .roundsAndRepetitions,
           block.completedRounds == 0,
           block.additionalRepetitions == 0 {
            return nil
        }

        let score: Double
        switch block.scoreKind {
        case .roundsAndRepetitions:
            score = Double(max(0, block.completedRounds))
        case .none:
            return nil
        default:
            guard let value = block.scoreValue, value.isFinite else { return nil }
            score = value
        }

        let orderedEntries = orderedEntries(for: block, in: workout)
        let date = workout.endTime ?? workout.startTime
        return ExecutionBlockBenchmarkResult(
            blockID: block.id,
            workoutID: workout.id,
            performedAt: date,
            scoreKind: block.scoreKind,
            scoreValue: score,
            scoreTiebreakValue: block.scoreTiebreakValue,
            completedRounds: block.completedRounds,
            additionalRepetitions: block.additionalRepetitions,
            orderedExerciseIdentities: orderedEntries.map(\.historicalExerciseID),
            sourceIdentity: ExecutionBlockBenchmarkSourceIdentity(
                templateBlockID: block.sourceTemplateBlockID,
                plannedBlockID: block.sourcePlannedBlockID,
                definitionBlockKey: block.sourceDefinitionBlockKey,
                programDefinitionID: workout.sourceProgramDefinitionID
            ),
            signature: ExecutionBlockBenchmarkSignature(
                kind: block.kind,
                clockMode: block.clockMode,
                prescribedDurationSeconds: block.prescribedDurationSeconds,
                timeCapSeconds: block.timeCapSeconds,
                intervalSeconds: block.intervalSeconds,
                targetRounds: block.targetRounds,
                repetitionScheme: block.repetitionScheme,
                repetitionStart: block.repetitionStart,
                repetitionEnd: block.repetitionEnd,
                repetitionStep: block.repetitionStep
            ),
            status: block.status
        )
    }

    private static func configuration(
        for block: WorkoutExecutionBlock,
        in workout: Workout
    ) -> ExecutionBlockBenchmarkConfiguration {
        let entries = orderedEntries(for: block, in: workout)
        return ExecutionBlockBenchmarkConfiguration(
            signature: ExecutionBlockBenchmarkSignature(
                kind: block.kind,
                clockMode: block.clockMode,
                prescribedDurationSeconds: block.prescribedDurationSeconds,
                timeCapSeconds: block.timeCapSeconds,
                intervalSeconds: block.intervalSeconds,
                targetRounds: block.targetRounds,
                repetitionScheme: block.repetitionScheme,
                repetitionStart: block.repetitionStart,
                repetitionEnd: block.repetitionEnd,
                repetitionStep: block.repetitionStep
            ),
            orderedExerciseIdentities: entries.map(\.historicalExerciseID),
            sourceIdentity: ExecutionBlockBenchmarkSourceIdentity(
                templateBlockID: block.sourceTemplateBlockID,
                plannedBlockID: block.sourcePlannedBlockID,
                definitionBlockKey: block.sourceDefinitionBlockKey,
                programDefinitionID: workout.sourceProgramDefinitionID
            )
        )
    }

    private static func mismatch(
        current: WorkoutExecutionBlock,
        in workout: Workout,
        candidate: ExecutionBlockBenchmarkResult
    ) -> ExecutionBlockBenchmarkUnavailabilityReason? {
        guard current.kind == candidate.signature.kind,
              current.scoreKind == candidate.scoreKind,
              current.scoreKind != .none else {
            return current.kind == candidate.signature.kind
                ? .scoreKindMismatch
                : .blockKindMismatch
        }

        let currentExercises = orderedEntries(for: current, in: workout)
            .map(\.historicalExerciseID)
        guard currentExercises == candidate.orderedExerciseIdentities else {
            return .exerciseIdentityMismatch
        }

        guard current.clockMode == candidate.signature.clockMode,
              current.prescribedDurationSeconds == candidate.signature.prescribedDurationSeconds,
              current.timeCapSeconds == candidate.signature.timeCapSeconds,
              current.intervalSeconds == candidate.signature.intervalSeconds else {
            return .clockConfigurationMismatch
        }
        guard current.targetRounds == candidate.signature.targetRounds else {
            return .targetRoundsMismatch
        }
        guard current.repetitionScheme == candidate.signature.repetitionScheme,
              current.repetitionStart == candidate.signature.repetitionStart,
              current.repetitionEnd == candidate.signature.repetitionEnd,
              current.repetitionStep == candidate.signature.repetitionStep else {
            return .repetitionSchemeMismatch
        }
        if current.scoreKind == .duration, candidate.status == .capped {
            return .timeScoreWasCapped
        }
        return nil
    }

    private static func orderedEntries(
        for block: WorkoutExecutionBlock,
        in workout: Workout
    ) -> [ExerciseEntry] {
        workout.orderedExercises
            .filter { $0.executionBlockID == block.id }
            .sorted {
                let lhsOrder = $0.executionBlockComponentOrder ?? .max
                let rhsOrder = $1.executionBlockComponentOrder ?? .max
                return lhsOrder == rhsOrder ? $0.orderIndex < $1.orderIndex : lhsOrder < rhsOrder
            }
    }

    private static func sourceMatchRank(
        _ lhs: ExecutionBlockBenchmarkSourceIdentity,
        _ rhs: ExecutionBlockBenchmarkSourceIdentity
    ) -> Int {
        if let lhsKey = lhs.stableKey, lhsKey == rhs.stableKey { return 2 }
        return 1
    }
}
