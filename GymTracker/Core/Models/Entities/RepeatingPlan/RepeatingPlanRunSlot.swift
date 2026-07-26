import Foundation
import SwiftData

@Model
final class RepeatingPlanRunSlot {
    var id = UUID()
    var sourceSlotID: UUID
    var orderIndex: Int
    var templateIDSnapshot: UUID
    var templateNameSnapshot: String
    var run: RepeatingPlanRun?
    var workoutTemplate: WorkoutTemplate?
    var preWorkoutMobilityRoutine: MobilityRoutine?
    var preWorkoutMobilityRoutineIDSnapshot: UUID?
    var preWorkoutMobilityRoutineNameSnapshot: String?
    var postWorkoutMobilityRoutine: MobilityRoutine?
    var postWorkoutMobilityRoutineIDSnapshot: UUID?
    var postWorkoutMobilityRoutineNameSnapshot: String?

    convenience init(slot: RepeatingPlanSlot) {
        self.init(
            sourceSlotID: slot.id,
            orderIndex: slot.orderIndex,
            templateIDSnapshot: slot.templateIDSnapshot,
            templateNameSnapshot: slot.templateNameSnapshot,
            workoutTemplate: slot.workoutTemplate,
            preWorkoutMobilityRoutine: slot.preWorkoutMobilityRoutine,
            preWorkoutMobilityRoutineIDSnapshot: slot.preWorkoutMobilityRoutineIDSnapshot,
            preWorkoutMobilityRoutineNameSnapshot: slot.preWorkoutMobilityRoutineNameSnapshot,
            postWorkoutMobilityRoutine: slot.postWorkoutMobilityRoutine,
            postWorkoutMobilityRoutineIDSnapshot: slot.postWorkoutMobilityRoutineIDSnapshot,
            postWorkoutMobilityRoutineNameSnapshot: slot.postWorkoutMobilityRoutineNameSnapshot
        )
    }

    init(
        sourceSlotID: UUID,
        orderIndex: Int,
        templateIDSnapshot: UUID,
        templateNameSnapshot: String,
        workoutTemplate: WorkoutTemplate? = nil,
        preWorkoutMobilityRoutine: MobilityRoutine? = nil,
        preWorkoutMobilityRoutineIDSnapshot: UUID? = nil,
        preWorkoutMobilityRoutineNameSnapshot: String? = nil,
        postWorkoutMobilityRoutine: MobilityRoutine? = nil,
        postWorkoutMobilityRoutineIDSnapshot: UUID? = nil,
        postWorkoutMobilityRoutineNameSnapshot: String? = nil
    ) {
        precondition(
            (preWorkoutMobilityRoutineIDSnapshot == nil) == (preWorkoutMobilityRoutineNameSnapshot == nil),
            "A repeating-plan run slot's pre-workout mobility snapshot requires both ID and name."
        )
        precondition(
            (postWorkoutMobilityRoutineIDSnapshot == nil) == (postWorkoutMobilityRoutineNameSnapshot == nil),
            "A repeating-plan run slot's post-workout mobility snapshot requires both ID and name."
        )
        self.sourceSlotID = sourceSlotID
        self.orderIndex = orderIndex
        self.templateIDSnapshot = templateIDSnapshot
        self.templateNameSnapshot = templateNameSnapshot
        self.workoutTemplate = workoutTemplate
        self.preWorkoutMobilityRoutine = preWorkoutMobilityRoutine
        self.preWorkoutMobilityRoutineIDSnapshot = preWorkoutMobilityRoutineIDSnapshot ?? preWorkoutMobilityRoutine?.id
        self.preWorkoutMobilityRoutineNameSnapshot = preWorkoutMobilityRoutineNameSnapshot ?? preWorkoutMobilityRoutine?.name
        self.postWorkoutMobilityRoutine = postWorkoutMobilityRoutine
        self.postWorkoutMobilityRoutineIDSnapshot = postWorkoutMobilityRoutineIDSnapshot ?? postWorkoutMobilityRoutine?.id
        self.postWorkoutMobilityRoutineNameSnapshot = postWorkoutMobilityRoutineNameSnapshot ?? postWorkoutMobilityRoutine?.name
    }
}
