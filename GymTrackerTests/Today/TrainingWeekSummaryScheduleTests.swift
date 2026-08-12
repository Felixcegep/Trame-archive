import XCTest
@testable import GymTracker

final class TrainingWeekSummaryScheduleTests: XCTestCase {
    func testScheduleMarksOnlyUntrainedTodayAndFutureDaysAndFindsNextBeyondWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let later = calendar.date(byAdding: .day, value: 10, to: today)!
        let completed = Workout(name: "Completed", endTime: now)
        completed.startTime = today

        let summary = TrainingWeekSummary.make(
            recentWorkoutsNewestFirst: [completed],
            scheduled: [
                .init(date: today, title: "Today plan"),
                .init(date: tomorrow, title: "Tomorrow plan"),
                .init(date: later, title: "Later plan")
            ],
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(summary.days.first(where: { $0.date == today })!.isScheduled)
        XCTAssertTrue(summary.days.first(where: { $0.date == tomorrow })!.isScheduled)
        XCTAssertEqual(summary.nextScheduled, .init(date: today, title: "Today plan"))
    }

    func testPastScheduleIsNotMarkedOrSelectedAsNext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let summary = TrainingWeekSummary.make(
            recentWorkoutsNewestFirst: [],
            scheduled: [.init(date: yesterday, title: "Past")],
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(summary.days.contains(where: \.isScheduled))
        XCTAssertNil(summary.nextScheduled)
    }
}
