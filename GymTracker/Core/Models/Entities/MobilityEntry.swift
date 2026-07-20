import Foundation
import SwiftData

@Model
final class MobilityEntry {
    var id: UUID
    var orderIndex: Int
    var definitionIDSnapshot: UUID
    var definitionNameSnapshot: String
    var instructionsSnapshot: String?
    var trackingTypeRaw: String
    var targetDurationSeconds: Int?
    var targetRepetitions: Int?
    var sideRaw: String
    var restSeconds: Int?
    var notesSnapshot: String?
    var timerStartedAt: Date?
    var session: MobilitySession?
    @Relationship(deleteRule: .cascade, inverse: \MobilityResult.entry)
    var results: [MobilityResult] = []

    var trackingType: MobilityTrackingType {
        get { MobilityTrackingType(rawValue: trackingTypeRaw) ?? .duration }
        set { trackingTypeRaw = newValue.rawValue }
    }

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    init(
        routineItem: MobilityRoutineItem,
        orderIndex: Int,
        id: UUID = UUID()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.definitionIDSnapshot = routineItem.definition.id
        self.definitionNameSnapshot = routineItem.definition.name
        self.instructionsSnapshot = routineItem.definition.instructions
        self.trackingTypeRaw = routineItem.definition.trackingType.rawValue
        self.targetDurationSeconds = routineItem.targetDurationSeconds ?? routineItem.definition.defaultDurationSeconds
        self.targetRepetitions = routineItem.targetRepetitions ?? routineItem.definition.defaultRepetitions
        self.sideRaw = routineItem.side.rawValue
        self.restSeconds = routineItem.restSeconds
        self.notesSnapshot = routineItem.notes
        self.timerStartedAt = nil
    }

    init(
        definitionIDSnapshot: UUID,
        definitionNameSnapshot: String,
        instructionsSnapshot: String?,
        trackingType: MobilityTrackingType,
        targetDurationSeconds: Int?,
        targetRepetitions: Int?,
        side: MobilitySide,
        restSeconds: Int?,
        notesSnapshot: String?,
        timerStartedAt: Date?,
        orderIndex: Int,
        id: UUID
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.definitionIDSnapshot = definitionIDSnapshot
        self.definitionNameSnapshot = definitionNameSnapshot
        self.instructionsSnapshot = instructionsSnapshot
        self.trackingTypeRaw = trackingType.rawValue
        self.targetDurationSeconds = targetDurationSeconds
        self.targetRepetitions = targetRepetitions
        self.sideRaw = side.rawValue
        self.restSeconds = restSeconds
        self.notesSnapshot = notesSnapshot
        self.timerStartedAt = timerStartedAt
    }

    var orderedResults: [MobilityResult] {
        results.sorted { $0.sideRaw < $1.sideRaw }
    }
}
