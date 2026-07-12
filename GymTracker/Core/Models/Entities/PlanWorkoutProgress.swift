import Foundation
import SwiftData

@Model
final class PlanWorkoutProgress {
    var id = UUID()
    var plannedWorkoutID: UUID
    var plannedWorkoutName: String
    var weekIndex: Int
    var workoutIndex: Int
    var scheduledDate: Date?
    var status: PlanWorkoutStatus
    var startedAt: Date?
    var completedAt: Date?
    var skipReason: String?
    var planRun: PlanRun?
    @Relationship(deleteRule: .nullify)
    var completedWorkout: Workout?

    init(
        plannedWorkout: PlannedWorkout,
        weekIndex: Int,
        workoutIndex: Int,
        scheduledDate: Date? = nil
    ) {
        self.plannedWorkoutID = plannedWorkout.id
        self.plannedWorkoutName = plannedWorkout.name
        self.weekIndex = weekIndex
        self.workoutIndex = workoutIndex
        self.scheduledDate = scheduledDate
        self.status = .upcoming
    }
}
