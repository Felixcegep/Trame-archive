import XCTest
@testable import GymTracker

final class TodayMobilityRowPolicyTests: XCTestCase {
    func testTodayDoesNotChooseAvailableRoutineDuringActiveWorkout() {
        XCTAssertFalse(
            TodayMobilityRowPolicy.shouldShowRow(
                hasActiveMobilitySession: false
            )
        )
    }

    func testTodayDoesNotChooseStandaloneRoutineWithoutActiveWorkout() {
        XCTAssertFalse(
            TodayMobilityRowPolicy.shouldShowRow(
                hasActiveMobilitySession: false
            )
        )
    }

    func testActiveMobilitySessionCanAlwaysBeResumed() {
        XCTAssertTrue(
            TodayMobilityRowPolicy.shouldShowRow(
                hasActiveMobilitySession: true
            )
        )
    }
}
