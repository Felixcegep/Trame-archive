import Foundation

nonisolated enum GarminPingPongProtocol {
    static let version = 1

    static func ping(id: String, sentAt: Date) -> [String: Any] {
        [
            "type": "ping",
            "protocolVersion": NSNumber(value: version),
            "pingID": id,
            "sentAtMilliseconds": NSNumber(value: Int64(sentAt.timeIntervalSince1970 * 1_000))
        ]
    }

    static func matchingPongID(from message: Any, expectedPingID: String?) -> String? {
        guard
            let expectedPingID,
            let payload = message as? [String: Any],
            payload["type"] as? String == "pong",
            (payload["protocolVersion"] as? NSNumber)?.intValue == version,
            payload["pingID"] as? String == expectedPingID
        else { return nil }
        return expectedPingID
    }
}
