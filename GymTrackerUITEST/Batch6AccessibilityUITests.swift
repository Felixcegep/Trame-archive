import XCTest

final class Batch6AccessibilityUITests: GymTrackerUITestCase {
    func testExerciseReorderMenuPersistsOrderAndExposesOnlyValidDirections() {
        let app = launchFixture("active-superset")
        tapButton("exercise-menu-Bench Press", in: app)
        XCTAssertFalse(app.buttons["move-exercise-up-Bench Press"].exists)
        XCTAssertTrue(app.buttons["move-exercise-down-Bench Press"].waitForExistence(timeout: 5))
        app.buttons["move-exercise-down-Bench Press"].tap()

        let benchMenu = app.buttons["exercise-menu-Bench Press"]
        XCTAssertTrue(benchMenu.waitForExistence(timeout: 5))
        benchMenu.tap()
        XCTAssertTrue(app.buttons["move-exercise-up-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["move-exercise-down-Bench Press"].exists)

        let bench = app.descendants(matching: .any)["active-exercise-Bench Press"]
        let row = app.descendants(matching: .any)["active-exercise-Barbell Row"]
        XCTAssertTrue(bench.exists)
        XCTAssertTrue(row.exists)
        XCTAssertGreaterThan(bench.frame.minY, row.frame.minY)

        app.buttons["move-exercise-up-Bench Press"].tap()
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["active-exercise-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.descendants(matching: .any)["active-exercise-Bench Press"].frame.minY,
            app.descendants(matching: .any)["active-exercise-Barbell Row"].frame.minY
        )
    }
}
