import Foundation
import Observation
@preconcurrency import WatchConnectivity

nonisolated enum WatchRestPhase: String, Codable, Sendable {
    case inactive
    case running
    case paused
    case ready
}

nonisolated struct WatchWorkoutDisplaySnapshot: Equatable, Sendable {
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

/// Typed value crossing the WatchConnectivity callback boundary. Foundation's
/// `[String: Any]` transport dictionaries are not `Sendable`; decode them on
/// the callback executor before handing only immutable values to MainActor.
private nonisolated struct WatchCommandResponse: Sendable {
    let outcome: String?
    let snapshot: WatchWorkoutDisplaySnapshot?
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
                let response = Self.decode(reply)
                Task { @MainActor in self?.consume(response) }
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
        let response = Self.decode(session.receivedApplicationContext)
        let didActivate = error == nil
        Task { @MainActor in
            connectionDescription = didActivate
                ? String(localized: "Connected to iPhone")
                : String(localized: "Waiting for iPhone")
            consume(response)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let response = Self.decode(applicationContext)
        Task { @MainActor in consume(response) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let response = Self.decode(message)
        Task { @MainActor in consume(response) }
    }

    private func consume(_ response: WatchCommandResponse) {
        if let outcome = response.outcome {
            lastCommandStatus = outcome == "applied"
                ? String(localized: "Saved on iPhone")
                : String(localized: "Open iPhone to review the latest workout state")
        }
        if let snapshot = response.snapshot {
            self.snapshot = snapshot
        }
    }

    private nonisolated static func decode(_ payload: [String: Any]) -> WatchCommandResponse {
        let snapshotPayload = payload["snapshot"] as? [String: Any]
            ?? (payload["workoutID"] == nil ? nil : payload)
        guard let snapshotPayload,
              let snapshotID = snapshotPayload["snapshotID"] as? String,
              let workoutString = snapshotPayload["workoutID"] as? String,
              let workoutID = UUID(uuidString: workoutString),
              let start = snapshotPayload["startTime"] as? TimeInterval,
              let generated = snapshotPayload["generatedAt"] as? TimeInterval
        else {
            return WatchCommandResponse(
                outcome: payload["outcome"] as? String,
                snapshot: nil
            )
        }
        return WatchCommandResponse(
            outcome: payload["outcome"] as? String,
            snapshot: WatchWorkoutDisplaySnapshot(
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
        )
    }
}
