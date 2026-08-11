import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// The phone remains authoritative for SwiftData and workout mutations. The
/// future Watch target is a command surface and a read-only snapshot client.
enum WatchCompanionAuthority: String, Codable, Equatable, Hashable, Sendable {
    case phone
    case watchCommandSurface
}

enum WatchCompanionConnection: String, Codable, Equatable, Hashable, Sendable {
    case unsupported
    case notPaired
    case appNotInstalled
    case inactive
    case reachable
    case offline
}

struct WatchCompanionOwnershipState: Codable, Equatable, Hashable, Sendable {
    let authority: WatchCompanionAuthority
    let connection: WatchCompanionConnection
    let phoneOwnsPersistence: Bool
    let watchMayIssueCommands: Bool

    init(connection: WatchCompanionConnection) {
        self.authority = .phone
        self.connection = connection
        self.phoneOwnsPersistence = true
        self.watchMayIssueCommands = connection == .reachable || connection == .offline
    }
}

enum WatchCompanionCommandKind: String, Codable, Equatable, Hashable, Sendable {
    case completeCurrentSet
    case pauseRest
    case resumeRest
    case extendRest
    case skipRest
    case completeWorkout
    case requestSnapshot
}

/// A command is an intent, not performed truth. `commandID` is the stable
/// idempotency key that the future Watch adapter must pass to the existing
/// durable mutation boundary where supported (notably execution-block splits).
struct WatchCompanionCommandEnvelope: Codable, Equatable, Hashable, Sendable {
    let commandID: UUID
    let workoutID: UUID
    let kind: WatchCompanionCommandKind
    let issuedAt: Date
    let expectedExerciseOrderIndex: Int?
    let expectedSetOrderIndex: Int?
    let expectedRestPhase: LiveActivityRestPhase?
    let restExtensionSeconds: Int?
    let expectedSnapshotID: String?

    init(
        commandID: UUID,
        workoutID: UUID,
        kind: WatchCompanionCommandKind,
        issuedAt: Date,
        expectedExerciseOrderIndex: Int? = nil,
        expectedSetOrderIndex: Int? = nil,
        expectedRestPhase: LiveActivityRestPhase? = nil,
        restExtensionSeconds: Int? = nil,
        expectedSnapshotID: String? = nil
    ) {
        self.commandID = commandID
        self.workoutID = workoutID
        self.kind = kind
        self.issuedAt = issuedAt
        self.expectedExerciseOrderIndex = expectedExerciseOrderIndex
        self.expectedSetOrderIndex = expectedSetOrderIndex
        self.expectedRestPhase = expectedRestPhase
        self.restExtensionSeconds = restExtensionSeconds
        self.expectedSnapshotID = expectedSnapshotID
    }
}

enum WatchCompanionCommandOutcome: String, Codable, Equatable, Hashable, Sendable {
    case applied
    case duplicate
    case queuedOffline
    case stale
    case conflict
    case rejected
    case handoffRequired
}

enum WatchCompanionConflictReason: String, Codable, Equatable, Hashable, Sendable {
    case workoutChanged
    case currentSetChanged
    case restStateChanged
    case workoutAlreadyCompleted
    case commandNotSupported
    case snapshotChanged
}

struct WatchCompanionCommandReceipt: Codable, Equatable, Hashable, Sendable {
    let commandID: UUID
    let workoutID: UUID
    let kind: WatchCompanionCommandKind
    let outcome: WatchCompanionCommandOutcome
    let reason: WatchCompanionConflictReason?
    let recordedAt: Date
    let snapshotID: String?
}

/// A compact latest-state snapshot. It contains enough for a Watch set/rest
/// surface and completion handoff without creating a Watch-owned workout graph.
struct WatchCompanionWorkoutSnapshot: Codable, Equatable, Hashable, Sendable {
    let snapshotID: String
    let workoutID: UUID
    let generatedAt: Date
    let startTime: Date
    let currentExerciseName: String?
    let currentSet: Int?
    let totalSets: Int?
    let currentExerciseOrderIndex: Int?
    let currentSetOrderIndex: Int?
    let hasAnySets: Bool
    let restPhase: LiveActivityRestPhase
    let restEndDate: Date?
    let pausedRemainingTime: TimeInterval?
    let isWorkoutCompleted: Bool
    let ownership: WatchCompanionOwnershipState

