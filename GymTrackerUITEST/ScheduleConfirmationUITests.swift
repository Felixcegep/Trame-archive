import XCTest

final class ScheduleConfirmationUITests: GymTrackerUITestCase {
    func testPostponeShowsTransientConfirmation() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        tapButton("today-postpone-planned-workout", in: app)
        XCTAssertTrue(app.staticTexts["Moved to tomorrow."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["gym-status-banner"].exists)
    }

    func testRescheduleNamesChosenDateInConfirmation() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        tapButton("today-reschedule-planned-workout", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForExistence(timeout: 5))
        let datePicker = app.datePickers["today-reschedule-date"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        datePicker.tap()
        let tomorrowLabel = tomorrow.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let tomorrowButton = app.buttons[tomorrowLabel]
        XCTAssertTrue(tomorrowButton.waitForExistence(timeout: 5))
        tomorrowButton.tap()
        let dismissDatePicker = app.buttons["PopoverDismissRegion"]
        if dismissDatePicker.exists {
            dismissDatePicker.tap()
        }
        let save = app.buttons["today-confirm-reschedule"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        save.tap()

        let banner = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Moved to '")
        ).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
    }

    func testCancelSkipDoesNotConfirmButCommittedSkipDoes() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        tapButton("today-skip-planned-workout", in: app)
        XCTAssertTrue(app.staticTexts["Skip this workout?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today-cancel-skip-workout"].waitForExistence(timeout: 10))
        app.buttons["today-cancel-skip-workout"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Skip this workout?"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["gym-status-banner"].exists)

        tapButton("today-skip-planned-workout", in: app)
        tapButton("today-confirm-skip-workout", in: app)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Workout skipped'")
        ).firstMatch.waitForExistence(timeout: 5))
    }

    func testScheduleConfirmationDoesNotPersistAcrossTabSwitch() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        tapButton("today-postpone-planned-workout", in: app)
        let banner = app.descendants(matching: .any)["gym-status-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))

        selectTab(.library, in: app)
        selectTab(.today, in: app)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
    }
}
