import Foundation
import SwiftData

@Model
final class MobilityRoutineItem {
    var id: UUID
    var orderIndex: Int
    var targetDurationSeconds: Int?
    var targetRepetitions: Int?
    var sideRaw: String
    var restSeconds: Int?
    var notes: String?
    var definition: MobilityDefinition
    var routine: MobilityRoutine?

    var side: MobilitySide {
        get { MobilitySide(rawValue: sideRaw) ?? .none }
        set { sideRaw = newValue.rawValue }
    }

    init(
        definition: MobilityDefinition,
        orderIndex: Int,
        targetDurationSeconds: Int? = nil,
        targetRepetitions: Int? = nil,
        side: MobilitySide = .none,
        restSeconds: Int? = nil,
        notes: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.definition = definition
        self.orderIndex = orderIndex
        self.targetDurationSeconds = targetDurationSeconds
        self.targetRepetitions = targetRepetitions
        self.sideRaw = side.rawValue
        self.restSeconds = restSeconds
        self.notes = notes
    }
}
