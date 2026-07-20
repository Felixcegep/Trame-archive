import Foundation
import SwiftData

@Model
final class MobilitySession {
    var id: UUID
    var statusRaw: String
    var nameSnapshot: String
    var sourceRoutineID: UUID?
    var sourceRoutineName: String?
    var workoutID: UUID?
    var contextRaw: String
    var startTime: Date
    var endTime: Date?
    var currentEntryIndex: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MobilityEntry.session)
    var entries: [MobilityEntry] = []

    var status: MobilitySessionStatus {
        get { MobilitySessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var context: MobilitySessionContext {
        get { MobilitySessionContext(rawValue: contextRaw) ?? .standalone }
        set { contextRaw = newValue.rawValue }
    }

    init(
        nameSnapshot: String,
        sourceRoutineID: UUID? = nil,
        sourceRoutineName: String? = nil,
        workoutID: UUID? = nil,
        context: MobilitySessionContext = .standalone,
        id: UUID = UUID(),
        startTime: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.statusRaw = MobilitySessionStatus.active.rawValue
        self.nameSnapshot = nameSnapshot
        self.sourceRoutineID = sourceRoutineID
        self.sourceRoutineName = sourceRoutineName
        self.workoutID = workoutID
        self.contextRaw = context.rawValue
        self.startTime = startTime
        self.endTime = nil
        self.currentEntryIndex = 0
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedEntries: [MobilityEntry] {
        entries.sorted { $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex }
    }

    var currentEntry: MobilityEntry? {
        orderedEntries.first { $0.orderIndex == currentEntryIndex }
    }
}
