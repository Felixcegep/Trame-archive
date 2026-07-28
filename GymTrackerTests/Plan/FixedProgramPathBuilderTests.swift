import XCTest
@testable import GymTracker

final class FixedProgramPathBuilderTests: XCTestCase {
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        today = date(2026, 7, 16, 12)
    }

    func testBuildDerivesProgramOrderLifecycleCurrentPositionAndDeload() {
        let buildWeek = PlanWeek(weekIndex: 0, name: "Build")
        let deloadWeek = PlanWeek(weekIndex: 1, name: "Deload week")
        let buildBlock = PlanBlock(name: "Build", phaseType: .strength, orderIndex: 0, weeks: [buildWeek])
        let deloadBlock = PlanBlock(
            name: "Deload",
            phaseType: .deload,
            orderIndex: 1,
            deloadVolumeReductionPercent: 40,
            deloadIntensityReductionPercent: 15,
            weeks: [deloadWeek]
        )
        let plan = WorkoutPlan(
            name: "Strength Block",
            daysPerWeek: 2,
            durationWeeks: 2,
            blocks: [buildBlock, deloadBlock]
        )
        let run = PlanRun(plan: plan, startDate: date(2026, 7, 14, 0))

        let completed = progress("Lower", week: 0, sourceWeek: 0, workout: 0, date: date(2026, 7, 14, 8))
        completed.status = .completed

        let ready = progress("Upper", week: 0, sourceWeek: 0, workout: 1, date: date(2026, 7, 20, 8))
        ready.status = .available
        ready.originalScheduledDate = date(2026, 7, 15, 8)
        ready.lastRescheduledAt = date(2026, 7, 14, 9)

        let deload = progress("Deload Full Body", week: 1, sourceWeek: 1, workout: 0, date: date(2026, 7, 23, 8))
        deload.status = .upcoming
        run.workoutProgress = [deload, ready, completed]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertEqual(projection.title, "Strength Block")
        XCTAssertEqual(projection.progress.completedSessionCount, 1)
        XCTAssertEqual(projection.progress.totalSessionCount, 3)
        XCTAssertEqual(projection.position.blockIndex, 0)
        XCTAssertEqual(projection.position.totalBlockCount, 2)
        XCTAssertEqual(projection.position.runWeekIndex, 0)
        XCTAssertEqual(projection.position.weekPosition, 0)
        XCTAssertEqual(projection.position.sessionIndex, 1)
        XCTAssertEqual(projection.position.sessionCountInWeek, 2)
        XCTAssertEqual(projection.currentSessionID, ready.id)
        XCTAssertEqual(
            projection.primaryAction,
            .startFixedWorkout(runID: run.id, progressID: ready.id)
        )
        XCTAssertEqual(projection.weeks.map(\.runWeekIndex), [0, 1])
        XCTAssertEqual(projection.weeks[0].sessions.map(\.workoutName), ["Lower", "Upper"])
        XCTAssertEqual(projection.weeks[0].sessions.map(\.displayState), [.completed, .available])
        XCTAssertTrue(projection.weeks[0].sessions[1].isCurrent)
        XCTAssertTrue(projection.weeks[0].sessions[1].isRescheduled)
        XCTAssertEqual(projection.weeks[0].block?.name, "Build")
        XCTAssertEqual(projection.weeks[1].block?.name, "Deload")
        XCTAssertEqual(projection.upcomingDeload?.block.name, "Deload")
        XCTAssertEqual(projection.upcomingDeload?.firstRunWeekIndex, 1)
        XCTAssertEqual(projection.upcomingDeload?.block.deloadVolumeReductionPercent, 40)
        XCTAssertEqual(projection.upcomingDeload?.block.deloadIntensityReductionPercent, 15)
        XCTAssertNil(projection.currentDeload)
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testBuildUsesCalendarMissedStateAndDoesNotTreatUnchangedDateAsRescheduled() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Plan", startDate: today)
        let missed = progress("Missed", week: 0, sourceWeek: 0, workout: 0, date: date(2026, 7, 15, 8))
        missed.status = .upcoming
        missed.originalScheduledDate = date(2026, 7, 15, 20)

        let available = progress("Ready", week: 0, sourceWeek: 0, workout: 1, date: nil)
        available.status = .available
        run.workoutProgress = [available, missed]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertEqual(projection.weeks[0].sessions[0].displayState, .missed)
        XCTAssertFalse(projection.weeks[0].sessions[0].isRescheduled)
        XCTAssertEqual(projection.weeks[0].sessions[1].displayState, .available)
        XCTAssertTrue(projection.weeks[0].sessions[1].isCurrent)
        XCTAssertEqual(projection.currentSessionID, available.id)
    }

    func testBuildDoesNotLabelAutomaticScheduleMovementAsUserReschedule() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Plan", startDate: today)
        let moved = progress("Moved automatically", week: 0, sourceWeek: 0, workout: 0, date: date(2026, 7, 18, 8))
        moved.status = .available
        moved.originalScheduledDate = date(2026, 7, 17, 8)
        moved.lastRescheduledAt = nil
        run.workoutProgress = [moved]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertFalse(projection.weeks[0].sessions[0].isRescheduled)
    }

    func testBuildRecognizesCurrentPositionInsideMultiWeekDeload() {
        let deloadWeekOne = PlanWeek(weekIndex: 1, name: "Deload 1")
        let deloadWeekTwo = PlanWeek(weekIndex: 2, name: "Deload 2")
        let deloadBlock = PlanBlock(
            name: "Deload",
            phaseType: .deload,
            orderIndex: 0,
            weeks: [deloadWeekOne, deloadWeekTwo]
        )
        let plan = WorkoutPlan(name: "Long Deload", daysPerWeek: 1, durationWeeks: 2, blocks: [deloadBlock])
        let run = PlanRun(plan: plan, startDate: today)
        let first = progress("Deload A", week: 1, sourceWeek: 1, workout: 0, date: date(2026, 7, 17, 8))
        first.status = .completed
        let current = progress("Deload B", week: 2, sourceWeek: 2, workout: 0, date: date(2026, 7, 24, 8))
        current.status = .available
        run.workoutProgress = [first, current]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertEqual(projection.currentDeload?.runWeekIndices, [1, 2])
        XCTAssertNil(projection.upcomingDeload)
    }

    func testBuildKeepsRepeatedOccurrenceInEffectiveWeekAndResolvesItsSourceBlock() {
        let sourceWeek = PlanWeek(weekIndex: 0, name: "Source week")
        let block = PlanBlock(name: "Accumulation", phaseType: .accumulation, orderIndex: 0, weeks: [sourceWeek])
        let plan = WorkoutPlan(name: "Repeat", daysPerWeek: 1, durationWeeks: 1, blocks: [block])
        let run = PlanRun(plan: plan, startDate: today)
        let repeated = progress("Repeated lower", week: 2, sourceWeek: 0, workout: 0, date: date(2026, 7, 24, 8))
        repeated.status = .available
        run.workoutProgress = [repeated]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertEqual(projection.weeks.map(\.runWeekIndex), [2])
        XCTAssertEqual(projection.weeks[0].sourceWeekIndex, 0)
        XCTAssertEqual(projection.weeks[0].sourceWeekName, "Source week")
        XCTAssertEqual(projection.weeks[0].block?.name, "Accumulation")
        XCTAssertEqual(projection.position.runWeekIndex, 2)
        XCTAssertEqual(projection.position.weekPosition, 0)
        XCTAssertTrue(projection.warnings.isEmpty)
    }

    func testBuildKeepsRunHistoryWhenSourcePlanIsUnavailable() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Deleted plan", startDate: today)
        let completed = progress("Preserved workout", week: 0, sourceWeek: 0, workout: 0, date: date(2026, 7, 14, 8))
        completed.status = .completed
        run.workoutProgress = [completed]

        let projection = FixedProgramPathBuilder.build(for: run, today: today, calendar: calendar)

        XCTAssertEqual(projection.weeks.count, 1)
        XCTAssertEqual(projection.weeks[0].sessions[0].workoutName, "Preserved workout")
        XCTAssertEqual(projection.weeks[0].sessions[0].displayState, .completed)
        XCTAssertEqual(projection.warnings, [.sourcePlanUnavailable])
        XCTAssertNil(projection.upcomingDeload)
    }

    private func progress(
        _ name: String,
        week: Int,
        sourceWeek: Int,
        workout: Int,
        date: Date?
    ) -> PlanWorkoutProgress {
        PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: name,
            weekIndex: week,
            sourceWeekIndex: sourceWeek,
            workoutIndex: workout,
            scheduledDate: date
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
