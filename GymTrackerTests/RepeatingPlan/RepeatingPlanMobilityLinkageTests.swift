import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanMobilityLinkageTests: XCTestCase {
    func testRunSlotsKeepMobilityIntentAfterTemplateLinksChange() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let originalWarmup = MobilityRoutine(name: "Original Warmup")
        let originalCooldown = MobilityRoutine(name: "Original Cooldown")
        let replacementWarmup = MobilityRoutine(name: "Replacement Warmup")
        let template = WorkoutTemplate(
            name: "Full Body",
            exercises: [],
            preWorkoutMobilityRoutine: originalWarmup,
            postWorkoutMobilityRoutine: originalCooldown
        )
        let definitionSlot = RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)
        let plan = RepeatingPlan(name: "Continuous Full Body", slots: [definitionSlot])
        let run = RepeatingPlanRun(plan: plan)

        context.insert(originalWarmup)
        context.insert(originalCooldown)
        context.insert(replacementWarmup)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        template.preWorkoutMobilityRoutine = replacementWarmup
        template.postWorkoutMobilityRoutine = nil
        try context.save()

        let freshContext = ModelContext(container)
        let storedTemplate = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.id == template.id }
        )
        let storedPlan = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )
        let storedRun = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )
        let storedDefinitionSlot = try XCTUnwrap(storedPlan.orderedSlots.first)
        let storedRunSlot = try XCTUnwrap(storedRun.orderedSlots.first)

        XCTAssertEqual(storedTemplate.preWorkoutMobilityRoutine?.id, replacementWarmup.id)
        XCTAssertNil(storedTemplate.postWorkoutMobilityRoutine)
        XCTAssertEqual(storedDefinitionSlot.preWorkoutMobilityRoutine?.id, originalWarmup.id)
        XCTAssertEqual(storedDefinitionSlot.preWorkoutMobilityRoutineIDSnapshot, originalWarmup.id)
        XCTAssertEqual(storedDefinitionSlot.preWorkoutMobilityRoutineNameSnapshot, "Original Warmup")
        XCTAssertEqual(storedDefinitionSlot.postWorkoutMobilityRoutine?.id, originalCooldown.id)
        XCTAssertEqual(storedRunSlot.preWorkoutMobilityRoutine?.id, originalWarmup.id)
        XCTAssertEqual(storedRunSlot.preWorkoutMobilityRoutineIDSnapshot, originalWarmup.id)
        XCTAssertEqual(storedRunSlot.preWorkoutMobilityRoutineNameSnapshot, "Original Warmup")
        XCTAssertEqual(storedRunSlot.postWorkoutMobilityRoutine?.id, originalCooldown.id)
        XCTAssertEqual(storedRunSlot.postWorkoutMobilityRoutineIDSnapshot, originalCooldown.id)
        XCTAssertEqual(storedRunSlot.postWorkoutMobilityRoutineNameSnapshot, "Original Cooldown")
    }

    func testDeletingRoutineNullifiesLiveLinksWithoutRemovingSlotSnapshots() throws {
        let container = try GymTrackerTestStore.makeInMemoryContainer()
        let context = ModelContext(container)
        let routine = MobilityRoutine(name: "Deleted Preparation")
        let template = WorkoutTemplate(
            name: "Upper",
            exercises: [],
            preWorkoutMobilityRoutine: routine,
            postWorkoutMobilityRoutine: routine
        )
        let definitionSlot = RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)
        let plan = RepeatingPlan(name: "Upper Rotation", slots: [definitionSlot])
        let run = RepeatingPlanRun(plan: plan)

        context.insert(routine)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()
        let routineID = routine.id

        context.delete(routine)
        try context.save()

        let freshContext = ModelContext(container)
        let storedTemplate = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.id == template.id }
        )
        let storedPlan = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )
        let storedRun = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )
        let storedDefinitionSlot = try XCTUnwrap(storedPlan.orderedSlots.first)
        let storedRunSlot = try XCTUnwrap(storedRun.orderedSlots.first)

        XCTAssertNil(storedTemplate.preWorkoutMobilityRoutine)
        XCTAssertNil(storedTemplate.postWorkoutMobilityRoutine)
        XCTAssertNil(storedDefinitionSlot.preWorkoutMobilityRoutine)
        XCTAssertNil(storedDefinitionSlot.postWorkoutMobilityRoutine)
        XCTAssertEqual(storedDefinitionSlot.preWorkoutMobilityRoutineIDSnapshot, routineID)
        XCTAssertEqual(storedDefinitionSlot.preWorkoutMobilityRoutineNameSnapshot, "Deleted Preparation")
        XCTAssertEqual(storedDefinitionSlot.postWorkoutMobilityRoutineIDSnapshot, routineID)
        XCTAssertEqual(storedDefinitionSlot.postWorkoutMobilityRoutineNameSnapshot, "Deleted Preparation")
        XCTAssertNil(storedRunSlot.preWorkoutMobilityRoutine)
        XCTAssertNil(storedRunSlot.postWorkoutMobilityRoutine)
        XCTAssertEqual(storedRunSlot.preWorkoutMobilityRoutineIDSnapshot, routineID)
        XCTAssertEqual(storedRunSlot.preWorkoutMobilityRoutineNameSnapshot, "Deleted Preparation")
        XCTAssertEqual(storedRunSlot.postWorkoutMobilityRoutineIDSnapshot, routineID)
        XCTAssertEqual(storedRunSlot.postWorkoutMobilityRoutineNameSnapshot, "Deleted Preparation")
    }
}
