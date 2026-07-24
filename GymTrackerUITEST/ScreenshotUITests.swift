import XCTest
@testable import GymTracker

final class ScreenshotUITests: GymTrackerUITestCase {
    func testCaptureNewWorkoutFormScreenshot() {
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
    }

    func testCaptureNewExerciseFormScreenshots() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("Create library item", in: app)
        tapButton("New Exercise", in: app)

        let nameField = app.textFields["exercise-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        saveScreenshot("exercises/18_New_Exercise_Form")

        tapButton("exercise-muscles-link", in: app)
        XCTAssertTrue(app.navigationBars["Muscles Worked"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18b_New_Exercise_Muscles")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tapButton("exercise-advanced-link", in: app)
        XCTAssertTrue(app.navigationBars["Advanced Details"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/18c_New_Exercise_Advanced")
    }

    func testCaptureHiddenExercisesScreenshot() {
        let app = launchFreshApp()
        selectTab(.library, in: app)

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


    func testCaptureOverviewScreenshots() {
        let app = launchFreshApp()

        saveScreenshot("overview/01_Today")
        selectTab(.library, in: app)
        saveScreenshot("overview/02_Train")
        selectTab(.progress, in: app)
        saveScreenshot("overview/03_Progress_Empty")
        selectTab(.settings, in: app)
        saveScreenshot("overview/04_Settings")
    }

    func testCaptureSettingsShortcutsScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launch()

        let shortcutsLink = app.descendants(matching: .any)["settings-shortcuts-link"]
        XCTAssertTrue(shortcutsLink.waitForExistence(timeout: 10))
        scrollToElement(shortcutsLink, in: app)
        saveScreenshot("overview/04d_Settings_Shortcuts")
    }

    func testCaptureSettingsBetaFeedbackScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launch()

        let feedbackRow = app.descendants(matching: .any)["settings-beta-feedback"]
        scrollToElement(feedbackRow, in: app)
        feedbackRow.tap()

        let feedbackScreen = app.descendants(matching: .any)["beta-feedback-screen"]
        XCTAssertTrue(feedbackScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["beta-feedback-diagnostics-preview"].exists)
        saveScreenshot("overview/04e_Settings_Beta_Feedback")
    }

    func testCaptureActiveEmptyAndResumeScreenshots() {
        let empty = launchFixture("active-empty")
        saveScreenshot("active-workout/05_Active_Workout_Empty")
        tapButton("minimize-workout", in: empty)
        saveScreenshot("overview/05_Home_With_Active_Workout")
    }

    func testCaptureActiveToolScreenshots() {
        let inProgress = launchFixture("active-in-progress")
        tapButton("add-active-exercise", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["exercise-picker-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.navigationBars["Add Exercise"].exists)
        saveScreenshot("active-workout/06_Add_Exercise_Sheet")
        tapButton("close-exercise-picker", in: inProgress)
        XCTAssertFalse(inProgress.descendants(matching: .any)["exercise-picker-screen"].waitForExistence(timeout: 2))
        // Plate calculator is a child action of the set's native Menu, so it
        // is not present in the accessibility tree until that menu is open.
        tapButton("set-menu-Bench Press-0", in: inProgress)
        tapButton("plate-calculator-Bench Press", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["plate-calculator-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.navigationBars["Plate calculator"].exists)
        saveScreenshot("active-workout/07_Plate_Calculator")
        tapFirstAvailableButton(["Done", "Terminé"], in: inProgress)
        tapButton("set-menu-Bench Press-0", in: inProgress)
        tapButton("Set details", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.staticTexts["Set 1"].exists)
        XCTAssertTrue(inProgress.sliders["rir-slider"].exists)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-advanced-options"].exists)
        XCTAssertFalse(inProgress.descendants(matching: .any)["set-method-picker"].exists)
        saveScreenshot("active-workout/07b_Set_Details")
        tapButton("set-advanced-options", in: inProgress)
        XCTAssertTrue(inProgress.descendants(matching: .any)["set-method-picker"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.buttons["record-set-velocity"].exists)
    }

    func testCaptureExecutionBlockScreenshots() {
        let builder = launchFixture("active-in-progress")
        tapButton("add-execution-block", in: builder)
        XCTAssertTrue(builder.navigationBars["Execution Block"].waitForExistence(timeout: 5))
        XCTAssertTrue(builder.buttons["create-execution-block"].exists)
        saveScreenshot("active-workout/07c_Execution_Block_Builder")

        let active = launchFixture("active-execution-block")
        XCTAssertTrue(active.staticTexts["EXECUTION BLOCKS"].waitForExistence(timeout: 5))
        XCTAssertTrue(active.staticTexts["Power circuit"].exists)
        XCTAssertTrue(active.buttons["Complete round"].exists)
        saveScreenshot("active-workout/07d_Execution_Block_Active")

        let advancedSet = launchFixture("active-advanced-set")
        tapButton("set-menu-Bench Press-0", in: advancedSet)
        tapButton("Set details", in: advancedSet)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["drop-set-structure"].waitForExistence(timeout: 5))
        XCTAssertFalse(advancedSet.descendants(matching: .any)["set-method-picker"].exists)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["specialized-metric-picker"].exists)
        XCTAssertTrue(advancedSet.descendants(matching: .any)["add-set-segment"].exists)
        saveScreenshot("active-workout/07e_Set_Method_Segments")
    }

    func testCaptureComplexComponentResultsScreenshot() {
        let app = launchFixture("active-complex-components")
        XCTAssertTrue(app.staticTexts["Three-Position Snatch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["complex-component-0"].exists)
        XCTAssertTrue(app.buttons["complex-component-1"].exists)
        XCTAssertTrue(app.buttons["complex-component-2"].exists)
        saveScreenshot("active-workout/07f_Complex_Component_Results")
    }

    func testCaptureExerciseSwapScreenshot() {
        let app = launchFixture("active-draft")
        tapButton("exercise-menu-Bench Press", in: app)
        tapButton("swap-exercise-Bench Press", in: app)
        XCTAssertTrue(app.navigationBars["Swap Exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["swap-option-Dumbbell Bench Press"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08j_Exercise_Swap")
    }

    func testCaptureCompletedSetScreenshot() {
        let completedSet = launchFixture("active-completed-set")
        XCTAssertTrue(completedSet.buttons["complete-set-Bench Press-1"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08_Active_Workout_With_Set")
    }

    func testCaptureSupersetScreenshot() {
        let app = launchFixture("active-superset")
        XCTAssertTrue(app.staticTexts["superset-label-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["superset-label-Barbell Row"].exists)
        saveScreenshot("active-workout/08k_Active_Superset")
    }

    func testSupersetCompletionAdvancesWithoutRest() {
        let app = launchFixture("active-superset")
        XCTAssertTrue(app.staticTexts["superset-label-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["superset-label-Barbell Row"].exists)

        tapButton("complete-set-Bench Press-0", in: app)

        XCTAssertTrue(app.buttons["complete-set-Barbell Row-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Rest between sets"].exists)
    }

    func testCaptureCompletedExerciseCollapsedScreenshot() {
        let collapsed = launchFixture("active-completed-exercise")
        XCTAssertTrue(collapsed.buttons["complete-set-Barbell Row-0"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08d_Completed_Exercise_Collapsed")
    }

    func testCapturePartialSaveScreenshots() {
        let partial = launchFixture("active-partial-save")
        tapButton("Review Workout", in: partial)
        saveScreenshot("review/09_Save_Workout")
        tapButton("save-workout", in: partial)
        XCTAssertTrue(partial.buttons["Save completed sets"].waitForExistence(timeout: 5))
        saveScreenshot("review/09b_Partial_Save_Confirmation")
    }

    func testCaptureDiscardWorkoutScreenshot() {
        let discard = launchFixture("active-in-progress")
        tapButton("active-workout-menu", in: discard)
        XCTAssertTrue(discard.buttons["Discard workout"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08e_Discard_Workout")
    }

    func testCaptureDurationTimerScreenshots() {
        let app = launchFreshApp()
        let startWorkout = app.buttons["start-free-workout"]
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: startWorkout
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        startWorkout.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
        addExercise("Plank", in: app)

        // Starting without seconds keeps the timer idle and asks for input.
        let start = app.buttons["start-countdown-Plank-0"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["Enter seconds before starting the timer."].waitForExistence(timeout: 3))

        let duration = app.textFields["duration-field-Plank-0"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        duration.tap()
        duration.typeText("45")
        app.buttons["Done"].tap()
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

        // Reset, shorten the target, and let the countdown finish.
        app.buttons["Reset timer"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        duration.tap()
        duration.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        duration.typeText("2")
        app.buttons["Done"].tap()
        start.tap()
        XCTAssertTrue(app.staticTexts["Time complete"].waitForExistence(timeout: 8))
        saveScreenshot("active-workout/08i_Duration_Timer_Complete")

        // Restarting from the completed state runs the countdown again.
        app.buttons["Restart timer"].tap()
        XCTAssertTrue(app.buttons["Pause timer"].waitForExistence(timeout: 3))
    }

    func testCaptureRunningRestScreenshot() {
        let running = launchFixture("active-rest-running")
        XCTAssertTrue(running.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertTrue(running.buttons["Pause rest"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08_Rest_Countdown")
    }

    func testCapturePausedRestScreenshot() {
        let paused = launchFixture("active-rest-paused")
        XCTAssertTrue(paused.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(paused.buttons["Resume rest"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08b_Rest_Paused")
    }

    func testCaptureReadyRestScreenshot() {
        let ready = launchFixture("active-rest-ready")
        XCTAssertTrue(ready.descendants(matching: .any)["rest-ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(ready.buttons["Continue workout"].waitForExistence(timeout: 5))
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

    func testCaptureExerciseDetailVariationsScreenshot() {
        let app = launchExerciseInsightsFixture()
        let variation = app.buttons["exercise-variation-Dumbbell Bench Press"]
        scrollToElement(variation, in: app)
        saveScreenshot("exercises/17a_Exercise_Detail_Variations")
    }

    func testCaptureExerciseRelationshipsScreenshot() {
        let app = launchExerciseInsightsFixture()
        tapButton("exercise-relationships", in: app)
        XCTAssertTrue(app.navigationBars["Exercise Relationships"].waitForExistence(timeout: 5))
        saveScreenshot("exercises/17b_Exercise_Relationships")
    }

    func testCaptureExercisePerformanceInsightsScreenshot() {
        let app = launchExerciseInsightsFixture()
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

    private func launchExerciseInsightsFixture() -> XCUIApplication {
        launchFixture(
            "exercise-insights",
            additionalArguments: ["-ui-testing-open-exercise-detail"],
            expectsActiveWorkout: false,
            expectedHomeControl: "exercise-relationships"
        )
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
        XCTAssertEqual(increase.textFields["weight-field-Bench Press-0"].value as? String, "52.5")
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
        XCTAssertTrue(insufficient.keyboards.firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("progression/10d_Progression_Manual_Edit")
    }

    func testCaptureRecommendationWithRunningRestScreenshot() {
        let running = launchFixture("progression-rest-running")
        XCTAssertTrue(running.descendants(matching: .any)["progression-recommendation-card-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(running.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10f_Progression_With_Rest_Running")
    }

    func testCaptureRecommendationWithPausedRestScreenshot() {
        let paused = launchFixture("progression-rest-paused")
        XCTAssertTrue(paused.descendants(matching: .any)["progression-recommendation-card-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(paused.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        saveScreenshot("progression/10g_Progression_With_Rest_Paused")
    }

    func testCapturePerformanceComparisonReviewScreenshot() {
        let app = launchFixture("performance-comparison")

        tapButton("Review Workout", in: app)
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

    func testCaptureHomeTemplateSheetScreenshot() {
        let templatePicker = launchFreshApp()
        tapButton("start-from-template", in: templatePicker)
        XCTAssertTrue(templatePicker.navigationBars["Start a saved workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01b_Home_Template_Sheet")
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

    func testCaptureDailyCheckInScreenshot() {
        let app = launchFixture("today-complete", expectsActiveWorkout: false)
        tapButton("open-daily-check-in", in: app)
        XCTAssertTrue(app.navigationBars["Daily check-in"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01e_Daily_Check_In")
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

    func testCaptureCaffeineQuickLogScreenshot() {
        let app = launchFixture("today-complete", expectsActiveWorkout: false)
        tapButton("today-caffeine-summary", in: app)
        XCTAssertTrue(app.navigationBars["Log caffeine"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20a_Caffeine_Quick_Log")
    }

    func testCaptureTodayRescheduleScreenshot() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        tapButton("today-reschedule-planned-workout", in: app)
        XCTAssertTrue(app.navigationBars["Reschedule workout"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01f_Today_Reschedule_Workout")
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

    func testCaptureMobilityLibraryScreenshot() {
        let app = launchFixture("today-complete", expectsActiveWorkout: false)
        tapButton("manage-mobility-routines", in: app)
        XCTAssertTrue(app.navigationBars["Mobility"].waitForExistence(timeout: 5))
        saveScreenshot("mobility/18_Mobility_Routines")
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

    func testCaptureRecipeManualFallbackScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditorForScreenshot(app)
        XCTAssertFalse(app.buttons["generate-recipe"].exists)
        saveScreenshot("nutrition/20g_Recipe_Manual_Fallback")
    }

    func testCaptureFoodPickerScreenshot() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditorForScreenshot(app)
        tapButton("recipe-add-foods", in: app)
        XCTAssertTrue(app.navigationBars["Add foods"].waitForExistence(timeout: 5))
        saveScreenshot("nutrition/20h_Food_Picker")
    }

    func testCaptureRecipeDetailAndLogScreenshots() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        selectTab(.nutrition, in: app)
        tapButton("open-meal-templates", in: app)
        // The seeded catalogue ships recipes; open the first one's detail.
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

    func testCaptureLibrarySecondaryStatesScreenshots() {
        let library = launchFreshApp()
        selectTab(.library, in: library)
        let myWorkoutsHeader = library.staticTexts["MY WORKOUTS"].firstMatch
        XCTAssertTrue(myWorkoutsHeader.waitForExistence(timeout: 5))
        library.swipeUp()
        saveScreenshot("overview/02b_Train_Templates")
        library.swipeDown()
        tapButton("plans-browser", in: library)
        saveScreenshot("overview/02c_Train_Plans")
        library.navigationBars.buttons.firstMatch.tap()
        let search = library.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("not-a-real-library-item")
        saveScreenshot("overview/02d_Train_Empty_Search")
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
        tapButton("New Program", in: app)

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

        let deloadIntensity = app.steppers["plan-deload-intensity-reduction"]
        scrollToElement(deloadIntensity, in: app)
        XCTAssertTrue(deloadIntensity.waitForExistence(timeout: 5))
        saveScreenshot("plans/13d_Plan_Deload_Schedule")

        let mondayTemplate = app.buttons["plan-day-template-0"]
        scrollToElement(mondayTemplate, in: app)
        saveScreenshot("plans/13_Plan_Day_Assignments")
        tapButton("save-plan", in: app)

        tapButton("plans-browser", in: app)
        tapButton("plan-row-Screenshot Plan", in: app)
        tapButton("edit-plan", in: app)
        XCTAssertTrue(app.buttons["edit-plan-workout"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["edit-plan-workout"].firstMatch.tap()
        let executionBlock = app.buttons["add-plan-execution-block"]
        XCTAssertTrue(executionBlock.waitForExistence(timeout: 5))
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

    func testCaptureProgramDefinitionBuilderScreenshot() {
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
    }

    func testCaptureProgramCatalogScreenshots() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("program-catalog-browser", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog"].waitForExistence(timeout: 8))
        saveScreenshot("plans/13k_Program_Catalog")

        let program = app.descendants(matching: .any)["program-catalog-Double Progression Builder"]
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

    func testCaptureActivePlanRunScreenshot() {
        let activeRun = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        XCTAssertTrue(activeRun.descendants(matching: .any)["active-plan-badge"].waitForExistence(timeout: 5))
        saveScreenshot("overview/01d_Home_Active_Plan")

        selectTab(.library, in: activeRun)
        tapButton("plans-browser", in: activeRun)
        tapButton("plan-row-Screenshot Plan Run", in: activeRun)
        XCTAssertTrue(activeRun.buttons["start-planned-workout"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13b_Plan_Active_Run")
    }

    func testPlanCalendarShowsDerivedStatesAndKeepsCompletedSessionsLocked() {
        let app = launchFixture(
            "plan-calendar",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        selectTab(.library, in: app)
        tapButton("plans-browser", in: app)
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
        selectTab(.library, in: app)
        tapButton("plans-browser", in: app)
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

}
