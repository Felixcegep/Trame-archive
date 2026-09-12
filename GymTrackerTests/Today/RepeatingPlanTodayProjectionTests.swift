import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class RepeatingPlanTodayProjectionTests: XCTestCase {
    func testActiveWorkoutOutranksConflictingGuidedSources() {
        let workout = Workout(name: "In Progress")
        let fixedRun = makeFixedRun()
        let repeatingRun = makeRepeatingRun(names: ["Push", "Pull"])

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: workout,
            planRuns: [fixedRun],
            repeatingPlanRuns: [repeatingRun]
        )

        XCTAssertEqual(summary.kind, .active)
        XCTAssertEqual(summary.title, "Resume In Progress")
    }

    func testSoleActiveFixedPlanProjectsItsNextWorkout() {
        let fixedRun = makeFixedRun(planName: "Strength Base", workoutName: "Heavy Squat")

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [fixedRun],
            repeatingPlanRuns: []
        )

        XCTAssertEqual(summary.kind, .planned)
        XCTAssertEqual(summary.title, "Heavy Squat")
        XCTAssertTrue(summary.subtitle.contains("Strength Base"))
        XCTAssertTrue(summary.subtitle.contains("Week 1"))
    }

    func testFlexibleWeekTodayCopyStatesRemainingWork() {
        let plan = WorkoutPlan(
            name: "Open Week",
            daysPerWeek: 3,
            durationWeeks: 4,
            scheduleMode: .flexibleWeek
        )
        let run = PlanRun(plan: plan, startDate: .now)
        let first = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Push",
            weekIndex: 0,
            workoutIndex: 0
        )
        first.status = .available
        let second = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Pull",
            weekIndex: 0,
            workoutIndex: 1
        )
        second.status = .upcoming
        run.workoutProgress = [first, second]

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [run],
            repeatingPlanRuns: []
        )

        XCTAssertEqual(summary.kind, .planned)
        XCTAssertEqual(summary.title, "Push")
        XCTAssertTrue(summary.subtitle.contains("2 remaining this week"))
    }

    func testSoleActiveRepeatingPlanProjectsCursorAndCycle() {
        let run = makeRepeatingRun(names: ["Push", "Pull", "Legs"])
        run.currentSlotIndex = 1
        run.completedCycleCount = 2

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [],
            repeatingPlanRuns: [run]
        )

        XCTAssertEqual(summary.kind, .repeating)
        XCTAssertEqual(summary.title, "Pull")
        XCTAssertEqual(summary.subtitle, "Test Rotation · Cycle 3 · Workout 2 of 3")
    }

    func testActiveFixedAndRepeatingPlansRequireExplicitResolution() {
        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [makeFixedRun()],
            repeatingPlanRuns: [makeRepeatingRun(names: ["Full Body"])]
        )

        XCTAssertEqual(summary.kind, .guidedConflict)
        XCTAssertEqual(summary.title, "Choose what to follow")
    }

    func testNoActiveGuidedSourceProjectsFreeWorkout() {
        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [],
            repeatingPlanRuns: []
        )

        XCTAssertEqual(summary.kind, .free)
        XCTAssertEqual(summary.title, "Free Workout")
    }

    func testUnavailableRepeatingTemplateProducesRepairState() {
        let slot = RepeatingPlanRunSlot(
            sourceSlotID: UUID(),
            orderIndex: 0,
            templateIDSnapshot: UUID(),
            templateNameSnapshot: "Missing Day"
        )
        let run = RepeatingPlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: "Broken Rotation",
            slots: [slot]
        )

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [],
            repeatingPlanRuns: [run]
        )

        XCTAssertEqual(summary.kind, .unavailable)
        XCTAssertEqual(summary.title, "Missing Day")
        XCTAssertTrue(summary.subtitle.contains("restored"))
    }

    func testTestDayAvailabilityDoesNotCountAsAnActiveGuidedSource() {
        let fixedRun = makeFixedRun()
        fixedRun.status = .testDayAvailable

        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: nil,
            planRuns: [fixedRun],
            repeatingPlanRuns: []
        )

        XCTAssertEqual(summary.kind, .free)
    }

    private func makeFixedRun(
        planName: String = "Fixed Plan",
        workoutName: String = "Plan Day"
    ) -> PlanRun {
        let run = PlanRun(
            sourcePlanID: UUID(),
            sourcePlanName: planName,
            startDate: .now
        )
        let progress = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: workoutName,
            weekIndex: 0,
            workoutIndex: 0
        )
        progress.status = .available
        run.workoutProgress = [progress]
        return run
    }

    private func makeRepeatingRun(names: [String]) -> RepeatingPlanRun {
        let slots = names.enumerated().map { index, name in
            RepeatingPlanSlot(
                orderIndex: index,
                workoutTemplate: WorkoutTemplate(name: name, exercises: [])
            )
        }
        return RepeatingPlanRun(plan: RepeatingPlan(name: "Test Rotation", slots: slots))
    }
}
