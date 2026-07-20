import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanReminderActionTests: XCTestCase {
    func testEligibilityRequiresAnIncompleteWorkoutScheduledTodayInAnActiveRun() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let fixture = try makeFixture(in: context)

        XCTAssertTrue(PlanReminderEligibility.canSchedule(fixture.today, in: fixture.run))
        XCTAssertTrue(PlanReminderEligibility.isActionableToday(fixture.today, in: fixture.run))
        XCTAssertFalse(PlanReminderEligibility.isActionableToday(fixture.tomorrow, in: fixture.run))

        fixture.today.status = .inProgress
        XCTAssertFalse(PlanReminderEligibility.canSchedule(fixture.today, in: fixture.run))
        fixture.today.status = .available

        fixture.run.status = .paused
        XCTAssertFalse(PlanReminderEligibility.canSchedule(fixture.today, in: fixture.run))
    }

    func testSkipTodayPreservesThePlanAndHistoryWhileAdvancingRunAvailability() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let fixture = try makeFixture(in: context)
        let originalPlanName = fixture.plan.name
        let originalTodayDate = fixture.today.scheduledDate
        let destination = PlanNotificationDestination(
            planID: fixture.plan.id,
            runID: fixture.run.id,
            progressID: fixture.today.id
        )

        XCTAssertTrue(PlanReminderActionService.skipToday(destination, using: context))
        XCTAssertEqual(fixture.today.status, .skipped)
        XCTAssertNotNil(fixture.today.completedAt)
        XCTAssertEqual(fixture.today.scheduledDate, originalTodayDate)
        XCTAssertNil(fixture.today.completedWorkout)
        XCTAssertEqual(fixture.tomorrow.status, .available)
        XCTAssertEqual(fixture.plan.name, originalPlanName)
    }

    func testStaleOrMismatchedNotificationCannotSkipAWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let fixture = try makeFixture(in: context)
        let mismatchedPlan = PlanNotificationDestination(
            planID: UUID(),
            runID: fixture.run.id,
            progressID: fixture.today.id
        )
        let staleProgress = PlanNotificationDestination(
            planID: fixture.plan.id,
            runID: fixture.run.id,
            progressID: UUID()
        )

        XCTAssertFalse(PlanReminderActionService.skipToday(mismatchedPlan, using: context))
        XCTAssertFalse(PlanReminderActionService.skipToday(staleProgress, using: context))
        XCTAssertEqual(fixture.today.status, .available)
    }

    func testNotificationPayloadRoundTripsStableIdentifiers() throws {
        let destination = PlanNotificationDestination(planID: UUID(), runID: UUID(), progressID: UUID())
        let payload: [AnyHashable: Any] = [
            "planID": destination.planID.uuidString,
            "runID": destination.runID.uuidString,
            "progressID": destination.progressID.uuidString
        ]

        let decoded = try XCTUnwrap(PlanNotificationDestination(userInfo: payload, action: .reschedule))
        XCTAssertEqual(decoded.planID, destination.planID)
        XCTAssertEqual(decoded.runID, destination.runID)
        XCTAssertEqual(decoded.progressID, destination.progressID)
        XCTAssertEqual(decoded.action, .reschedule)
    }

    private func makeFixture(in context: ModelContext) throws -> (
        plan: WorkoutPlan,
        run: PlanRun,
        today: PlanWorkoutProgress,
        tomorrow: PlanWorkoutProgress
    ) {
        let plan = WorkoutPlan(name: "Reminder plan", daysPerWeek: 2, durationWeeks: 1)
        let run = PlanRun(plan: plan)
        let today = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Today workout",
            weekIndex: 0,
            workoutIndex: 0,
            scheduledDate: Calendar.current.startOfDay(for: .now)
        )
        let tomorrow = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Tomorrow workout",
            weekIndex: 0,
            workoutIndex: 1,
            scheduledDate: try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: .now))
        )
        today.status = .available
        run.workoutProgress = [today, tomorrow]
        plan.runs = [run]
        context.insert(plan)
        context.insert(run)
        try context.save()
        return (plan, run, today, tomorrow)
    }
}
