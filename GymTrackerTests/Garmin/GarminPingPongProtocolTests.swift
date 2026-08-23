import Foundation
import Testing
@testable import GymTracker

@Suite("Garmin ping/pong protocol")
struct GarminPingPongProtocolTests {
    @Test("Ping uses only Connect IQ-compatible primitive containers")
    func pingEnvelope() {
        let payload = GarminPingPongProtocol.ping(
            id: "ping-123",
            sentAt: Date(timeIntervalSince1970: 42)
        )

        #expect(payload["type"] as? String == "ping")
        #expect((payload["protocolVersion"] as? NSNumber)?.intValue == 1)
        #expect(payload["pingID"] as? String == "ping-123")
        #expect((payload["sentAtMilliseconds"] as? NSNumber)?.int64Value == 42_000)
    }

    @Test("Only the current correlated pong is accepted")
    func pongCorrelation() {
        let valid: [String: Any] = [
            "type": "pong",
            "protocolVersion": NSNumber(value: 1),
            "pingID": "ping-123"
        ]
        let stale: [String: Any] = [
            "type": "pong",
            "protocolVersion": NSNumber(value: 1),
            "pingID": "ping-old"
        ]

        #expect(GarminPingPongProtocol.matchingPongID(from: valid, expectedPingID: "ping-123") == "ping-123")
        #expect(GarminPingPongProtocol.matchingPongID(from: stale, expectedPingID: "ping-123") == nil)
        #expect(GarminPingPongProtocol.matchingPongID(from: ["type": "other"], expectedPingID: "ping-123") == nil)
    }
}
