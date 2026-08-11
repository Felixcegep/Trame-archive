import Foundation
import Observation
import WatchConnectivity

enum WatchRestPhase: String, Codable {
    case inactive
    case running
    case paused
    case ready
}

struct WatchWorkoutDisplaySnapshot: Equatable {
    let snapshotID: String
    let workoutID: UUID
    let generatedAt: Date
    let startTime: Date
    let currentExerciseName: String?
    let currentSet: Int?
    let totalSets: Int?
    let currentExerciseOrderIndex: Int?
    let currentSetOrderIndex: Int?
    let restPhase: WatchRestPhase
    let restEndDate: Date?
    let pausedRemainingTime: TimeInterval?
}

@MainActor
@Observable
final class WatchWorkoutConnectivity: NSObject, WCSessionDelegate {
    private(set) var snapshot: WatchWorkoutDisplaySnapshot?
    private(set) var connectionDescription = String(localized: "Waiting for iPhone")
    private(set) var lastCommandStatus: String?

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            connectionDescription = String(localized: "Watch connectivity unavailable")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ kind: String, extensionSeconds: Int? = nil) {
        guard let snapshot else {
            lastCommandStatus = String(localized: "Open Trame on iPhone to start a workout.")
            return
        }
        var envelope: [String: Any] = [
            "commandID": UUID().uuidString,
            "workoutID": snapshot.workoutID.uuidString,
            "kind": kind,
            "issuedAt": Date.now.timeIntervalSince1970,
            "snapshotID": snapshot.snapshotID,
            "expectedRestPhase": snapshot.restPhase.rawValue
        ]
        if let index = snapshot.currentExerciseOrderIndex { envelope["expectedExerciseOrderIndex"] = index }
        if let index = snapshot.currentSetOrderIndex { envelope["expectedSetOrderIndex"] = index }
        if let extensionSeconds { envelope["restExtensionSeconds"] = extensionSeconds }

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(envelope, replyHandler: { [weak self] reply in
                Task { @MainActor in self?.consume(reply) }
            }, errorHandler: { [weak self] _ in
                session.transferUserInfo(envelope)
                Task { @MainActor in self?.lastCommandStatus = String(localized: "Queued until iPhone reconnects") }
            })
        } else {
            session.transferUserInfo(envelope)
            lastCommandStatus = String(localized: "Queued until iPhone reconnects")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            connectionDescription = error == nil
                ? String(localized: "Connected to iPhone")
                : String(localized: "Waiting for iPhone")
            consume(session.receivedApplicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in consume(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in consume(message) }
    }

    private func consume(_ payload: [String: Any]) {
        if let outcome = payload["outcome"] as? String {
            lastCommandStatus = outcome == "applied"
                ? String(localized: "Saved on iPhone")
                : String(localized: "Open iPhone to review the latest workout state")
        }
        guard let snapshotPayload = payload["snapshot"] as? [String: Any] ?? (payload["workoutID"] == nil ? nil : payload),
              let snapshotID = snapshotPayload["snapshotID"] as? String,
              let workoutString = snapshotPayload["workoutID"] as? String,
              let workoutID = UUID(uuidString: workoutString),
              let start = snapshotPayload["startTime"] as? TimeInterval,
              let generated = snapshotPayload["generatedAt"] as? TimeInterval
        else { return }
        snapshot = WatchWorkoutDisplaySnapshot(
            snapshotID: snapshotID,
            workoutID: workoutID,
            generatedAt: Date(timeIntervalSince1970: generated),
            startTime: Date(timeIntervalSince1970: start),
            currentExerciseName: snapshotPayload["currentExerciseName"] as? String,
            currentSet: snapshotPayload["currentSet"] as? Int,
            totalSets: snapshotPayload["totalSets"] as? Int,
            currentExerciseOrderIndex: snapshotPayload["currentExerciseOrderIndex"] as? Int,
            currentSetOrderIndex: snapshotPayload["currentSetOrderIndex"] as? Int,
            restPhase: (snapshotPayload["restPhase"] as? String).flatMap(WatchRestPhase.init(rawValue:)) ?? .inactive,
            restEndDate: (snapshotPayload["restEndDate"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
            pausedRemainingTime: snapshotPayload["pausedRemainingTime"] as? TimeInterval
        )
    }
}
