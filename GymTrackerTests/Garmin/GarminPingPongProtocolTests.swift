import Foundation
import Testing
@testable import GymTracker

@Suite("Garmin ping/pong protocol")
struct GarminPingPongProtocolTests {
    @Test("Ping uses the versioned primitive Connect IQ envelope")
    func pingEnvelope() {
        let payload = GarminPingPongProtocol.ping(
            id: "ping-123",
            sentAt: Date(timeIntervalSince1970: 42)
        )

        #expect(payload.count == 6)
        #expect(payload[0] as? String == "trame")
        #expect((payload[1] as? NSNumber)?.intValue == 2)
        #expect(payload[2] as? String == "ping")
        #expect(payload[3] as? String == "ping-123")
        #expect(payload[4] as? String == "")
        let body = payload[5] as? [Any]
        #expect((body?.first as? NSNumber)?.int64Value == 42_000)
    }

    @Test("Only the current correlated pong is accepted")
    func pongCorrelation() {
        let valid = "pong|ping-123"
        let validArray = ["pong", "ping-123"]
        let validV2: [Any] = ["trame", NSNumber(value: 2), "pong", "response-1", "ping-123", []]
        let stale: [String: Any] = [
            "type": "pong",
            "protocolVersion": NSNumber(value: 1),
            "pingID": "ping-old"
        ]

        let connectIQArray: NSArray = [
            "trame" as NSString,
            NSNumber(value: 2),
            "pong" as NSString,
            "00000000-0000-4000-8000-000000000001" as NSString,
            "ping-123" as NSString,
            [] as NSArray
        ]
        let mixedCasePingID = "PING-123"

        #expect(GarminPingPongProtocol.matchingPongID(from: valid, expectedPingID: "ping-123") == "ping-123")
        #expect(GarminPingPongProtocol.matchingPongID(from: validArray, expectedPingID: "ping-123") == "ping-123")
        #expect(GarminPingPongProtocol.matchingPongID(from: validV2, expectedPingID: "ping-123") == "ping-123")
        #expect(GarminPingPongProtocol.matchingPongID(from: connectIQArray, expectedPingID: "ping-123") == "ping-123")
        #expect(GarminPingPongProtocol.matchingPongID(from: connectIQArray, expectedPingID: mixedCasePingID) == mixedCasePingID)
        #expect(GarminPingPongProtocol.matchingPongID(from: stale, expectedPingID: "ping-123") == nil)
        #expect(GarminPingPongProtocol.matchingPongID(from: ["type": "other"], expectedPingID: "ping-123") == nil)

        let envelope = GarminWorkoutProtocol.decodeEnvelope(connectIQArray)
        #expect(envelope?.type == "pong")
        #expect(envelope?.correlationID == "ping-123")
    }

    @Test("Pending pings preserve identity and back off across persistence")
    func pendingPingPersistenceAndBackoff() throws {
        let createdAt = Date(timeIntervalSince1970: 42)
        var pending = GarminPingPongProtocol.PendingPing(id: "ping-123", createdAt: createdAt)

        pending.recordAttempt(at: createdAt)
        #expect(pending.attemptCount == 1)
        #expect(pending.nextAttemptAt == createdAt.addingTimeInterval(2))
        pending.recordAttempt(at: pending.nextAttemptAt)
        #expect(pending.attemptCount == 2)
        #expect(pending.nextAttemptAt == createdAt.addingTimeInterval(6))

        let restored = try JSONDecoder().decode(
            GarminPingPongProtocol.PendingPing.self,
            from: JSONEncoder().encode(pending)
        )
        #expect(restored == pending)
        #expect(GarminPingPongProtocol.PendingPing.retryDelay(after: 99) == 60)
    }
}