    static func build(
        projection: LiveActivityProjection,
        isWorkoutCompleted: Bool,
        connection: WatchCompanionConnection,
        now: Date
    ) -> Self {
        let snapshotID = [
            projection.workoutID.uuidString,
            projection.currentExerciseOrderIndex.map(String.init) ?? "-",
            projection.currentSetOrderIndex.map(String.init) ?? "-",
            projection.restPhase.rawValue,
            projection.restEndDate?.timeIntervalSince1970.description ?? "-",
            projection.pausedRemainingTime?.description ?? "-",
            isWorkoutCompleted.description
        ].joined(separator: "|")
        return Self(
            snapshotID: snapshotID,
            workoutID: projection.workoutID,
            generatedAt: now,
            startTime: projection.startTime,
            currentExerciseName: projection.currentExerciseName,
            currentSet: projection.currentSet,
            totalSets: projection.totalSets,
            currentExerciseOrderIndex: projection.currentExerciseOrderIndex,
            currentSetOrderIndex: projection.currentSetOrderIndex,
            hasAnySets: projection.hasAnySets,
            restPhase: projection.restPhase,
            restEndDate: projection.restEndDate,
            pausedRemainingTime: projection.pausedRemainingTime,
            isWorkoutCompleted: isWorkoutCompleted,
            ownership: WatchCompanionOwnershipState(connection: connection)
        )
    }
}

enum WatchCompanionCommandReconciliation {
    static func reconcile(
        _ command: WatchCompanionCommandEnvelope,
        snapshot: WatchCompanionWorkoutSnapshot,
        existingReceipts: [WatchCompanionCommandReceipt],
        connection: WatchCompanionConnection,
        recordedAt: Date
    ) -> WatchCompanionCommandReceipt {
        if let prior = existingReceipts.first(where: { $0.commandID == command.commandID }) {
            return WatchCompanionCommandReceipt(
                commandID: command.commandID,
                workoutID: command.workoutID,
                kind: command.kind,
                outcome: .duplicate,
                reason: prior.reason,
                recordedAt: recordedAt,
                snapshotID: prior.snapshotID
            )
        }

        if connection != .reachable {
            return receipt(command, outcome: .queuedOffline, reason: nil, snapshot: snapshot, recordedAt: recordedAt)
        }
        guard command.workoutID == snapshot.workoutID else {
            return receipt(command, outcome: .conflict, reason: .workoutChanged, snapshot: snapshot, recordedAt: recordedAt)
        }
        if let expectedSnapshotID = command.expectedSnapshotID,
           expectedSnapshotID != snapshot.snapshotID {
            return receipt(command, outcome: .conflict, reason: .snapshotChanged, snapshot: snapshot, recordedAt: recordedAt)
        }
        if snapshot.isWorkoutCompleted {
            return receipt(command, outcome: .stale, reason: .workoutAlreadyCompleted, snapshot: snapshot, recordedAt: recordedAt)
        }
        if command.kind == .completeCurrentSet,
           (command.expectedExerciseOrderIndex != snapshot.currentExerciseOrderIndex
            || command.expectedSetOrderIndex != snapshot.currentSetOrderIndex) {
            return receipt(command, outcome: .conflict, reason: .currentSetChanged, snapshot: snapshot, recordedAt: recordedAt)
        }
        if let expectedRestPhase = command.expectedRestPhase,
           expectedRestPhase != snapshot.restPhase {
            return receipt(command, outcome: .conflict, reason: .restStateChanged, snapshot: snapshot, recordedAt: recordedAt)
        }
        if command.kind == .extendRest,
           command.restExtensionSeconds.map({ $0 > 0 }) != true {
            return receipt(command, outcome: .rejected, reason: .commandNotSupported, snapshot: snapshot, recordedAt: recordedAt)
        }
        if command.kind == .completeWorkout {
            return receipt(command, outcome: .handoffRequired, reason: nil, snapshot: snapshot, recordedAt: recordedAt)
        }
        return receipt(command, outcome: .applied, reason: nil, snapshot: snapshot, recordedAt: recordedAt)
    }

    static func recover(
        pending: [WatchCompanionCommandEnvelope],
        snapshot: WatchCompanionWorkoutSnapshot,
        existingReceipts: [WatchCompanionCommandReceipt],
        connection: WatchCompanionConnection,
        recordedAt: Date
    ) -> [WatchCompanionCommandReceipt] {
        var receipts = existingReceipts
        var appliedCurrentSetTargets: Set<String> = []
        return pending
            .sorted {
                if $0.issuedAt != $1.issuedAt { return $0.issuedAt < $1.issuedAt }
                return $0.commandID.uuidString < $1.commandID.uuidString
            }
            .map { command in
                let targetKey = "\(command.workoutID.uuidString)|\(command.expectedExerciseOrderIndex.map(String.init) ?? "-")|\(command.expectedSetOrderIndex.map(String.init) ?? "-")"
                if command.kind == .completeCurrentSet,
                   appliedCurrentSetTargets.contains(targetKey) {
                    let result = receipt(
                        command,
                        outcome: .conflict,
                        reason: .currentSetChanged,
                        snapshot: snapshot,
                        recordedAt: recordedAt
                    )
                    receipts.append(result)
                    return result
                }
                let result = reconcile(
                    command,
                    snapshot: snapshot,
                    existingReceipts: receipts,
                    connection: connection,
                    recordedAt: recordedAt
                )
                if result.outcome != .queuedOffline { receipts.append(result) }
                if command.kind == .completeCurrentSet, result.outcome == .applied {
                    appliedCurrentSetTargets.insert(targetKey)
                }
                return result
            }
    }

