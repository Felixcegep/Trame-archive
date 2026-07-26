import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanModelTests: XCTestCase {
    func testDefinitionOrdersAndNormalizesSlotsDeterministically() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let push = makeTemplate(named: "Push")
        let pull = makeTemplate(named: "Pull")
        let first = RepeatingPlanSlot(orderIndex: 8, workoutTemplate: push)
        let second = RepeatingPlanSlot(orderIndex: 2, workoutTemplate: pull)
        let plan = RepeatingPlan(name: "PPL Continuous", slots: [first, second])

        context.insert(push)
        context.insert(pull)
        context.insert(plan)
        try context.save()

        XCTAssertEqual(plan.orderedSlots.map(\.templateNameSnapshot), ["Pull", "Push"])
        plan.normalizeSlotOrder()
        XCTAssertEqual(plan.orderedSlots.map(\.orderIndex), [0, 1])
        XCTAssertTrue(plan.validationIssues.isEmpty)
    }

    func testRunCopiesSlotOrderAndIdentityIndependentlyOfDefinitionChanges() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let push = makeTemplate(named: "Push")
        let pull = makeTemplate(named: "Pull")
        let pushSlot = RepeatingPlanSlot(orderIndex: 0, workoutTemplate: push)
        let pullSlot = RepeatingPlanSlot(orderIndex: 1, workoutTemplate: pull)
        let plan = RepeatingPlan(name: "PPL Continuous", slots: [pushSlot, pullSlot])
        let run = RepeatingPlanRun(plan: plan)

        context.insert(push)
        context.insert(pull)
        context.insert(plan)
        context.insert(run)
        try context.save()

        plan.name = "Edited Definition"
        push.name = "Edited Push"
        pushSlot.orderIndex = 1
        pullSlot.orderIndex = 0
        try context.save()

        XCTAssertEqual(run.sourcePlanID, plan.id)
        XCTAssertEqual(run.sourcePlanName, "PPL Continuous")
        XCTAssertEqual(run.orderedSlots.map(\.sourceSlotID), [pushSlot.id, pullSlot.id])
        XCTAssertEqual(run.orderedSlots.map(\.templateNameSnapshot), ["Push", "Pull"])
        XCTAssertEqual(run.orderedSlots.map(\.orderIndex), [0, 1])
    }

    func testDeletingDefinitionCascadesDefinitionSlotsButPreservesRunSnapshots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = makeTemplate(named: "Full Body A")
        let plan = RepeatingPlan(
            name: "Beginner Full Body",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = RepeatingPlanRun(plan: plan)
        let runID = run.id

        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        context.delete(plan)
        try context.save()
        context.processPendingChanges()

        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlanSlot>()).isEmpty)
        let preservedRun = try XCTUnwrap(
            context.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == runID }
        )
        XCTAssertNil(preservedRun.plan)
        XCTAssertEqual(preservedRun.sourcePlanName, "Beginner Full Body")
        XCTAssertEqual(preservedRun.orderedSlots.map(\.templateNameSnapshot), ["Full Body A"])
    }

    func testDeletingTemplateNullifiesLiveLinksAndPreservesFallbackSnapshots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = makeTemplate(named: "Upper A")
        let templateID = template.id
        let slot = RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)
        let plan = RepeatingPlan(name: "Upper Lower", slots: [slot])
        let run = RepeatingPlanRun(plan: plan)

        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        context.delete(template)
        try context.save()

        // SwiftData keeps deleted relationship objects cached in the writing
        // context. A fresh context is the authoritative persisted view.
        let freshContext = ModelContext(context.container)
        let persistedSlot = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlanSlot>()).first { $0.id == slot.id }
        )
        let persistedRun = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlanRun>()).first { $0.id == run.id }
        )
        let persistedPlan = try XCTUnwrap(
            freshContext.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == plan.id }
        )

        XCTAssertNil(persistedSlot.workoutTemplate)
        XCTAssertEqual(persistedSlot.templateIDSnapshot, templateID)
        XCTAssertEqual(persistedSlot.templateNameSnapshot, "Upper A")
        XCTAssertNil(persistedRun.orderedSlots.first?.workoutTemplate)
        XCTAssertEqual(persistedRun.orderedSlots.first?.templateIDSnapshot, templateID)
        XCTAssertEqual(persistedRun.orderedSlots.first?.templateNameSnapshot, "Upper A")
        XCTAssertTrue(persistedPlan.validationIssues.contains(.unavailableTemplate(slot.id)))
    }

    func testOccurrenceAndWorkoutSourceIdentityPersistWithoutOwningHistory() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let workout = Workout(name: "Push", endTime: .now)
        let planID = UUID()
        let runID = UUID()
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 3,
            expectedSlotIndex: 1,
            selectedSlotIndex: 1,
            cursorBefore: 10,
            cursorAfter: 11,
            cycleBefore: 3,
            cycleAfter: 4,
            completedAt: .now,
            completedWorkout: workout
        )
        occurrence.status = .completed
        workout.sourceRepeatingPlanID = planID
        workout.sourceRepeatingPlanRunID = runID
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = "PPL Continuous"

        context.insert(workout)
        context.insert(occurrence)
        try context.save()

        XCTAssertEqual(occurrence.completedWorkout?.id, workout.id)
        XCTAssertEqual(workout.sourceRepeatingPlanID, planID)
        XCTAssertEqual(workout.sourceRepeatingPlanRunID, runID)
        XCTAssertEqual(workout.sourceRepeatingPlanOccurrenceID, occurrence.id)
        XCTAssertEqual(workout.sourceRepeatingPlanName, "PPL Continuous")

        context.delete(workout)
        try context.save()

        let preservedOccurrence = try XCTUnwrap(
            ModelContext(context.container)
                .fetch(FetchDescriptor<RepeatingPlanOccurrence>())
                .first
        )
        XCTAssertNil(preservedOccurrence.completedWorkout)
        XCTAssertEqual(preservedOccurrence.status, .completed)
        XCTAssertEqual(preservedOccurrence.cursorBefore, 10)
        XCTAssertEqual(preservedOccurrence.cursorAfter, 11)
        XCTAssertEqual(preservedOccurrence.cycleBefore, 3)
        XCTAssertEqual(preservedOccurrence.cycleAfter, 4)
        XCTAssertNil(preservedOccurrence.undoneAt)
    }

    func testClearAllGymDataRemovesRepeatingPlanRoots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let template = makeTemplate(named: "Legs")
        let plan = RepeatingPlan(
            name: "PPL Continuous",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = RepeatingPlanRun(plan: plan)
        run.occurrences = [
            RepeatingPlanOccurrence(
                cycleIndex: 0,
                expectedSlotIndex: 0,
                cursorBefore: 0,
                cursorAfter: 1
            )
        ]

        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()
        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlanRun>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlanOccurrence>()).isEmpty)
    }

    private func makeTemplate(named name: String) -> WorkoutTemplate {
        WorkoutTemplate(name: name, exercises: [])
    }
}
