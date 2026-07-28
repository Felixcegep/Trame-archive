import XCTest

/// Canonical visual states for the derived Plan Path. The two fixtures encode
/// lifecycle and occurrence history directly, so these captures do not create
/// or advance a workout journey just to reach a visual state.
final class ProgramPathScreenshotUITests: GymTrackerUITestCase {
    func testCaptureProgramPathFixedScreenshots() {
        let app = launchFixture(
            "program-path-fixed",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        // The entry is visible UI added to the existing Current Plan card; it
        // is captured before navigation so the destination's state remains a
        // separate, scannable image.
        selectTab(.train, in: app)
        XCTAssertTrue(app.buttons["current-plan-program-path"].waitForExistence(timeout: 10))
        saveScreenshot("overview/01j_Home_Program_Path")

        tapButton("current-plan-program-path", in: app)
        let path = app.descendants(matching: .any)["program-path-fixed-screen"]
        XCTAssertTrue(path.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-current-session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-deload"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13o_Program_Path_Fixed")

        let reschedule = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@",
                "program-path-session-reschedulable",
                "Moved from"
            )
        ).firstMatch
        scrollToElement(reschedule, in: app)
        reschedule.tap()
        XCTAssertTrue(app.datePickers["plan-reschedule-date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["program-path-confirm-reschedule"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13p_Program_Path_Reschedule")
    }

    func testCaptureProgramPathRotationScreenshot() {
        let app = launchFixture(
            "program-path-rotation",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )

        selectTab(.train, in: app)
        tapButton("current-plan-program-path", in: app)
        let path = app.descendants(matching: .any)["program-path-rotation-screen"]
        XCTAssertTrue(path.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-rotation-cursor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-slot-cursor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-slot-completed"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22d_Repeating_Plan_Path")
    }

    private func saveScreenshot(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let environment = ProcessInfo.processInfo.environment
        let defaultDirectory = "/Users/felixlachapelle/Desktop/GymTracker/Screenshots"
        let directory = environment["SCREENSHOT_OUTPUT_DIR"] ?? defaultDirectory
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("\(name).png")

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: fileURL)
            print("Saved screenshot to \(fileURL.path)")
        } catch {
            XCTFail("Failed to save screenshot '\(name)': \(error)", file: file, line: line)
        }
    }
}
