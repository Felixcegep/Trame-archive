import XCTest
@testable import GymTracker

final class ScreenshotUITests: GymTrackerUITestCase {
    /// Walks the common Progress destinations from one deterministic history
    /// fixture so the hub, records, charts, volume evidence, and supporting
    /// history can be reviewed as one visual system. Two comparable Bench
    /// sessions also exercise the evidence-gated overview trend.
    func testCaptureProgressTabAnalysisScreenshots() {
        let app = launchFixture("performance-history-comparison", expectsActiveWorkout: false)
        selectTab(.progress, in: app)

        // A full `.descendants(.any)` snapshot can stall behind Swift Charts'
        // accessibility bridge on iOS 26. The native navigation bar is the
        // lightweight, user-visible sentinel for the completed tab change.
        let progressScreen = app.navigationBars["Progress"]
        XCTAssertTrue(progressScreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["progress-overview-current-period"].waitForExistence(timeout: 10))
        saveScreenshot("progress/03_Progress_Hub")

        // The chart publishes a single static accessibility summary instead of
        // exposing every mark. It is intentionally not a hittability sentinel;
        // visibility is enough for this visual capture.
        let earlyComparison = app.descendants(matching: .any)["progress-overview-featured-trend-chart"]
        scrollToVisibleElement(earlyComparison, in: app)
        XCTAssertTrue(earlyComparison.waitForExistence(timeout: 10))
        // The identifier covers the whole tappable evidence panel, so its top
        // can intersect the viewport while the actual plot is still below the
        // floating tab bar. Advance one viewport for the plot-specific frame.
        app.swipeUp()
        saveScreenshot("progress/03n_Exercise_Early_Comparison")

        captureProgressDestination(
            "progress-workout-history",
            expected: "history-screen",
            screenshot: "progress/03i_Training_History",
            in: app
        )
        let tools = app.buttons["progress-tools-disclosure"].firstMatch
        scrollToVisibleElement(tools, in: app)
        XCTAssertTrue(tools.isHittable)
        tools.tap()
        XCTAssertTrue(app.descendants(matching: .any)["progress-records"].waitForExistence(timeout: 5))
        captureProgressDestination(
            "progress-records",
            expected: "history-screen",
            screenshot: "progress/03j_Records",
            in: app
        )

        openProgressDestination("progress-training-trends", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["training-frequency-chart"].waitForExistence(timeout: 10))
        saveScreenshot("progress/03k_Exercise_Trends")
        returnToProgressHub(in: app)

        openProgressDestination("progress-muscle-group-volume", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-chart"].waitForExistence(timeout: 10))
        saveScreenshot("progress/03l_Muscle_Group_Volume")
        returnToProgressHub(in: app)

        openProgressDestination("progress-supporting-history-mobility", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["supporting-history-screen"].waitForExistence(timeout: 10))
        saveScreenshot("progress/03m_Supporting_History")
    }

    private func captureProgressDestination(
        _ identifier: String,
        expected expectedIdentifier: String,
        screenshot: String,
        in app: XCUIApplication
    ) {
        openProgressDestination(identifier, in: app)
        XCTAssertTrue(app.descendants(matching: .any)[expectedIdentifier].waitForExistence(timeout: 10))
        saveScreenshot(screenshot)
        returnToProgressHub(in: app)
    }

    private func openProgressDestination(_ identifier: String, in app: XCUIApplication) {
        let destination = app.descendants(matching: .any)[identifier]
        scrollToElement(destination, in: app)
        XCTAssertTrue(destination.waitForExistence(timeout: 10))
        destination.tap()
    }

    private func returnToProgressHub(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 10))
    }

    /// One deterministic path covers the Athlete Intelligence hierarchy and a
    /// snapshot-backed sport lens without exercising unrelated destinations.
    func testCaptureAthleteIntelligenceHubScreenshots() {
        let app = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: app)

        let globalOverview = app.descendants(matching: .any)["progress-overview-current-period"]
        XCTAssertTrue(globalOverview.waitForExistence(timeout: 10))
        scrollToVisibleElement(globalOverview, in: app)
        saveScreenshot("overview/03g_Progress_Global_Populated")

        tapControl("progress-sport-lens-picker", in: app)
        let strengthLens = app.descendants(matching: .any)["progress-lens-generalStrength"].firstMatch
        XCTAssertTrue(strengthLens.waitForExistence(timeout: 5))
        strengthLens.tap()
        XCTAssertTrue(app.descendants(matching: .any)["progress-sport-lens-generalStrength"].waitForExistence(timeout: 5))
        saveScreenshot("overview/03h_Progress_General_Strength_Lens")
    }

    /// Captures the complete first-run decision path before and after UI
    /// changes. The selected answers are deliberately ordinary so this remains
    /// a representative product audit, not a special-case fixture.
    func testCaptureOnboardingJourneyScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-show-welcome"]
        app.launchWithGymTrackerUITestArguments()

        XCTAssertTrue(app.descendants(matching: .any)["welcome"].waitForExistence(timeout: 30))
        settleOnboardingCapture()
        saveScreenshot("onboarding/00_Welcome")

        tapButton("welcome-follow-plan", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-step-discipline"].waitForExistence(timeout: 10))
        settleOnboardingCapture()
        saveScreenshot("onboarding/01_Discipline")

        tapButton("onboarding-discipline-generalStrength", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-step-goal"].waitForExistence(timeout: 10))
        settleOnboardingCapture()
        saveScreenshot("onboarding/02_Goal")

        tapButton("onboarding-goal-getStronger", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-step-experience"].waitForExistence(timeout: 10))
        settleOnboardingCapture()
        saveScreenshot("onboarding/03_Experience")

        tapButton("onboarding-experience-experienced", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-step-frequency"].waitForExistence(timeout: 10))
        settleOnboardingCapture()
        saveScreenshot("onboarding/03a_Frequency")

        tapButton("onboarding-frequency-4", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-step-equipment"].waitForExistence(timeout: 10))
        settleOnboardingCapture()
        saveScreenshot("onboarding/03b_Equipment")

        tapButton("onboarding-location-commercialGym", in: app)
        XCTAssertTrue(app.buttons["Confirm equipment"].waitForExistence(timeout: 10))
        app.buttons["Confirm equipment"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding-recommendations"].waitForExistence(timeout: 15))
        settleOnboardingCapture()
        saveScreenshot("onboarding/04_Recommendations")
    }

    func testCaptureWave1LightModeScreenshots() {
        let overview = launchFreshApp(additionalArguments: ["-appearance", "light"])
        saveScreenshot("overview/01_Today_Light")

        selectTab(.train, in: overview)
        saveScreenshot("overview/02_Train_Light")

        selectTab(.progress, in: overview)
        XCTAssertTrue(overview.descendants(matching: .any)["progress-screen"].waitForExistence(timeout: 5))
        saveScreenshot("overview/03_Progress_Empty_Light")

        selectTab(.today, in: overview)
        let openSettings = overview.buttons["open-settings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        openSettings.tap()
        XCTAssertTrue(overview.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        saveScreenshot("overview/04_Settings_Light")

        let active = launchFixture(
            "active-empty",
            additionalArguments: ["-appearance", "light"]
        )
        tapButton("minimize-workout", in: active)
        XCTAssertTrue(active.buttons["resume-active-workout"].waitForExistence(timeout: 10))
        saveScreenshot("overview/05_Home_With_Active_Workout_Light")

        let nutrition = launchFixture(
            "nutrition-today",
            additionalArguments: ["-appearance", "light"],
            expectsActiveWorkout: false,
            expectedHomeControl: "tab-nutrition"
        )
        selectTab(.nutrition, in: nutrition)
        XCTAssertTrue(nutrition.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        XCTAssertTrue(nutrition.descendants(matching: .any)["nutrition-today-totals"].waitForExistence(timeout: 5))
        XCTAssertTrue(nutrition.buttons["open-caffeine-log"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20_Nutrition_Today_Light")
    }

    func testCaptureLaunchBrandScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-hold-launch-experience"
        ]
        app.launchWithGymTrackerUITestArguments()

        // The animated canvas is intentionally decorative and does not always
        // publish its container identifier on iOS 26. The visible brand name
        // is the stable, user-facing completion signal.
        XCTAssertTrue(app.staticTexts["Trame"].waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(0.75))
        saveScreenshot("overview/00a_Launch_Brand")
    }

    /// New Workout and New Exercise are two mutually exclusive options of the
    /// same "Create library item" menu, both dismissible without saving, and
    /// hiding an exercise is the one destructive step — kept last so it
    /// cannot affect the exercises the earlier forms reference. One launch
    /// replaces what used to be three.
    func testCaptureLibraryFormsScreenshots() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("library-create", in: app)
        tapButton("new-workout-template", in: app)

        let nameField = app.textFields["template-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        let search = app.textFields["template-exercise-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Arnold Press")
        dismissTemplateExerciseSearchKeyboard(search, in: app)
        tapButton("template-exercise-Arnold Press", in: app)
        saveScreenshot("templates/12b_New_Workout_Form")

        tapButton("exercise-filters-button", in: app)
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        saveScreenshot("templates/12c_Exercise_Filters")
        tapFirstAvailableButton(["Done"], in: app)
        if app.keyboards.firstMatch.waitForExistence(timeout: 1) {
            dismissTemplateExerciseSearchKeyboard(search, in: app)
        }
        let cancel = app.navigationBars["New Workout"].buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        tapButton("confirm-discard-workout-template", in: app)
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5))

        tapButton("library-create", in: app)
        tapButton("new-exercise", in: app)

        let exerciseNameField = app.textFields["exercise-name-field"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5))
        saveScreenshot("exercises/18_New_Exercise_Form")

        tapButton("exercise-muscles-link", in: app)
        XCTAssertTrue(app.navigationBars["Muscles Worked"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18b_New_Exercise_Muscles")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tapButton("exercise-advanced-link", in: app)
        XCTAssertTrue(app.navigationBars["Logging & Classification"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18c_New_Exercise_Advanced")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Logging & Classification"].waitForNonExistence(timeout: 5))
        tapButton("Cancel", in: app)
        XCTAssertTrue(exerciseNameField.waitForNonExistence(timeout: 5))

        tapButton("exercises-browser", in: app)

        for _ in 0..<6 where !app.buttons["exercise-row-Bench Press"].firstMatch.isHittable {
            app.swipeUp(velocity: .slow)
        }
        let benchPress = app.buttons["exercise-row-Bench Press"].firstMatch
        XCTAssertTrue(benchPress.waitForExistence(timeout: 5))
        XCTAssertTrue(benchPress.isHittable)
        benchPress.press(forDuration: 1.2)
        tapButton("Hide", in: app)

        let statusAlert = app.alerts["Exercise Status"]
        XCTAssertTrue(statusAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(statusAlert.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "archived to preserve")
        ).firstMatch.exists)
        statusAlert.buttons["OK"].tap()
        XCTAssertTrue(statusAlert.waitForNonExistence(timeout: 5))

        let rowRemoved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: benchPress
        )
        XCTAssertEqual(XCTWaiter().wait(for: [rowRemoved], timeout: 5), .completed)

        // The context-menu interaction can leave the list scrolled, occluding
        // the Hidden Exercises row under the top edge. Re-query while returning
        // to the start because lazy rows are recycled during the scroll.
        for _ in 0..<8 where !app.buttons["hidden-exercises"].firstMatch.isHittable {
            app.swipeDown(velocity: .slow)
        }
        let hiddenExercises = app.buttons["hidden-exercises"].firstMatch
        XCTAssertTrue(hiddenExercises.waitForExistence(timeout: 5))
        XCTAssertTrue(hiddenExercises.isHittable)
        hiddenExercises.tap()
        XCTAssertTrue(app.navigationBars["Hidden Exercises"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restore-exercise-Bench Press"].exists)
        let historyNote = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "History remains unchanged")
        ).firstMatch
        XCTAssertTrue(historyNote.exists)

        saveScreenshot("exercises/16_Hidden_Exercises")
    }


    /// Today, the saved-workout picker, the Train secondary states, empty
    /// Progress, and Settings are five destinations of the exact same fresh
    /// seed, navigated by tab and sheet taps. One launch replaces what used
    /// to be three (the plain tab tour, the template sheet, and the Train
    /// secondary states, which were already three separate launches of this
    /// identical seed).
    func testCaptureOverviewAndLibraryTourScreenshots() {
        let app = launchFreshApp()

        saveScreenshot("overview/01_Today")

        let savedWorkouts = app.descendants(matching: .any)["today-open-saved-workouts"]
        scrollToElement(savedWorkouts, in: app)
        savedWorkouts.tap()
        XCTAssertTrue(app.navigationBars["Start workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01b_Home_Template_Sheet")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Start workout"].waitForNonExistence(timeout: 5))

        selectTab(.library, in: app)
        saveScreenshot("overview/02_Train")

        let workoutsBrowser = app.descendants(matching: .any)["workouts-browser"]
        XCTAssertTrue(workoutsBrowser.waitForExistence(timeout: 10))
        workoutsBrowser.tap()
        saveScreenshot("overview/02b_Train_Templates")
        app.navigationBars.buttons.firstMatch.tap()
        tapButton("plans-browser", in: app)
        saveScreenshot("overview/02c_Train_Plans")
        app.navigationBars.buttons.firstMatch.tap()
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("not-a-real-library-item")
        XCTAssertTrue(app.descendants(matching: .any)["train-search-empty"].waitForExistence(timeout: 5))
        saveScreenshot("overview/02d_Train_Empty_Search")

        // Submit the focused single-line search field to resign it. The
        // Simulator's alphabetic keyboard does not consistently expose a
        // queryable Return or Close key, so targeting a rendered keyboard
        // control makes this capture dependent on keyboard configuration.
        search.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        let clearSearch = app.buttons["Clear search"]
        if clearSearch.waitForExistence(timeout: 2) {
            clearSearch.tap()
        }

        selectTab(.progress, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["progress-screen"].waitForExistence(timeout: 5))
        saveScreenshot("overview/03_Progress_Empty")

        selectTab(.today, in: app)
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        let openSettings = app.buttons["open-settings"]
        XCTAssertTrue(openSettings.waitForExistence(timeout: 5))
        openSettings.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        saveScreenshot("overview/04_Settings")

        let populatedProgress = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: populatedProgress)
        XCTAssertTrue(populatedProgress.descendants(matching: .any)["progress-screen"].waitForExistence(timeout: 10))
        saveScreenshot("overview/03a_Progress_Populated")
        populatedProgress.terminate()
    }

    /// Capture the nested Settings destinations with deterministic navigation.
    func testCaptureSettingsShortcutsAndBetaFeedbackScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launchWithGymTrackerUITestArguments()

        tapButton("settings-advanced", in: app)
        let shortcutsLink = app.descendants(matching: .any)["settings-shortcuts-link"]
        XCTAssertTrue(shortcutsLink.waitForExistence(timeout: 5))
        scrollToElement(shortcutsLink, in: app)
        saveScreenshot("overview/04d_Settings_Shortcuts")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let feedbackRow = app.descendants(matching: .any)["settings-beta-feedback"]
        scrollToElement(feedbackRow, in: app)
        feedbackRow.tap()

        let feedbackScreen = app.descendants(matching: .any)["beta-feedback-screen"]
        XCTAssertTrue(feedbackScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["beta-feedback-diagnostics-preview"].exists)
        saveScreenshot("overview/04e_Settings_Beta_Feedback")
    }

    func testCaptureSettingsDataSafetyScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 45))
        tapButton("settings-data", in: app)
        let dataSafety = app.descendants(matching: .any)["settings-data-safety-last-export"]
        XCTAssertTrue(dataSafety.waitForExistence(timeout: 5))
        app.swipeUp()
        saveScreenshot("overview/04g_Settings_Data_Safety")

        tapButton("settings-export-data", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["backup-export-wizard"].waitForExistence(timeout: 5))
        saveScreenshot("overview/04h_Backup_Export_Wizard")
    }

    /// Coach Exchange is reached through the Progress hub rather than a
    /// capture-only launch destination. The first two frames intentionally
    /// show the untouched package selection state and then the local package
    /// builder after one deterministic definition has been selected.
    func testCaptureCoachExchangeScreenshots() {
        let app = launchFreshApp()
        selectTab(.progress, in: app)
        let tools = app.descendants(matching: .any)["progress-tools-disclosure"].firstMatch
        scrollToVisibleElement(tools, in: app)
        tools.tap()
        openProgressDestination("progress-coach-exchange", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["coach-exchange-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["coach-exchange-package-empty"].waitForExistence(timeout: 5))
        saveScreenshot("coach-exchange/23_Coach_Exchange_Empty")
        app.terminate()

        let builder = launchFixture(
            "coach-exchange",
            additionalArguments: [
                "-ui-testing-open-coach-exchange",
                "-ui-testing-coach-exchange-builder-expanded",
                "-ui-testing-coach-exchange-select-first",
                "-ui-testing-coach-exchange-build-first"
            ],
            expectsActiveWorkout: false,
            expectedHomeControl: "coach-exchange-screen"
        )
        XCTAssertTrue(builder.staticTexts["GymTracker"].waitForExistence(timeout: 10))
        saveScreenshot("coach-exchange/23a_Coach_Exchange_Package_Builder")
    }

    /// The app-side test hook named below must inject a deterministic package
    /// preview into CoachExchangeView. This keeps the capture independent of
    /// the system file picker while exercising the real conflict picker and
    /// atomic-application success state. The hook is intentionally not
    /// implemented in this UI-test target; it belongs to the app/bootstrap
    /// seam and is reported in the implementation handoff.
    func testCaptureCoachExchangeImportScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-coach-exchange-import-conflict"
        ]
        app.launchWithGymTrackerUITestArguments()

        let preview = app.descendants(matching: .any)["coach-exchange-import-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 30))
        let apply = app.buttons["coach-exchange-import-apply"]
        scrollToElement(apply, in: app)
        saveScreenshot("coach-exchange/23b_Coach_Exchange_Conflict_Preview")

        // The preview fixture defaults to the safest explicit decision: keep
        // the existing definition. Resolution variants are covered by the
        // atomic importer tests; this scene proves the visible conflict and
        // real application/success path without depending on menu internals.
        for _ in 0..<4 where !apply.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(
                    forDuration: 0.05,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
                )
        }
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        XCTAssertTrue(apply.isHittable)
        apply.tap()
        let success = app.descendants(matching: .any)["coach-exchange-import-success"]
        if !success.waitForExistence(timeout: 15) {
            let alert = app.alerts.firstMatch
            let detail = alert.exists
                ? alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
                : "No import error alert appeared."
            XCTFail("Coach import did not reach its success state. \(detail)")
        }
        // The success label replaces the button in-place. Re-scrolling here
        // with XCTest's hittability helper can move the short row under the
        // navigation material on iOS 26. Pull the content down slightly so the
        // completed state has breathing room beneath the title instead.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.34))
            .press(
                forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52))
            )
        // Allow the navigation bar and material layers to settle after the
        // atomic import redraw before recording the completion state.
        RunLoop.current.run(until: Date().addingTimeInterval(0.75))
        saveScreenshot("coach-exchange/23c_Coach_Exchange_Import_Complete")
    }

    /// The history fixture provides one completed, immutable chapter without
    /// recreating a workout through UI actions. Capture both supported Journey
    /// presentations so the timeline remains a first-class visual surface.
    func testCaptureTrainingJourneyScreenshots() {
        let app = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: app)
        let tools = app.buttons["progress-tools-disclosure"].firstMatch
        scrollToVisibleElement(tools, in: app)
        tools.tap()
        let journey = app.buttons["progress-training-journey"].firstMatch
        scrollToElement(journey, in: app)
        journey.tap()

        let chapter = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "training-journey-chapter-")
        ).firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        saveScreenshot("journey/24_Training_Journey_List")

        tapFirstAvailableButton(["Timeline", "Chronologie"], in: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.75))
        saveScreenshot("journey/24a_Training_Journey_Timeline")
    }

    /// The deterministic fixture contains made, partial, and missed completed
    /// attempts so the dashboard proves both full-lift evidence and the
    /// component-level evidence boundary.
    func testCaptureWeightliftingDashboardScreenshot() {
        let app = launchFixture(
            "weightlifting-dashboard",
            additionalArguments: ["-ui-testing-open-weightlifting"],
            expectsActiveWorkout: false,
            expectedHomeControl: "weightlifting-dashboard"
        )

        XCTAssertTrue(app.descendants(matching: .any)["weightlifting-dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["competition-attempts-snatch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["start-competition-day"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["weightlifting-attempt-summary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["weightlifting-component-outcomes-unknown"].waitForExistence(timeout: 10))
        saveScreenshot("progress/26_Weightlifting_Populated")

        tapControl("start-competition-day", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["active-workout-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Competition day"].waitForExistence(timeout: 5))
        saveScreenshot("progress/26a_Competition_Day_Active")
    }

    /// The progression-receipt fixture already owns a persisted recommendation
    /// ledger entry. Capture the list and its evidence/detail destination.
    func testCaptureProgressionLedgerScreenshots() {
        let app = launchFixture(
            "progression-receipt",
            additionalArguments: ["-ui-testing-open-training-ledger"],
            expectsActiveWorkout: false,
            expectedHomeControl: "progression-ledger-screen"
        )
        let receiptDone = app.buttons["Done"]
        if receiptDone.waitForExistence(timeout: 3) {
            receiptDone.tap()
        } else {
            let frenchDone = app.buttons["Terminé"]
            if frenchDone.waitForExistence(timeout: 1) { frenchDone.tap() }
        }

        XCTAssertTrue(app.descendants(matching: .any)["progression-ledger-screen"].waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "progression-ledger-row-")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        saveScreenshot("progression/25_Training_Ledger")

        row.tap()
        let detail = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "progression-ledger-detail-")
        ).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        saveScreenshot("progression/25a_Training_Ledger_Detail")
    }

    /// CE-05 owns a focused, shared execution surface rather than a second
    /// widget-side state graph. The existing fixtures provide a running
    /// execution block, a durable round transition (which also surfaces the
    /// existing rest state), and explicit complex-component outcomes.
    func testCaptureMixedWorkoutScreenshots() {
        let eyesUp = launchFixture("active-execution-block")
        // The Stage page contains the eyes-up card, but its container identifier
        // is intentionally not flattened through SwiftUI's containment tree.
        // Assert the visible hero identity and its primary action instead.
        XCTAssertTrue(eyesUp.staticTexts["Power circuit"].waitForExistence(timeout: 10))
        XCTAssertTrue(eyesUp.buttons["Complete round"].waitForExistence(timeout: 5))
        saveScreenshot("mixed-workout/27_Mixed_Eyes_Up_Runtime")

        // The block has two exercise components. The first action advances the
        // component cursor; the second closes the round and records the
        // round-completed split that starts the existing rest state.
        tapButton("Complete round", in: eyesUp)
        tapButton("Complete round", in: eyesUp)
        XCTAssertTrue(eyesUp.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 10))
        saveScreenshot("mixed-workout/27a_Mixed_Runtime_Split")

        let complex = launchFixture("active-complex-components")
        XCTAssertTrue(complex.staticTexts["Three-Position Snatch"].waitForExistence(timeout: 10))
        XCTAssertTrue(complex.buttons["complex-component-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(complex.buttons["complex-component-1"].exists)
        XCTAssertTrue(complex.buttons["complex-component-2"].exists)
        saveScreenshot("mixed-workout/27b_Mixed_Complex_Component_Evidence")
    }

    func testCaptureBetaFeedbackActiveLoggingScreenshot() {
        let app = launchFixture("active-in-progress")
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: true, in: app)
        tapButton("minimize-workout", in: app)
        XCTAssertTrue(app.buttons["resume-active-workout"].waitForExistence(timeout: 10))

        tapButton("open-settings", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let feedbackRow = app.descendants(matching: .any)["settings-beta-feedback"]
        scrollToElement(feedbackRow, in: app)
        feedbackRow.tap()

        // The feedback form begins with a tall `TextEditor`, so a regular
        // swipe starts in that editor instead of moving the outer Form. Drag
        // from below it to bring the aggregate-only rows into the capture.
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<4 {
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        let setEntrySamples = app.staticTexts["Set entry samples"]
        XCTAssertTrue(setEntrySamples.waitForExistence(timeout: 5))
        saveScreenshot("overview/04f_Settings_Beta_Feedback_Active_Logging")
    }

    /// One launch of "active-empty" plus one launch of "active-in-progress"
    /// drive every Active Workout overlay that fixture can reach through taps
    /// alone: the exercise picker, plate calculator, set details, the
    /// execution-block builder, and the discard confirmation. Three more
    /// fixtures cover states "active-in-progress" cannot reach by tapping
    /// (an active execution block, an advanced drop-set structure, an Olympic
    /// complex, an explicit substitution, a completed set, a superset, a
    /// collapsed completed exercise, and a partial save) — each is a distinct
    /// persisted graph, so it still needs its own launch, but all of them run
    /// inside this single test method instead of one method per fixture.
    func testCaptureActiveWorkoutStatesScreenshots() {
        let empty = launchFixture("active-empty")
        XCTAssertTrue(empty.descendants(matching: .any)["empty-workout-state"].waitForExistence(timeout: 10))
        XCTAssertTrue(empty.staticTexts["Add your first exercise"].waitForExistence(timeout: 2))
        XCTAssertTrue(empty.buttons["add-first-exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            empty.descendants(matching: .any)["add-first-mobility-empty"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(empty.descendants(matching: .any)["finish-summary"].exists)
        saveScreenshot("active-workout/05_Active_Workout_Empty")
        tapButton("minimize-workout", in: empty)
        XCTAssertTrue(empty.buttons["resume-active-workout"].waitForExistence(timeout: 10))
        XCTAssertFalse(empty.staticTexts["EXERCISES"].exists)
        saveScreenshot("overview/05_Home_With_Active_Workout")

        let inProgress = launchFixture("active-in-progress")
        tapButton("active-workout-menu", in: inProgress)
        tapButton("add-active-exercise-menu", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["exercise-picker-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.navigationBars["Add Exercise"].exists)
        saveScreenshot("active-workout/06_Add_Exercise_Sheet")
        tapButton("close-exercise-picker", in: inProgress)
        XCTAssertFalse(inProgress.descendants(matching: .any)["exercise-picker-screen"].waitForExistence(timeout: 2))
        // Plate calculation, set details, and the other per-set actions belong
        // to the set-entry panel, which opens when a value is selected.
        tapButton("weight-field-Bench Press-0", in: inProgress)
        tapButton("panel-chip-plates", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["plate-calculator-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.navigationBars["Plate calculator"].exists)
        saveScreenshot("active-workout/07_Plate_Calculator")
        tapFirstAvailableButton(["Done", "Terminé"], in: inProgress)
        tapButton("panel-details", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.staticTexts["Set 1"].exists)
        XCTAssertTrue(inProgress.sliders["rir-slider"].exists)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-advanced-options"].exists)
        XCTAssertFalse(inProgress.descendants(matching: .any)["set-method-picker"].exists)
        saveScreenshot("active-workout/07b_Set_Details")
        tapButton("close-set-details", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-details-screen"].waitForNonExistence(timeout: 5))
        dismissKeypadIfPresent(in: inProgress)

        tapButton("active-workout-menu", in: inProgress)
        tapButton("add-execution-block", in: inProgress)
        XCTAssertTrue(inProgress.navigationBars["Execution Block"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.buttons["create-execution-block"].exists)
        saveScreenshot("active-workout/07c_Execution_Block_Builder")
        tapButton("Cancel", in: inProgress)
        XCTAssertTrue(inProgress.navigationBars["Execution Block"].waitForNonExistence(timeout: 5))
        dismissKeypadIfPresent(in: inProgress)

        tapButton("active-workout-menu", in: inProgress)
        tapControl("discard-workout", in: inProgress)
        XCTAssertDiscardConfirmationVisible(in: inProgress)
        saveScreenshot("active-workout/08e_Discard_Workout")
        dismissDiscardConfirmation(in: inProgress)

        let executionBlockActive = launchFixture("active-execution-block")
        XCTAssertTrue(executionBlockActive.staticTexts["Power circuit"].waitForExistence(timeout: 10))
        XCTAssertTrue(executionBlockActive.buttons["Complete round"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/07d_Execution_Block_Active")

        let advancedSet = launchFixture("active-advanced-set")
        tapButton("reps-field-Bench Press-0", in: advancedSet)
        tapButton("panel-details", in: advancedSet)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["set-method-stage-hint"].waitForExistence(timeout: 5))
        // Advanced set methods are edited through the method-specific picker;
        // the redesigned sheet intentionally exposes it in this captured state.
        XCTAssertTrue(advancedSet.descendants(matching: .any)["set-method-picker"].exists)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["specialized-metric-picker"].exists)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["add-set-segment"].exists)
        saveScreenshot("active-workout/07e_Set_Method_Segments")

        let complexComponents = launchFixture("active-complex-components")
        XCTAssertTrue(complexComponents.staticTexts["Three-Position Snatch"].waitForExistence(timeout: 5))
        XCTAssertTrue(complexComponents.buttons["complex-component-0"].exists)
        XCTAssertTrue(complexComponents.buttons["complex-component-1"].exists)
        XCTAssertTrue(complexComponents.buttons["complex-component-2"].exists)
        saveScreenshot("active-workout/07f_Complex_Component_Results")

        let completedSet = launchFixture("active-completed-set")
        XCTAssertTrue(completedSet.buttons["complete-set-Bench Press-1"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08_Active_Workout_With_Set")

        let superset = launchFixture("active-superset")
        XCTAssertTrue(superset.staticTexts["superset-label-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(superset.staticTexts["superset-label-Barbell Row"].exists)
        saveScreenshot("active-workout/08k_Active_Superset")

        let collapsed = launchFixture("active-completed-exercise")
        XCTAssertTrue(collapsed.buttons["complete-set-Barbell Row-0"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08d_Completed_Exercise_Collapsed")

        let partial = launchFixture("active-partial-save")
        navigateToWorkoutFinish(in: partial)
        tapButton("finish-workout", in: partial)
        XCTAssertTrue(partial.descendants(matching: .any)["workout-sport-section"].waitForExistence(timeout: 5))
        saveScreenshot("review/09_Save_Workout")

        let bodyweight = launchFixture("active-bodyweight-save")
        navigateToWorkoutFinish(in: bodyweight)
        tapButton("finish-workout", in: bodyweight)
        XCTAssertTrue(bodyweight.descendants(matching: .any)["body-weight-prompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(bodyweight.descendants(matching: .any)["workout-sport-section"].exists)
        saveScreenshot("review/09d_Bodyweight_And_Sport")
    }

    /// Kept independent from the wide Active Workout tour: decision-aware
    /// substitution owns three related screens and needs a stable fixture for
    /// its reason → option → explanation → confirmation path.
    func testCaptureDecisionAwareSubstitutionScreenshots() {
        let draft = launchFixture("active-draft")
        tapButton("swap-exercise-Bench Press", in: draft)
        XCTAssertTrue(draft.navigationBars["Why are you swapping?"].waitForExistence(timeout: 5))
        tapButton("swap-reason-preference", in: draft)
        XCTAssertTrue(draft.navigationBars["Swap Exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(draft.buttons["swap-option-Dumbbell Bench Press"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08j_Exercise_Swap")

        tapButton("swap-why-Dumbbell Bench Press", in: draft)
        XCTAssertTrue(draft.navigationBars["Why?"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08o_Substitution_Why")
        tapButton("why-explanation-done", in: draft)

        tapButton("swap-option-Dumbbell Bench Press", in: draft)
        XCTAssertTrue(draft.navigationBars["Confirm swap"].waitForExistence(timeout: 5))
        XCTAssertTrue(draft.buttons["swap-scope-today"].exists)
        saveScreenshot("active-workout/08p_Substitution_Confirmation")
    }

    func testSupersetCompletionAdvancesWithoutRest() {
        let app = launchFixture("active-superset")
        XCTAssertTrue(app.staticTexts["superset-label-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["superset-label-Barbell Row"].exists)

        tapButton("complete-set-Bench Press-0", in: app)

        XCTAssertTrue(app.buttons["complete-set-Barbell Row-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Rest between sets"].exists)
    }

    func testCaptureDurationTimerScreenshots() {
        let app = launchFreshApp()
        let startWorkout = app.buttons["start-free-workout"]
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: startWorkout
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        startEmptyWorkout(in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
        addExercise("Plank", in: app)

        // Starting without seconds keeps the timer idle and asks for input.
        let start = app.buttons["start-countdown-Plank-0"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["Enter seconds before starting the timer."].waitForExistence(timeout: 3))

        tapButton("duration-field-Plank-0", in: app)
        tapButton("duration-key-45", in: app)
        dismissKeypadIfPresent(in: app)
        XCTAssertTrue(
            app.staticTexts["Enter seconds before starting the timer."].waitForNonExistence(timeout: 3)
        )
        saveScreenshot("active-workout/08f_Duration_Timer_Idle")

        start.tap()
        let pause = app.buttons["Pause timer"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        saveScreenshot("active-workout/08g_Duration_Timer_Running")

        pause.tap()
        XCTAssertTrue(app.buttons["Resume timer"].waitForExistence(timeout: 3))
        saveScreenshot("active-workout/08h_Duration_Timer_Paused")

        // Reset, shorten the target, and let the countdown finish. Selecting the
        // value starts a fresh entry, so "2" replaces the 45 already there.
        app.buttons["Reset timer"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        tapButton("duration-field-Plank-0", in: app)
        tapButton("duration-keypad-digits", in: app)
        tapButton("keypad-key-2", in: app)
        dismissKeypadIfPresent(in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts["Time complete"].waitForExistence(timeout: 8))
        saveScreenshot("active-workout/08i_Duration_Timer_Complete")

        // Restarting from the completed state runs the countdown again.
        app.buttons["Restart timer"].tap()
        XCTAssertTrue(app.buttons["Pause timer"].waitForExistence(timeout: 3))
    }

    /// Running, paused, and ready are mutually exclusive states of the exact
    /// same rest countdown, and the product's own Pause/Resume affordance is
    /// how a lifter moves between them. One "active-rest-running" launch
    /// captures all three: pause to reach paused, resume and let the real
    /// countdown finish to reach ready, instead of paying for three launches
    /// of three fixtures that only ever differed by this one runtime toggle.
    func testCaptureRestScreenshots() {
        let app = launchFixture("active-rest-running")
        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        let pauseButton = app.buttons["Pause rest"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08_Rest_Countdown")

        pauseButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Resume rest"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08b_Rest_Paused")

        app.buttons["Resume rest"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        // The fixture starts with ~45 seconds remaining; resuming continues
        // that same countdown, so waiting for it to actually finish reaches
        // the ready state without manufacturing it.
        XCTAssertTrue(app.descendants(matching: .any)["rest-ready"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["Continue to next set"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Rest continues"].exists)
        saveScreenshot("active-workout/08c_Rest_Ready")
    }

    /// Captures the two new Stage transitions that persisted-state fixtures do
    /// not prove: a freshly started rest (with its known-duration arc) and the
    /// terminal summary reached through Stage navigation.
    func testCaptureStageTransitionScreenshots() {
        let rest = launchFixture("active-in-progress")
        tapButton("complete-set-Bench Press-0", in: rest)
        XCTAssertTrue(rest.buttons["rest-pill"].waitForExistence(timeout: 5))
        rest.buttons["rest-pill"].tap()
        XCTAssertTrue(rest.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertTrue(rest.descendants(matching: .any)["rest-just-logged"].exists)
        saveScreenshot("active-workout/08u_Fresh_Rest_Transition")

        let finish = launchFixture("active-partial-save")
        navigateToWorkoutFinish(in: finish)
        XCTAssertTrue(finish.descendants(matching: .any)["finish-summary"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08v_Stage_Finish_Summary")
    }

    /// Pale is the authored appearance and Dark is its low-light counterpart,
    /// so the stage's two load-bearing states are captured in both. Everything
    /// on these screens resolves through dual-appearance tokens; this is what
    /// verifies that rather than assuming it.
    func testCaptureActiveWorkoutPaleAppearanceScreenshots() {
        let completedSet = launchFixture(
            "active-completed-set",
            additionalArguments: ["-appearance", "light"]
        )
        XCTAssertTrue(completedSet.buttons["complete-set-Bench Press-1"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08_Active_Workout_With_Set_Pale")

        let rest = launchFixture(
            "active-rest-running",
            additionalArguments: ["-appearance", "light"]
        )
        XCTAssertTrue(rest.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 10))
        XCTAssertTrue(rest.buttons["Pause rest"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08_Rest_Countdown_Pale")
    }

    /// AX5 on the two densest stage surfaces: the rest takeover, whose
    /// countdown and controls compete for one screen, and an expanded warm-up
    /// ramp, which is the longest set ledger the stage renders.
    func testCaptureActiveWorkoutAccessibilitySizeScreenshots() {
        let rest = launchFixture(
            "active-rest-running",
            additionalArguments: ["-ui-testing-dynamic-type", "accessibility5"]
        )
        XCTAssertTrue(rest.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08w_Rest_Countdown_AX5")

        let warmUp = launchFixture(
            "active-warmup-expanded",
            additionalArguments: ["-ui-testing-dynamic-type", "accessibility5"]
        )
        XCTAssertTrue(warmUp.buttons["warm-up-section-Bench Press"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/07l_Warmup_Expanded_AX5")
    }

    func testCaptureActiveWorkoutPanelAndGroupingStates() {
        let expanded = launchFixture("active-warmup-expanded")
        XCTAssertTrue(expanded.buttons["warm-up-section-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(expanded.buttons["complete-set-Bench Press-0"].exists)
        saveScreenshot("active-workout/07g_Warmup_Expanded")

        let collapsed = launchFixture("active-warmup-collapsed")
        XCTAssertTrue(collapsed.buttons["warm-up-section-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(collapsed.buttons["complete-set-Bench Press-0"].exists)
        saveScreenshot("active-workout/07h_Warmup_Collapsed")

        let badges = launchFixture("active-set-type-badges")
        XCTAssertEqual(badges.images["set-type-badge-Bench Press-0"].label, "Top set")
        XCTAssertEqual(badges.images["set-type-badge-Bench Press-1"].label, "Technique")
        saveScreenshot("active-workout/07i_Top_And_Technique_Badges")

        let complex = launchFixture("active-complex-unresolved")
        tapButton("reps-field-Three-Position Snatch-0", in: complex)
        XCTAssertTrue(complex.descendants(matching: .any)["panel-component-readiness"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/07j_Complex_Readiness")
        tapButton("panel-complete-set", in: complex)
        XCTAssertTrue(complex.descendants(matching: .any)["panel-complex-components"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/07k_Complex_Resolver")
    }

    func testCaptureWorkoutPreparationLargeDetent() {
        let app = launchFixture("linked-mobility-workout", expectsActiveWorkout: false)
        tapButton("today-open-saved-workouts", in: app)
        let search = app.textFields["workout-search"]
        for _ in 0..<4 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Linked Mobility Screenshot")
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        }
        let template = app.buttons["workout-template-Linked Mobility Screenshot"]
        XCTAssertTrue(template.waitForExistence(timeout: 10))
        template.tap()

        let sheet = app.descendants(matching: .any)["workout-preparation-sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        start.press(forDuration: 0.1, thenDragTo: end)
        // The sheet remains the asserted presentation identity. SwiftUI merges
        // the pinned action labels into that container at the large detent, so
        // they are not reliably exposed as separate XCUI elements.
        XCTAssertTrue(sheet.exists)
        saveScreenshot("active-workout/08q_Warmup_Preparation_Large")
    }

    func testCaptureRemainingActiveWorkoutCatalogStates() {
        let more = launchFixture("active-in-progress")
        tapButton("reps-field-Bench Press-0", in: more)
        tapButton("panel-details", in: more)
        XCTAssertTrue(more.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
        tapButton("set-type-more-toggle", in: more)
        XCTAssertTrue(more.buttons["set-type-option-dailyMaximum"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/07g_Set_Details_More_Types")

        let recent = launchFixture("active-recent-set-type")
        tapButton("reps-field-Bench Press-0", in: recent)
        tapButton("panel-details", in: recent)
        XCTAssertTrue(recent.descendants(matching: .any)["set-type-group-recent"].waitForExistence(timeout: 5))
        XCTAssertTrue(recent.buttons["set-type-recent-dailyMaximum"].exists)
        saveScreenshot("active-workout/07h_Set_Details_Recent_Types")

        let maximum = launchFixture("active-daily-maximum")
        XCTAssertTrue(maximum.buttons["select-daily-maximum-Bench Press-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(maximum.buttons["select-daily-maximum-Bench Press-0"].label, "Selected daily maximum")
        saveScreenshot("active-workout/08l_Selected_Daily_Maximum")

        let backoff = launchFixture("active-generated-backoff")
        XCTAssertTrue(backoff.descendants(matching: .any)["set-type-badge-Bench Press-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(backoff.buttons["complete-set-Bench Press-1"].exists)
        saveScreenshot("active-workout/08m_Generated_Back_Off")
    }

    func testCaptureHistoryScreenshots() {
        let app = launchFixture("history-bench", expectsActiveWorkout: false)

        selectTab(.history, in: app)
        XCTAssertTrue(app.buttons["history-workout-row"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("history/10_History_With_Workout")

        returnToProgressHub(in: app)
        let tools = app.buttons["progress-tools-disclosure"].firstMatch
        scrollToVisibleElement(tools, in: app)
        tools.tap()
        openProgressDestination("progress-records", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["history-records-heading"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("history/10b_Expanded_Records")

        returnToProgressHub(in: app)
        openProgressDestination("progress-workout-history", in: app)
        XCTAssertTrue(app.buttons["history-workout-row"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["history-workout-row"].firstMatch.tap()
        saveScreenshot("history/11_History_Detail")
    }

    /// Variations, relationships, and performance insights are three
    /// destinations reachable by tapping from the same exercise-detail
    /// screen, so one "exercise-insights" launch captures all three instead
    /// of three separate launches of the identical fixture.
    func testCaptureExerciseInsightsScreenshots() {
        let app = launchFixture(
            "exercise-insights",
            additionalArguments: ["-ui-testing-open-exercise-detail"],
            expectsActiveWorkout: false,
            expectedHomeControl: "exercise-relationships"
        )

        XCTAssertTrue(app.descendants(matching: .any)["exercise-identity"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/17c_Exercise_Detail_Overview")

        let variation = app.buttons["exercise-variation-Dumbbell Bench Press"]
        scrollToElement(variation, in: app)
        saveScreenshot("exercises/17a_Exercise_Detail_Variations")

        tapButton("exercise-relationships", in: app)
        XCTAssertTrue(app.navigationBars["Exercise Relationships"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/17b_Exercise_Relationships")
        tapButton("Done", in: app)
        XCTAssertTrue(app.navigationBars["Exercise Relationships"].waitForNonExistence(timeout: 5))

        let statistics = app.buttons["exercise-stats"]
        scrollToElement(statistics, in: app)
        statistics.tap()
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["exercise-insights-back"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-last-session"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-volume"].exists)

        saveScreenshot("exercises/17_Exercise_Insights")
    }

    func testCaptureMuscleBalanceScreenshot() {
        let app = launchFixture("muscle-balance", expectsActiveWorkout: false)
        selectTab(.progress, in: app)
        let tools = app.descendants(matching: .any)["progress-tools-disclosure"].firstMatch
        scrollToVisibleElement(tools, in: app)
        tools.tap()
        openProgressDestination("progress-muscle-group-volume", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-content"].waitForExistence(timeout: 10))
        let chart = app.descendants(matching: .any)["muscle-balance-chart"]
        XCTAssertTrue(chart.exists)
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-callouts"].exists)
        app.swipeUp(velocity: .slow)

        saveScreenshot("history/16_Muscle_Balance")
    }

    func testCaptureIncreaseRecommendationScreenshots() {
        let increase = launchFixture("progression-increase")
        XCTAssertTrue(increase.descendants(matching: .any)["progression-recommendation-card-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(increase.buttons["accept-recommendation-Bench Press"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10_Previous_Performance")
        tapButton("accept-recommendation-Bench Press", in: increase)
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: increase), "52.5")
        saveScreenshot("progression/10e_Progression_Applied_Weight")
    }

    func testCaptureHoldRecommendationScreenshot() {
        let hold = launchFixture("progression-hold")
        XCTAssertTrue(hold.buttons["keep-last-recommendation-Bench Press"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10b_Progression_Hold")
    }

    func testCaptureInsufficientHistoryRecommendationScreenshots() {
        let insufficient = launchFixture("progression-insufficient-history")
        XCTAssertTrue(insufficient.buttons["enter-starting-weight-Bench Press"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10c_Progression_Starting_Weight")
        tapButton("enter-starting-weight-Bench Press", in: insufficient)
        // The keypad is part of the set-entry panel, not a system keyboard.
        let exactDigits = insufficient.buttons["plate-keypad-digits"].firstMatch
        scrollToElement(exactDigits, in: insufficient)
        exactDigits.tap()
        XCTAssertTrue(insufficient.buttons["keypad-key-1"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10d_Progression_Manual_Edit")
    }

    /// "progression-rest-running" and "progression-rest-paused" differ only
    /// by the same Pause/Resume toggle exercised in
    /// `testCaptureRestScreenshots`. Pausing the running fixture in place
    /// reaches the paused state without a second launch.
    func testCaptureRecommendationWithRestScreenshots() {
        let app = launchFixture("progression-rest-running")
        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        // The recommendation belongs to the next exercise stage while rest
        // remains globally available from the command bar.
        tapButton("collapse-rest-takeover", in: app)
        XCTAssertTrue(app.buttons["collapse-rest-takeover"].waitForNonExistence(timeout: 5))
        let benchStage = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Page 2 of 2", "Bench Press")
        ).firstMatch
        XCTAssertTrue(benchStage.waitForExistence(timeout: 5))
        XCTAssertTrue(benchStage.isHittable)
        benchStage.tap()
        XCTAssertTrue(app.staticTexts["active-exercise-Bench Press"].waitForExistence(timeout: 5))
        let card = app.descendants(matching: .any)["progression-recommendation-card-Bench Press"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        scrollToVisibleElement(card, in: app)
        saveScreenshot("progression/10f_Progression_With_Rest_Running")

        tapButton("rest-pill", in: app)
        tapButton("rest-pause-toggle", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        tapButton("collapse-rest-takeover", in: app)
        if !app.staticTexts["active-exercise-Bench Press"].waitForExistence(timeout: 2) {
            let pausedBenchStage = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Page 2 of 2", "Bench Press")
            ).firstMatch
            XCTAssertTrue(pausedBenchStage.waitForExistence(timeout: 5))
            pausedBenchStage.tap()
        }
        XCTAssertTrue(app.staticTexts["active-exercise-Bench Press"].waitForExistence(timeout: 5))

        let pausedCard = app.descendants(matching: .any)["progression-recommendation-card-Bench Press"]
        XCTAssertTrue(pausedCard.waitForExistence(timeout: 5))
        scrollToVisibleElement(pausedCard, in: app)
        saveScreenshot("progression/10g_Progression_With_Rest_Paused")
    }

    func testCaptureProgressionReceiptWhyScreenshot() {
        let app = launchFixture(
            "progression-receipt",
            expectsActiveWorkout: false,
            expectedHomeControl: "progression-receipt-done"
        )
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "progression-receipt-card-")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        saveScreenshot("progression/10h_Progression_Receipt")
        let why = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "progression-receipt-why-")
        ).firstMatch
        XCTAssertTrue(why.waitForExistence(timeout: 5))
        why.tap()
        XCTAssertTrue(app.navigationBars["Why?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Progression rule v2")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["The rule's condition was met."].exists)
        XCTAssertTrue(app.staticTexts["Effect on your plan"].waitForExistence(timeout: 5))
        app.swipeUp()
        saveScreenshot("progression/10g_Progression_Receipt_Why")
    }

    /// T-36 reachability pass. These states were previously either behind a
    /// capture-only launch hook or reachable only after seeded navigation.
    func testCaptureT36MissingStatesScreenshots() {
        let welcome = XCUIApplication()
        welcome.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-show-welcome"]
        welcome.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(welcome.descendants(matching: .any)["welcome"].waitForExistence(timeout: 30))
        saveScreenshot("overview/00_Welcome")
        welcome.terminate()

        let storage = XCUIApplication()
        storage.launchArguments = ["-ui-testing", "-ui-testing-storage-unavailable"]
        storage.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(storage.descendants(matching: .any)["storage-unavailable"].waitForExistence(timeout: 15))
        XCTAssertTrue(storage.buttons["storage-export"].waitForExistence(timeout: 5))
        XCTAssertFalse(storage.buttons["storage-remove"].exists)
        saveScreenshot("overview/00b_Storage_Unavailable")
        storage.terminate()

        let missingRoute = XCUIApplication()
        missingRoute.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-missing-route"]
        missingRoute.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(missingRoute.staticTexts["Exercise unavailable"].waitForExistence(timeout: 30))
        saveScreenshot("overview/02e_Route_Unavailable")
        missingRoute.terminate()

        let guidedError = XCUIApplication()
        guidedError.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-guided-source-error"]
        guidedError.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(guidedError.alerts["Plan change failed"].waitForExistence(timeout: 30))
        saveScreenshot("active-workout/08s_Guided_Source_Error")
        guidedError.terminate()

        let mobilityError = XCUIApplication()
        mobilityError.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-mobility-link-error"]
        mobilityError.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(mobilityError.alerts["Couldn’t start mobility"].waitForExistence(timeout: 30))
        saveScreenshot("active-workout/08t_Mobility_Link_Error")
        mobilityError.terminate()

        let failedSave = launchFixture(
            "active-completed-set",
            additionalArguments: ["-ui-testing-fail-workout-save"]
        )
        navigateToWorkoutFinish(in: failedSave)
        tapButton("finish-workout", in: failedSave)
        tapButton("save-workout", in: failedSave)
        XCTAssertTrue(failedSave.alerts.firstMatch.waitForExistence(timeout: 10))
        saveScreenshot("review/09c_Save_Failure_Alert")
        failedSave.terminate()

        let linked = launchFixture("linked-mobility-workout", expectsActiveWorkout: false)
        tapButton("today-open-saved-workouts", in: linked)
        let linkedSearch = linked.textFields["workout-search"]
        for _ in 0..<4 where !linkedSearch.isHittable {
            linked.swipeUp()
        }
        XCTAssertTrue(linkedSearch.waitForExistence(timeout: 5))
        linkedSearch.tap()
        linkedSearch.typeText("Linked Mobility Screenshot")
        if linked.keyboards.buttons["Return"].exists {
            linked.keyboards.buttons["Return"].tap()
        }
        let linkedTemplate = linked.buttons["workout-template-Linked Mobility Screenshot"]
        XCTAssertTrue(linkedTemplate.waitForExistence(timeout: 10))
        XCTAssertTrue(linkedTemplate.isHittable)
        linkedTemplate.tap()
        XCTAssertTrue(linked.buttons["skip-linked-warmup"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08q_Warmup_Preparation_Dialog")
        tapButton("skip-linked-warmup", in: linked)
        XCTAssertTrue(linked.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        for setIndex in 0..<2 {
            enterValidValues(for: "Bench Press", set: setIndex, in: linked)
            completeSet("Bench Press", index: setIndex, dismissRest: true, in: linked)
        }
        enterValidValues(for: "Bench Press", set: 2, in: linked)
        tapButton("complete-set-Bench Press-2", in: linked)
        XCTAssertTrue(linked.buttons["finish-workout"].waitForExistence(timeout: 10))
        tapButton("finish-workout", in: linked)
        tapButton("save-workout", in: linked)
        let cooldownStage = linked.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(cooldownStage.waitForExistence(timeout: 10))
        XCTAssertTrue(
            linked.buttons["complete-mobility-movement"].exists
                || linked.buttons["complete-mobility-phase"].exists
        )
        XCTAssertFalse(linked.buttons["start-linked-cooldown"].exists)
        saveScreenshot("active-workout/08r_Cooldown_Stage")
        linked.terminate()

        let midPicker = launchFixture("active-in-progress")
        tapButton("active-workout-menu", in: midPicker)
        tapButton("add-active-mobility-menu", in: midPicker)
        XCTAssertTrue(
            midPicker.descendants(matching: .any)["active-workout-mobility-insert-picker"]
                .waitForExistence(timeout: 10)
        )
        saveScreenshot("active-workout/08x_Mid_Workout_Mobility_Picker")
        midPicker.terminate()

        let midStage = launchFixture("mid-workout-mobility")
        XCTAssertTrue(
            midStage.descendants(matching: .any)["active-workout-mobility-stage"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(midStage.staticTexts["MOVEMENT"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08y_Mid_Workout_Mobility_Stage")
        midStage.terminate()

        let history = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: history)
        let trendsLink = history.descendants(matching: .any)["progress-training-trends"]
        scrollToElement(trendsLink, in: history)
        XCTAssertTrue(trendsLink.waitForExistence(timeout: 10))
        trendsLink.tap()
        XCTAssertTrue(history.descendants(matching: .any)["history-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(history.descendants(matching: .any)["training-frequency-chart"].waitForExistence(timeout: 10))
        saveScreenshot("history/03b_Progress_Trends_Frequency")
        history.swipeUp()
        let chartPoint = history.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.72))
        chartPoint.press(forDuration: 0.1)
        saveScreenshot("history/03c_Progress_Trends_Exercise_Selected")

        let nutrition = launchFixture(
            "nutrition-today",
            expectsActiveWorkout: false,
            expectedHomeControl: "tab-nutrition"
        )
        selectTab(.nutrition, in: nutrition)
        tapButton("open-food-library", in: nutrition)
        XCTAssertTrue(nutrition.navigationBars["Food library"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20b_Food_Library")
        nutrition.navigationBars.buttons.element(boundBy: 0).tap()
        tapButton("open-meal-templates", in: nutrition)
        XCTAssertTrue(nutrition.navigationBars["Recipes"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20c_Meal_Template_Library")

        let repeatMeal = launchFixture(
            "today-complete",
            expectsActiveWorkout: false,
            expectedHomeControl: "tab-nutrition"
        )
        selectTab(.nutrition, in: repeatMeal)
        XCTAssertTrue(repeatMeal.descendants(matching: .any)["nutrition-today-totals"].waitForExistence(timeout: 10))
        let loggedMeal = repeatMeal.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "logged-meal-")
        ).firstMatch
        scrollToElement(loggedMeal, in: repeatMeal)
        XCTAssertTrue(loggedMeal.waitForExistence(timeout: 10))
        loggedMeal.tap()
        XCTAssertTrue(repeatMeal.navigationBars["Food entry"].waitForExistence(timeout: 10))
        tapButton("repeat-logged-meal", in: repeatMeal)
        XCTAssertTrue(repeatMeal.navigationBars["Repeat meal"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20d_Repeat_Meal_Sheet")

        let archived = launchFreshApp()
        selectTab(.library, in: archived)
        tapButton("exercises-browser", in: archived)
        let archivedLink = archived.buttons["hidden-exercises"]
        scrollToElement(archivedLink, in: archived)
        archivedLink.tap()
        XCTAssertTrue(archived.navigationBars["Hidden Exercises"].waitForExistence(timeout: 10))
        saveScreenshot("overview/02f_Archived_Exercises_Empty")

        let collection = launchFreshApp()
        selectTab(.library, in: collection)
        tapButton("workouts-browser", in: collection)
        let collectionLink = collection.descendants(matching: .any)["workout-collection-Upper/Lower Program – 4 Days"]
        scrollToElement(collectionLink, in: collection)
        collectionLink.tap()
        XCTAssertTrue(collection.navigationBars["Upper/Lower Program – 4 Days"].waitForExistence(timeout: 10))
        saveScreenshot("overview/02g_Workout_Collection_Detail")
    }

    func testCapturePerformanceComparisonReviewScreenshot() {
        let app = launchFixture("performance-comparison")

        navigateToWorkoutFinish(in: app)
        tapButton("finish-workout", in: app)
        let comparison = app.descendants(matching: .any)["performance-comparison"].firstMatch
        scrollToElement(comparison, in: app)
        app.swipeUp()
        app.swipeUp()
        saveScreenshot("review/14_Save_Performance_Comparison")
    }

    func testCapturePerformanceComparisonHistoryScreenshot() {
        let app = launchFixture("performance-history-comparison", expectsActiveWorkout: false)
        selectTab(.history, in: app)
        tapButton("history-workout-row", in: app)
        let historyComparison = app.descendants(matching: .any)["performance-comparison"].firstMatch
        scrollToElement(historyComparison, in: app)
        saveScreenshot("history/15_History_Performance_Comparison")
    }

    func testCaptureHomeConflictScreenshot() {
        let conflict = launchFixture(
            "home-active-conflict",
            expectsActiveWorkout: false,
            expectedHomeControl: "resume-active-workout"
        )
        XCTAssertTrue(conflict.staticTexts["An active workout is already in progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(conflict.buttons["Resume"].waitForExistence(timeout: 2))
        XCTAssertTrue(conflict.buttons["Cancel"].waitForExistence(timeout: 2))
        saveScreenshot("overview/01c_Home_Workout_Conflict")
    }

    /// Daily check-in, the caffeine quick log, and the Mobility library are
    /// three sheets/destinations opened directly from the same "today-complete"
    /// Today screen. Check-in and caffeine are cancelable without saving, so
    /// one launch replaces three.
    func testCaptureTodayCompleteTourScreenshots() {
        let app = launchFixture(
            "today-complete",
            additionalArguments: ["-ui-testing-open-daily-check-in"],
            expectsActiveWorkout: false,
            expectedHomeControl: "daily-check-in-save"
        )
        saveScreenshot("overview/01e_Daily_Check_In")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Daily check-in"].waitForNonExistence(timeout: 5))
        app.terminate()

        let caffeine = launchFixture(
            "today-complete",
            additionalArguments: ["-ui-testing-open-caffeine-log"],
            expectsActiveWorkout: false,
            expectedHomeControl: "confirm-log-caffeine"
        )
        XCTAssertTrue(caffeine.navigationBars["Log caffeine"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20a_Caffeine_Quick_Log")
        tapButton("Cancel", in: caffeine)
        XCTAssertTrue(caffeine.navigationBars["Log caffeine"].waitForNonExistence(timeout: 5))

        // Managing routines is the Train tab's job; Today only starts or resumes
        // one, so the library is reached from Train rather than a Today link.
        selectTab(.library, in: caffeine)
        tapButton("train-mobility-library", in: caffeine)
        XCTAssertTrue(caffeine.navigationBars["Mobility"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18_Mobility_Routines")
    }

    func testCaptureDailyCheckInWeightDueScreenshot() {
        let app = launchFixture(
            "today-weight-due",
            additionalArguments: ["-ui-testing-open-daily-check-in"],
            expectsActiveWorkout: false,
            expectedHomeControl: "daily-check-in-weight"
        )
        XCTAssertTrue(app.textFields["daily-check-in-weight"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01h_Daily_Check_In_Weight_Due")
    }

    func testCaptureBodyWeightHistoryScreenshot() {
        let app = launchFixture("body-weight-history", expectsActiveWorkout: false)
        selectTab(.settings, in: app)
        tapButton("settings-personal-details", in: app)
        let bodyWeight = app.buttons["settings-body-weight"]
        scrollToElement(bodyWeight, in: app)
        bodyWeight.tap()
        XCTAssertTrue(app.descendants(matching: .any)["body-weight-history"].waitForExistence(timeout: 5))
        saveScreenshot("overview/04a_Body_Weight_History")
    }

    /// The active-plan badge on Today, its reschedule editor, and the plan's
    /// own "next workout" run card all come from the same "plan-active-run"
    /// fixture. Rescheduling is canceled here (never confirmed), so the run
    /// stays intact for the Library capture that follows in the same launch.
    func testCapturePlanActiveRunScreenshots() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        XCTAssertTrue(app.descendants(matching: .any)["active-plan-badge"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Next · Today'")).firstMatch.exists
        )
        saveScreenshot("overview/01d_Home_Active_Plan")

        tapButton("today-reschedule-planned-workout", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01f_Today_Reschedule_Workout")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForNonExistence(timeout: 5))

        selectTab(.train, in: app)
        XCTAssertTrue(app.buttons["current-plan-card"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["current-plan-start-next"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13a_Train_Current_Plan")

        tapButton("current-plan-weekly-review", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["weekly-review-screen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["weekly-review-session-summary"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13aa_Weekly_Review_Status")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        openPlans(.following, in: app)
        tapButton("plan-row-Screenshot Plan Run", in: app)
        XCTAssertTrue(app.buttons["start-planned-workout"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13b_Plan_Active_Run")
    }

    func testCaptureNotificationRescheduleScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-test-fixture",
            "plan-active-run",
            "-ui-testing-open-plan-reminder-reschedule"
        ]
        app.launchWithGymTrackerUITestArguments()
        XCTAssertEqual(app.state, .runningForeground)
        let preparing = app.descendants(matching: .any)["app-preparing"]
        XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01g_Notification_Reschedule_Workout")
    }

    func testCaptureActiveMobilityScreenshot() {
        let app = launchFixture(
            "mobility-active",
            expectsActiveWorkout: false,
            expectsMobilitySession: true
        )
        XCTAssertTrue(app.buttons["complete-mobility-movement"].waitForExistence(timeout: 5))
        let details = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "mobility-result-details-")
        ).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "mobility-sensation-")
            ).firstMatch.exists
        )
        let reportSensation = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "mobility-report-sensation-")
        ).firstMatch
        XCTAssertTrue(reportSensation.waitForExistence(timeout: 5))
        saveScreenshot("mobility/19_Active_Mobility")

        scrollToElement(reportSensation, in: app)
        XCTAssertTrue(reportSensation.isHittable)
        reportSensation.tap()
        let sensation = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "mobility-sensation-")
        ).firstMatch
        scrollToElement(sensation, in: app)
        XCTAssertTrue(sensation.waitForExistence(timeout: 5))
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            .press(
                forDuration: 0.05,
                thenDragTo: app.windows.firstMatch.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38)
                )
            )
        saveScreenshot("mobility/19a_Active_Mobility_Safety")
    }

    func testCaptureMobilityRoutinePurposeScreenshot() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("train-mobility-library", in: app)
        XCTAssertTrue(app.navigationBars["Mobility"].waitForExistence(timeout: 5))

        let all = app.buttons["mobility-purpose-filter-all"]
        let preparation = app.buttons["mobility-purpose-filter-preparation"]
        let development = app.buttons["mobility-purpose-filter-development"]
        let postWorkout = app.buttons["mobility-purpose-filter-cooldown"]
        for chip in [all, preparation, development, postWorkout] {
            XCTAssertTrue(chip.waitForExistence(timeout: 5))
            XCTAssertTrue(chip.isHittable, "Each purpose chip must remain independently tappable inside its List row")
        }

        preparation.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobility-purpose-section-preparation"].waitForExistence(timeout: 5))
        development.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobility-purpose-section-development"].waitForExistence(timeout: 5))
        postWorkout.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobility-purpose-section-cooldown"].waitForExistence(timeout: 5))

        let unspecified = app.buttons["mobility-purpose-filter-unspecified"]
        XCTAssertTrue(unspecified.waitForExistence(timeout: 5))
        unspecified.tap()
        let clear = app.buttons["clear-mobility-purpose-filter"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobility-purpose-section-preparation"].waitForExistence(timeout: 5))

        let createRoutine = app.buttons["create-mobility-routine"]
        for _ in 0..<8 where !createRoutine.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(createRoutine.waitForExistence(timeout: 5))
        XCTAssertTrue(createRoutine.isHittable)
        createRoutine.tap()
        let picker = app.buttons["mobility-routine-purpose-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        saveScreenshot("mobility/18b_Mobility_Routine_Purpose")
    }

    func testCaptureNutritionTodayScreenshot() {
        let app = launchFixture(
            "nutrition-today",
            expectsActiveWorkout: false,
            expectedHomeControl: "tab-nutrition"
        )
        selectTab(.nutrition, in: app)
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["nutrition-today-totals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["open-caffeine-log"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20_Nutrition_Today")

        // Open the food-entry sheet before any other sheet. Presenting Log food
        // first and then this one left SwiftUI with a stale item binding, so
        // the entry screen never appeared.
        let loggedMeal = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "logged-meal-")
        ).firstMatch
        scrollToElement(loggedMeal, in: app)
        XCTAssertTrue(loggedMeal.waitForExistence(timeout: 5))
        loggedMeal.tap()
        let foodEntryPresented = app.navigationBars["Food entry"].waitForExistence(timeout: 10)
            || app.buttons["delete-logged-meal"].waitForExistence(timeout: 2)
        XCTAssertTrue(foodEntryPresented)
        guard foodEntryPresented else { return }
        saveScreenshot("nutrition/20l_Food_Entry")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))

        tapButton("open-food-library", in: app)
        let foodRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "food-row-")
        ).firstMatch
        XCTAssertTrue(foodRow.waitForExistence(timeout: 5))
        foodRow.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20k_Food_Intake")
    }

    func testCapturePhotoEstimateReviewScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-meal-photo-estimate-result", "success",
        ])
        selectTab(.nutrition, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["photo-estimate-screen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["confirm-photo-estimate"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20m_Photo_Estimate_Review")
    }

    func testCaptureNutritionTargetsEmptyScreenshot() {
        let app = launchFreshApp()
        selectTab(.nutrition, in: app)
        tapButton("open-nutrition-targets", in: app)
        XCTAssertTrue(app.navigationBars["Nutrition targets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["create-nutrition-target-empty"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20b_Nutrition_Targets_Empty")
    }

    private func openNewRecipeEditorForScreenshot(_ app: XCUIApplication) {
        selectTab(.nutrition, in: app)
        tapButton("open-meal-templates", in: app)
        tapButton("create-meal-template", in: app)
    }

    func testCaptureRecipeGenerationControlsScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
        ])
        openNewRecipeEditorForScreenshot(app)
        XCTAssertTrue(app.buttons["generate-recipe"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20c_Recipe_Generation_Controls")
    }

    func testCaptureRecipeGeneratingScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "slow",
        ])
        openNewRecipeEditorForScreenshot(app)
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        tapButton("generate-recipe", in: app)
        XCTAssertTrue(app.staticTexts["Generating recipe…"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20d_Recipe_Generating")
    }

    func testCaptureRecipeGeneratedDraftScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "success",
        ])
        openNewRecipeEditorForScreenshot(app)
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        tapButton("generate-recipe", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["recipe-generation-notice"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20e_Recipe_Generated_Draft")
    }

    func testCaptureRecipePartialMatchScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "partial-match",
        ])
        openNewRecipeEditorForScreenshot(app)
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("High-protein breakfast")
        tapButton("generate-recipe", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["recipe-generation-notice"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20f_Recipe_Partial_Match")
    }

    /// All three states share the "unsupportedDevice" generation-availability
    /// argument, so one launch produces the manual-fallback editor, its food
    /// picker, and — after canceling back out to the recipe library, since
    /// none of this is saved — an existing recipe's detail and log sheet.
    func testCaptureRecipeManualFallbackAndCatalogScreenshots() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditorForScreenshot(app)
        XCTAssertFalse(app.buttons["generate-recipe"].exists)
        saveScreenshot("nutrition/20g_Recipe_Manual_Fallback")

        tapButton("recipe-add-foods", in: app)
        XCTAssertTrue(app.navigationBars["Add foods"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20h_Food_Picker")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Add foods"].waitForNonExistence(timeout: 5))
        tapButton("Cancel", in: app)

        // Canceling the new-recipe editor returns to the meal template
        // library that opened it; the seeded catalogue ships recipes, so open
        // the first one's detail.
        let firstRecipe = app.cells.firstMatch
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 5))
        firstRecipe.tap()
        let addToToday = app.buttons["recipe-add-to-today"]
        XCTAssertTrue(addToToday.waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20i_Recipe_Detail")

        addToToday.tap()
        XCTAssertTrue(app.navigationBars["Add to today"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20j_Log_Recipe")
    }

    func testTodayCanQuickLogFood() {
        let app = launchFixture(
            "nutrition-today",
            expectsActiveWorkout: false,
            expectedHomeControl: "today-open-exercises"
        )
        // Nutrition is a first-class destination, not a Today shortcut. Enter
        // it through the tab bar so this test follows the shipped navigation
        // contract instead of depending on a removed Home affordance.
        selectTab(.nutrition, in: app)
        tapButton("open-food-library", in: app)
        XCTAssertTrue(app.navigationBars["Food library"].waitForExistence(timeout: 5))
        let search = app.searchFields["Search foods"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Chicken breast")
        let result = app.staticTexts["Chicken breast"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        tapButton("confirm-log-food", in: app)
        XCTAssertTrue(app.navigationBars["Food library"].waitForExistence(timeout: 5))
    }

    func testTodayCanSkipPlannedWorkoutWithoutChangingThePlan() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        tapButton("today-skip-planned-workout", in: app)
        XCTAssertTrue(app.staticTexts["Skip this workout?"].waitForExistence(timeout: 5))
        tapButton("today-confirm-skip-workout", in: app)
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
    }

    func testCaptureSettingsImportErrorScreenshot() {
        let settings = XCUIApplication()
        settings.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings", "-ui-testing-import-error"]
        settings.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(settings.alerts["Import Error"].waitForExistence(timeout: 15))
        saveScreenshot("overview/04b_Settings_Import_Error")
    }

    func testCaptureSettingsImportPreviewScreenshot() {
        let preview = XCUIApplication()
        preview.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-open-settings",
            "-ui-testing-import-valid",
            "-ui-test-fixture",
            "backup-import-target"
        ]
        preview.launchWithGymTrackerUITestArguments()
        let importPreview = preview.descendants(matching: .any)["import-preview"]
        if !importPreview.waitForExistence(timeout: 15) {
            let bars = preview.navigationBars.allElementsBoundByIndex.map(\.identifier).joined(separator: ", ")
            let alert = preview.alerts.firstMatch
            let alertText = alert.exists
                ? alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
                : "none"
            XCTFail("Import preview did not appear. Navigation: \(bars). Alert: \(alertText)")
        }
        saveScreenshot("overview/04c_Settings_Import_Preview")
    }

    func testCaptureTemplateProgressionScreenshot() {
        let app = launchFreshApp()
        openUpperBodyTemplateEditor(in: app)

        tapButton("template-exercise-editor-Bench Press", in: app)
        XCTAssertTrue(app.switches["double-progression-toggle"].waitForExistence(timeout: 5))
        saveScreenshot("templates/12_Template_Progression")
    }

    func testCaptureTemplateExecutionBlockScreenshot() {
        let app = launchFreshApp()
        openUpperBodyTemplateEditor(in: app)
        tapControl("template-options-menu", in: app)
        tapButton("add-template-execution-block", in: app)
        XCTAssertTrue(app.navigationBars["Execution Block"].waitForExistence(timeout: 5))
        saveScreenshot("templates/12d_Template_Execution_Block")
    }

    func testCapturePlanReviewScreenshot() {
        let app = launchFreshApp(additionalArguments: ["-ui-testing-plan-deload"])
        selectTab(.library, in: app)

        tapButton("Create library item", in: app)
        // Target the stable accessibility identifier rather than the visible
        // label, which has already been renamed once ("New Program" ->
        // "New Training Plan") and silently broke this capture.
        tapButton("new-plan", in: app)

        let planName = app.textFields["plan-name-field"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("Screenshot Plan")
        planName.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))

        let equipmentPicker = app.buttons["plan-equipment-picker"]
        scrollToElement(equipmentPicker, in: app)
        tapButton("plan-equipment-picker", in: app)
        tapButton("plan-equipment-barbell", in: app)
        saveScreenshot("plans/13c_Program_Equipment")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()

        let deloadToggle = app.switches["plan-deload-toggle"]
        scrollToElement(deloadToggle, in: app)
        XCTAssertTrue(deloadToggle.waitForExistence(timeout: 5))
        deloadToggle.tap()

        let deloadIntensity = app.steppers["plan-deload-intensity-reduction"]
        scrollToElement(deloadIntensity, in: app)
        XCTAssertTrue(deloadIntensity.waitForExistence(timeout: 5))
        saveScreenshot("plans/13d_Plan_Deload_Schedule")

        let mondayTemplate = app.buttons["plan-day-template-0"]
        scrollToElement(mondayTemplate, in: app)
        saveScreenshot("plans/13_Plan_Day_Assignments")
        tapButton("save-plan", in: app)

        openPlans(.mine, in: app)
        tapButton("plan-row-Screenshot Plan", in: app)
        let options = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Plan options")
        ).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        tapControl("edit-plan", in: app)
        XCTAssertTrue(app.navigationBars["Edit Plan"].waitForExistence(timeout: 5))
        let editWorkout = app.descendants(matching: .any)["edit-plan-workout"].firstMatch
        scrollToElement(editWorkout, in: app)
        editWorkout.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let executionBlock = app.descendants(matching: .any)["add-plan-execution-block"].firstMatch
        if !executionBlock.waitForExistence(timeout: 3), editWorkout.exists {
            // The editor row is a nested SwiftUI button inside a Form cell;
            // retry once through XCTest's semantic tap if the coordinate event
            // was consumed by the cell's scroll transition.
            editWorkout.tap()
        }
        scrollToElement(executionBlock, in: app)
        executionBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Execution Block"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13n_Plan_Execution_Block")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.buttons["plan-workout-exercise"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["plan-workout-exercise"].firstMatch.tap()
        let addAlternative = app.buttons["add-plan-exercise-alternative"]
        scrollToElement(addAlternative, in: app)
        saveScreenshot("plans/13g_Plan_Exercise_Alternatives")
        let addSet = app.buttons["add-plan-set-prescription"]
        scrollToElement(addSet, in: app)
        tapButton("add-plan-set-prescription", in: app)
        XCTAssertTrue(app.buttons["plan-set-prescription-row"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("plans/13h_Plan_Per_Set_Prescription")
        tapButton("Done", in: app)
        XCTAssertTrue(app.buttons["plan-workout-exercise"].firstMatch.waitForExistence(timeout: 5))
        tapButton("Done", in: app)
        XCTAssertTrue(app.buttons["edit-plan-workout"].firstMatch.waitForExistence(timeout: 5))
        tapButton("save-plan-edits", in: app)
        XCTAssertTrue(app.buttons["confirm-plan-changes"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13_Plan_Review")

        tapButton("confirm-plan-changes", in: app)
        XCTAssertTrue(app.buttons["view-program-prescription-preview"].waitForExistence(timeout: 5))
        tapButton("view-program-prescription-preview", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-preview-summary"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13i_Program_Prescription_Preview")

    }

    /// The definition builder draft is canceled without saving, then the same
    /// launch browses the built-in catalog — a forward-only flow that never
    /// needs to navigate back — so one launch replaces two.
    func testCaptureProgramDefinitionAndCatalogScreenshots() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("Create library item", in: app)
        tapButton("new-program-definition", in: app)

        let name = app.textFields["definition-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Custom Strength Recipe")
        name.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        saveScreenshot("plans/13j_Program_Definition_Builder")
        tapButton("Cancel", in: app)
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))

        openPlans(.readyMade, in: app)
        saveScreenshot("plans/13k_Program_Catalog")

        tapButton("program-discovery-filter-button", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-discovery-filters"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13ka_Program_Catalog_Filters")
        tapButton("Powerlifting", in: app)
        tapButton("Done", in: app)
        XCTAssertTrue(app.buttons["program-catalog-Powerlifting Foundations"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13kb_Program_Catalog_Filtered")
        tapButton("program-discovery-filter-button", in: app)
        tapButton("Clear", in: app)
        tapButton("Done", in: app)

        let program = app.buttons["program-catalog-Double Progression Builder"].firstMatch
        XCTAssertTrue(program.waitForExistence(timeout: 5))
        program.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog-detail"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13l_Program_Catalog_Detail")

        let useProgram = app.buttons["use-program"]
        scrollToElement(useProgram, in: app)
        useProgram.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-intake"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13m_Program_Intake")
    }

    func testPlanCalendarShowsDerivedStatesAndKeepsCompletedSessionsLocked() {
        let app = launchFixture(
            "plan-calendar",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        openPlans(.following, in: app)
        tapButton("plan-row-Calendar Fixture Plan", in: app)
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            let schedule = app.buttons["view-plan-schedule"].firstMatch
            let stickyAction = app.buttons["start-planned-workout"].firstMatch
            if schedule.exists,
               app.frame.intersects(schedule.frame),
               (!stickyAction.exists || schedule.frame.maxY < stickyAction.frame.minY - 4) {
                break
            }
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
                .press(
                    forDuration: 0.05,
                    thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                )
        }
        let schedule = app.buttons["view-plan-schedule"].firstMatch
        let stickyAction = app.buttons["start-planned-workout"].firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.intersects(schedule.frame))
        XCTAssertTrue(!stickyAction.exists || schedule.frame.maxY < stickyAction.frame.minY - 4)
        schedule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-screen"].waitForExistence(timeout: 5))
        let dayRows = app.buttons.matching(identifier: "plan-calendar-day")
        XCTAssertEqual(dayRows.count, 6)
        let spokenStates = (0..<dayRows.count)
            .map { dayRows.element(boundBy: $0).label }
            .joined(separator: " ")
        for state in ["Completed", "Skipped", "Missed", "In progress", "Ready", "Upcoming"] {
            XCTAssertTrue(spokenStates.contains(state), "Expected the calendar to speak the \(state) state")
        }
        dayRows.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-day-screen"].waitForExistence(timeout: 5))
        let rescheduleButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "calendar-reschedule-")
        )
        XCTAssertEqual(rescheduleButtons.count, 1)
        rescheduleButtons.firstMatch.tap()
        XCTAssertTrue(app.buttons["calendar-confirm-reschedule"].waitForExistence(timeout: 5))
        app.buttons["calendar-confirm-reschedule"].tap()

        app.navigationBars.buttons.firstMatch.tap()
        dayRows.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-day-screen"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar-reschedule-")).count,
            0
        )
    }

    func testRelaunchRefreshesHomeWithTheSessionScheduledForToday() {
        let app = launchFixture(
            "plan-relaunch-schedule",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        XCTAssertTrue(app.staticTexts["Tomorrow Fixture Workout"].waitForExistence(timeout: 10))

        relaunchPreservingData(app)

        XCTAssertTrue(app.buttons["start-planned-workout"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Today Fixture Workout"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Tomorrow Fixture Workout"].exists)
    }

    func testCapturePlanCalendarScreenshots() {
        let app = launchFixture(
            "plan-calendar",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        openPlans(.following, in: app)
        tapButton("plan-row-Calendar Fixture Plan", in: app)
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            let schedule = app.buttons["view-plan-schedule"].firstMatch
            let stickyAction = app.buttons["start-planned-workout"].firstMatch
            if schedule.exists,
               app.frame.intersects(schedule.frame),
               (!stickyAction.exists || schedule.frame.maxY < stickyAction.frame.minY - 4) {
                break
            }
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
                .press(
                    forDuration: 0.05,
                    thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                )
        }
        let schedule = app.buttons["view-plan-schedule"].firstMatch
        let stickyAction = app.buttons["start-planned-workout"].firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.intersects(schedule.frame))
        XCTAssertTrue(!stickyAction.exists || schedule.frame.maxY < stickyAction.frame.minY - 4)
        schedule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-screen"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13e_Plan_Calendar")

        let dayRows = app.buttons.matching(identifier: "plan-calendar-day")
        XCTAssertGreaterThan(dayRows.count, 2)
        dayRows.element(boundBy: 2).tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-day-screen"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13f_Plan_Calendar_Day")
    }

    func testCaptureTrainingCalendarScreenshots() {
        let app = launchFixture(
            "training-calendar",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        tapButton("open-training-calendar", in: app)
        waitForTrainingCalendar(in: app)
        XCTAssertTrue(app.staticTexts["Today Strength"].waitForExistence(timeout: 5))
        saveScreenshot("calendar/21_Training_Calendar")

        let reschedule = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "training-calendar-reschedule-")
        ).firstMatch
        XCTAssertTrue(reschedule.waitForExistence(timeout: 5))
        reschedule.tap()
        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 5))
        saveScreenshot("calendar/21b_Training_Calendar_Reschedule")
    }

    func testCaptureTrainingCalendarEmptyScreenshot() {
        let app = launchFreshApp()
        tapButton("open-training-calendar", in: app)
        waitForTrainingCalendar(in: app)
        let emptyState = app.staticTexts["Nothing recorded for this day"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        app.swipeUp()
        saveScreenshot("calendar/21c_Training_Calendar_Empty")
    }

    /// The rotation fixture deliberately includes a completed advancement, so
    /// its More menu exposes a meaningful Undo action. Each mutable detail
    /// state gets a fresh launch, keeping the screenshots independent and
    /// avoiding a paused state leaking into the active source capture.
    func testCaptureRepeatingPlanScreenshots() {
        let home = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        XCTAssertTrue(home.descendants(matching: .any)["active-repeating-plan-badge"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01i_Home_Active_Rotation")

        selectTab(.train, in: home)
        XCTAssertTrue(home.buttons["current-plan-start-next"].waitForExistence(timeout: 8))
        XCTAssertFalse(home.descendants(matching: .any)["current-plan-progress"].exists)
        saveScreenshot("plans/22_Train_Current_Rotation")
        selectTab(.today, in: home)

        tapButton("start-repeating-workout", in: home)
        XCTAssertTrue(home.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        let rotationSource = home.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Rotation Screenshot Fixture")
        ).firstMatch
        XCTAssertTrue(rotationSource.waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08n_Active_Workout_Rotation_Source")

        let detail = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        openRepeatingPlanFixture(in: detail)
        detail.swipeUp()
        saveScreenshot("plans/22_Repeating_Plan_Detail")

        revealRepeatingPlanActions(in: detail)
        tapControl("repeating-plan-more-actions", in: detail)
        tapButton("Choose Another Workout", in: detail)
        XCTAssertTrue(detail.navigationBars["Choose Workout"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22a_Repeating_Plan_Choose_Another")

        let paused = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        openRepeatingPlanFixture(in: paused)
        revealRepeatingPlanActions(in: paused)
        tapControl("pause-repeating-plan", in: paused)
        XCTAssertTrue(paused.buttons["resume-repeating-plan"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22b_Repeating_Plan_Paused")

        let undo = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        openRepeatingPlanFixture(in: undo)
        revealRepeatingPlanActions(in: undo)
        tapControl("repeating-plan-more-actions", in: undo)
        XCTAssertTrue(undo.buttons["Undo Last Advancement"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22c_Repeating_Plan_Undo")
    }

    private func openRepeatingPlanFixture(in app: XCUIApplication) {
        openPlans(.mine, in: app)
        let plan = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Rotation Screenshot Fixture")
        ).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        XCTAssertTrue(app.buttons["start-repeating-plan-workout"].waitForExistence(timeout: 5))
    }

    private func revealRepeatingPlanActions(in app: XCUIApplication) {
        let actions = app.descendants(matching: .any)["repeating-plan-more-actions"]
        for _ in 0..<3 where !actions.exists {
            app.swipeUp()
        }
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
    }

    private func waitForTrainingCalendar(in app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["training-calendar-screen"].waitForExistence(timeout: 5))
        let today = app.buttons["training-calendar-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: today
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 5), .completed)
    }

    /// Accessibility identifiers appear as soon as a question transition
    /// starts. Screenshots need the short directional spring (and the results
    /// assembly) to finish, otherwise the captured frame can contain the new
    /// identifier while its header is still clipped between positions.
    private func settleOnboardingCapture() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.55))
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
            XCTFail(
                "Failed to save screenshot '\(name)': \(error)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Active-workout keypad matrix

    /// Captures every editable field exposed by every `TrackingType`.
    func testCaptureEveryActiveWorkoutKeypad() {
        let app = launchFixture("active-all-tracking-types")

        func capture(
            _ exerciseName: String,
            field: String,
            slug: String,
            typedDigits: String? = nil,
            expectedValue: String? = nil
        ) {
            XCTAssertTrue(app.staticTexts["active-exercise-\(exerciseName)"].waitForExistence(timeout: 5))
            let identifier = "\(field)-field-\(exerciseName)-0"
            scrollToElement(app.buttons[identifier].firstMatch, in: app)
            var target = app.buttons[identifier].firstMatch
            XCTAssertTrue(target.waitForExistence(timeout: 5))
            XCTAssertTrue(target.isHittable)
            target.tap()

            let pill = app.buttons["panel-value-\(field)"]
            if !pill.waitForExistence(timeout: 2) {
                target = app.buttons[identifier].firstMatch
                XCTAssertTrue(target.waitForExistence(timeout: 5))
                XCTAssertTrue(target.isHittable)
                target.tap()
            }
            XCTAssertTrue(pill.waitForExistence(timeout: 5), "Panel did not select \(field) for \(exerciseName)")
            XCTAssertTrue(pill.isSelected)
            if let typedDigits {
                if field == "duration" {
                    tapButton("duration-keypad-digits", in: app)
                }
                for digit in typedDigits {
                    tapButton("keypad-key-\(digit)", in: app)
                }
            }
            if let expectedValue {
                XCTAssertEqual(
                    pill.value as? String,
                    expectedValue,
                    "Expected \(field) entry to render as \(expectedValue)"
                )
            }
            saveScreenshot("keyboards/\(slug)")
            dismissKeypadIfPresent(in: app)
        }

        func advance(to exerciseName: String) {
            tapButton("stage-next", in: app)
            XCTAssertTrue(app.staticTexts["active-exercise-\(exerciseName)"].waitForExistence(timeout: 5))
        }

        capture("Bench Press", field: "reps", slug: "01_Weight_And_Reps_Reps")
        capture("Bench Press", field: "weight", slug: "02_Weight_And_Reps_Weight")
        advance(to: "Push-Up")
        capture("Push-Up", field: "reps", slug: "03_Reps_Only")
        advance(to: "Weighted Pull-Up")
        capture("Weighted Pull-Up", field: "reps", slug: "04_Weighted_Bodyweight_Reps")
        capture("Weighted Pull-Up", field: "weight", slug: "05_Weighted_Bodyweight_Weight")
        advance(to: "Assisted Pull Up")
        capture("Assisted Pull Up", field: "reps", slug: "06_Assisted_Bodyweight_Reps")
        capture("Assisted Pull Up", field: "weight", slug: "07_Assisted_Bodyweight_Assistance")
        advance(to: "Plank")
        capture(
            "Plank",
            field: "duration",
            slug: "08_Duration",
            typedDigits: "130",
            expectedValue: "1:30"
        )
        advance(to: "Treadmill Run")
        capture(
            "Treadmill Run",
            field: "duration",
            slug: "09_Duration_And_Distance_Duration",
            typedDigits: "130",
            expectedValue: "1:30"
        )
        capture("Treadmill Run", field: "distance", slug: "10_Duration_And_Distance_Distance")
        advance(to: "Stationary Bike")
        capture("Stationary Bike", field: "calories", slug: "11_Calories")
    }

    // MARK: - Manual caffeine-source review (not part of the ScreenshotCoverage.md catalog)

    /// Captures the Log caffeine source states the catalogued
    /// `nutrition/20a_Caffeine_Quick_Log.png` never reaches: the pre-workout
    /// intensity list, its custom-value fields, and the free-form entry. This is
    /// a design review aid, not a canonical product screenshot. Run it directly:
    /// `-only-testing:GymTrackerUITEST/ScreenshotUITests/testReviewCaffeineSourceStates`.
    func testReviewCaffeineSourceStates() {
        let app = launchFixture(
            "today-complete",
            additionalArguments: ["-ui-testing-open-caffeine-log"],
            expectsActiveWorkout: false,
            expectedHomeControl: "confirm-log-caffeine"
        )
        XCTAssertTrue(app.navigationBars["Log caffeine"].waitForExistence(timeout: 5))

        tapControl("Pre-workout", in: app)
        XCTAssertTrue(app.staticTexts["How strong?"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-preworkout-intensity")

        tapControl("Custom", in: app)
        XCTAssertTrue(app.textFields["caffeine-preworkout-exact-mg"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-preworkout-custom")

        tapControl("Other caffeine source", in: app)
        XCTAssertTrue(app.textFields["caffeine-other-exact-mg"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-other")
    }

}
