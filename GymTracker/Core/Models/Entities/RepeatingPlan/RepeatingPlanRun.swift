import Foundation
import SwiftData

@Model
final class RepeatingPlanRun {
    var id = UUID()
    var sourcePlanID: UUID
    var sourcePlanName: String
    var status: RepeatingPlanRunStatus
    var currentSlotIndex: Int
    var completedCycleCount: Int
    var startedAt: Date
    var endedAt: Date?
    var updatedAt: Date
    var plan: RepeatingPlan?
    @Relationship(deleteRule: .cascade, inverse: \RepeatingPlanRunSlot.run)
    var slots: [RepeatingPlanRunSlot] = []
    @Relationship(deleteRule: .cascade, inverse: \RepeatingPlanOccurrence.run)
    var occurrences: [RepeatingPlanOccurrence] = []

    convenience init(plan: RepeatingPlan, startedAt: Date = .now) {
        self.init(
            sourcePlanID: plan.id,
            sourcePlanName: plan.name,
            startedAt: startedAt,
            plan: plan,
            slots: plan.orderedSlots.map(RepeatingPlanRunSlot.init(slot:))
        )
    }

    init(
        sourcePlanID: UUID,
        sourcePlanName: String,
        status: RepeatingPlanRunStatus = .active,
        currentSlotIndex: Int = 0,
        completedCycleCount: Int = 0,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        updatedAt: Date? = nil,
        plan: RepeatingPlan? = nil,
        slots: [RepeatingPlanRunSlot] = [],
        occurrences: [RepeatingPlanOccurrence] = []
    ) {
        self.sourcePlanID = sourcePlanID
        self.sourcePlanName = sourcePlanName
        self.status = status
        self.currentSlotIndex = currentSlotIndex
        self.completedCycleCount = completedCycleCount
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.updatedAt = updatedAt ?? startedAt
        self.plan = plan
        self.slots = slots
        self.occurrences = occurrences
    }

    var orderedSlots: [RepeatingPlanRunSlot] {
        slots.sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var orderedOccurrences: [RepeatingPlanOccurrence] {
        occurrences.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var validationIssues: [RepeatingPlanValidationIssue] {
        var issues: [RepeatingPlanValidationIssue] = []
        if slots.isEmpty {
            issues.append(.noSlots)
        } else if !slots.indices.contains(currentSlotIndex) {
            issues.append(.invalidCursor)
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
}
