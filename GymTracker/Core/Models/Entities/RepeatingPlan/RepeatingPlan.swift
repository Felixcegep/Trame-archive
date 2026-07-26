import Foundation
import SwiftData

@Model
final class RepeatingPlan {
    var id = UUID()
    var name: String
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var requiredEquipment: [EquipmentType]
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var isBuiltIn: Bool
    @Relationship(deleteRule: .cascade, inverse: \RepeatingPlanSlot.plan)
    var slots: [RepeatingPlanSlot] = []
    @Relationship(deleteRule: .nullify, inverse: \RepeatingPlanRun.plan)
    var runs: [RepeatingPlanRun] = []

    init(
        name: String,
        goal: PlanGoal = .generalStrength,
        experienceLevel: PlanExperienceLevel = .beginner,
        requiredEquipment: [EquipmentType] = [],
        notes: String? = nil,
        isArchived: Bool = false,
        isBuiltIn: Bool = false,
        slots: [RepeatingPlanSlot] = []
    ) {
        self.name = name
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.requiredEquipment = Array(Set(requiredEquipment)).sorted { $0.rawValue < $1.rawValue }
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
        self.isArchived = isArchived
        self.isBuiltIn = isBuiltIn
        self.slots = slots
    }

    var orderedSlots: [RepeatingPlanSlot] {
        slots.sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var validationIssues: [RepeatingPlanValidationIssue] {
        var issues: [RepeatingPlanValidationIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyName)
        }
        if slots.isEmpty {
            issues.append(.noSlots)
        }
        let duplicateOrders = Dictionary(grouping: slots, by: \.orderIndex)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        issues.append(contentsOf: duplicateOrders.map(RepeatingPlanValidationIssue.duplicateSlotOrder))
        issues.append(contentsOf: orderedSlots.compactMap { slot in
            slot.workoutTemplate == nil ? .unavailableTemplate(slot.id) : nil
        })
        return issues
    }

    func normalizeSlotOrder() {
        for (index, slot) in orderedSlots.enumerated() {
            slot.orderIndex = index
        }
        updatedAt = .now
    }
}
