import Foundation
import SwiftData

@Model
final class MobilityRoutine {
    var id: UUID
    var name: String
    var catalogueKey: String? = nil
    var notes: String?
    /// Optional by design: legacy and custom routines may genuinely be unclassified.
    var purposeRaw: String?
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
        purpose: MobilityRoutinePurpose? = nil,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.purposeRaw = purpose?.rawValue
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Reads an unknown future value as unclassified without destroying its raw storage.
    var purpose: MobilityRoutinePurpose? {
        get { purposeRaw.flatMap(MobilityRoutinePurpose.init(rawValue:)) }
        set { purposeRaw = newValue?.rawValue }
    }

    var orderedItems: [MobilityRoutineItem] {
        items.sorted { $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex }
    }

    func normalizeItemOrder() {
        for (index, item) in orderedItems.enumerated() { item.orderIndex = index }
        updatedAt = .now
    }
}
