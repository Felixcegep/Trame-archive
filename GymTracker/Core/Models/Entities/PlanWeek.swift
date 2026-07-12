import Foundation
import SwiftData

@Model
final class PlanWeek {
    var id = UUID()
    var weekIndex: Int
    var name: String?
    var notes: String?
    var block: PlanBlock?
    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkout.week)
    var plannedWorkouts: [PlannedWorkout] = []

    init(
        weekIndex: Int,
        name: String? = nil,
        notes: String? = nil,
        plannedWorkouts: [PlannedWorkout] = []
    ) {
        self.weekIndex = weekIndex
        self.name = name
        self.notes = notes
        self.plannedWorkouts = plannedWorkouts
    }

    var orderedPlannedWorkouts: [PlannedWorkout] {
        plannedWorkouts.sorted { $0.orderIndex < $1.orderIndex }
    }
}
