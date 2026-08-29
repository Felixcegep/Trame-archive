import Foundation
import Testing
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@Suite("Garmin workout protocol v2")
@MainActor
struct GarminWorkoutProtocolTests {
    private let commandID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let workoutID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!

    @Test("Command codec preserves exact workout, snapshot, set, and rest identity")
    func commandCodec() throws {
        let issuedAt = Date(
            timeIntervalSince1970: floor(Date.now.timeIntervalSince1970 * 1_000) / 1_000
        )
        let wire = GarminPingPongProtocol.envelope(
            type: "command",
            messageID: commandID.uuidString.lowercased(),
            correlationID: "",
            payload: [
                commandID.uuidString.lowercased() as NSString,
                workoutID.uuidString.lowercased() as NSString,
                WatchCompanionCommandKind.pauseRest.rawValue as NSString,
                NSNumber(value: Int64(issuedAt.timeIntervalSince1970 * 1_000)),
                NSNumber(value: 2),
                NSNumber(value: 3),
                LiveActivityRestPhase.running.rawValue as NSString,
                NSNumber(value: -1),
                "snapshot-1" as NSString
            ]
        )

        let envelope = try #require(GarminWorkoutProtocol.decodeEnvelope(wire))
        let decoded = try #require(GarminWorkoutProtocol.decodeCommand(from: envelope))

        #expect(decoded.commandID == commandID)
        #expect(decoded.workoutID == workoutID)
        #expect(decoded.kind == .pauseRest)
        #expect(decoded.issuedAt == issuedAt)
        #expect(decoded.expectedExerciseOrderIndex == 2)
        #expect(decoded.expectedSetOrderIndex == 3)
        #expect(decoded.expectedRestPhase == .running)
        #expect(decoded.restExtensionSeconds == nil)
        #expect(decoded.expectedSnapshotID == "snapshot-1")
    }

    @Test("Malformed, mismatched, and unsupported command envelopes are rejected")
    func invalidCommands() throws {
        let validPayload: [Any] = [
            commandID.uuidString.lowercased(), workoutID.uuidString.lowercased(),
            WatchCompanionCommandKind.completeCurrentSet.rawValue,
            NSNumber(value: Int64(Date.now.timeIntervalSince1970 * 1_000)),
            NSNumber(value: 0), NSNumber(value: 0), "", NSNumber(value: -1), "snapshot-1"
        ]
        let wrongMarker: [Any] = ["other", NSNumber(value: 2), "command", commandID.uuidString, "", validPayload]
        let wrongVersion: [Any] = ["trame", NSNumber(value: 99), "command", commandID.uuidString, "", validPayload]
        #expect(GarminWorkoutProtocol.decodeEnvelope(wrongMarker) == nil)
        #expect(GarminWorkoutProtocol.decodeEnvelope(wrongVersion) == nil)

        let mismatched = GarminPingPongProtocol.envelope(
            type: "command",
            messageID: UUID().uuidString.lowercased(),
            correlationID: "",
            payload: validPayload as NSArray
        )
        let envelope = try #require(GarminWorkoutProtocol.decodeEnvelope(mismatched))
        #expect(GarminWorkoutProtocol.decodeCommand(from: envelope) == nil)

        var oldTimestamp = validPayload
        oldTimestamp[3] = NSNumber(value: Int64(Date.now.addingTimeInterval(-86_401).timeIntervalSince1970 * 1_000))
        let replay = GarminPingPongProtocol.envelope(
            type: "command",
            messageID: commandID.uuidString.lowercased(),
            correlationID: "",
            payload: oldTimestamp as NSArray
        )
        let replayEnvelope = try #require(GarminWorkoutProtocol.decodeEnvelope(replay))
        #expect(GarminWorkoutProtocol.decodeCommand(from: replayEnvelope) == nil)

        var missingSnapshot = validPayload
        missingSnapshot[8] = ""
        let unsafeMutation = GarminPingPongProtocol.envelope(
            type: "command",
            messageID: commandID.uuidString.lowercased(),
            correlationID: "",
            payload: missingSnapshot as NSArray
        )
        let unsafeEnvelope = try #require(GarminWorkoutProtocol.decodeEnvelope(unsafeMutation))
        #expect(GarminWorkoutProtocol.decodeCommand(from: unsafeEnvelope) == nil)
    }

