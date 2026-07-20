import Foundation
import SwiftData

@Model
final class MobilityDefinition {
    var id: UUID
    @Attribute(.unique) var name: String
    var instructions: String?
    var trackingTypeRaw: String
    var defaultDurationSeconds: Int?
    var defaultRepetitions: Int?
    var isFavorite: Bool
    var isCustom: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var family: MobilityFamily?
    @Relationship(deleteRule: .nullify, inverse: \MobilityRoutineItem.definition)
    var routineItems: [MobilityRoutineItem] = []

    var trackingType: MobilityTrackingType {
        get { MobilityTrackingType(rawValue: trackingTypeRaw) ?? .duration }
        set { trackingTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        instructions: String? = nil,
        trackingType: MobilityTrackingType = .duration,
        defaultDurationSeconds: Int? = 30,
        defaultRepetitions: Int? = nil,
        isFavorite: Bool = false,
        isCustom: Bool = true,
        isArchived: Bool = false,
        family: MobilityFamily? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.trackingTypeRaw = trackingType.rawValue
        self.defaultDurationSeconds = defaultDurationSeconds
        self.defaultRepetitions = defaultRepetitions
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.family = family
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
