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
    var scheduleMode: PlanScheduleMode
    var scheduleIntervalDays: Int
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var sourceProgramDefinitionID: UUID?
    var sourceProgramDefinitionVersion: Int?
    /// Codable storage keeps associated-value completion policies compatible
    /// with the shared model used by the extension target.
    var completionPolicyData: Data?
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
        scheduleMode: PlanScheduleMode = .fixedWeekdays,
        scheduleIntervalDays: Int = 1,
        notes: String? = nil,
        blocks: [PlanBlock] = [],
        sourceProgramDefinitionID: UUID? = nil,
        sourceProgramDefinitionVersion: Int? = nil
    ) {
        self.name = name
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.requiredEquipment = requiredEquipment
        self.daysPerWeek = daysPerWeek
        self.durationWeeks = durationWeeks
        self.scheduleMode = scheduleMode
        self.scheduleIntervalDays = max(1, scheduleIntervalDays)
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
        self.isArchived = false
        self.sourceProgramDefinitionID = sourceProgramDefinitionID
        self.sourceProgramDefinitionVersion = sourceProgramDefinitionVersion
        self.completionPolicyData = nil
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
