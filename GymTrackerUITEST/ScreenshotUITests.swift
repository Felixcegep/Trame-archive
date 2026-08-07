import XCTest
@testable import GymTracker

final class ScreenshotUITests: GymTrackerUITestCase {
    func testCaptureLaunchBrandScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-hold-launch-experience"
        ]
        app.launch()

        let brandMark = app.descendants(matching: .any)["launch-brand-mark"]
        XCTAssertTrue(brandMark.waitForExistence(timeout: 15))
        let completedFrame = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Ready"),
            object: brandMark
        )
        XCTAssertEqual(XCTWaiter().wait(for: [completedFrame], timeout: 15), .completed)
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
        tapButton("Create library item", in: app)
        tapButton("New Workout", in: app)

        let nameField = app.textFields["template-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        tapButton("template-exercise-Arnold Press", in: app)
        saveScreenshot("templates/12b_New_Workout_Form")

        tapButton("exercise-filters-button", in: app)
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        saveScreenshot("templates/12c_Exercise_Filters")
        tapFirstAvailableButton(["Done"], in: app)
        tapButton("Cancel", in: app)
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5))

        tapButton("Create library item", in: app)
        tapButton("New Exercise", in: app)

        let exerciseNameField = app.textFields["exercise-name-field"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 5))
        saveScreenshot("exercises/18_New_Exercise_Form")

        tapButton("exercise-muscles-link", in: app)
        XCTAssertTrue(app.navigationBars["Muscles Worked"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18b_New_Exercise_Muscles")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tapButton("exercise-advanced-link", in: app)
        XCTAssertTrue(app.navigationBars["Advanced Details"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18c_New_Exercise_Advanced")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Advanced Details"].waitForNonExistence(timeout: 5))
        tapButton("Cancel", in: app)
        XCTAssertTrue(exerciseNameField.waitForNonExistence(timeout: 5))

        tapButton("exercises-browser", in: app)

        let benchPress = app.buttons["exercise-row-Bench Press"]
        XCTAssertTrue(benchPress.waitForExistence(timeout: 5))
        benchPress.press(forDuration: 1.2)
        tapButton("Hide", in: app)

        let rowRemoved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: benchPress
        )
        XCTAssertEqual(XCTWaiter().wait(for: [rowRemoved], timeout: 5), .completed)

        // The context-menu interaction can leave the list scrolled, occluding
        // the Hidden Exercises row under the top edge. Scroll back first.
        app.swipeDown()

        let hiddenExercises = app.buttons["hidden-exercises"]
        XCTAssertTrue(hiddenExercises.waitForExistence(timeout: 5))
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


    /// Today, the "Start a workout" sheet, the Train secondary states, empty
    /// Progress, and Settings are five destinations of the exact same fresh
    /// seed, navigated by tab and sheet taps. One launch replaces what used
    /// to be three (the plain tab tour, the template sheet, and the Train
    /// secondary states, which were already three separate launches of this
    /// identical seed).
    func testCaptureOverviewAndLibraryTourScreenshots() {
        let app = launchFreshApp()

        saveScreenshot("overview/01_Today")

        tapButton("start-free-workout", in: app)
        XCTAssertTrue(app.navigationBars["Start a workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01b_Home_Template_Sheet")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Start a workout"].waitForNonExistence(timeout: 5))

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
    }

    /// Both destinations only need Settings opened once, then a scroll to
    /// each row — one launch replaces two.
    func testCaptureSettingsShortcutsAndBetaFeedbackScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launch()

        let shortcutsLink = app.descendants(matching: .any)["settings-shortcuts-link"]
        // Settings is a lazy Form; the link is below the initial viewport and
        // is not materialized until the form has been scrolled toward it.
        for _ in 0..<8 where !shortcutsLink.exists {
            app.swipeUp()
        }
        XCTAssertTrue(shortcutsLink.waitForExistence(timeout: 45))
        scrollToElement(shortcutsLink, in: app)
        saveScreenshot("overview/04d_Settings_Shortcuts")

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
        app.launch()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 45))
        let dataSafety = app.descendants(matching: .any)["settings-data-safety-last-export"]
        for _ in 0..<6 where dataSafety.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(dataSafety.exists)
        app.swipeUp()
        saveScreenshot("overview/04g_Settings_Data_Safety")
    }

    func testCaptureBetaFeedbackActiveLoggingScreenshot() {
        let app = launchFixture("active-in-progress")
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: true, in: app)
        tapButton("minimize-workout", in: app)
        XCTAssertTrue(app.buttons["resume-active-workout"].waitForExistence(timeout: 10))

        selectTab(.settings, in: app)
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
        saveScreenshot("active-workout/05_Active_Workout_Empty")
        tapButton("minimize-workout", in: empty)
        saveScreenshot("overview/05_Home_With_Active_Workout")

        let inProgress = launchFixture("active-in-progress")
        tapButton("add-active-exercise", in: inProgress)
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

        tapButton("add-execution-block", in: inProgress)
        XCTAssertTrue(inProgress.navigationBars["Execution Block"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.buttons["create-execution-block"].exists)
        saveScreenshot("active-workout/07c_Execution_Block_Builder")
        tapButton("Cancel", in: inProgress)
        XCTAssertTrue(inProgress.navigationBars["Execution Block"].waitForNonExistence(timeout: 5))

        tapButton("active-workout-menu", in: inProgress)
        tapButton("discard-workout", in: inProgress)
        XCTAssertTrue(inProgress.buttons["confirm-discard-workout"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08e_Discard_Workout")

        let executionBlockActive = launchFixture("active-execution-block")
        XCTAssertTrue(executionBlockActive.staticTexts["EXECUTION BLOCKS"].waitForExistence(timeout: 5))
        XCTAssertTrue(executionBlockActive.staticTexts["Power circuit"].exists)
        XCTAssertTrue(executionBlockActive.buttons["Complete round"].exists)
        saveScreenshot("active-workout/07d_Execution_Block_Active")

        let advancedSet = launchFixture("active-advanced-set")
        tapButton("reps-field-Bench Press-0", in: advancedSet)
        tapButton("panel-details", in: advancedSet)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["drop-set-structure"].waitForExistence(timeout: 5))
        XCTAssertFalse(advancedSet.descendants(matching: .any)["set-method-picker"].exists)
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
        tapButton("Finish workout", in: partial)
        saveScreenshot("review/09_Save_Workout")
        tapButton("save-workout", in: partial)
        XCTAssertTrue(partial.buttons["Save completed sets"].waitForExistence(timeout: 5))
        saveScreenshot("review/09b_Partial_Save_Confirmation")
    }

    /// Kept independent from the wide Active Workout tour: decision-aware
    /// substitution owns three related screens and needs a stable fixture for
    /// its reason → option → explanation → confirmation path.
    func testCaptureDecisionAwareSubstitutionScreenshots() {
        let draft = launchFixture("active-draft")
        tapButton("exercise-menu-Bench Press", in: draft)
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

        enterValue("45", field: "duration", for: "Plank", set: 0, in: app)
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
        enterValue("2", field: "duration", for: "Plank", set: 0, in: app)
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
        XCTAssertTrue(app.buttons["Start next set"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08c_Rest_Ready")
    }

    func testCaptureHistoryScreenshots() {
        let app = launchFixture("history-bench", expectsActiveWorkout: false)

        selectTab(.history, in: app)
        XCTAssertTrue(app.buttons["history-workout-row"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("history/10_History_With_Workout")
        tapButton("Records", in: app)
        XCTAssertTrue(app.staticTexts["Format records"].waitForExistence(timeout: 5))
        saveScreenshot("history/10b_Expanded_Records")
        tapButton("Workouts", in: app)
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
        selectTab(.history, in: app)

        let balanceTab = app.buttons["Volume"]
        XCTAssertTrue(balanceTab.waitForExistence(timeout: 5))
        balanceTab.tap()
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
        // The recommendation now lives inside the exercise it describes, which
        // is the next one down while rest belongs to the completed exercise.
        let card = app.descendants(matching: .any)["progression-recommendation-card-Bench Press"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        scrollToElement(card, in: app)
        saveScreenshot("progression/10f_Progression_With_Rest_Running")

        // scrollToElement only scrolls forward (down), so bring the rest
        // card's Pause control back into view before tapping it.
        let pauseButton = app.buttons["Pause rest"]
        for _ in 0..<6 where !pauseButton.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(pauseButton.isHittable)
        pauseButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))

        let pausedCard = app.descendants(matching: .any)["progression-recommendation-card-Bench Press"]
        XCTAssertTrue(pausedCard.waitForExistence(timeout: 5))
        scrollToElement(pausedCard, in: app)
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
        saveScreenshot("progression/10g_Progression_Receipt_Why")
    }

    /// T-36 reachability pass. These states were previously either behind a
    /// capture-only launch hook or reachable only after seeded navigation.
    func testCaptureT36MissingStatesScreenshots() {
        let welcome = XCUIApplication()
        welcome.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-show-welcome"]
        welcome.launch()
        XCTAssertTrue(welcome.descendants(matching: .any)["welcome"].waitForExistence(timeout: 30))
        saveScreenshot("overview/00_Welcome")
        welcome.terminate()

        let storage = XCUIApplication()
        storage.launchArguments = ["-ui-testing", "-ui-testing-storage-unavailable"]
        storage.launch()
        XCTAssertTrue(storage.descendants(matching: .any)["storage-unavailable"].waitForExistence(timeout: 15))
        saveScreenshot("overview/00b_Storage_Unavailable")
        storage.terminate()

        let missingRoute = XCUIApplication()
        missingRoute.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-missing-route"]
        missingRoute.launch()
        XCTAssertTrue(missingRoute.staticTexts["Exercise unavailable"].waitForExistence(timeout: 30))
        saveScreenshot("overview/02e_Route_Unavailable")
        missingRoute.terminate()

        let guidedError = XCUIApplication()
        guidedError.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-guided-source-error"]
        guidedError.launch()
        XCTAssertTrue(guidedError.alerts["Couldn’t update training source"].waitForExistence(timeout: 30))
        saveScreenshot("active-workout/08s_Guided_Source_Error")
        guidedError.terminate()

        let mobilityError = XCUIApplication()
        mobilityError.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-mobility-link-error"]
        mobilityError.launch()
        XCTAssertTrue(mobilityError.alerts["Couldn’t start mobility"].waitForExistence(timeout: 30))
        saveScreenshot("active-workout/08t_Mobility_Link_Error")
        mobilityError.terminate()

        let failedSave = launchFixture(
            "active-completed-set",
            additionalArguments: ["-ui-testing-fail-workout-save"]
        )
        tapButton("Finish workout", in: failedSave)
        tapButton("save-workout", in: failedSave)
        if failedSave.buttons["Save completed sets"].waitForExistence(timeout: 5) {
            tapButton("Save completed sets", in: failedSave)
        }
        XCTAssertTrue(failedSave.alerts.firstMatch.waitForExistence(timeout: 10))
        saveScreenshot("review/09c_Save_Failure_Alert")
        failedSave.terminate()

        let linked = launchFixture("linked-mobility-workout", expectsActiveWorkout: false)
        tapButton("start-free-workout", in: linked)
        let linkedTemplate = linked.buttons["workout-template-Linked Mobility Screenshot"]
        // The picker is a lazy List. The fixture template is sorted into the
        // middle of the catalogue, so it may not be materialized until the
        // list has been scrolled far enough for its row to enter the viewport.
        for _ in 0..<12 where !linkedTemplate.isHittable {
            linked.swipeUp()
        }
        XCTAssertTrue(linkedTemplate.waitForExistence(timeout: 10))
        XCTAssertTrue(linkedTemplate.isHittable)
        linkedTemplate.tap()
        XCTAssertTrue(linked.buttons["skip-linked-warmup"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08q_Warmup_Preparation_Dialog")
        tapButton("skip-linked-warmup", in: linked)
        XCTAssertTrue(linked.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        enterValidValues(for: "Bench Press", set: 0, in: linked)
        completeSet("Bench Press", index: 0, dismissRest: true, in: linked)
        tapButton("Finish workout", in: linked)
        tapButton("save-workout", in: linked)
        if linked.buttons["Save completed sets"].waitForExistence(timeout: 5) {
            tapButton("Save completed sets", in: linked)
        }
        XCTAssertTrue(linked.buttons["start-linked-cooldown"].waitForExistence(timeout: 10))
        saveScreenshot("active-workout/08r_Cooldown_Prompt")

        let history = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: history)
        saveScreenshot("overview/03a_Progress_Populated")
        let trendsLink = history.descendants(matching: .any)["progress-training-trends"]
        XCTAssertTrue(trendsLink.waitForExistence(timeout: 10))
        trendsLink.tap()
        XCTAssertTrue(history.navigationBars["History"].waitForExistence(timeout: 10))
        XCTAssertTrue(history.descendants(matching: .any)["training-frequency-chart"].waitForExistence(timeout: 10))
        saveScreenshot("history/03b_Progress_Trends_Frequency")
        history.swipeUp()
        let chartPoint = history.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.72))
        chartPoint.press(forDuration: 0.1)
        saveScreenshot("history/03c_Progress_Trends_Exercise_Selected")

        let nutrition = launchFixture(
            "nutrition-today",
            expectsActiveWorkout: false,
            expectedHomeControl: "open-nutrition-today"
        )
        tapButton("open-nutrition-today", in: nutrition)
        tapButton("open-food-library", in: nutrition)
        XCTAssertTrue(nutrition.navigationBars["Food library"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20b_Food_Library")
        nutrition.navigationBars.buttons.element(boundBy: 0).tap()
        tapButton("open-meal-templates", in: nutrition)
        XCTAssertTrue(nutrition.navigationBars["Recipes"].waitForExistence(timeout: 10))
        saveScreenshot("nutrition/20c_Meal_Template_Library")

        let repeatMeal = launchFixture(
            "today-complete",
            expectsActiveWorkout: false
        )
        tapButton("open-nutrition-today", in: repeatMeal)
        XCTAssertTrue(repeatMeal.descendants(matching: .any)["nutrition-today-totals"].waitForExistence(timeout: 10))
        let repeatButton = repeatMeal.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "repeat-logged-meal-")
        ).firstMatch
        scrollToElement(repeatButton, in: repeatMeal)
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 10))
        repeatButton.tap()
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

        tapButton("Finish workout", in: app)
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
        saveScreenshot("overview/01c_Home_Workout_Conflict")
    }

    /// Daily check-in, the caffeine quick log, and the Mobility library are
    /// three sheets/destinations opened directly from the same "today-complete"
    /// Today screen. Check-in and caffeine are cancelable without saving, so
    /// one launch replaces three.
    func testCaptureTodayCompleteTourScreenshots() {
        let app = launchFixture("today-complete", expectsActiveWorkout: false)

        // A completed check-in is intentionally tucked behind Today's handled
        // support disclosure. Expand it before reopening the entry.
        tapButton("today-toggle-handled-support", in: app)
        tapButton("open-daily-check-in", in: app)
        XCTAssertTrue(app.navigationBars["Daily check-in"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01e_Daily_Check_In")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Daily check-in"].waitForNonExistence(timeout: 5))

        tapButton("today-caffeine-summary", in: app)
        XCTAssertTrue(app.navigationBars["Log caffeine"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20a_Caffeine_Quick_Log")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Log caffeine"].waitForNonExistence(timeout: 5))

        // Managing routines is the Train tab's job; Today only starts or resumes
        // one, so the library is reached from Train rather than a Today link.
        selectTab(.library, in: app)
        tapButton("train-mobility-library", in: app)
        XCTAssertTrue(app.navigationBars["Mobility"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18_Mobility_Routines")
    }

    func testCaptureDailyCheckInWeightDueScreenshot() {
        let app = launchFixture("today-weight-due", expectsActiveWorkout: false)
        tapButton("open-daily-check-in", in: app)
        XCTAssertTrue(app.textFields["daily-check-in-weight"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01h_Daily_Check_In_Weight_Due")
    }

    func testCaptureBodyWeightHistoryScreenshot() {
        let app = launchFixture("body-weight-history", expectsActiveWorkout: false)
        selectTab(.settings, in: app)
        tapButton("settings-body-weight", in: app)
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
        saveScreenshot("overview/01d_Home_Active_Plan")

        tapButton("today-reschedule-planned-workout", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01f_Today_Reschedule_Workout")
        tapButton("Cancel", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForNonExistence(timeout: 5))

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
        app.launch()
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
        saveScreenshot("mobility/19_Active_Mobility")
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
        scrollToElement(createRoutine, in: app)
        XCTAssertTrue(createRoutine.waitForExistence(timeout: 5))
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
            expectedHomeControl: "open-nutrition-today"
        )
        tapButton("open-nutrition-today", in: app)
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["nutrition-today-totals"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20_Nutrition_Today")
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
            expectedHomeControl: "open-nutrition-today"
        )
        tapButton("open-nutrition-today", in: app)
        let quickLog = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-log-food-")).firstMatch
        XCTAssertTrue(quickLog.waitForExistence(timeout: 5))
        quickLog.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5))
        tapButton("confirm-log-food", in: app)
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
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
        settings.launch()
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
        preview.launch()
        XCTAssertTrue(preview.descendants(matching: .any)["import-preview"].waitForExistence(timeout: 15))
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
        tapButton("template-add-menu", in: app)
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
        tapButton("edit-plan", in: app)
        let editWorkout = app.buttons["edit-plan-workout"].firstMatch
        scrollToElement(editWorkout, in: app)
        editWorkout.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let executionBlock = app.buttons["add-plan-execution-block"]
        if executionBlock.exists == false {
            // The editor row is a nested SwiftUI button inside a Form cell;
            // retry once through XCTest's semantic tap if the coordinate event
            // was consumed by the cell's scroll transition.
            editWorkout.tap()
        }
        scrollToElement(executionBlock, in: app)
        executionBlock.tap()
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
        tapButton("view-plan-schedule", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-completed"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-skipped"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-missed"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-in-progress"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-available"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["plan-calendar-state-upcoming"].exists)

        let dayRows = app.buttons.matching(identifier: "plan-calendar-day")
        XCTAssertEqual(dayRows.count, 6)
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
        tapButton("view-plan-schedule", in: app)
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
        XCTAssertTrue(app.staticTexts["Nothing recorded for this day"].waitForExistence(timeout: 5))
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
        saveScreenshot("plans/22_Repeating_Plan_Detail")

        revealRepeatingPlanActions(in: detail)
        tapButton("repeating-plan-more-actions", in: detail)
        tapButton("Choose Another Workout", in: detail)
        XCTAssertTrue(detail.navigationBars["Choose Workout"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22a_Repeating_Plan_Choose_Another")

        let paused = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        openRepeatingPlanFixture(in: paused)
        tapButton("pause-repeating-plan", in: paused)
        XCTAssertTrue(paused.buttons["resume-repeating-plan"].waitForExistence(timeout: 5))
        saveScreenshot("plans/22b_Repeating_Plan_Paused")

        let undo = launchFixture(
            "repeating-plan-active",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-repeating-workout"
        )
        openRepeatingPlanFixture(in: undo)
        revealRepeatingPlanActions(in: undo)
        tapButton("repeating-plan-more-actions", in: undo)
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
        let actions = app.buttons["repeating-plan-more-actions"]
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

    // MARK: - Manual keypad review (not part of the ScreenshotCoverage.md catalog)

    /// Walks the `active-all-tracking-types` fixture — one exercise per
    /// `TrackingType` — and captures its set-entry panel, the keypad it opens,
    /// and Set Details with Advanced options both collapsed and expanded. This
    /// is a debug aid for reviewing every keypad configuration in one pass, not
    /// a canonical product screenshot: it is not wired into any
    /// `capture_screenshots.sh` scene and is not listed in
    /// `ScreenshotCoverage.md`. Run it directly:
    /// `-only-testing:GymTrackerUITEST/ScreenshotUITests/testReviewKeypadForEveryTrackingType`.
    func testReviewKeypadForEveryTrackingType() {
        let app = launchFixture("active-all-tracking-types")

        func review(_ exerciseName: String, field: String, slug: String) {
            let target = app.buttons["\(field)-field-\(exerciseName)-0"]
            if !target.exists {
                let card = activeExerciseCard(exerciseName, in: app)
                scrollToElement(card, in: app)
                card.tap()
            }
            scrollToElement(target, in: app)
            target.tap()

            let pill = app.buttons["panel-value-\(field)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 5), "Panel did not select \(field) for \(exerciseName)")
            XCTAssertTrue(pill.isSelected)
            saveScreenshot("debug/keypad-\(slug)")

            // Set Details — same destination the panel's "Details" chip and a
            // set row's advanced entry paths both open — first with Advanced
            // options collapsed, then expanded.
            tapButton("panel-details", in: app)
            XCTAssertTrue(app.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
            saveScreenshot("debug/details-\(slug)")

            tapButton("set-advanced-options", in: app)
            XCTAssertTrue(app.buttons["record-set-velocity"].waitForExistence(timeout: 5))
            saveScreenshot("debug/details-advanced-\(slug)")

            tapButton("close-set-details", in: app)
            // Wait for the sheet's dismissal animation to finish before acting
            // again — a tap thrown immediately after can land on the closing
            // sheet instead of the panel underneath it.
            XCTAssertTrue(
                app.descendants(matching: .any)["set-details-screen"].waitForNonExistence(timeout: 5)
            )
            dismissKeypadIfPresent(in: app)
        }

        review("Bench Press", field: "reps", slug: "01-weight-and-reps")
        review("Push-Up", field: "reps", slug: "02-reps-only")
        review("Weighted Pull-Up", field: "reps", slug: "03-weighted-bodyweight")
        review("Assisted Pull-Up", field: "reps", slug: "04-assisted-bodyweight")
        review("Plank", field: "duration", slug: "05-duration")
        review("Treadmill Run", field: "duration", slug: "06-duration-and-distance-duration-field")
        review("Treadmill Run", field: "distance", slug: "07-duration-and-distance-distance-field")
        review("Stationary Bike", field: "calories", slug: "08-calories")
    }

    // MARK: - Manual caffeine-source review (not part of the ScreenshotCoverage.md catalog)

    /// Captures the Log caffeine source states the catalogued
    /// `nutrition/20a_Caffeine_Quick_Log.png` never reaches: the pre-workout
    /// intensity list, its custom-value fields, and the free-form entry. This is
    /// a design review aid, not a canonical product screenshot. Run it directly:
    /// `-only-testing:GymTrackerUITEST/ScreenshotUITests/testReviewCaffeineSourceStates`.
    func testReviewCaffeineSourceStates() {
        let app = launchFixture("today-complete", expectsActiveWorkout: false)

        tapButton("today-caffeine-summary", in: app)
        XCTAssertTrue(app.navigationBars["Log caffeine"].waitForExistence(timeout: 5))

        tapButton("Pre-workout", in: app)
        XCTAssertTrue(app.staticTexts["How strong?"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-preworkout-intensity")

        tapButton("Custom, Enter the exact label value", in: app)
        XCTAssertTrue(app.textFields["caffeine-preworkout-exact-mg"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-preworkout-custom")

        tapButton("Other caffeine source", in: app)
        XCTAssertTrue(app.textFields["caffeine-other-exact-mg"].waitForExistence(timeout: 5))
        saveScreenshot("debug/caffeine-other")
    }

}
