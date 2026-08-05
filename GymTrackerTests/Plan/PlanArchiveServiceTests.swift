import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanArchiveServiceTests: XCTestCase {

    // MARK: - WorkoutPlan Rename

    func testRenamePlanTrimsAndSaves() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(name: "Push Pull", daysPerWeek: 4, durationWeeks: 8)
        context.insert(plan)
        try context.save()

        try WorkoutPlanArchiveService.rename(plan, to: "  Upper Lower Split  ", using: context)
        XCTAssertEqual(plan.name, "Upper Lower Split")
    }

    func testRenamePlanRejectsEmptyName() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(name: "Push Pull", daysPerWeek: 4, durationWeeks: 8)
        context.insert(plan)
        try context.save()

        XCTAssertThrowsError(try WorkoutPlanArchiveService.rename(plan, to: "   ", using: context)) { error in
            guard let planError = error as? PlanArchiveError else {
                return XCTFail("Expected PlanArchiveError")
            }
            XCTAssertEqual(planError, .emptyName)
        }
    }

    // MARK: - WorkoutPlan Duplicate

    func testDuplicatePlanCreatesDeepCopy() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(name: "Leg Day", exercises: [exercise])
        let plan = WorkoutPlan(name: "Hypertrophy Block", daysPerWeek: 4, durationWeeks: 8)
        let block = PlanBlock(name: "Main Phase", phaseType: .hypertrophy, orderIndex: 0)
        let week = PlanWeek(weekIndex: 0)
        let workout = PlannedWorkout(name: "Day 1", orderIndex: 0, dayOffset: 0, sourceTemplate: template)
        week.plannedWorkouts.append(workout)
        block.weeks.append(week)
        plan.blocks.append(block)

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        try context.save()

        let copy = try WorkoutPlanArchiveService.duplicate(plan, using: context)

        XCTAssertEqual(copy.name, "Hypertrophy Block Copy")
        XCTAssertNotEqual(copy.id, plan.id)
        XCTAssertEqual(copy.daysPerWeek, 4)
        XCTAssertEqual(copy.durationWeeks, 8)
        XCTAssertEqual(copy.orderedBlocks.count, 1)
        XCTAssertEqual(copy.orderedBlocks.first?.orderedWeeks.count, 1)
        XCTAssertEqual(copy.orderedBlocks.first?.orderedWeeks.first?.orderedPlannedWorkouts.count, 1)
        XCTAssertEqual(copy.orderedBlocks.first?.orderedWeeks.first?.orderedPlannedWorkouts.first?.name, "Day 1")
    }

    // MARK: - WorkoutPlan Delete

    func testDeleteUnreferencedPlanDeletesFromStore() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(name: "Unused Plan", daysPerWeek: 3, durationWeeks: 4)
        context.insert(plan)
        try context.save()

        let outcome = try WorkoutPlanArchiveService.hideOrDeleteResult(plan, using: context)

        XCTAssertEqual(outcome, .deleted)
        let allPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        XCTAssertFalse(allPlans.contains { $0.name == "Unused Plan" })
    }

    func testDeleteReferencedPlanArchivesWithReason() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(name: "Active Plan", daysPerWeek: 4, durationWeeks: 8)
        let run = PlanRun(plan: plan)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let outcome = try WorkoutPlanArchiveService.hideOrDeleteResult(plan, using: context)

        if case .archived(let reason) = outcome {
            XCTAssertFalse(reason.isEmpty, "Expected non-empty archive reason")
        } else {
            XCTFail("Expected referenced plan to return .archived(reason:)")
        }

        XCTAssertTrue(plan.isArchived)
        let allPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        XCTAssertTrue(allPlans.contains { $0.id == plan.id })
    }

    // MARK: - WorkoutPlan Restore

    func testRestorePlanClearsArchivedFlag() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(name: "Archived Plan", daysPerWeek: 3, durationWeeks: 6)
        plan.isArchived = true
        context.insert(plan)
        try context.save()

        try WorkoutPlanArchiveService.restore(plan, using: context)

        XCTAssertFalse(plan.isArchived)
    }

    // MARK: - RepeatingPlan Rename

    func testRenameRepeatingPlanTrimsAndSaves() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Push", exercises: [])
        let rotation = RepeatingPlan(
            name: "PPL Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        context.insert(template)
        context.insert(rotation)
        try context.save()

        try RepeatingPlanArchiveService.rename(rotation, to: "  Upper Lower Rotation  ", using: context)
        XCTAssertEqual(rotation.name, "Upper Lower Rotation")
    }

    // MARK: - RepeatingPlan Duplicate

    func testDuplicateRepeatingPlanCopiesSlots() throws {
        let context = try makeContext()
        let template1 = WorkoutTemplate(name: "Push", exercises: [])
        let template2 = WorkoutTemplate(name: "Pull", exercises: [])
        let rotation = RepeatingPlan(
            name: "PPL",
            slots: [
                RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template1),
                RepeatingPlanSlot(orderIndex: 1, workoutTemplate: template2)
            ]
        )
        context.insert(template1)
        context.insert(template2)
        context.insert(rotation)
        try context.save()

        let copy = try RepeatingPlanArchiveService.duplicate(rotation, using: context)

        XCTAssertEqual(copy.name, "PPL Copy")
        XCTAssertNotEqual(copy.id, rotation.id)
        XCTAssertEqual(copy.orderedSlots.count, 2)
        XCTAssertEqual(copy.orderedSlots[0].templateNameSnapshot, "Push")
        XCTAssertEqual(copy.orderedSlots[1].templateNameSnapshot, "Pull")
        XCTAssertFalse(copy.isBuiltIn)
    }

    // MARK: - RepeatingPlan Delete

    func testDeleteUnreferencedRepeatingPlanDeletes() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Push", exercises: [])
        let rotation = RepeatingPlan(
            name: "Unused Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        context.insert(template)
        context.insert(rotation)
        try context.save()

        let outcome = try RepeatingPlanArchiveService.hideOrDeleteResult(rotation, using: context)

        XCTAssertEqual(outcome, .deleted)
        let allRotations = try context.fetch(FetchDescriptor<RepeatingPlan>())
        XCTAssertFalse(allRotations.contains { $0.name == "Unused Rotation" })
    }

    func testDeleteReferencedRepeatingPlanArchives() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Push", exercises: [])
        let rotation = RepeatingPlan(
            name: "Active Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        let run = RepeatingPlanRun(plan: rotation)
        context.insert(template)
        context.insert(rotation)
        context.insert(run)
        try context.save()

        let outcome = try RepeatingPlanArchiveService.hideOrDeleteResult(rotation, using: context)

        if case .archived(let reason) = outcome {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected referenced rotation to return .archived(reason:)")
        }

        XCTAssertTrue(rotation.isArchived)
    }

    func testDeleteBuiltInRepeatingPlanArchives() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Push", exercises: [])
        let rotation = RepeatingPlan(
            name: "Built-In Rotation",
            isBuiltIn: true,
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        context.insert(template)
        context.insert(rotation)
        try context.save()

        let outcome = try RepeatingPlanArchiveService.hideOrDeleteResult(rotation, using: context)

        if case .archived(let reason) = outcome {
            XCTAssertTrue(reason.contains("System"), "Expected system archive reason, got: \(reason)")
        } else {
            XCTFail("Expected built-in rotation to return .archived(reason:)")
        }
    }

    // MARK: - RepeatingPlan Restore

    func testRestoreRepeatingPlanClearsArchivedFlag() throws {
        let context = try makeContext()
        let template = WorkoutTemplate(name: "Push", exercises: [])
        let rotation = RepeatingPlan(
            name: "Archived Rotation",
            isArchived: true,
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: template)]
        )
        context.insert(template)
        context.insert(rotation)
        try context.save()

        try RepeatingPlanArchiveService.restore(rotation, using: context)

        XCTAssertFalse(rotation.isArchived)
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
