import XCTest

/// End-to-end coverage for the read-only Plan Path surface. The fixtures own
/// the unusual lifecycle combinations here (for example an in-progress row
/// beside a future deload), so these tests exercise navigation and user-visible
/// output rather than recreating persistence setup through the UI.
final class ProgramPathUITests: GymTrackerUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFixedPathFromCurrentPlanCardShowsCurrentPositionAndDeload() {
        let app = launchFixture(
            "program-path-fixed",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        selectTab(.train, in: app)
        tapButton("current-plan-program-path", in: app)

        assertFixedPathHeader(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-path-current-session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-state-in-progress"].exists)
        XCTAssertTrue(app.staticTexts["Path Row Accessory"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["program-path-deload"].waitForExistence(timeout: 5))

        let unscheduled = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Path Pull Volume", "Unscheduled")
        ).firstMatch
        scrollToElement(unscheduled, in: app)
        XCTAssertTrue(unscheduled.exists)
    }

    func testFixedPathFromPlanDetailOpensHistoryScheduleAndReschedules() {
        let app = launchFixture(
            "program-path-fixed",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        openPlans(.following, in: app)
        tapButton("plan-row-Program Path Fixed Fixture", in: app)
        tapButton("view-plan-program-path", in: app)
        assertFixedPathHeader(in: app)

        // Plan Path owns no parallel calendar. Its schedule row must lead to
        // the existing date-oriented screen for this exact run.
        tapButton("program-path-open-schedule", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-path-fixed-screen"].waitForExistence(timeout: 5))

        // The completed session is a History destination, not a mutable plan
        // row. It must resolve the persisted completed-workout snapshot.
        let completed = app.buttons["program-path-session-completed"].firstMatch
        scrollToElement(completed, in: app)
        completed.tap()
        let completedWorkoutBar = app.navigationBars["Path Squat Strength"]
        XCTAssertTrue(
            completedWorkoutBar.waitForExistence(timeout: 5),
            app.debugDescription
        )
        completedWorkoutBar.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-path-fixed-screen"].waitForExistence(timeout: 5))

        // The fixture's available session is already moved from its original
        // date. Saving through the shared sheet verifies the path's mutation
        // bridge and preserves the visible provenance on return.
        let movedSession = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@",
                "program-path-session-reschedulable",
                "Moved from"
            )
        ).firstMatch
        scrollToElement(movedSession, in: app)
        movedSession.tap()
        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["plan-reschedule-date"].exists)
        tapButton("program-path-confirm-reschedule", in: app)
        // The sheet dismissal and the SwiftData projection update are
        // separate main-actor turns on iOS 26. Give the presentation owner
        // enough time to complete before asserting the return state.
        // The save callback is authoritative; the sheet may remain in the
        // accessibility tree during its dismissal animation. Verify the path
        // is visible again instead of asserting on that transient tree node.
        XCTAssertTrue(app.descendants(matching: .any)["program-path-fixed-screen"].waitForExistence(timeout: 10))

        let preservedMovedSession = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@",
                "program-path-session-reschedulable",
                "Moved from"
            )
        ).firstMatch
        XCTAssertTrue(preservedMovedSession.waitForExistence(timeout: 5))
    }

    func testRotationPathFromRepeatingPlanDetailShowsCursorHistoryAndStartsExpectedWorkout() {
        let app = launchFixture(
            "program-path-rotation",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )

        openPlans(.following, in: app)
        let rotation = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Program Path Rotation Fixture")
        ).firstMatch
        XCTAssertTrue(rotation.waitForExistence(timeout: 5))
        rotation.tap()
        tapButton("view-repeating-plan-program-path", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["program-path-rotation-screen"].waitForExistence(timeout: 5))
        let cursor = app.descendants(matching: .any)["program-path-rotation-cursor"]
        XCTAssertTrue(cursor.waitForExistence(timeout: 5))
        XCTAssertTrue(cursor.label.contains("Cycle 3"))
        XCTAssertTrue(cursor.label.contains("Workout 2 of 3"))
        XCTAssertTrue(app.descendants(matching: .any)["program-path-slot-cursor"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["program-path-slot-completed"].exists)

        let undone = app.descendants(matching: .any)["program-path-occurrence-undone"]
        scrollToElement(undone, in: app)
        XCTAssertTrue(undone.exists)
        let keepsExpected = app.staticTexts["The expected workout stayed next"].firstMatch
        scrollToElement(keepsExpected, in: app)
        XCTAssertTrue(keepsExpected.exists)

    }

    func testRotationPathStartsExpectedWorkout() {
        let app = launchFixture(
            "program-path-rotation",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )

        openPlans(.following, in: app)
        let rotation = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Program Path Rotation Fixture")
        ).firstMatch
        XCTAssertTrue(rotation.waitForExistence(timeout: 5))
        rotation.tap()
        tapButton("view-repeating-plan-program-path", in: app)

        let start = app.descendants(matching: .any)["program-path-start-rotation-workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription)
        start.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Path Rotation Squat"].waitForExistence(timeout: 5))
    }
}

private extension ProgramPathUITests {
    func assertFixedPathHeader(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.descendants(matching: .any)["program-path-fixed-screen"].waitForExistence(timeout: 5),
            file: file,
            line: line
        )
        let header = app.descendants(matching: .any)["program-path-header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(header.label.contains("Program Path Fixed Fixture"), file: file, line: line)
        XCTAssertTrue(header.label.contains("Block 2 of 4"), file: file, line: line)
        XCTAssertTrue(header.label.contains("Week 2 of 4"), file: file, line: line)
        XCTAssertTrue(header.label.contains("Session 2 of 2"), file: file, line: line)
    }
}
