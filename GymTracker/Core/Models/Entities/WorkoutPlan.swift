import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var id = UUID()
    var name: String
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var requiredEquipment: [EquipmentType]
    var daysPerWeek: Int
    var durationWeeks: Int
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    @Relationship(deleteRule: .cascade, inverse: \PlanBlock.plan)
    var blocks: [PlanBlock] = []
    @Relationship(deleteRule: .nullify, inverse: \PlanRun.plan)
    var runs: [PlanRun] = []

    init(
        name: String,
        goal: PlanGoal = .generalStrength,
        experienceLevel: PlanExperienceLevel = .beginner,
        requiredEquipment: [EquipmentType] = [],
        daysPerWeek: Int,
        durationWeeks: Int,
        notes: String? = nil,
        blocks: [PlanBlock] = []
    ) {
        self.name = name
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.requiredEquipment = requiredEquipment
        self.daysPerWeek = daysPerWeek
        self.durationWeeks = durationWeeks
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
        self.isArchived = false
        self.blocks = blocks
    }

    var orderedBlocks: [PlanBlock] {
        blocks.sorted { $0.orderIndex < $1.orderIndex }
    }

    var orderedWeeks: [PlanWeek] {
        orderedBlocks
            .flatMap(\.orderedWeeks)
            .sorted { $0.weekIndex < $1.weekIndex }
    }
}
