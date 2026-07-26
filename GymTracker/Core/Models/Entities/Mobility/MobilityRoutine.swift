import Foundation
import SwiftData

@Model
final class MobilityRoutine {
    var id: UUID
    @Attribute(.unique) var name: String
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MobilityRoutineItem.routine)
    var items: [MobilityRoutineItem] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutTemplate.preWorkoutMobilityRoutine)
    var preWorkoutTemplates: [WorkoutTemplate] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutTemplate.postWorkoutMobilityRoutine)
    var postWorkoutTemplates: [WorkoutTemplate] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanSlot.preWorkoutMobilityRoutine)
    var preWorkoutRepeatingPlanSlots: [RepeatingPlanSlot] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanSlot.postWorkoutMobilityRoutine)
    var postWorkoutRepeatingPlanSlots: [RepeatingPlanSlot] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanRunSlot.preWorkoutMobilityRoutine)
    var preWorkoutRepeatingPlanRunSlots: [RepeatingPlanRunSlot] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanRunSlot.postWorkoutMobilityRoutine)
    var postWorkoutRepeatingPlanRunSlots: [RepeatingPlanRunSlot] = []

    init(
        name: String,
        notes: String? = nil,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedItems: [MobilityRoutineItem] {
        items.sorted { $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex }
    }

    func normalizeItemOrder() {
        for (index, item) in orderedItems.enumerated() { item.orderIndex = index }
        updatedAt = .now
    }
}
