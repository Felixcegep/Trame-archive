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

    convenience init(
        plannedWorkout: PlannedWorkout,
        weekIndex: Int,
        workoutIndex: Int,
        scheduledDate: Date? = nil
    ) {
        self.init(
            plannedWorkoutID: plannedWorkout.id,
            plannedWorkoutName: plannedWorkout.name,
            weekIndex: weekIndex,
            workoutIndex: workoutIndex,
            scheduledDate: scheduledDate
        )
    }

    init(
        plannedWorkoutID: UUID,
        plannedWorkoutName: String,
        weekIndex: Int,
        workoutIndex: Int,
        scheduledDate: Date? = nil
    ) {
        self.plannedWorkoutID = plannedWorkoutID
        self.plannedWorkoutName = plannedWorkoutName
        self.weekIndex = weekIndex
        self.workoutIndex = workoutIndex
        self.scheduledDate = scheduledDate
        self.status = .upcoming
    }
}
