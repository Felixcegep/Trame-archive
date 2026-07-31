import XCTest

final class MobilityAssessmentUITests: GymTrackerUITestCase {
    func testPrimaryAndAssessmentHistory() {
        let app = launchFixture(
            "mobility-assessment-history",
            expectsActiveWorkout: false
        )
        openMobilityHub(in: app)

        let assessmentHistory = app.descendants(matching: .any)[
            "open-mobility-assessment-history-from-hub"
        ]
        scrollToElement(assessmentHistory, in: app)
        assessmentHistory.tap()
        XCTAssertTrue(app.navigationBars["Assessment history"].waitForExistence(timeout: 5))
        XCTAssertEqual(historySessionRows(in: app).count, 1)

        selectTab(.progress, in: app)
        let progressHistory = app.descendants(matching: .any)["progress-mobility-assessment-history"]
        XCTAssertTrue(progressHistory.waitForExistence(timeout: 5))
        XCTAssertTrue(progressHistory.label.contains("1"), "A zero-result sitting must not be counted")
        progressHistory.tap()
        XCTAssertTrue(app.navigationBars["Assessment history"].waitForExistence(timeout: 5))
        XCTAssertEqual(historySessionRows(in: app).count, 1)
    }

    func testHubCardResumesInProgressAssessment() {
        let app = launchFixture(
            "mobility-assessment-in-progress",
            expectsActiveWorkout: false
        )
        openMobilityHub(in: app)

        tapButton("resume-mobility-assessment-from-hub", in: app)
        XCTAssertTrue(app.navigationBars["Assessment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["mobility-assessment-progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Choose assessments"].exists)
    }

    func testCaptureMobilityHubCards() {
        let empty = launchFreshApp()
        openMobilityHub(in: empty)
        XCTAssertTrue(empty.buttons["open-mobility-assessment"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18e_Mobility_Hub_Card_Empty")

        let recorded = launchFixture("mobility-assessment-recorded", expectsActiveWorkout: false)
        openMobilityHub(in: recorded)
        XCTAssertTrue(recorded.buttons["open-mobility-assessment"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18f_Mobility_Hub_Card_Recorded")

        let inProgress = launchFixture("mobility-assessment-in-progress", expectsActiveWorkout: false)
        openMobilityHub(in: inProgress)
        XCTAssertTrue(inProgress.buttons["resume-mobility-assessment-from-hub"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18g_Mobility_Hub_Card_InProgress")
    }

    func testCaptureAssessmentFlow() {
        let app = launchFreshApp()
        openMobilityHub(in: app)
        tapButton("open-mobility-assessment", in: app)
        XCTAssertTrue(app.navigationBars["Assessment"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21_Assessment_Landing_Empty")

        tapButton("start-mobility-assessment", in: app)
        XCTAssertTrue(app.navigationBars["Choose assessments"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21b_Assessment_Selection")

        tapButton("toggle-all-mobility-assessments", in: app)
        tapButton("mobility-assessment-select-mobility-assessment.thoracic-rotation-seated", in: app)
        let beginAssessment = app.buttons["begin-mobility-assessment"]
        scrollToElement(beginAssessment, in: app)
        beginAssessment.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobility-assessment-progress"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21c_Assessment_Instruction")

        tapButton("record-mobility-assessment-result", in: app)
        XCTAssertTrue(app.textFields["mobility-assessment-value-left"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21d_Assessment_Manual_Entry")

        let left = app.textFields["mobility-assessment-value-left"]
        left.tap()
        left.typeText("45")
        let right = app.textFields["mobility-assessment-value-right"]
        right.tap()
        right.typeText("38")
        tapButton("save-mobility-assessment-result", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["mobility-assessment-side-difference"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21e_Assessment_Confirmation")

        tapButton("mobility-assessment-next", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["mobility-assessment-summary"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21f_Assessment_Summary")
        tapButton("finish-mobility-assessment", in: app)
    }

    func testCaptureAssessmentLandingAndHistoryDetail() {
        let landing = launchFixture("mobility-assessment-recorded", expectsActiveWorkout: false)
        openMobilityHub(in: landing)
        tapButton("open-mobility-assessment", in: landing)
        XCTAssertTrue(landing.navigationBars["Assessment"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21a_Assessment_Landing_Recorded")

        let history = launchFixture("mobility-assessment-history-detail", expectsActiveWorkout: false)
        openMobilityHub(in: history)
        let historyLink = history.descendants(matching: .any)[
            "open-mobility-assessment-history-from-hub"
        ]
        scrollToElement(historyLink, in: history)
        historyLink.tap()
        let session = historySessionRows(in: history).firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        session.tap()
        XCTAssertTrue(history.navigationBars["Assessment"].waitForExistence(timeout: 5))
        saveScreenshot("mobility-assessment/21g_Assessment_History_Detail")
    }

    private func openMobilityHub(in app: XCUIApplication) {
        selectTab(.train, in: app)
        tapButton("train-mobility-library", in: app)
        XCTAssertTrue(app.navigationBars["Mobility"].waitForExistence(timeout: 5))
    }

    private func historySessionRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "mobility-assessment-history-session-")
        )
    }

    private func saveScreenshot(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let environment = ProcessInfo.processInfo.environment
        let directory = environment["SCREENSHOT_OUTPUT_DIR"]
            ?? "/Users/felixlachapelle/Desktop/GymTracker/Screenshots"
        let fileURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("\(name).png")

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
