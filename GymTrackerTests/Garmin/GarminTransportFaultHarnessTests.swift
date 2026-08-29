import Foundation
import Testing
@testable import GymTracker

#if !GYMTRACKER_EXTENSION

@Suite("Garmin transport fault harness")
struct GarminTransportFaultHarnessTests {
    @Test("Loss, duplication, reordering, reconnect, and relaunch preserve one logical mutation")
    func combinedTransportFaults() throws {
        let workoutID = UUID(uuidString: "00000000-0000-0000-0000-000000000500")!
        let first = Self.command(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            workoutID: workoutID,
            issuedAt: Date(timeIntervalSince1970: 10)
        )
        let second = Self.command(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
            workoutID: workoutID,
            issuedAt: Date(timeIntervalSince1970: 11)
        )
        var harness = FaultHarness(
            connection: .offline,
            snapshot: Self.snapshot(workoutID: workoutID, currentSetIndex: 0),
            senderOutbox: [second, first]
        )

        // Disconnection retains intent; it never implies application.
        #expect(harness.deliverNext() == nil)
        #expect(harness.senderOutbox.count == 2)
        #expect(harness.appliedMutationCount == 0)

        // A process relaunch round-trips the durable outbox. Reconnect then
        // orders messages by issue time even though they arrived reversed.
        harness.senderOutbox = try JSONDecoder().decode(
            [WatchCompanionCommandEnvelope].self,
            from: JSONEncoder().encode(harness.senderOutbox)
        )
        harness.connection = .reachable
        let firstDelivery = harness.deliverNext(dropReceipt: true)
        let appliedButReceiptLost = try #require(firstDelivery)
        #expect(appliedButReceiptLost.outcome == .applied)
        #expect(appliedButReceiptLost.commandID == first.commandID)
        #expect(harness.appliedMutationCount == 1)
        #expect(harness.senderOutbox.contains { $0.commandID == first.commandID })

        // Retrying after the lost receipt duplicates delivery, not mutation.
        let duplicateDelivery = harness.deliver(commandID: first.commandID)
        let duplicate = try #require(duplicateDelivery)
        #expect(duplicate.outcome == .duplicate)
        #expect(harness.appliedMutationCount == 1)
        harness.acknowledge(duplicate)

        // The later command targeted the old current set. After the first
        // mutation advances the snapshot, replay rejects it as a conflict.
        let reorderedDelivery = harness.deliverNext()
        let conflict = try #require(reorderedDelivery)
        #expect(conflict.commandID == second.commandID)
        #expect(conflict.outcome == .conflict)
        #expect(conflict.reason == .snapshotChanged)
        #expect(harness.appliedMutationCount == 1)
        harness.acknowledge(conflict)

        // A duplicate conflict receipt/delivery remains harmless and the
        // sender outbox is empty only after correlated acknowledgement.
        harness.senderOutbox.append(second)
        let repeatedConflictDelivery = harness.deliverNext()
        let duplicateConflict = try #require(repeatedConflictDelivery)
        #expect(duplicateConflict.outcome == .duplicate)
        #expect(harness.appliedMutationCount == 1)
        harness.acknowledge(duplicateConflict)
        #expect(harness.senderOutbox.isEmpty)
    }

    private struct FaultHarness {
        var connection: WatchCompanionConnection
        var snapshot: WatchCompanionWorkoutSnapshot
        var senderOutbox: [WatchCompanionCommandEnvelope]
        var receiverReceipts: [WatchCompanionCommandReceipt] = []
        var appliedMutationCount = 0

        mutating func deliverNext(dropReceipt: Bool = false) -> WatchCompanionCommandReceipt? {
            guard connection == .reachable else { return nil }
            guard let command = senderOutbox.min(by: { $0.issuedAt < $1.issuedAt }) else { return nil }
            return deliver(commandID: command.commandID, dropReceipt: dropReceipt)
        }

        mutating func deliver(
            commandID: UUID,
            dropReceipt: Bool = false
        ) -> WatchCompanionCommandReceipt? {
            guard connection == .reachable,
                  let command = senderOutbox.first(where: { $0.commandID == commandID })
            else { return nil }
            let receipt = WatchCompanionCommandReconciliation.reconcile(
                command,
                snapshot: snapshot,
                existingReceipts: receiverReceipts,
                connection: connection,
                recordedAt: command.issuedAt.addingTimeInterval(1)
            )
            if receipt.outcome == .applied {
                appliedMutationCount += 1
                snapshot = GarminTransportFaultHarnessTests.snapshot(
                    workoutID: snapshot.workoutID,
                    currentSetIndex: (snapshot.currentSetOrderIndex ?? 0) + 1
                )
            }
            if receipt.outcome != .queuedOffline {
                receiverReceipts.removeAll { $0.commandID == receipt.commandID }
                receiverReceipts.append(receipt)
            }
            if !dropReceipt { acknowledge(receipt) }
            return receipt
        }

        mutating func acknowledge(_ receipt: WatchCompanionCommandReceipt) {
            senderOutbox.removeAll { $0.commandID == receipt.commandID }
        }
    }

    private static func command(
        id: UUID,
        workoutID: UUID,
        issuedAt: Date
    ) -> WatchCompanionCommandEnvelope {
        WatchCompanionCommandEnvelope(
            commandID: id,
            workoutID: workoutID,
            kind: .completeCurrentSet,
            issuedAt: issuedAt,
            expectedExerciseOrderIndex: 0,
            expectedSetOrderIndex: 0,
            expectedSnapshotID: "snapshot-0"
        )
    }

    private static func snapshot(
        workoutID: UUID,
        currentSetIndex: Int
    ) -> WatchCompanionWorkoutSnapshot {
        WatchCompanionWorkoutSnapshot(
            snapshotID: "snapshot-\(currentSetIndex)",
            workoutID: workoutID,
            generatedAt: Date(timeIntervalSince1970: 1),
            startTime: Date(timeIntervalSince1970: 0),
            currentExerciseName: "Squat",
            currentSet: currentSetIndex + 1,
            totalSets: 3,
            currentExerciseOrderIndex: 0,
            currentSetOrderIndex: currentSetIndex,
            hasAnySets: true,
            restPhase: .inactive,
            restEndDate: nil,
            pausedRemainingTime: nil,
            isWorkoutCompleted: false,
            ownership: WatchCompanionOwnershipState(connection: .reachable)
        )
    }
}

#endif
