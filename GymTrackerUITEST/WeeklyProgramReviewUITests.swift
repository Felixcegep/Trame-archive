import XCTest

final class WeeklyProgramReviewUITests: GymTrackerUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWeeklyReviewOpensFromAllFixedRunEntryPoints() {
        let app = launchFixture(
            "program-path-fixed",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        selectTab(.train, in: app)
        openReview("current-plan-weekly-review", in: app)
        assertReviewHeaderAndSetSummary(in: app)
        app.navigationBars.buttons.firstMatch.tap()

        openPlans(.following, in: app)
        tapButton("plan-row-Program Path Fixed Fixture", in: app)
        openReview("view-plan-weekly-review", in: app)
        assertReviewHeaderAndSetSummary(in: app)
        app.navigationBars.buttons.firstMatch.tap()

        let programPath = app.buttons["view-plan-program-path"].firstMatch
        scrollToElement(programPath, in: app)
        programPath.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-path-fixed-screen"].waitForExistence(timeout: 8))
        openReview("program-path-weekly-review", in: app)
        assertReviewHeaderAndSetSummary(in: app)
    }

    func testCaptureWeeklyProgramReviewScreenshot() throws {
        let app = launchFixture(
            "program-path-fixed",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        selectTab(.train, in: app)
        openReview("current-plan-weekly-review", in: app)
        assertReviewHeaderAndSetSummary(in: app)

        let output = URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"]
                ?? "/Users/felixlachapelle/Desktop/GymTracker/Screenshots",
            isDirectory: true
        )
        let fileURL = output.appendingPathComponent("plans/13q_Weekly_Program_Review.png")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: fileURL)
    }

    private func openReview(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let entry = app.buttons[identifier].firstMatch
        scrollToElement(entry, in: app)
        XCTAssertTrue(entry.isHittable, "Expected \(identifier) to be hittable", file: file, line: line)
        entry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["weekly-review-screen"].waitForExistence(timeout: 8),
            app.debugDescription,
            file: file,
            line: line
        )
    }

    private func assertReviewHeaderAndSetSummary(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let header = app.descendants(matching: .any)["weekly-review-header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(header.label.contains("Program Path Fixed Fixture"), file: file, line: line)
        XCTAssertTrue(header.label.contains("Week 2"), file: file, line: line)

        let setSummary = app.descendants(matching: .any)["weekly-review-set-summary"]
        for _ in 0..<3 where !setSummary.exists {
            app.swipeUp()
        }
        XCTAssertTrue(setSummary.exists, file: file, line: line)
        XCTAssertTrue(setSummary.label.localizedCaseInsensitiveContains("prescribed sets"), file: file, line: line)
        XCTAssertTrue(setSummary.label.localizedCaseInsensitiveContains("performed sets"), file: file, line: line)
    }
}
