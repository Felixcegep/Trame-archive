import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class TodayFoundationTests: XCTestCase {
    func testLocalDayUsesProvidedCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 60 * 60)!
        let date = Date(timeIntervalSince1970: 1_735_700_400) // 2025-01-01 01:00 UTC

        XCTAssertEqual(LocalDay(date: date, calendar: calendar).rawValue, "2024-12-31")
    }

    func testTodaySummaryUsesActiveWorkoutBeforePlan() {
        let workout = Workout(name: "Upper Body")
        let summary = TodayWorkoutSummary.resolve(
            activeWorkout: workout,
            activePlanRun: nil,
            nextPlanProgress: nil
        )

        XCTAssertEqual(summary.kind, .active)
        XCTAssertEqual(summary.title, "Resume Upper Body")
    }

    func testBackupRoundTripsDailyCheckInAndCreatineOccurrence() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let day = LocalDay(rawValue: "2026-07-20")
        let entry = DailyLogEntry(
            day: day,
            sleepQuality: 4,
            energy: 3,
            workoutDifficulty: 2,
            note: "Felt steady."
        )
        let creatine = SupplementOccurrence(kind: .creatine, day: day)
        source.insert(entry)
        source.insert(creatine)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let restoredEntry = try XCTUnwrap(restored.fetch(FetchDescriptor<DailyLogEntry>()).first)
        let restoredCreatine = try XCTUnwrap(restored.fetch(FetchDescriptor<SupplementOccurrence>()).first)
        XCTAssertEqual(restoredEntry.dayKey, day.rawValue)
        XCTAssertEqual(restoredEntry.note, "Felt steady.")
        XCTAssertEqual(restoredCreatine.occurrenceKey, "2026-07-20|creatine")
        XCTAssertEqual(restoredCreatine.status, .completed)
    }

    func testClearAllGymDataRemovesTodayRecords() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        context.insert(DailyLogEntry())
        context.insert(SupplementOccurrence())
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyLogEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SupplementOccurrence>()).isEmpty)
    }

    func testBackupRejectsAnOutOfRangeCheckInScore() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        context.insert(DailyLogEntry(day: .today, sleepQuality: 6))
        try context.save()

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        XCTAssertThrowsError(try backup.validate())
    }

    func testBackupRejectsAnInvalidLocalDayKey() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        context.insert(DailyLogEntry(day: LocalDay(rawValue: "not-a-day")))
        try context.save()

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        XCTAssertThrowsError(try backup.validate())
    }
}
