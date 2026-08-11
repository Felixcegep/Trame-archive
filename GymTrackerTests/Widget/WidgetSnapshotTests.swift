import Foundation
import XCTest
@testable import GymTracker

final class WidgetSnapshotTests: XCTestCase {
    func testMobilityProjectionPrefersActiveSessionAndPreservesWeeklyCount() {
        let now = Date(timeIntervalSince1970: 1_754_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let active = MobilityWidgetSessionSnapshot(
            state: .active,
            sessionID: UUID(),
            title: "Post-lift hips",
            currentEntryID: UUID(),
            currentMovementName: "90/90 switch",
            currentEntryNeedsRepetitions: false,
            completedEntryCount: 1,
            totalEntryCount: 3,
            startTime: now.addingTimeInterval(-300)
        )
        let completed = MobilityWidgetSessionSnapshot(
            state: .completed,
            sessionID: UUID(),
            title: "Warm-up",
            currentEntryID: nil,
            currentMovementName: nil,
            currentEntryNeedsRepetitions: nil,
            completedEntryCount: 2,
            totalEntryCount: 2,
            startTime: now.addingTimeInterval(-86_400)
        )

        let result = MobilityWidgetProjection.resolve(sessions: [completed, active], now: now, calendar: calendar)

        XCTAssertEqual(result.state, .activeSession)
        XCTAssertEqual(result.title, "Post-lift hips")
        XCTAssertEqual(result.currentMovementName, "90/90 switch")
        XCTAssertEqual(result.completedEntryCount, 1)
        XCTAssertEqual(result.totalEntryCount, 3)
        XCTAssertEqual(result.completedSessionCountThisWeek, 1)
        XCTAssertEqual(result.sessionID, active.sessionID)
        XCTAssertEqual(result.currentEntryID, active.currentEntryID)
    }

    func testOlderSnapshotWithoutMobilityDecodesAndEmptyProjectionIsTruthful() throws {
        let oldJSON = #"{"generatedAt":0,"today":{"state":"noWorkout","title":"","completedSetCount":0,"totalSetCount":0,"currentExerciseName":null},"weeklyVolume":{"completedWorkoutCount":0,"workingSetCount":0,"loadVolume":null,"unitSymbol":null},"caffeine":{"loggedMilligrams":0,"referenceMilligrams":null},"creatine":{"isConfirmed":false}}"#.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: oldJSON)

        let result = MobilityWidgetProjection.resolve(sessions: [], now: .now, calendar: .current)

        XCTAssertNil(snapshot.mobility)
        XCTAssertEqual(result.state, .noSession)
        XCTAssertEqual(result.completedSessionCountThisWeek, 0)
    }

    func testMobilityCompletionActionRequiresFreshExactNonRepetitionIdentity() {
        let now = Date(timeIntervalSince1970: 2_000)
        var data = MobilityWidgetData(
            state: .activeSession,
            title: "Hips",
            currentMovementName: "Hold",
            completedEntryCount: 0,
            totalEntryCount: 1,
            completedSessionCountThisWeek: 0,
            sessionID: UUID(),
            currentEntryID: UUID(),
            currentEntryNeedsRepetitions: false
        )

        XCTAssertTrue(MobilityWidgetActionPolicy.canOfferCompletion(data: data, generatedAt: now.addingTimeInterval(-30), now: now))
        XCTAssertFalse(MobilityWidgetActionPolicy.canOfferCompletion(data: data, generatedAt: now.addingTimeInterval(-301), now: now))
        data.currentEntryNeedsRepetitions = true
        XCTAssertFalse(MobilityWidgetActionPolicy.canOfferCompletion(data: data, generatedAt: now, now: now))
        data.currentEntryNeedsRepetitions = false
        data.currentEntryID = nil
        XCTAssertFalse(MobilityWidgetActionPolicy.canOfferCompletion(data: data, generatedAt: now, now: now))
    }
}
