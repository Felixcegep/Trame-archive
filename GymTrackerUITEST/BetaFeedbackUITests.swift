import XCTest

final class BetaFeedbackUITests: GymTrackerUITestCase {
    private func launchSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)

        let preparing = app.descendants(matching: .any)["app-preparing"]
        if preparing.exists {
            XCTAssertTrue(preparing.waitForNonExistence(timeout: 60))
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 45))
        return app
    }

    private func openBetaFeedback(in app: XCUIApplication) {
        let feedbackRow = app.descendants(matching: .any)["settings-beta-feedback"]
        scrollToElement(feedbackRow, in: app)
        feedbackRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["beta-feedback-screen"].waitForExistence(timeout: 5))
    }

    /// The feedback sheet's first row is a tall `TextEditor`, which
    /// intercepts a center-of-screen `swipeUp()` as its own (no-op) internal
    /// scroll instead of letting the outer Form scroll. Drag from well below
    /// it toward the top so the gesture starts outside its bounds.
    private func scrollFeedbackFormDown(in app: XCUIApplication, times: Int = 4) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<times {
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    func testOpeningSettingsShowsTheBetaFeedbackRow() {
        let app = launchSettings()
        let feedbackRow = app.descendants(matching: .any)["settings-beta-feedback"]
        scrollToElement(feedbackRow, in: app)
    }

    func testOpeningTheFeedbackSheetShowsTheDiagnosticsPreviewByDefault() {
        let app = launchSettings()
        openBetaFeedback(in: app)

        let toggle = app.switches["beta-feedback-diagnostics-toggle"]
        scrollFeedbackFormDown(in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1", "Diagnostics must be included by default.")
        XCTAssertTrue(app.staticTexts["App Version"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Screen"].exists)
    }

    func testDisablingDiagnosticsHidesThePreview() {
        let app = launchSettings()
        openBetaFeedback(in: app)

        let toggle = app.switches["beta-feedback-diagnostics-toggle"]
        scrollFeedbackFormDown(in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // Only the trailing switch control toggles a Form row like this; the
        // rest of the row (where a plain `.tap()` lands) is inert.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.staticTexts["App Version"].exists)
    }

    func testCancelDismissesWithoutSharing() {
        let app = launchSettings()
        openBetaFeedback(in: app)

        tapButton("beta-feedback-cancel", in: app)
        XCTAssertFalse(app.descendants(matching: .any)["beta-feedback-screen"].waitForExistence(timeout: 3))
    }

    func testShareButtonIsVisibleBeforeSharing() {
        let app = launchSettings()
        openBetaFeedback(in: app)

        XCTAssertTrue(app.buttons["beta-feedback-share"].waitForExistence(timeout: 5))
    }

    func testFeedbackPreviewIncludesAggregateActiveLoggingMetrics() {
        let app = launchFixture("active-in-progress")
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: true, in: app)
        tapButton("minimize-workout", in: app)
        XCTAssertTrue(app.buttons["resume-active-workout"].waitForExistence(timeout: 10))

        selectTab(.settings, in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        openBetaFeedback(in: app)
        scrollFeedbackFormDown(in: app)

        XCTAssertTrue(app.staticTexts["Set entry samples"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Median set entry"].exists)
        XCTAssertFalse(app.staticTexts["Bench Press"].exists)
    }
}
