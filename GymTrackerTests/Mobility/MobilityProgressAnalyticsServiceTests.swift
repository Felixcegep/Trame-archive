import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class MobilityProgressAnalyticsServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    func testLoaderFetchesGraphAndShapesEveryProgressMetric() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sessionDate = date(2026, 8, 10, 9)
        let session = MobilitySession(nameSnapshot: "Development", startTime: sessionDate)
        session.status = .completed
        session.endTime = sessionDate.addingTimeInterval(300)

        let entry = makeEntry(trackingType: .duration, side: .bilateral)
        let left = makeResult(side: .left, duration: 30)
        let right = makeResult(side: .right, duration: 45)
        entry.results = [left, right]
        entry.session = session
        session.entries = [entry]
        let leftEvidence = makeEvidence(resultID: left.id, entryID: entry.id, purpose: .flexibilityDevelopment)
        let rightEvidence = makeEvidence(resultID: right.id, entryID: entry.id, purpose: .flexibilityDevelopment)

        context.insert(session)
        context.insert(leftEvidence)
        context.insert(rightEvidence)
        try context.save()

        let analytics = try MobilityProgressAnalyticsService(modelContext: context).analytics(
            referenceDate: date(2026, 8, 12, 12),
            weekCount: 3,
            calendar: calendar
        )

        XCTAssertEqual(analytics.weeklyFrequency.count, 3)
        XCTAssertEqual(analytics.weeklyFrequency.last?.sessionCount, 1)
        XCTAssertEqual(analytics.holdTimeTrend.map(\.totalSeconds), [75])
        XCTAssertEqual(analytics.sideSymmetry.count, 1)
        XCTAssertEqual(analytics.sideSymmetry.first?.leftValue, 30)
        XCTAssertEqual(analytics.sideSymmetry.first?.rightValue, 45)
        XCTAssertEqual(analytics.sideSymmetry.first?.absoluteDifference, 15)
        XCTAssertEqual(analytics.stopSignalCounts.map(\.count), [0, 0, 0])
    }

    func testStopSignalCountsIncludeStoppedSafetySessionWithoutInflatingTrainingTrends() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sessionDate = date(2026, 8, 11, 9)
        let session = MobilitySession(nameSnapshot: "Stopped", startTime: sessionDate)
        session.status = .stopped
        session.endTime = sessionDate.addingTimeInterval(20)

        let entry = makeEntry(trackingType: .duration, side: .left)
        let result = makeResult(side: .left, duration: 20, status: .stopped)
        entry.results = [result]
        entry.session = session
        session.entries = [entry]
        let evidence = makeEvidence(resultID: result.id, entryID: entry.id, sensation: .pain)

        context.insert(session)
        context.insert(evidence)
        try context.save()

        let analytics = try MobilityProgressAnalyticsService(modelContext: context).analytics(
            referenceDate: date(2026, 8, 12, 12),
            weekCount: 2,
            calendar: calendar
        )

        XCTAssertEqual(analytics.stopSignalCounts.map(\.count), [0, 1])
        XCTAssertTrue(analytics.weeklyFrequency.allSatisfy { $0.sessionCount == 0 })
        XCTAssertTrue(analytics.holdTimeTrend.isEmpty)
        XCTAssertTrue(analytics.sideSymmetry.isEmpty)
    }

    func testSideSymmetryPureProjectionKeepsMissingSideMissing() {
        let session = MobilitySession(nameSnapshot: "One side", startTime: date(2026, 8, 10, 9))
        session.status = .completed
        let entry = makeEntry(trackingType: .repetitions, side: .left)
        let result = makeResult(side: .left, repetitions: 8)
        entry.results = [result]
        entry.session = session
        session.entries = [entry]
        let occurrence = MobilityAnalyticsOccurrence(session: session, entry: entry, result: result, evidence: nil)

        XCTAssertTrue(MobilityAnalyticsService.sideSymmetryHistory([occurrence]).isEmpty)
    }

    private func makeEntry(trackingType: MobilityTrackingType, side: MobilitySide) -> MobilityEntry {
        MobilityEntry(
            definitionIDSnapshot: UUID(),
            definitionNameSnapshot: "Test movement",
            instructionsSnapshot: nil,
            trackingType: trackingType,
            targetDurationSeconds: trackingType == .duration ? 30 : nil,
            targetRepetitions: trackingType == .repetitions ? 8 : nil,
            side: side,
            restSeconds: nil,
            notesSnapshot: nil,
            timerStartedAt: nil,
            orderIndex: 0,
            id: UUID()
        )
    }

    private func makeResult(
        side: MobilitySide,
        duration: Int? = nil,
        repetitions: Int? = nil,
        status: MobilityResultStatus = .completed
    ) -> MobilityResult {
        let result = MobilityResult(side: side, id: UUID())
        result.status = status
        result.performedDurationSeconds = duration
        result.performedRepetitions = repetitions
        return result
    }

    private func makeEvidence(
        resultID: UUID,
        entryID: UUID,
        purpose: MobilityTrainingPurpose? = nil,
        sensation: MobilitySensation? = nil
    ) -> MobilityResultEvidence {
        MobilityResultEvidence(
            resultID: resultID,
            entryIDSnapshot: entryID,
            side: .left,
            methodSnapshot: .staticPassive,
            purposeSnapshot: purpose,
            sensation: sensation
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
