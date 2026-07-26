import Foundation
import SwiftData

@Model
final class RepeatingPlanSlot {
    var id = UUID()
    var orderIndex: Int
    var templateIDSnapshot: UUID
    var templateNameSnapshot: String
    var plan: RepeatingPlan?
    var workoutTemplate: WorkoutTemplate?
    var preWorkoutMobilityRoutine: MobilityRoutine?
    var preWorkoutMobilityRoutineIDSnapshot: UUID?
    var preWorkoutMobilityRoutineNameSnapshot: String?
    var postWorkoutMobilityRoutine: MobilityRoutine?
    var postWorkoutMobilityRoutineIDSnapshot: UUID?
    var postWorkoutMobilityRoutineNameSnapshot: String?

    init(
        orderIndex: Int,
        workoutTemplate: WorkoutTemplate?,
        templateIDSnapshot: UUID? = nil,
        templateNameSnapshot: String? = nil,
        preWorkoutMobilityRoutine: MobilityRoutine? = nil,
        preWorkoutMobilityRoutineIDSnapshot: UUID? = nil,
        preWorkoutMobilityRoutineNameSnapshot: String? = nil,
        postWorkoutMobilityRoutine: MobilityRoutine? = nil,
        postWorkoutMobilityRoutineIDSnapshot: UUID? = nil,
        postWorkoutMobilityRoutineNameSnapshot: String? = nil
    ) {
        let resolvedTemplateID = templateIDSnapshot ?? workoutTemplate?.id
        let resolvedTemplateName = templateNameSnapshot ?? workoutTemplate?.name
        let resolvedPreWorkoutRoutine = preWorkoutMobilityRoutine ?? (
            preWorkoutMobilityRoutineIDSnapshot == nil && preWorkoutMobilityRoutineNameSnapshot == nil
                ? workoutTemplate?.preWorkoutMobilityRoutine
                : nil
        )
        let resolvedPostWorkoutRoutine = postWorkoutMobilityRoutine ?? (
            postWorkoutMobilityRoutineIDSnapshot == nil && postWorkoutMobilityRoutineNameSnapshot == nil
                ? workoutTemplate?.postWorkoutMobilityRoutine
                : nil
        )
        precondition(
            resolvedTemplateID != nil && resolvedTemplateName != nil,
            "A repeating-plan slot requires either a live template or explicit source snapshots."
        )
        precondition(
            (preWorkoutMobilityRoutineIDSnapshot == nil) == (preWorkoutMobilityRoutineNameSnapshot == nil),
            "A repeating-plan slot's pre-workout mobility snapshot requires both ID and name."
        )
        precondition(
            (postWorkoutMobilityRoutineIDSnapshot == nil) == (postWorkoutMobilityRoutineNameSnapshot == nil),
            "A repeating-plan slot's post-workout mobility snapshot requires both ID and name."
        )
        self.orderIndex = orderIndex
        self.templateIDSnapshot = resolvedTemplateID!
        self.templateNameSnapshot = resolvedTemplateName!
        self.workoutTemplate = workoutTemplate
        self.preWorkoutMobilityRoutine = resolvedPreWorkoutRoutine
        self.preWorkoutMobilityRoutineIDSnapshot = preWorkoutMobilityRoutineIDSnapshot ?? resolvedPreWorkoutRoutine?.id
        self.preWorkoutMobilityRoutineNameSnapshot = preWorkoutMobilityRoutineNameSnapshot ?? resolvedPreWorkoutRoutine?.name
        self.postWorkoutMobilityRoutine = resolvedPostWorkoutRoutine
        self.postWorkoutMobilityRoutineIDSnapshot = postWorkoutMobilityRoutineIDSnapshot ?? resolvedPostWorkoutRoutine?.id
        self.postWorkoutMobilityRoutineNameSnapshot = postWorkoutMobilityRoutineNameSnapshot ?? resolvedPostWorkoutRoutine?.name
    }
}
