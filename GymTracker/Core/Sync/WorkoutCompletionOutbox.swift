import Foundation
import SwiftData

public enum OutboxStatus: String, Codable, Sendable {
    case pending
    case processing
    case delivered
    case failed
}

/// Local outbox record that safely bridges completed workout materialization
/// from local device state to the cloud user-data store idempotently.
@Model
final class WorkoutCompletionOutbox {
    var id: UUID
    var mutationID: UUID
    var workoutID: UUID
    var payloadData: Data
    var createdAt: Date
    var attemptCount: Int
    var lastAttemptAt: Date?
    var lastErrorCode: String?
    var statusRaw: String

    var status: OutboxStatus {
        get { OutboxStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        mutationID: UUID = UUID(),
        workoutID: UUID,
        payloadData: Data,
        createdAt: Date = .now,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        status: OutboxStatus = .pending
    ) {
        self.id = id
        self.mutationID = mutationID
        self.workoutID = workoutID
        self.payloadData = payloadData
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.lastErrorCode = lastErrorCode
        self.statusRaw = status.rawValue
    }
}