    @Test("Snapshot codec preserves explicit state and unknown values")
    func snapshotCodec() throws {
        let snapshot = makeSnapshot(restPhase: .paused, pausedRemainingTime: 45)
        let messageID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let wire = GarminWorkoutProtocol.snapshotEnvelope(
            snapshot,
            messageID: messageID,
            currentSet: .init(
                trackingType: TrackingType.weightAndReps.rawValue,
                prescribedRepetitions: 5,
                prescribedRepRangeMinimum: 4,
                prescribedRepRangeMaximum: 6,
                prescribedLoad: 100,
                prescribedLoadUnit: WeightType.kg.rawValue,
                performedRepetitions: 5,
                performedLoad: 100,
                performedLoadUnit: WeightType.kg.rawValue,
                isCompleted: false
            )
        )
        let envelope = try #require(GarminWorkoutProtocol.decodeEnvelope(wire))

        #expect(envelope.type == "snapshot")
        #expect(envelope.messageID == messageID.uuidString.lowercased())
        #expect(envelope.correlationID.isEmpty)
        #expect(envelope.payload[0] as? String == "snapshot-1")
        #expect(envelope.payload[1] as? String == workoutID.uuidString.lowercased())
        #expect((envelope.payload[7] as? NSNumber)?.intValue == 0)
        #expect((envelope.payload[8] as? NSNumber)?.intValue == 1)
        #expect(envelope.payload[10] as? String == LiveActivityRestPhase.paused.rawValue)
        #expect((envelope.payload[12] as? NSNumber)?.int64Value == 45_000)
        #expect((envelope.payload[13] as? NSNumber)?.boolValue == false)
        #expect(envelope.payload[14] as? String == TrackingType.weightAndReps.rawValue)
        #expect((envelope.payload[15] as? NSNumber)?.intValue == 5)
        #expect((envelope.payload[18] as? NSNumber)?.doubleValue == 100)
        #expect(envelope.payload[19] as? String == WeightType.kg.rawValue)
        #expect((envelope.payload[20] as? NSNumber)?.doubleValue == 5)
        #expect((envelope.payload[21] as? NSNumber)?.doubleValue == 100)
        #expect(envelope.payload[22] as? String == WeightType.kg.rawValue)
    }

