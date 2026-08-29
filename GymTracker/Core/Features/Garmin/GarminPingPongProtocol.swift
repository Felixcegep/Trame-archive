import Foundation

nonisolated enum GarminPingPongProtocol {
    static let version = 2
    private static let marker = "trame"
    private static let pongPrefix = "pong|"

    struct PendingPing: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let createdAt: Date
        var attemptCount: Int
        var nextAttemptAt: Date

        init(id: String = UUID().uuidString.lowercased(), createdAt: Date = .now) {
            self.id = id
            self.createdAt = createdAt
            attemptCount = 0
            nextAttemptAt = createdAt
        }

        mutating func recordAttempt(at date: Date) {
            attemptCount += 1
            nextAttemptAt = date.addingTimeInterval(Self.retryDelay(after: attemptCount))
        }

        static func retryDelay(after attemptCount: Int) -> TimeInterval {
            // A short first retry keeps the diagnostic responsive; the cap
            // prevents an unreachable watch from creating a hot loop.
            min(pow(2, Double(max(0, attemptCount - 1))) * 2, 60)
        }
    }

    /// Compact, primitive-only envelope safe for the Connect IQ mailbox.
    /// The message ID remains stable across retries; correlation identifies
    /// the command being acknowledged or answered.
    static func ping(id: String, sentAt: Date) -> NSArray {
        envelope(
            type: "ping",
            messageID: id,
            correlationID: "",
            payload: [NSNumber(value: Int64(sentAt.timeIntervalSince1970 * 1_000))]
        )
    }

    static func envelope(
        type: String,
        messageID: String,
        correlationID: String,
        payload: NSArray
    ) -> NSArray {
        [
            marker as NSString,
            NSNumber(value: version),
            type as NSString,
            messageID as NSString,
            correlationID as NSString,
            payload
        ]
    }

    /// Connect IQ delivers `NSArray` with mixed primitives. `as? [Any]` can
    /// fail for that shape even when the mailbox payload is valid.
    static func connectIQArray(from message: Any) -> [Any]? {
        if let array = message as? NSArray {
            return array.map { $0 }
        }
        return message as? [Any]
    }

    static func connectIQString(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let string = value as? NSString { return string as String }
        return nil
    }

    static func connectIQInt(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    static func matchingPongID(from message: Any, expectedPingID: String?) -> String? {
        guard let expectedPingID else { return nil }

        if let values = connectIQArray(from: message),
           values.count >= 5,
           connectIQString(values[0]) == marker,
           connectIQInt(values[1]) == version,
           connectIQString(values[2]) == "pong",
           connectIQString(values[4])?.caseInsensitiveCompare(expectedPingID) == .orderedSame {
            return expectedPingID
        }

        // Version 1 compatibility during staged watch-app rollout.
        if let values = connectIQArray(from: message),
           values.count >= 2,
           connectIQString(values[0]) == "pong",
           connectIQString(values[1])?.caseInsensitiveCompare(expectedPingID) == .orderedSame {
            return expectedPingID
        }

        if let envelope = message as? String,
           envelope.hasPrefix(pongPrefix) {
            let pingID = String(envelope.dropFirst(pongPrefix.count))
            return pingID == expectedPingID ? pingID : nil
        }

        // Accept the original dictionary form for compatibility with older
        // watch builds that may still have a queued response.
        guard
            let payload = message as? [String: Any],
            payload["type"] as? String == "pong",
            (payload["protocolVersion"] as? NSNumber)?.intValue == 1,
            payload["pingID"] as? String == expectedPingID
        else { return nil }
        return expectedPingID
    }
}
