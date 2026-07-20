import Foundation
import SwiftData

enum SupplementKind: String, Codable, CaseIterable {
    case creatine

    var displayName: String {
        switch self {
        case .creatine: "Creatine"
        }
    }
}

enum SupplementOccurrenceStatus: String, Codable, CaseIterable {
    case completed
    case skipped
}

/// A lightweight daily supplement occurrence. The initial Today slice ships
/// creatine only; future supplement definitions must not reinterpret this
/// historical confirmation.
@Model
final class SupplementOccurrence {
    var id: UUID
    @Attribute(.unique) var occurrenceKey: String
    var dayKey: String
    var kindRaw: String
    var statusRaw: String
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var kind: SupplementKind {
        get { SupplementKind(rawValue: kindRaw) ?? .creatine }
        set { kindRaw = newValue.rawValue }
    }

    var status: SupplementOccurrenceStatus {
        get { SupplementOccurrenceStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        kind: SupplementKind = .creatine,
        day: LocalDay = .today,
        status: SupplementOccurrenceStatus = .completed,
        completedAt: Date? = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.occurrenceKey = "\(day.rawValue)|\(kind.rawValue)"
        self.dayKey = day.rawValue
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(status: SupplementOccurrenceStatus) {
        self.status = status
        completedAt = status == .completed ? .now : nil
        updatedAt = .now
    }
}