    @Test("Receipts correlate duplicate, stale, and conflict outcomes")
    func receiptOutcomes() throws {
        let snapshot = makeSnapshot()
        let base = command(expectedSnapshotID: snapshot.snapshotID)
        let applied = WatchCompanionCommandReconciliation.reconcile(
            base, snapshot: snapshot, existingReceipts: [], connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 50)
        )
        let duplicate = WatchCompanionCommandReconciliation.reconcile(
            base, snapshot: snapshot, existingReceipts: [applied], connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 51)
        )
        let stale = WatchCompanionCommandReconciliation.reconcile(
            base, snapshot: makeSnapshot(isCompleted: true), existingReceipts: [], connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 52)
        )
        let conflict = WatchCompanionCommandReconciliation.reconcile(
            command(expectedSnapshotID: "older"), snapshot: snapshot, existingReceipts: [], connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 53)
        )

        #expect(duplicate.outcome == .duplicate)
        #expect(stale.outcome == .stale)
        #expect(stale.reason == .workoutAlreadyCompleted)
        #expect(conflict.outcome == .conflict)
        #expect(conflict.reason == .snapshotChanged)

        for receipt in [duplicate, stale, conflict] {
            let wire = GarminWorkoutProtocol.receiptEnvelope(
                receipt,
                messageID: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
                correlationID: commandID.uuidString.lowercased()
            )
            let envelope = try #require(GarminWorkoutProtocol.decodeEnvelope(wire))
            #expect(envelope.type == "receipt")
            #expect(envelope.correlationID == commandID.uuidString.lowercased())
            #expect(envelope.payload[0] as? String == commandID.uuidString.lowercased())
            #expect(envelope.payload[3] as? String == receipt.outcome.rawValue)
            #expect(envelope.payload[4] as? String == (receipt.reason?.rawValue ?? ""))
        }
    }

    @Test("Reconnect replay orders commands and prevents a second stale mutation")
    func reconnectReplayAndReordering() {
        let snapshot = makeSnapshot()
        let first = command(id: commandID, issuedAt: Date(timeIntervalSince1970: 10))
        let second = command(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            issuedAt: Date(timeIntervalSince1970: 11)
        )

        let offline = WatchCompanionCommandReconciliation.reconcile(
            first, snapshot: snapshot, existingReceipts: [], connection: .offline,
            recordedAt: Date(timeIntervalSince1970: 12)
        )
        #expect(offline.outcome == .queuedOffline)

        let recovered = WatchCompanionCommandReconciliation.recover(
            pending: [second, first], snapshot: snapshot, existingReceipts: [],
            connection: .reachable, recordedAt: Date(timeIntervalSince1970: 20)
        )
        #expect(recovered.map(\.commandID) == [first.commandID, second.commandID])
        #expect(recovered.map(\.outcome) == [.applied, .conflict])
        #expect(recovered.last?.reason == .currentSetChanged)
    }

    @Test("Pending transport identity and retry schedule survive relaunch encoding")
    func pendingOutboxRelaunch() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        var pending = GarminPingPongProtocol.PendingPing(
            id: commandID.uuidString.lowercased(), createdAt: createdAt
        )
        pending.recordAttempt(at: createdAt)
        pending.recordAttempt(at: pending.nextAttemptAt)

        let restored = try JSONDecoder().decode(
            GarminPingPongProtocol.PendingPing.self,
            from: JSONEncoder().encode(pending)
        )
        #expect(restored.id == pending.id)
        #expect(restored.attemptCount == 2)
        #expect(restored.nextAttemptAt == createdAt.addingTimeInterval(6))
        #expect(GarminPingPongProtocol.PendingPing.retryDelay(after: 100) == 60)
    }

    @Test("Garmin duplicate delivery mutates once and completed history rejects stale commands")
    func processorLifecycleAndHistoryBoundary() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Garmin squat", primaryMuscles: [.quadriceps])
        let activeSet = ExerciseSet(repetitions: 5, weight: 100, orderIndex: 0, usedMetric: .metric)
        let activeEntry = ExerciseEntry(exercise: exercise, sets: [activeSet], usedMetric: .metric)
        let activeWorkout = Workout(name: "Garmin active")
        activeWorkout.exercises = [activeEntry]
        context.insert(activeWorkout)
        try context.save()

        let activeSnapshot = WatchCompanionWorkoutSnapshot.build(
            projection: LiveActivityProjection(workout: activeWorkout, now: .now),
            isWorkoutCompleted: false,
            connection: .reachable,
            now: .now
        )
        let command = WatchCompanionCommandEnvelope(
            commandID: commandID,
            workoutID: activeWorkout.id,
            kind: .completeCurrentSet,
            issuedAt: .now,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0,
            expectedSnapshotID: activeSnapshot.snapshotID
        )
        let first = WatchCompanionCommandProcessor.process(
            command, existingReceipts: [], connection: .reachable, using: context
        )
        let afterFirst = LiveActivityProjection(workout: activeWorkout, now: .now)
        let duplicate = WatchCompanionCommandProcessor.process(
            command, existingReceipts: [first], connection: .reachable, using: context
        )
        let afterDuplicate = LiveActivityProjection(workout: activeWorkout, now: .now)

        #expect(first.outcome == .applied)
        #expect(duplicate.outcome == .duplicate)
        #expect(activeSet.done)
        #expect(afterDuplicate.currentSetOrderIndex == afterFirst.currentSetOrderIndex)
        #expect(afterDuplicate.restEndDate == afterFirst.restEndDate)

        let historicalSet = ExerciseSet(repetitions: 3, weight: 120, orderIndex: 0, usedMetric: .metric)
        let historicalEntry = ExerciseEntry(exercise: exercise, sets: [historicalSet], usedMetric: .metric)
        let completedWorkout = Workout(name: "Garmin history", endTime: .now)
        completedWorkout.exercises = [historicalEntry]
        context.insert(completedWorkout)
        try context.save()
        let completedSnapshot = WatchCompanionWorkoutSnapshot.build(
            projection: LiveActivityProjection(workout: completedWorkout, now: .now),
            isWorkoutCompleted: true,
            connection: .reachable,
            now: .now
        )
        let staleCommand = WatchCompanionCommandEnvelope(
            commandID: UUID(),
            workoutID: completedWorkout.id,
            kind: .completeCurrentSet,
            issuedAt: .now,
            expectedExerciseOrderIndex: completedSnapshot.currentExerciseOrderIndex,
            expectedSetOrderIndex: completedSnapshot.currentSetOrderIndex,
            expectedSnapshotID: completedSnapshot.snapshotID
        )
        let stale = WatchCompanionCommandProcessor.process(
            staleCommand, existingReceipts: [], connection: .reachable, using: context
        )

        #expect(stale.outcome == .stale)
        #expect(stale.reason == .workoutAlreadyCompleted)
        #expect(!historicalSet.done)
        #expect(completedWorkout.endTime != nil)
    }

    private func command(
        id: UUID? = nil,
        issuedAt: Date = Date(timeIntervalSince1970: 42),
        expectedSnapshotID: String? = "snapshot-1"
    ) -> WatchCompanionCommandEnvelope {
        WatchCompanionCommandEnvelope(
            commandID: id ?? commandID,
            workoutID: workoutID,
            kind: .completeCurrentSet,
            issuedAt: issuedAt,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 1,
            expectedSnapshotID: expectedSnapshotID
        )
    }

    private func makeSnapshot(
        restPhase: LiveActivityRestPhase = .inactive,
        pausedRemainingTime: TimeInterval? = nil,
        isCompleted: Bool = false
    ) -> WatchCompanionWorkoutSnapshot {
        WatchCompanionWorkoutSnapshot(
            snapshotID: "snapshot-1",
            workoutID: workoutID,
            generatedAt: Date(timeIntervalSince1970: 2),
            startTime: Date(timeIntervalSince1970: 1),
            currentExerciseName: "Squat",
            currentSet: 2,
            totalSets: 3,
            currentExerciseOrderIndex: 0,
            currentSetOrderIndex: 1,
            hasAnySets: true,
            restPhase: restPhase,
            restEndDate: nil,
            pausedRemainingTime: pausedRemainingTime,
            isWorkoutCompleted: isCompleted,
            ownership: WatchCompanionOwnershipState(connection: .reachable)
        )
    }
}

#endif
