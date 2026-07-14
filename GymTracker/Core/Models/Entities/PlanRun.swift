import Foundation
import SwiftData

@Model
final class PlanRun {
    var id = UUID()
    var sourcePlanID: UUID
    var sourcePlanName: String
    var startDate: Date
    var endDate: Date?
    var status: PlanRunStatus
    var currentWeekIndex: Int
    var currentWorkoutIndex: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .nullify)
    var plan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlanWorkoutProgress.planRun)
    var workoutProgress: [PlanWorkoutProgress] = []

    convenience init(plan: WorkoutPlan, startDate: Date = .now) {
        self.init(
            sourcePlanID: plan.id,
            sourcePlanName: plan.name,
            startDate: startDate,
            plan: plan
        )
    }

    init(
        sourcePlanID: UUID,
        sourcePlanName: String,
        startDate: Date,
        plan: WorkoutPlan? = nil
    ) {
        self.sourcePlanID = sourcePlanID
        self.sourcePlanName = sourcePlanName
        self.startDate = startDate
        self.status = .active
        self.currentWeekIndex = 0
        self.currentWorkoutIndex = 0
        self.createdAt = .now
        self.updatedAt = .now
        self.plan = plan
    }

    var orderedWorkoutProgress: [PlanWorkoutProgress] {
        workoutProgress.sorted {
            $0.weekIndex == $1.weekIndex
                ? $0.workoutIndex < $1.workoutIndex
                : $0.weekIndex < $1.weekIndex
        }
    }
}
