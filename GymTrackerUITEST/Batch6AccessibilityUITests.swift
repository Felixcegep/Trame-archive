import XCTest

final class Batch6AccessibilityUITests: GymTrackerUITestCase {
    func testTrainRowsAndTabBarRemainReachableAtAccessibility3() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-reset-data",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
        ]
        app.launchWithGymTrackerUITestArguments()

        XCTAssertTrue(app.descendants(matching: .any)["app-preparing"].waitForNonExistence(timeout: 30))
        selectTab(.train, in: app)

        let plans = app.buttons["plans-browser"]
        let workouts = app.buttons["workouts-browser"]
        XCTAssertTrue(plans.waitForExistence(timeout: 10))
        XCTAssertTrue(workouts.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(plans.frame.height, 0)
        XCTAssertGreaterThan(workouts.frame.height, 0)
        XCTAssertTrue(app.buttons["tab-train"].isHittable)
    }

    func testExerciseReorderMenuPersistsOrderAndExposesOnlyValidDirections() {
        let app = launchFixture("active-superset")
        tapButton("exercise-actions-Bench Press", in: app)
        XCTAssertFalse(app.buttons["move-exercise-up-Bench Press"].exists)
        XCTAssertTrue(app.buttons["move-exercise-down-Bench Press"].waitForExistence(timeout: 5))
        tapControl("move-exercise-down-Bench Press", in: app)

        let bench = app.descendants(matching: .any)["active-exercise-Bench Press"]
        let row = app.descendants(matching: .any)["active-exercise-Barbell Row"]
        XCTAssertTrue(bench.exists)
        XCTAssertTrue(row.exists)
        XCTAssertGreaterThan(bench.frame.minY, row.frame.minY)

        tapButton("exercise-actions-Bench Press", in: app)
        XCTAssertTrue(app.buttons["move-exercise-up-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["move-exercise-down-Bench Press"].exists)
        tapControl("move-exercise-up-Bench Press", in: app)
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["active-exercise-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.descendants(matching: .any)["active-exercise-Bench Press"].frame.minY,
            app.descendants(matching: .any)["active-exercise-Barbell Row"].frame.minY
        )
    }
}
