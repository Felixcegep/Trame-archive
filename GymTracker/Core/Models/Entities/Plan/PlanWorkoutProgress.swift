import Foundation
import SwiftData

@Model
final class PlanWorkoutProgress {
    var id = UUID()
    var plannedWorkoutID: UUID
    var plannedWorkoutName: String
    var weekIndex: Int
    /// The immutable template week used to generate this occurrence. It stays
    /// stable when a run repeats a week or block and shifts occurrence indices.
    var sourceWeekIndex: Int?
    var workoutIndex: Int
    /// The first known scheduled local day for this run occurrence. It is
    /// immutable once established so a later schedule edit can be presented
    /// as a reschedule without consulting the mutable plan definition.
    var originalScheduledDate: Date?
    var scheduledDate: Date?
    /// Evidence that the user explicitly moved this occurrence. Automatic
    /// run re-anchoring may change `scheduledDate`, but does not fabricate a
    /// user reschedule event.
    var lastRescheduledAt: Date?
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
        sourceWeekIndex: Int? = nil,
        workoutIndex: Int,
        scheduledDate: Date? = nil
    ) {
        self.plannedWorkoutID = plannedWorkoutID
        self.plannedWorkoutName = plannedWorkoutName
        self.weekIndex = weekIndex
        self.sourceWeekIndex = sourceWeekIndex ?? weekIndex
        self.workoutIndex = workoutIndex
        self.scheduledDate = scheduledDate
        self.originalScheduledDate = scheduledDate
        self.lastRescheduledAt = nil
        self.status = .upcoming
    }
}