    private static func receipt(
        _ command: WatchCompanionCommandEnvelope,
        outcome: WatchCompanionCommandOutcome,
        reason: WatchCompanionConflictReason?,
        snapshot: WatchCompanionWorkoutSnapshot,
        recordedAt: Date
    ) -> WatchCompanionCommandReceipt {
        WatchCompanionCommandReceipt(
            commandID: command.commandID,
            workoutID: command.workoutID,
            kind: command.kind,
            outcome: outcome,
            reason: reason,
            recordedAt: recordedAt,
            snapshotID: snapshot.snapshotID
        )
    }
}

/// Phone-side executor. Connectivity transports enqueue value envelopes; only
/// this adapter may turn an accepted command into a SwiftData mutation.
/// ActiveWorkoutMutationService remains the sole workout mutation authority.
@MainActor
enum WatchCompanionCommandProcessor {
    static func process(
        _ command: WatchCompanionCommandEnvelope,
        existingReceipts: [WatchCompanionCommandReceipt],
        connection: WatchCompanionConnection,
        now: Date = .now,
        using context: ModelContext
    ) -> WatchCompanionCommandReceipt {
        guard let workout = ((try? context.fetch(FetchDescriptor<Workout>())) ?? [])
            .first(where: { $0.id == command.workoutID }) else {
            return receipt(command, outcome: .conflict, reason: .workoutChanged, snapshotID: nil, at: now)
        }
        let before = WatchCompanionWorkoutSnapshot.build(
            projection: LiveActivityProjection(workout: workout, now: now),
            isWorkoutCompleted: workout.isCompleted,
            connection: connection,
            now: now
        )
        let reconciled = WatchCompanionCommandReconciliation.reconcile(
            command,
            snapshot: before,
            existingReceipts: existingReceipts,
            connection: connection,
            recordedAt: now
        )
        guard reconciled.outcome == .applied else { return reconciled }

        let service = ActiveWorkoutMutationService(modelContext: context)
        let mutation: ActiveWorkoutMutationService.Result?
        switch command.kind {
        case .completeCurrentSet:
            guard let exercise = command.expectedExerciseOrderIndex, let set = command.expectedSetOrderIndex else {
                return receipt(command, outcome: .rejected, reason: .commandNotSupported, snapshotID: before.snapshotID, at: now)
            }
            mutation = service.completeCurrentSet(
                workoutID: command.workoutID,
                expectedExerciseOrderIndex: exercise,
                expectedSetOrderIndex: set,
                now: now
            )
        case .pauseRest:
            mutation = service.pauseRest(workoutID: command.workoutID, now: now)
        case .resumeRest:
            mutation = service.resumeRest(workoutID: command.workoutID, now: now)
        case .skipRest:
            mutation = service.skipRest(workoutID: command.workoutID, now: now)
        case .extendRest:
            mutation = service.extendRest(
                workoutID: command.workoutID,
                by: TimeInterval(command.restExtensionSeconds ?? 0),
                now: now
            )
        case .requestSnapshot:
            mutation = nil
        case .completeWorkout:
            return receipt(command, outcome: .handoffRequired, reason: nil, snapshotID: before.snapshotID, at: now)
        }

        guard let mutation else {
            return receipt(command, outcome: .applied, reason: nil, snapshotID: before.snapshotID, at: now)
        }
        switch mutation {
        case .applied(let projection):
            let after = WatchCompanionWorkoutSnapshot.build(
                projection: projection,
                isWorkoutCompleted: false,
                connection: connection,
                now: now
            )
            return receipt(command, outcome: .applied, reason: nil, snapshotID: after.snapshotID, at: now)
        case .stale:
            let reason: WatchCompanionConflictReason = command.kind == .completeCurrentSet ? .currentSetChanged : .restStateChanged
            return receipt(command, outcome: .stale, reason: reason, snapshotID: before.snapshotID, at: now)
        case .invalid:
            return receipt(command, outcome: .rejected, reason: .commandNotSupported, snapshotID: before.snapshotID, at: now)
        case .unavailable:
            return receipt(command, outcome: .conflict, reason: .workoutChanged, snapshotID: before.snapshotID, at: now)
        }
    }

    private static func receipt(
        _ command: WatchCompanionCommandEnvelope,
        outcome: WatchCompanionCommandOutcome,
        reason: WatchCompanionConflictReason?,
        snapshotID: String?,
        at date: Date
    ) -> WatchCompanionCommandReceipt {
        WatchCompanionCommandReceipt(
            commandID: command.commandID,
            workoutID: command.workoutID,
            kind: command.kind,
            outcome: outcome,
            reason: reason,
            recordedAt: date,
            snapshotID: snapshotID
        )
    }
}

#endif
