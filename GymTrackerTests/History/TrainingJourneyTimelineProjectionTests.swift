import XCTest
@testable import GymTracker

final class TrainingJourneyTimelineProjectionTests: XCTestCase {
    func testOverlappingPlanChaptersUseDeterministicSublanesAndFreeLaneRemainsSeparate() {
        let fixedA = chapter(id: "fixed-a", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 10))
        let fixedB = chapter(id: "fixed-b", kind: .fixedPlan, start: date(2024, 1, 5), end: date(2024, 1, 12))
        let free = chapter(id: "free-a", kind: .freeTraining, start: date(2024, 1, 5), end: date(2024, 1, 6))

        let projection = project([free, fixedB, fixedA], reference: date(2024, 1, 12))
        let fixed = try! XCTUnwrap(projection.lanes.first { $0.lane == .fixedPlan })
        let freeLane = try! XCTUnwrap(projection.lanes.first { $0.lane == .freeTraining })

        XCTAssertEqual(fixed.segments.map(\.chapterID), ["fixed-a", "fixed-b"])
        XCTAssertEqual(fixed.segments.map(\.sublane), [0, 1])
        XCTAssertEqual(freeLane.segments.map(\.sublane), [0])
        XCTAssertEqual(freeLane.segments.first?.positionStart, fixed.segments[1].positionStart)

        let reordered = project([fixedA, free, fixedB], reference: date(2024, 1, 12))
        XCTAssertEqual(projection, reordered)
    }

    func testOpenCurrentChapterUsesReferenceDayAndRemainsOpen() {
        let current = chapter(
            id: "current",
            kind: .repeatingPlan,
            start: date(2024, 1, 10),
            end: nil,
            status: "In progress"
        )
        let projection = project([current], reference: date(2024, 1, 20))
        let segment = try! XCTUnwrap(projection.lanes.first { $0.lane == .repeatingPlan }?.segments.first)

        XCTAssertTrue(segment.isOpenEnded)
        XCTAssertEqual(segment.normalizedStart, date(2024, 1, 10))
        XCTAssertEqual(segment.normalizedEndExclusive, date(2024, 1, 21))
        XCTAssertEqual(segment.positionStart, 0)
        XCTAssertEqual(segment.positionEnd, 1)

        XCTAssertEqual(projection.selection(for: date(2024, 1, 20), calendar: utcCalendar).hits.map(\.chapterID), ["current"])
        XCTAssertTrue(projection.selection(for: date(2024, 1, 21), calendar: utcCalendar).hits.isEmpty)
    }

    func testLongHistoryUsesCalendarDurationAndYearMonthTicks() {
        let chapter = chapter(id: "long", kind: .fixedPlan, start: date(2020, 1, 1), end: date(2025, 1, 1))
        let projection = project([chapter], reference: date(2025, 1, 1))
        let segment = try! XCTUnwrap(projection.lanes.first { $0.lane == .fixedPlan }?.segments.first)

        XCTAssertEqual(segment.positionStart, 0)
        XCTAssertEqual(segment.positionEnd, 1)
        XCTAssertEqual(projection.ticks.filter { $0.kind == .year }.map(\.year), [2020, 2021, 2022, 2023, 2024, 2025])
        XCTAssertEqual(projection.ticks.filter { $0.kind == .month }.count, 61)
        XCTAssertEqual(projection.ticks.first?.id, "year|2020")
        XCTAssertEqual(projection.ticks[1].id, "month|2020-1")
    }

    func testGapsAreCalendarIntervalsPerSemanticLane() {
        let first = chapter(id: "first", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 2))
        let second = chapter(id: "second", kind: .fixedPlan, start: date(2024, 1, 5), end: date(2024, 1, 5))
        let projection = project([first, second], reference: date(2024, 1, 5))
        let fixed = try! XCTUnwrap(projection.lanes.first { $0.lane == .fixedPlan })

        XCTAssertEqual(fixed.gaps.count, 1)
        XCTAssertEqual(fixed.gaps[0].normalizedStart, date(2024, 1, 3))
        XCTAssertEqual(fixed.gaps[0].normalizedEndExclusive, date(2024, 1, 5))
        XCTAssertEqual(fixed.gaps[0].positionStart, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(fixed.gaps[0].positionEnd, 0.8, accuracy: 0.000_001)
    }

    func testExactCalendarBoundariesAreStartInclusiveAndEndExclusive() {
        let chapter = chapter(
            id: "boundary",
            kind: .freeTraining,
            start: date(2024, 2, 10),
            end: date(2024, 2, 12),
            workouts: 3,
            records: 1,
            mobility: 2,
            assessments: 1
        )
        let projection = project([chapter], reference: date(2024, 2, 12))

        XCTAssertEqual(projection.selection(for: date(2024, 2, 10), calendar: utcCalendar).hits.map(\.chapterID), ["boundary"])
        XCTAssertEqual(projection.selection(for: date(2024, 2, 12), calendar: utcCalendar).hits.map(\.chapterID), ["boundary"])
        XCTAssertTrue(projection.selection(for: date(2024, 2, 13), calendar: utcCalendar).hits.isEmpty)
        let hit = try! XCTUnwrap(projection.selection(for: date(2024, 2, 12), calendar: utcCalendar).hits.first)
        XCTAssertEqual(hit.completedWorkouts, 3)
        XCTAssertEqual(hit.personalRecords, 1)
        XCTAssertEqual(hit.mobilitySessions, 2)
        XCTAssertEqual(hit.assessments, 1)
    }

    func testStableIDsAndEmptyInputAreDeterministic() {
        let empty = project([], reference: date(2024, 1, 1))
        XCTAssertEqual(empty.lanes.count, TrainingJourneyTimelineLane.allCases.count)
        XCTAssertTrue(empty.lanes.allSatisfy { $0.segments.isEmpty && $0.gaps.isEmpty })
        XCTAssertTrue(empty.ticks.isEmpty)

        let chapter = chapter(id: "stable", kind: .fixedPlan, start: date(2024, 1, 1), end: date(2024, 1, 1))
        let projection = project([chapter], reference: date(2024, 1, 1))
        XCTAssertEqual(projection.lanes.first { $0.lane == .fixedPlan }?.segments.first?.id, "segment|stable|fixedPlan|0")
        XCTAssertEqual(projection.ticks.map(\.id), ["year|2024", "month|2024-1"])
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func project(
        _ chapters: [TrainingJourneyChapter],
        reference: Date
    ) -> TrainingJourneyTimelineProjection {
        TrainingJourneyTimelineProjectionService.project(
            chapters: chapters,
            calendar: utcCalendar,
            referenceDate: reference
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func chapter(
        id: String,
        kind: TrainingJourneyChapter.Kind,
        start: Date,
        end: Date?,
        status: String? = nil,
        workouts: Int = 0,
        records: Int = 0,
        mobility: Int = 0,
        assessments: Int = 0
    ) -> TrainingJourneyChapter {
        TrainingJourneyChapter(
            id: id,
            kind: kind,
            title: id,
            start: start,
            end: end,
            statusText: status,
            completedWorkouts: workouts,
            personalRecords: records,
            mobilitySessions: mobility,
            assessments: assessments,
            disciplineDistribution: .empty
        )
    }
}
