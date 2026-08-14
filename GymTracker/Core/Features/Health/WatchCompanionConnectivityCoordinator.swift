import Foundation
import SwiftData
@preconcurrency import WatchConnectivity

#if !GYMTRACKER_EXTENSION

/// WatchConnectivity owns this reply closure and permits it to be invoked
/// asynchronously exactly once. The framework protocol predates Sendable, so
/// this narrow wrapper documents the one unchecked boundary while all command
/// data crossing into the main actor remains typed and Sendable.
private nonisolated final class WatchReplyHandler: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ response: [String: Any]) {
        handler(response)
    }
}

/// iPhone transport adapter. WatchConnectivity carries value envelopes only;
/// every accepted mutation is delegated to WatchCompanionCommandProcessor.
@MainActor
final class WatchCompanionConnectivityCoordinator: NSObject, WCSessionDelegate {
    static let shared = WatchCompanionConnectivityCoordinator()

    private var container: ModelContainer?
    private var receipts: [WatchCompanionCommandReceipt] = []
    private var isActivated = false

    func activate(container: ModelContainer) {
        self.container = container
        if isActivated { publishSnapshot(); return }
        isActivated = true
        receipts = loadReceipts()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activeWorkoutDidMutate),
            name: .activeWorkoutMutated,
            object: nil
        )
    }

    @objc private func activeWorkoutDidMutate() {
        publishSnapshot()
    }

    func publishSnapshot(now: Date = .now) {
        guard let container, WCSession.default.activationState == .activated else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        // SwiftData cannot reliably translate predicates over this enum-backed
        // property. Keep the persisted end-time bound and filter the small
        // active candidate set after the fetch.
        guard let workout = (try? context.fetch(descriptor))?
            .first(where: { $0.status == .active }) else { return }
        let snapshot = WatchCompanionWorkoutSnapshot.build(
            projection: LiveActivityProjection(workout: workout, now: now),
            isWorkoutCompleted: false,
            connection: WCSession.default.isReachable ? .reachable : .offline,
            now: now
        )
        try? WCSession.default.updateApplicationContext(snapshotDictionary(snapshot))
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard error == nil, activationState == .activated else { return }
        Task { @MainActor in publishSnapshot() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = Self.decodeCommand(message) else {
            replyHandler(["outcome": WatchCompanionCommandOutcome.rejected.rawValue])
            return
        }
        let reply = WatchReplyHandler(replyHandler)
        Task { @MainActor in
            reply(process(command, connection: .reachable))
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let command = Self.decodeCommand(userInfo) else { return }
        Task { @MainActor in _ = process(command, connection: .reachable) }
    }

    private func process(_ command: WatchCompanionCommandEnvelope, connection: WatchCompanionConnection) -> [String: Any] {
        guard let container else {
            return ["outcome": WatchCompanionCommandOutcome.rejected.rawValue]
        }
        let receipt = WatchCompanionCommandProcessor.process(
            command,
            existingReceipts: receipts,
            connection: connection,
            using: ModelContext(container)
        )
        if receipt.outcome != .queuedOffline {
            receipts.removeAll { $0.commandID == receipt.commandID }
            receipts.append(receipt)
            receipts = Array(receipts.suffix(200))
            saveReceipts(receipts)
        }
        publishSnapshot()
        var reply: [String: Any] = [
            "commandID": receipt.commandID.uuidString,
            "outcome": receipt.outcome.rawValue
        ]
        if let reason = receipt.reason { reply["reason"] = reason.rawValue }
        if let snapshot = currentSnapshot() { reply["snapshot"] = snapshotDictionary(snapshot) }
        return reply
    }

    private func currentSnapshot(now: Date = .now) -> WatchCompanionWorkoutSnapshot? {
        guard let container else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        guard let workout = (try? context.fetch(descriptor))?
            .first(where: { $0.status == .active }) else { return nil }
        return .build(
            projection: LiveActivityProjection(workout: workout, now: now),
            isWorkoutCompleted: false,
            connection: WCSession.default.isReachable ? .reachable : .offline,
            now: now
        )
    }

    private nonisolated static func decodeCommand(_ value: [String: Any]) -> WatchCompanionCommandEnvelope? {
        guard let commandString = value["commandID"] as? String,
              let commandID = UUID(uuidString: commandString),
              let workoutString = value["workoutID"] as? String,
              let workoutID = UUID(uuidString: workoutString),
              let kindString = value["kind"] as? String,
              let kind = WatchCompanionCommandKind(rawValue: kindString),
              let timestamp = value["issuedAt"] as? TimeInterval
        else { return nil }
        return WatchCompanionCommandEnvelope(
            commandID: commandID,
            workoutID: workoutID,
            kind: kind,
            issuedAt: Date(timeIntervalSince1970: timestamp),
            expectedExerciseOrderIndex: value["expectedExerciseOrderIndex"] as? Int,
            expectedSetOrderIndex: value["expectedSetOrderIndex"] as? Int,
            expectedRestPhase: (value["expectedRestPhase"] as? String).flatMap(LiveActivityRestPhase.init(rawValue:)),
            restExtensionSeconds: value["restExtensionSeconds"] as? Int,
            expectedSnapshotID: value["snapshotID"] as? String
        )
    }

    private func snapshotDictionary(_ snapshot: WatchCompanionWorkoutSnapshot) -> [String: Any] {
        var value: [String: Any] = [
            "snapshotID": snapshot.snapshotID,
            "workoutID": snapshot.workoutID.uuidString,
            "generatedAt": snapshot.generatedAt.timeIntervalSince1970,
            "startTime": snapshot.startTime.timeIntervalSince1970,
            "hasAnySets": snapshot.hasAnySets,
            "restPhase": snapshot.restPhase.rawValue,
            "isWorkoutCompleted": snapshot.isWorkoutCompleted
        ]
        if let field = snapshot.currentExerciseName { value["currentExerciseName"] = field }
        if let field = snapshot.currentSet { value["currentSet"] = field }
        if let field = snapshot.totalSets { value["totalSets"] = field }
        if let field = snapshot.currentExerciseOrderIndex { value["currentExerciseOrderIndex"] = field }
        if let field = snapshot.currentSetOrderIndex { value["currentSetOrderIndex"] = field }
        if let field = snapshot.restEndDate { value["restEndDate"] = field.timeIntervalSince1970 }
        if let field = snapshot.pausedRemainingTime { value["pausedRemainingTime"] = field }
        return value
    }

    private var receiptURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)?
            .appendingPathComponent("watch-command-receipts.json")
    }

    private func loadReceipts() -> [WatchCompanionCommandReceipt] {
        guard let receiptURL, let data = try? Data(contentsOf: receiptURL) else { return [] }
        return (try? JSONDecoder().decode([WatchCompanionCommandReceipt].self, from: data)) ?? []
    }

    private func saveReceipts(_ receipts: [WatchCompanionCommandReceipt]) {
        guard let receiptURL, let data = try? JSONEncoder().encode(receipts) else { return }
        try? data.write(to: receiptURL, options: .atomic)
    }
}

#endif
