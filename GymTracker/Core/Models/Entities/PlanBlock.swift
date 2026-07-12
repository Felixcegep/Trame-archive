import Foundation
import SwiftData

@Model
final class PlanBlock {
    var id = UUID()
    var name: String
    var phaseType: PlanPhaseType
    var goal: String?
    var notes: String?
    var orderIndex: Int
    var plan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlanWeek.block)
    var weeks: [PlanWeek] = []

    init(
        name: String,
        phaseType: PlanPhaseType,
        orderIndex: Int,
        goal: String? = nil,
        notes: String? = nil,
        weeks: [PlanWeek] = []
    ) {
        self.name = name
        self.phaseType = phaseType
        self.orderIndex = orderIndex
        self.goal = goal
        self.notes = notes
        self.weeks = weeks
    }

    var orderedWeeks: [PlanWeek] {
        weeks.sorted { $0.weekIndex < $1.weekIndex }
    }
}
