import XCTest

final class GymTrackerUITEST: GymTrackerUITestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoordinatedNavigationExposesFourDestinationsAndTodaySettings() {
        let app = launchFreshApp()

        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).label.contains("Today"))
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 1).label.contains("Train"))
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 2).label.contains("Nutrition"))
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 3).label.contains("Progress"))

        selectTab(.train, in: app)
        XCTAssertTrue(app.staticTexts["Train"].waitForExistence(timeout: 5))

        selectTab(.nutrition, in: app)
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))

        selectTab(.progress, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["progress-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["progress-workout-history"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["progress-training-trends"].exists)
        let muscleGroupVolume = app.descendants(matching: .any)["progress-muscle-group-volume"]
        XCTAssertTrue(muscleGroupVolume.exists)
        muscleGroupVolume.tap()
        XCTAssertTrue(app.navigationBars["Muscle-group volume"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        selectTab(.settings, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        // Settings is a lazy Form; the Shortcuts row is below the first
        // viewport and does not exist in the accessibility hierarchy until
        // it has been scrolled into view.
        let shortcuts = app.descendants(matching: .any)["settings-shortcuts-link"]
        var scrollAttempts = 0
        while shortcuts.exists == false && scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(shortcuts.waitForExistence(timeout: 5))
    }

    func testNutritionTargetsEmptyStateOffersCreationWithoutDuplicateDismissal() {
        let app = launchFreshApp()
        selectTab(.nutrition, in: app)
        tapButton("open-nutrition-targets", in: app)

        XCTAssertTrue(app.navigationBars["Nutrition targets"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)

        tapButton("create-nutrition-target-empty", in: app)
        XCTAssertTrue(app.navigationBars["New target"].waitForExistence(timeout: 5))
    }

    func testStartFreeWorkout() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        let startButton = app.buttons["start-free-workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // The primary card now opens the unified "Start a workout" sheet, where
        // an empty session is one explicit choice among the saved workouts.
        XCTAssertTrue(app.navigationBars["Start a workout"].waitForExistence(timeout: 5))

        let empty = app.buttons["start-empty-workout"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()

        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    func testBrowsesConfiguresAndActivatesBuiltInProgram() {
        let app = launchFreshApp()
        openPlans(.readyMade, in: app)

        app.searchFields["Search plans"].tap()
        app.searchFields["Search plans"].typeText("Double Progression")
        let program = app.buttons["program-catalog-Double Progression Builder"].firstMatch
        XCTAssertTrue(program.waitForExistence(timeout: 5))
        program.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog-detail"].waitForExistence(timeout: 5))

        let useProgram = app.buttons["use-program"]
        scrollToElement(useProgram, in: app)
        useProgram.tap()
        XCTAssertTrue(app.descendants(matching: .any)["program-intake"].waitForExistence(timeout: 5))
        let startingLoad = app.textFields["Starting load"]
        XCTAssertTrue(startingLoad.waitForExistence(timeout: 5))
        startingLoad.tap()
        startingLoad.typeText("20")
        let keyboardDone = app.buttons["Done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }
        tapButton("start-program", in: app)
        // Activation pops back to Train, where the plan is now the one being
        // followed. The old flow left the user on the catalogue detail with a
        // disabled "Plan added" label and no sign of what had changed.
        let currentPlan = app.buttons["current-plan-card"]
        XCTAssertTrue(currentPlan.waitForExistence(timeout: 8))
        XCTAssertTrue(currentPlan.label.contains("Double Progression Builder"))
    }

    func testResumesPersistedActiveWorkoutAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        startEmptyWorkout(in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))

        app.buttons["minimize-workout"].tap()
        app.terminate()

        app.launchArguments = ["-ui-testing"]
        app.launch()

        let resumeButton = app.buttons["resume-active-workout"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(resumeButton.label.contains("Resume"))
        resumeButton.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    func testResumesPersistedRestTimerAfterRelaunch() {
        let app = launchFixture("active-rest-running")

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")
    }

    // This is intentionally only the first phase of the reboot test. The
    // runner script restarts the simulator between this test and its matching
    // verification test, because an XCTest process cannot survive a simulator
    // shutdown itself.
    func testPrepareRunningRestForSimulatorReboot() {
        let app = launchFreshApp()

        startEmptyWorkout(in: app)
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: false, in: app)

        // The default rest period is short. Add five minutes so the timer
        // remains unexpired throughout a cold simulator restart.
        for _ in 0..<10 {
            tapButton("+30s", in: app)
        }

        XCTAssertTrue(app.descendants(matching: .any)["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause rest"].exists)
    }

    // The companion runner deliberately launches this test without
    // -reset-data after shutting down and booting the same simulator.
    func testVerifiesRunningRestAfterSimulatorReboot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)

        XCTAssertTrue(app.buttons["resume-active-workout"].waitForExistence(timeout: 15))
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause rest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bench Press"].exists)
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")

        // Confirm the restored countdown is live, not merely a stale card.
        tapButton("Pause rest", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["Rest paused"].waitForExistence(timeout: 5))
        tapButton("Resume rest", in: app)
        XCTAssertTrue(app.buttons["Pause rest"].waitForExistence(timeout: 5))
    }

    func testPersistsDraftSetValuesAfterTermination() {
        let app = launchFixture("active-draft")

        enterValue("7", field: "reps", for: "Bench Press", set: 0, in: app)
        enterValue("42", field: "weight", for: "Bench Press", set: 0, in: app)

        // Deliberately terminate with the keypad still open. Each keystroke must
        // persist independently of dismissal or scene phase.
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "7")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "42")
    }

    func testResumesPausedRestTimerAfterRelaunch() {
        let app = launchFixture("active-rest-paused")

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["Rest paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Resume rest"].exists)
    }

    func testStartSeededTemplateIncludesPrescription() {
        let app = launchFreshApp()

        let startFromTemplate = app.buttons["start-free-workout"]
        XCTAssertTrue(startFromTemplate.waitForExistence(timeout: 5))
        startFromTemplate.tap()

        let template = app.buttons["workout-template-Day 1 – Lower Body (Squat Focus)"]
        var scrollAttempts = 0
        while template.exists == false && scrollAttempts < 6 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        let templateEnabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: template
        )
        XCTAssertEqual(XCTWaiter().wait(for: [templateEnabled], timeout: 8), .completed)
        template.tap()

        let skipWarmup = app.buttons["skip-linked-warmup"].firstMatch
        XCTAssertTrue(skipWarmup.waitForExistence(timeout: 8))
        skipWarmup.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Goblet Stiletto Squat"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["prescription-summary-Goblet Stiletto Squat"]
                .waitForExistence(timeout: 5)
        )
    }

    func testPushFocusFiltersActiveExercisePicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        startEmptyWorkout(in: app)

        let addExercise = app.buttons["add-active-exercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 5))
        addExercise.tap()
        XCTAssertTrue(app.searchFields["Search exercises"].waitForExistence(timeout: 5))

        let pushFilter = app.buttons["exercise-focus-Push"]
        XCTAssertTrue(pushFilter.waitForExistence(timeout: 5))
        pushFilter.tap()

        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Back Squat"].exists)
    }

    /// The plate calculator is offered by the set-entry panel, and only for
    /// equipment whose load is actually assembled from plates.
    func testPlateCalculatorMatchesExerciseLoadingStyle() {
        let app = launchFixture("active-loading-styles")

        tapButton("weight-field-Bench Press-0", in: app)
        tapButton("panel-chip-plates", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["plate-calculator-screen"].waitForExistence(timeout: 5))
        tapButton("Done", in: app)
        dismissKeypadIfPresent(in: app)

        let dumbbellExercise = activeExerciseCard("Dumbbell Bench Press", in: app)
        scrollToElement(dumbbellExercise, in: app)
        dumbbellExercise.tap()
        tapButton("weight-field-Dumbbell Bench Press-0", in: app)
        XCTAssertTrue(app.buttons["panel-details"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["panel-chip-plates"].exists)

        // Relaunch the deterministic fixture so the open panel and disclosure
        // scroll position cannot obscure the final style check.
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        let legPressExercise = activeExerciseCard("Leg Press", in: app)
        scrollToElement(legPressExercise, in: app)
        legPressExercise.tap()
        tapButton("weight-field-Leg Press-0", in: app)
        XCTAssertTrue(app.buttons["panel-chip-plates"].waitForExistence(timeout: 5))
    }

    /// Whole-row selection: tapping a row outside any value opens the keypad on
    /// the first value the lifter still owes, then on the next one once that is
    /// supplied. Direct selection of a specific value keeps working alongside it.
    func testRowAndFieldSelectionOpenTheKeypadOnTheRightValue() {
        let app = launchFixture("active-draft")

        // Tap in the row's padding just below the status circle: inside the
        // row, outside every value and button, which is exactly the area a
        // whole-row target adds. Rows sit 6 points apart, so this stays well
        // inside the row it belongs to.
        let statusButton = app.buttons["complete-set-Bench Press-0"]
        XCTAssertTrue(statusButton.waitForExistence(timeout: 5))
        statusButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.06)).tap()

        // Nothing is entered yet, so the row hands the keypad its reps.
        let repsPill = app.buttons["panel-value-reps"]
        XCTAssertTrue(repsPill.waitForExistence(timeout: 5))
        XCTAssertTrue(repsPill.isSelected)
        XCTAssertFalse(app.buttons["panel-value-weight"].isSelected)

        tapButton("keypad-key-8", in: app)
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")

        // Aiming at one specific value selects that value instead. Which value
        // an untouched row opens on is covered by `SetInputFocusSelectionTests`.
        tapButton("weight-field-Bench Press-0", in: app)
        XCTAssertTrue(app.buttons["panel-value-weight"].isSelected)
        XCTAssertFalse(app.buttons["panel-value-reps"].isSelected)
    }

    /// The keypad writes the selected value in place, and backspace removes the
    /// digits it added rather than the stored value it never touched.
    func testKeypadEditsTheSelectedValue() {
        let app = launchFixture("active-draft")

        tapButton("weight-field-Bench Press-0", in: app)
        tapButton("keypad-key-6", in: app)
        tapButton("keypad-key-0", in: app)
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "60")

        tapButton("keypad-key-decimal", in: app)
        tapButton("keypad-key-5", in: app)
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "60.5")

        tapButton("keypad-key-backspace", in: app)
        tapButton("keypad-key-backspace", in: app)
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "60")

        // Selecting a different value starts a fresh entry instead of appending.
        tapButton("panel-value-reps", in: app)
        tapButton("keypad-key-5", in: app)
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "5")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "60")
    }

    func testWeightAdjustmentUsesOneSelectableIncrement() {
        let app = launchFixture("active-draft")

        tapButton("weight-field-Bench Press-0", in: app)

        let stepMenu = app.buttons["panel-weight-step"]
        XCTAssertTrue(stepMenu.waitForExistence(timeout: 5))
        XCTAssertEqual(stepMenu.value as? String, "2.5 kg")
        XCTAssertEqual(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Increase weight by")
        ).count, 1)
        XCTAssertEqual(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Decrease weight by")
        ).count, 1)

        app.buttons["Increase weight by 2.5"].tap()
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "2.5")

        stepMenu.tap()
        let fineStep = app.buttons["1 kg"]
        XCTAssertTrue(fineStep.waitForExistence(timeout: 2))
        fineStep.tap()

        XCTAssertEqual(stepMenu.value as? String, "1 kg")
        app.buttons["Decrease weight by 1"].tap()
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "1.5")
    }

    func testKeyboardNavigatesFocusedSetFieldsAndCopiesLastSet() {
        let app = launchFixture("active-in-progress")

        enterValidValues(for: "Bench Press", set: 0, repsValue: "10", in: app)

        let secondWeightField = app.buttons["weight-field-Bench Press-1"]
        XCTAssertTrue(secondWeightField.waitForExistence(timeout: 5))
        secondWeightField.tap()

        let previousButton = app.buttons["Previous field"]
        let nextButton = app.buttons["Next field"]
        XCTAssertTrue(previousButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.exists)
        XCTAssertTrue(previousButton.isEnabled)
        previousButton.tap()

        secondWeightField.tap()
        let copyLastSet = app.buttons["panel-chip-last set"]
        XCTAssertTrue(copyLastSet.waitForExistence(timeout: 5))
        XCTAssertTrue(copyLastSet.isEnabled)
        copyLastSet.tap()
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 1, in: app), "10")
    }

    /// Copying the last set, the plate calculator, and set details are offered
    /// once, by the set-entry panel. The row itself carries no actions menu.
    func testSetActionsAreOfferedOnlyByThePanel() {
        let app = launchFixture("active-in-progress")
        let secondWeightField = app.buttons["weight-field-Bench Press-1"]

        XCTAssertTrue(secondWeightField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["set-menu-Bench Press-1"].exists)

        secondWeightField.tap()
        XCTAssertTrue(app.buttons["panel-chip-last set"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["panel-details"].exists)
        XCTAssertTrue(app.buttons["panel-set-type"].exists)
        XCTAssertFalse(app.buttons["set-menu-Bench Press-1"].exists)
        XCTAssertFalse(app.buttons["copy-last-set-Bench Press-1"].exists)
    }

    func testActiveWorkoutSetMutationsAndRestTimer() {
        let app = launchFixture("active-in-progress")

        let addSet = app.buttons["add-set-Bench Press"]
        XCTAssertTrue(addSet.waitForExistence(timeout: 5))
        addSet.tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-3"].waitForExistence(timeout: 5))

        addSet.tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-4"].waitForExistence(timeout: 5))
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Rest between sets"].waitForExistence(timeout: 5))

        // Completing a set moves the keypad to the next one, which is the set
        // whose details the deletion below belongs to.
        XCTAssertTrue(app.buttons["panel-chip-last set"].waitForExistence(timeout: 5))
        tapButton("panel-details", in: app)
        XCTAssertTrue(app.buttons["delete-set-Bench Press-1"].waitForExistence(timeout: 5))
        app.buttons["delete-set-Bench Press-1"].tap()
        app.buttons["confirm-delete-set-Bench Press-1"].firstMatch.tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["complete-set-Bench Press-4"].exists)

        let exerciseMenu = app.buttons["exercise-menu-Bench Press"]
        XCTAssertTrue(exerciseMenu.waitForExistence(timeout: 5))
        exerciseMenu.tap()
        XCTAssertTrue(app.buttons["remove-exercise-Bench Press"].waitForExistence(timeout: 5))
        app.buttons["remove-exercise-Bench Press"].tap()
        app.buttons["confirm-remove-exercise-Bench Press"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Bench Press"].exists)
    }

    func testDropSetTypeConfiguresOneSegmentedChoice() {
        let app = launchFixture("active-in-progress")

        tapButton("reps-field-Bench Press-0", in: app)
        tapButton("panel-details", in: app)
        tapButton("set-type-option-dropSet", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["drop-set-structure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["add-set-segment"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["set-method-picker"].exists)
    }

    func testCompletedSetRequiresExplicitEditingAction() {
        let app = launchFixture("active-completed-set")

        let weightField = app.buttons["weight-field-Bench Press-0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        XCTAssertFalse(weightField.isEnabled)

        tapButton("edit-completed-set-Bench Press-0", in: app)
        XCTAssertTrue(weightField.isEnabled)
    }

    func testCurrentSetExposesCurrentAccessibilityValue() {
        let app = launchFixture("active-completed-set")

        let completed = app.buttons["complete-set-Bench Press-0"]
        let current = app.buttons["complete-set-Bench Press-1"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertEqual(current.value as? String, "Current set")
        XCTAssertNotEqual(completed.value as? String, "Current set")
    }

    func testEditingCompletedSetShowsPersistentEditingIndicator() {
        let app = launchFixture("active-completed-set")

        tapButton("edit-completed-set-Bench Press-0", in: app)
        XCTAssertTrue(app.images["editing-set-Bench Press-0"].waitForExistence(timeout: 5))
    }

    func testDataSafetySectionReportsExportState() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 45))
        let lastExport = app.descendants(matching: .any)["settings-data-safety-last-export"]
        let restoreTested = app.descendants(matching: .any)["settings-data-safety-restore-tested"]

        for _ in 0..<6 where lastExport.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(lastExport.exists)
        XCTAssertTrue(lastExport.label.contains("Never") || (lastExport.value as? String) == "Never")
        XCTAssertTrue(
            restoreTested.label.contains("Not yet") || (restoreTested.value as? String) == "Not yet"
        )

        let exportButton = app.buttons["settings-export-data"]
        for _ in 0..<4 where exportButton.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(exportButton.exists)
        exportButton.tap()
        XCTAssertTrue(
            app.buttons["Share Export"].waitForExistence(timeout: 10),
            "A produced backup should expose the share action."
        )
        let updatedLastExport = app.descendants(matching: .any)["settings-data-safety-last-export"]
        XCTAssertFalse(updatedLastExport.label.contains("Never"))
        XCTAssertNotEqual(updatedLastExport.value as? String, "Never")
    }

    func testRejectsEmptyWorkoutSave() {
        let app = launchFreshApp()
        startEmptyWorkout(in: app)

        let finishButton = app.buttons["Review Workout"]
        XCTAssertFalse(finishButton.exists)
    }

    func testSavesCompletedWorkoutToHistory() {
        let app = launchFixture("active-partial-save")

        let finishButton = app.buttons["Review Workout"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.tap()
        XCTAssertTrue(app.buttons["save-workout"].waitForExistence(timeout: 5))
        app.buttons["save-workout"].tap()

        let partialSave = app.buttons["Save completed sets"]
        if partialSave.waitForExistence(timeout: 2) {
            partialSave.tap()
        }

        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-testing-open-history"]
        app.launch()

        let historyScreen = app.descendants(matching: .any)
            .matching(identifier: "history-screen")
            .firstMatch
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["history-workout-row"].waitForExistence(timeout: 15))
    }

    func testShowsAndAppliesPreviousSessionPerformance() {
        let app = launchFreshApp()
        startEmptyWorkout(in: app)
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()
        dismissKeypadIfPresent(in: app)
        app.buttons["Review Workout"].tap()
        app.buttons["save-workout"].tap()
        if app.buttons["Save completed sets"].waitForExistence(timeout: 2) {
            app.buttons["Save completed sets"].tap()
        }

        startEmptyWorkout(in: app)
        addExercise("Bench Press", in: app)

        XCTAssertTrue(app.staticTexts["previous-performance-Bench Press"].waitForExistence(timeout: 5))
        let usePrevious = app.buttons["copy-previous-set-Bench Press-0"]
        XCTAssertTrue(usePrevious.waitForExistence(timeout: 5))
        usePrevious.tap()

        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")
    }

    func testDiscardsActiveWorkout() {
        let app = launchFixture("active-in-progress")

        // Discard is no longer a permanent toolbar control: it lives in the
        // workout menu and still requires an explicit destructive confirmation.
        tapButton("active-workout-menu", in: app)
        tapButton("discard-workout", in: app)
        // The dismissed menu item and the dialog action briefly share the
        // identifier, so take the action the dialog is presenting now.
        let confirmDiscard = app.sheets.buttons["confirm-discard-workout"].firstMatch
        XCTAssertTrue(confirmDiscard.waitForExistence(timeout: 5))
        confirmDiscard.tap()

        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-free-workout"].label.contains("Resume"))
    }

    func testCreatesCustomExercise() {
        let app = launchFreshApp()
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["Create library item"].tap()
        XCTAssertTrue(app.buttons["New Exercise"].waitForExistence(timeout: 5))
        app.buttons["New Exercise"].tap()

        let nameField = app.textFields["exercise-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Cable Chest Press")
        app.buttons["save-exercise"].tap()

        assertLibrarySearchResult("Cable Chest Press", in: app)
    }

    func testCreatesWorkoutTemplate() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("Create library item", in: app)
        XCTAssertTrue(app.buttons["New Workout"].waitForExistence(timeout: 5))
        app.buttons["New Workout"].tap()

        let nameField = app.textFields["template-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Push Integration Template")
        app.buttons["save-template"].tap()

        assertLibrarySearchResult("Push Integration Template", in: app)
    }

    func testCreatesPlanStartsRunAndLaunchesPlannedWorkout() {
        let app = launchFreshApp()
        app.tabBars.buttons.element(boundBy: 1).tap()

        app.buttons["Create library item"].tap()
        XCTAssertTrue(app.buttons["New Training Plan"].waitForExistence(timeout: 5))
        app.buttons["New Training Plan"].tap()

        let nameField = app.textFields["plan-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Four Week Integration Plan")
        nameField.typeText("\n")
        selectPlanTemplate(
            "Day 1 – Lower Body (Squat Focus)",
            forDayOffset: 0,
            in: app
        )
        tapButton("save-plan", in: app)

        openPlans(.mine, in: app)

        let plan = app.buttons["plan-row-Four Week Integration Plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()

        app.buttons["start-plan"].tap()
        XCTAssertTrue(app.buttons["confirm-start-plan"].waitForExistence(timeout: 5))
        app.buttons["confirm-start-plan"].tap()

        let startWorkout = app.buttons["start-planned-workout"]
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5))
        startWorkout.tap()

        // This plan day has a linked warmup (Ankle & Foot Mobilization) in the
        // seed data, so starting it offers an "Optional preparation" dialog
        // before the workout itself appears. Skip it to reach the workout.
        let skipWarmup = app.buttons["skip-linked-warmup"].firstMatch
        if skipWarmup.waitForExistence(timeout: 3) {
            skipWarmup.tap()
        }

        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(activeExerciseCard("Goblet Stiletto Squat", in: app).waitForExistence(timeout: 5))
    }

    func testPlannedWorkoutSavePersistsHistoryAndAdvancesRunAfterRelaunch() {
        let app = launchFixture("plan-partial-save")
        XCTAssertTrue(app.staticTexts["active-workout-title"].label.contains("Fixture Day 1"))

        // Verify that cancelling the partial-save confirmation keeps the draft
        // intact before exercising the committed path.
        tapButton("Review Workout", in: app)
        tapButton("save-workout", in: app)
        XCTAssertTrue(app.buttons["Save completed sets"].waitForExistence(timeout: 5))
        tapButton("keep-editing-partial-save", in: app)
        XCTAssertTrue(app.buttons["save-workout"].waitForExistence(timeout: 5))

        tapButton("save-workout", in: app)
        app.buttons["Save completed sets"].tap()

        relaunchPreservingData(app)
        selectTab(.history, in: app)
        XCTAssertTrue(app.buttons["history-workout-row"].waitForExistence(timeout: 5))
        let historyRows = app.buttons.matching(identifier: "history-workout-row")
        XCTAssertEqual(historyRows.count, 1)
        XCTAssertTrue(historyRows.firstMatch.label.contains("Fixture Day 1"))

        openPlans(.following, in: app)
        tapButton("plan-row-Integration Fixture Plan", in: app)
        let nextWorkout = app.buttons["start-planned-workout"]
        XCTAssertTrue(nextWorkout.waitForExistence(timeout: 5))
        XCTAssertTrue(nextWorkout.label.contains("Fixture Day 2"))

        // Relaunching after save must not duplicate History or advance the run
        // a second time.
        relaunchPreservingData(app)
        selectTab(.history, in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "history-workout-row").count, 1)
    }

    func testRecommendationEditFocusesTheFirstIncompleteSet() {
        let app = launchFixture("progression-increase")

        tapButton("edit-recommendation-Bench Press", in: app)
        let firstIncompleteWeight = app.buttons["weight-field-Bench Press-0"]
        XCTAssertTrue(firstIncompleteWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keypad-key-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["panel-value-weight"].isSelected)
        XCTAssertFalse(app.buttons["progression-recommendation-card-Bench Press"].exists)
    }

    func testSettingsImportsValidBackupAndRestoresPreferencesAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-open-settings",
            "-ui-testing-import-valid",
            "-ui-test-fixture",
            "backup-import-target"
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["import-preview"].waitForExistence(timeout: 15))

        tapButton("confirm-backup-restore", in: app)
        tapButton("restore-replace-all-data", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        assertUnitSystem("Imperial", in: app)
        assertRestDuration("120", in: app)

        // The preferences and replacement are persisted independently of the
        // sheet lifecycle and must survive a fresh process launch.
        relaunchPreservingData(app, launchArguments: ["-ui-testing", "-ui-testing-open-settings"])
        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 15))
        assertUnitSystem("Imperial", in: app)
        assertRestDuration("120", in: app)

        selectTab(.history, in: app)
        XCTAssertTrue(app.staticTexts["No Workout History"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Sentinel Workout"].exists)
    }

    func testSettingsRejectsCorruptBackupWithoutReplacingData() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-open-settings",
            "-ui-testing-import-corrupt",
            "-ui-test-fixture",
            "backup-import-target"
        ]
        app.launch()

        XCTAssertTrue(app.alerts["Import Error"].waitForExistence(timeout: 15))
        tapButton("OK", in: app)

        relaunchPreservingData(app, launchArguments: ["-ui-testing", "-ui-testing-open-history"])
        XCTAssertTrue(app.buttons["history-workout-row"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Sentinel Workout"].waitForExistence(timeout: 5))
    }

    func testDefaultCollectionSeededOnLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        app.tabBars.buttons.element(boundBy: 1).tap()
        // Saved workouts and their folders moved off the Train root into the
        // Workouts destination, so Train can state what you are following first.
        tapButton("workouts-browser", in: app)

        let seededCollection = app.staticTexts["Upper/Lower Program – 4 Days"]
        XCTAssertTrue(seededCollection.waitForExistence(timeout: 5))
    }

    func testTrainingCalendarShowsDerivedDayContextAndPlanActions() {
        let app = launchFixture(
            "training-calendar",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        tapButton("open-training-calendar", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["training-calendar-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today Strength"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed Strength"].exists)
        XCTAssertTrue(app.staticTexts["Accessory Work"].exists)

        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "training-calendar-start-")).count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "training-calendar-skip-")).count,
            1
        )
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "training-calendar-reschedule-")).count,
            1
        )

        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["Hip Mobility"].exists)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["Nutrition"].exists)
        XCTAssertTrue(app.staticTexts["Journal"].exists)
    }

}
