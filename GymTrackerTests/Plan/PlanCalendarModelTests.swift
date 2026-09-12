import XCTest
@testable import GymTracker

final class PlanCalendarModelTests: XCTestCase {
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        today = date(2026, 7, 16, 12)
    }

    func testPastUpcomingAndAvailableSessionsAreDisplayedAsMissed() {
        XCTAssertEqual(displayState(.upcoming, date(2026, 7, 15, 23)), .missed)
        XCTAssertEqual(displayState(.available, date(2026, 7, 15, 0)), .missed)
        XCTAssertEqual(displayState(.upcoming, date(2026, 7, 16, 0)), .upcoming)
        XCTAssertEqual(displayState(.available, date(2026, 7, 16, 0)), .available)
    }

    func testTerminalStatesAndUnscheduledSessionsAreNeverMissed() {
        XCTAssertEqual(displayState(.completed, date(2026, 7, 1, 12)), .completed)
        XCTAssertEqual(displayState(.skipped, date(2026, 7, 1, 12)), .skipped)
        XCTAssertEqual(displayState(.inProgress, date(2026, 7, 1, 12)), .inProgress)
        XCTAssertEqual(displayState(.upcoming, nil), .upcoming)
        XCTAssertEqual(displayState(.available, nil), .available)
    }

    func testFlexibleWeekUnscheduledSessionsAreMissedOnlyAfterTheWeekEnds() {
        let weekEnd = date(2026, 7, 20, 0)
        XCTAssertEqual(
            PlanCalendarBuilder.displayState(
                status: .available,
                scheduledDate: nil,
                today: date(2026, 7, 16, 12),
                calendar: calendar,
                weekDeadline: weekEnd
            ),
            .available
        )
        XCTAssertEqual(
            PlanCalendarBuilder.displayState(
                status: .upcoming,
                scheduledDate: nil,
                today: date(2026, 7, 21, 8),
                calendar: calendar,
                weekDeadline: weekEnd
            ),
            .missed
        )
    }

    func testWeeksGroupDaysInDateOrderAndKeepUnscheduledSessionsSeparate() {
        let late = progress(name: "Late", week: 0, workout: 2, date: date(2026, 7, 20, 8))
        let first = progress(name: "First", week: 0, workout: 0, date: date(2026, 7, 18, 8))
        let secondSameDay = progress(name: "Second", week: 0, workout: 1, date: date(2026, 7, 18, 18))
        let unscheduled = progress(name: "Unscheduled", week: 1, workout: 0, date: nil)

        let weeks = PlanCalendarBuilder.weeks(
            for: [late, secondSameDay, unscheduled, first],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(weeks.map(\.weekIndex), [0, 1])
        XCTAssertEqual(weeks[0].days.map(\.date), [date(2026, 7, 18, 0), date(2026, 7, 20, 0)])
        XCTAssertEqual(weeks[0].days[0].entries.map(\.workoutName), ["First", "Second"])
        XCTAssertEqual(weeks[1].unscheduledEntries.map(\.workoutName), ["Unscheduled"])
    }

    func testRescheduledSessionStaysInItsProgramWeekSection() {
        let rescheduled = progress(
            name: "Week 1 moved",
            week: 0,
            workout: 0,
            date: date(2026, 7, 25, 8)
        )
        let nativeWeekTwo = progress(
            name: "Week 2 native",
            week: 1,
            workout: 0,
            date: date(2026, 7, 25, 18)
        )

        let weeks = PlanCalendarBuilder.weeks(
            for: [nativeWeekTwo, rescheduled],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(weeks.map(\.weekIndex), [0, 1])
        XCTAssertEqual(weeks[0].days.first?.date, date(2026, 7, 25, 0))
        XCTAssertEqual(weeks[0].days.first?.entries.map(\.workoutName), ["Week 1 moved"])
        XCTAssertEqual(weeks[1].days.first?.entries.map(\.workoutName), ["Week 2 native"])
    }

    func testDuplicateSameDayEntriesUseOriginalPlanOrder() {
        let laterPlanEntry = progress(
            name: "Later plan entry",
            week: 0,
            workout: 2,
            date: date(2026, 7, 18, 18)
        )
        let earlierPlanEntry = progress(
            name: "Earlier plan entry",
            week: 0,
            workout: 1,
            date: date(2026, 7, 18, 8)
        )

        let weeks = PlanCalendarBuilder.weeks(
            for: [laterPlanEntry, earlierPlanEntry],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(weeks.count, 1)
        XCTAssertEqual(weeks[0].days.first?.entries.map(\.workoutName), ["Earlier plan entry", "Later plan entry"])
    }

    func testReschedulingAffordanceMatchesCoordinatorLockingRule() {
        XCTAssertTrue(entry(status: .upcoming).isReschedulable)
        XCTAssertTrue(entry(status: .available).isReschedulable)
        XCTAssertTrue(entry(status: .upcoming, scheduledDate: date(2026, 7, 15, 9)).isReschedulable)
        XCTAssertFalse(entry(status: .inProgress).isReschedulable)
        XCTAssertFalse(entry(status: .completed).isReschedulable)
        XCTAssertFalse(entry(status: .skipped).isReschedulable)
    }

    private func displayState(_ status: PlanWorkoutStatus, _ scheduledDate: Date?) -> PlanCalendarDisplayState {
        PlanCalendarBuilder.displayState(
            status: status,
            scheduledDate: scheduledDate,
            today: today,
            calendar: calendar
        )
    }

    private func entry(
        status: PlanWorkoutStatus,
        scheduledDate: Date? = nil
    ) -> PlanCalendarEntry {
        let item = progress(name: "Workout", week: 0, workout: 0, date: scheduledDate)
        item.status = status
        return try! XCTUnwrap(
            PlanCalendarBuilder.weeks(for: [item], today: today, calendar: calendar)
                .first?
                .days
                .first?
                .entries
                .first
                ?? PlanCalendarBuilder.weeks(for: [item], today: today, calendar: calendar)
                    .first?
                    .unscheduledEntries
                    .first
        )
    }

    private func progress(name: String, week: Int, workout: Int, date: Date?) -> PlanWorkoutProgress {
        PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: name,
            weekIndex: week,
            workoutIndex: workout,
            scheduledDate: date
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
