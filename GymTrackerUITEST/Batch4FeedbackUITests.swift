import XCTest

final class Batch4FeedbackUITests: GymTrackerUITestCase {
    func testMobilityHoldShowsTargetReachedState() {
        let app = launchFixture(
            "mobility-active",
            expectsActiveWorkout: false,
            expectsMobilitySession: true
        )

        // The deterministic seed starts with a repetition-tracked movement;
        // advance to its 45-second hold so this test exercises the new state.
        tapButton("skip-mobility-movement", in: app)

        let targetReached = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Target reached'")
        ).firstMatch
        XCTAssertTrue(targetReached.waitForExistence(timeout: 55))
    }

    func testSaveSuccessDismissesReviewAndShowsHistoryEntry() {
        let app = launchFixture("active-partial-save")
        navigateToWorkoutFinish(in: app)
        tapButton("finish-workout", in: app)
        tapButton("save-workout", in: app)

        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        let savedBanner = app.descendants(matching: .any)["gym-status-banner"]
        XCTAssertTrue(savedBanner.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Workout saved'")
        ).firstMatch.exists)
        selectTab(.history, in: app)
        XCTAssertTrue(app.buttons["history-workout-row"].waitForExistence(timeout: 10))
    }
}
