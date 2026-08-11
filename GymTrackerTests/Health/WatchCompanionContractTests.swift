import XCTest
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@MainActor
final class WatchCompanionContractTests: XCTestCase {
    func testOwnershipKeepsPhoneAuthoritativeAndOfflineWatchMayQueueCommands() {
        let offline = WatchCompanionOwnershipState(connection: .offline)
        let reachable = WatchCompanionOwnershipState(connection: .reachable)

        XCTAssertEqual(offline.authority, .phone)
        XCTAssertTrue(offline.phoneOwnsPersistence)
        XCTAssertTrue(offline.watchMayIssueCommands)
        XCTAssertTrue(reachable.phoneOwnsPersistence)
        XCTAssertTrue(reachable.watchMayIssueCommands)
    }

    func testOfflineCommandsQueueAndDuplicateCommandIDsAreIdempotent() {
        let snapshot = makeSnapshot()
        let commandID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let command = WatchCompanionCommandEnvelope(
            commandID: commandID,
            workoutID: snapshot.workoutID,
            kind: .completeCurrentSet,
            issuedAt: Date(timeIntervalSince1970: 10),
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )
        let queued = WatchCompanionCommandReconciliation.reconcile(
            command,
            snapshot: snapshot,
            existingReceipts: [],
            connection: .offline,
            recordedAt: Date(timeIntervalSince1970: 11)
        )
        XCTAssertEqual(queued.outcome, .queuedOffline)

        let duplicate = WatchCompanionCommandReconciliation.reconcile(
            command,
            snapshot: snapshot,
            existingReceipts: [queued],
            connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 12)
        )
        XCTAssertEqual(duplicate.outcome, .duplicate)
    }

    func testRecoveryOrdersCommandsAndRejectsStaleCurrentSetAfterSnapshotChanges() {
        let snapshot = makeSnapshot()
        let first = WatchCompanionCommandEnvelope(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            workoutID: snapshot.workoutID,
            kind: .completeCurrentSet,
            issuedAt: Date(timeIntervalSince1970: 20),
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )
        let second = WatchCompanionCommandEnvelope(
            commandID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            workoutID: snapshot.workoutID,
            kind: .completeCurrentSet,
            issuedAt: Date(timeIntervalSince1970: 21),
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0
        )

        let receipts = WatchCompanionCommandReconciliation.recover(
            pending: [second, first],
            snapshot: snapshot,
            existingReceipts: [],
            connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 30)
        )

        XCTAssertEqual(receipts.map(\.commandID), [first.commandID, second.commandID])
        XCTAssertEqual(receipts.map(\.outcome), [.applied, .conflict])

        let changedSnapshot = makeSnapshot(currentSetOrderIndex: 1)
        let conflict = WatchCompanionCommandReconciliation.reconcile(
            first,
            snapshot: changedSnapshot,
            existingReceipts: [],
            connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 31)
        )
        XCTAssertEqual(conflict.outcome, .conflict)
        XCTAssertEqual(conflict.reason, .currentSetChanged)
    }

    func testRestAndCompletionSnapshotPreserveExplicitState() {
        let snapshot = makeSnapshot(
            restPhase: .paused,
            pausedRemainingTime: 45,
            isWorkoutCompleted: false
        )
        XCTAssertEqual(snapshot.restPhase, .paused)
        XCTAssertEqual(snapshot.pausedRemainingTime, 45)
        XCTAssertFalse(snapshot.isWorkoutCompleted)

        let completed = makeSnapshot(isWorkoutCompleted: true)
        let command = WatchCompanionCommandEnvelope(
            commandID: UUID(),
            workoutID: completed.workoutID,
            kind: .completeWorkout,
            issuedAt: Date(timeIntervalSince1970: 40)
        )
        let receipt = WatchCompanionCommandReconciliation.reconcile(
            command,
            snapshot: completed,
            existingReceipts: [],
            connection: .reachable,
            recordedAt: Date(timeIntervalSince1970: 41)
        )
        XCTAssertEqual(receipt.outcome, .stale)
        XCTAssertEqual(receipt.reason, .workoutAlreadyCompleted)
    }

    func testPhoneProcessorCompletesExactCurrentSetAndRejectsDuplicateDelivery() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let set = ExerciseSet(repetitions: 5, weight: 100, orderIndex: 0, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Watch workout")
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
        let command = WatchCompanionCommandEnvelope(
            commandID: UUID(), workoutID: workout.id, kind: .completeCurrentSet, issuedAt: .now,
            expectedExerciseOrderIndex: 0, expectedSetOrderIndex: 0
        )

        let first = WatchCompanionCommandProcessor.process(command, existingReceipts: [], connection: .reachable, using: context)
        let duplicate = WatchCompanionCommandProcessor.process(command, existingReceipts: [first], connection: .reachable, using: context)

        XCTAssertEqual(first.outcome, .applied)
        XCTAssertTrue(set.done)
        XCTAssertEqual(duplicate.outcome, .duplicate)
    }

    func testWorkoutCompletionAlwaysHandsOffToPhone() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Needs review")
        context.insert(workout)
        try context.save()
        let command = WatchCompanionCommandEnvelope(
            commandID: UUID(), workoutID: workout.id, kind: .completeWorkout, issuedAt: .now
        )

        let result = WatchCompanionCommandProcessor.process(command, existingReceipts: [], connection: .reachable, using: context)

        XCTAssertEqual(result.outcome, .handoffRequired)
        XCTAssertFalse(workout.isCompleted)
    }

    func testCommandFromOlderSnapshotIsRejectedBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Current")
        context.insert(workout)
        try context.save()
        let command = WatchCompanionCommandEnvelope(
            commandID: UUID(),
            workoutID: workout.id,
            kind: .requestSnapshot,
            issuedAt: .now,
            expectedSnapshotID: "older-snapshot"
        )

        let result = WatchCompanionCommandProcessor.process(
            command,
            existingReceipts: [],
            connection: .reachable,
            using: context
        )

        XCTAssertEqual(result.outcome, .conflict)
        XCTAssertEqual(result.reason, .snapshotChanged)
    }

    private func makeSnapshot(
        currentSetOrderIndex: Int? = 0,
        restPhase: LiveActivityRestPhase = .inactive,
        pausedRemainingTime: TimeInterval? = nil,
        isWorkoutCompleted: Bool = false
    ) -> WatchCompanionWorkoutSnapshot {
        WatchCompanionWorkoutSnapshot(
            snapshotID: "snapshot",
            workoutID: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
            generatedAt: Date(timeIntervalSince1970: 1),
            startTime: Date(timeIntervalSince1970: 0),
            currentExerciseName: "Squat",
            currentSet: (currentSetOrderIndex ?? 0) + 1,
            totalSets: 3,
            currentExerciseOrderIndex: 0,
            currentSetOrderIndex: currentSetOrderIndex,
            hasAnySets: true,
            restPhase: restPhase,
            restEndDate: nil,
            pausedRemainingTime: pausedRemainingTime,
            isWorkoutCompleted: isWorkoutCompleted,
            ownership: WatchCompanionOwnershipState(connection: .reachable)
        )
    }
}

#endif
