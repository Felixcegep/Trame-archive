import XCTest

final class GymTrackerUITEST: GymTrackerUITestCase {
    func testMirroredLaunchArgumentsOpenFixtureWhenProcessArgumentsAreMissing() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchWithGymTrackerUITestArguments(mirroring: [
            "-ui-testing",
            "-reset-data",
            "-ui-test-fixture",
            "active-draft"
        ])

        let preparing = app.descendants(matching: .any)["app-preparing"]
        XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.descendants(matching: .any)["welcome"].exists)
    }

    func testMirroredLaunchArgumentsCanExplicitlyPresentWelcome() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchWithGymTrackerUITestArguments(mirroring: [
            "-ui-testing",
            "-reset-data",
            "-ui-testing-show-welcome"
        ])

        XCTAssertTrue(app.descendants(matching: .any)["welcome"].waitForExistence(timeout: 30))
    }


    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoordinatedNavigationExposesFourDestinationsAndTodaySettings() {
        let app = launchFreshApp(additionalArguments: [
            "-feature-flags", "today,mobility,nutrition,bodyWeight,dailyCheckIn,programBuilder,advancedExecution,betaFeedback"
        ])

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
        tapButton("settings-advanced", in: app)
        let shortcuts = app.descendants(matching: .any)["settings-shortcuts-link"]
        XCTAssertTrue(shortcuts.waitForExistence(timeout: 5))
    }

    func testAppearanceMenuSupportsSystemDarkAndLightModes() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launchWithGymTrackerUITestArguments()

        let picker = app.buttons["settings-appearance-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 45))
        XCTAssertTrue((picker.value as? String)?.contains("System Default") == true)

        picker.tap()
        app.buttons["Dark"].tap()
        XCTAssertTrue((picker.value as? String)?.contains("Dark") == true)

        picker.tap()
        app.buttons["Light"].tap()
        XCTAssertTrue((picker.value as? String)?.contains("Light") == true)

        picker.tap()
        app.buttons["System Default"].tap()
        XCTAssertTrue((picker.value as? String)?.contains("System Default") == true)
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
        app.launchWithGymTrackerUITestArguments()

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
        let startingLoad = app.textFields["Default starting load"]
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
        app.launchWithGymTrackerUITestArguments()

        startEmptyWorkout(in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))

        let minimize = app.buttons["minimize-workout"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        // Toolbar buttons can remain semantically present while XCTest is
        // still settling the full-screen cover. A coordinate tap avoids the
        // long synthetic-event hang in that transient state.
        minimize.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.terminate()

        app.launchArguments = ["-ui-testing"]
        app.launchWithGymTrackerUITestArguments()

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
        // remains unexpired throughout a cold simulator restart. Rest controls
        // intentionally collapse while the set-entry panel is open, so close
        // it before extending the timer.
        dismissKeypadIfPresent(in: app)
        for _ in 0..<10 {
            tapButton("+30s", in: app)
        }

        XCTAssertTrue(app.descendants(matching: .any)["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause rest"].exists)

        // Ensure the persisted deadline is flushed before the helper shuts
        // down and reboots the simulator. This mirrors the real lifecycle
        // boundary while avoiding a race with XCTest's test teardown.
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
    }

    // The companion runner deliberately launches this test without
    // -reset-data after shutting down and booting the same simulator.
    func testVerifiesRunningRestAfterSimulatorReboot() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reboot-rest-fixture"]
        app.launchWithGymTrackerUITestArguments()
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

        // Deliberately terminate with the keypad still open. The latest draft
        // must flush at the lifecycle boundary even though keypresses are
        // coalesced instead of saved one by one.
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
        while template.isHittable == false && scrollAttempts < 12 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(template.isHittable)
        let templateEnabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: template
        )
        XCTAssertEqual(XCTWaiter().wait(for: [templateEnabled], timeout: 8), .completed)
        // The picker keeps its search field docked above the bottom edge. A
        // final scroll ensures the selected row's tap target is fully clear
        // of that dock before synthesizing the tap.
        app.swipeUp()
        template.tap()

        // This catalogue template has no linked warm-up. Keep the optional
        // action tolerant if a future seed adds one.
        let skipWarmup = app.buttons["skip-linked-warmup"].firstMatch
        if skipWarmup.waitForExistence(timeout: 2) {
            skipWarmup.tap()
        }
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Goblet Stiletto Squat"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["prescription-summary-Goblet Stiletto Squat"]
                .waitForExistence(timeout: 5)
        )
    }

    func testLinkedWarmupStartsMobilityBeforeTheSameWorkout() {
        let app = launchFixture("linked-mobility-workout", expectsActiveWorkout: false)

        let startFreeWorkout = app.buttons["start-free-workout"]
        scrollToElement(startFreeWorkout, in: app)
        startFreeWorkout.tap()
        let template = app.buttons["workout-template-Linked Mobility Screenshot"]
        for _ in 0..<12 where !template.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(template.waitForExistence(timeout: 10))
        XCTAssertTrue(template.isHittable)
        template.tap()

        tapButton("start-linked-warmup", in: app)
        XCTAssertTrue(app.buttons["complete-mobility-movement"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["active-workout-title"].exists)

        tapButton("stop-mobility-session", in: app)
        tapButton("Stop Session", in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(activeExerciseCard("Bench Press", in: app).waitForExistence(timeout: 5))
    }

    func testPushFocusFiltersActiveExercisePicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launchWithGymTrackerUITestArguments()

        startEmptyWorkout(in: app)

        let addExercise = app.buttons["add-active-exercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 5))
        addExercise.tap()
        XCTAssertTrue(app.searchFields["Search exercises"].waitForExistence(timeout: 5))

        let pushFilter = app.buttons["exercise-focus-Push"]
        XCTAssertTrue(pushFilter.waitForExistence(timeout: 5))
        pushFilter.tap()

        XCTAssertTrue(app.buttons["exercise-link-Arnold Press"].waitForExistence(timeout: 5))
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

        // Target the disclosure label itself. The card's combined accessibility
        // button also contains its nested menu button and can resolve to that
        // child after a relaunch, which does not expand the exercise.
        let legPressExercise = app.staticTexts["active-exercise-Leg Press"]
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
        XCTAssertFalse(app.descendants(matching: .any)["active-exercise-Bench Press"].exists)
    }

    func testDropSetTypeConfiguresOneGroupedChoice() {
        let app = launchFixture("active-in-progress")

        tapButton("reps-field-Bench Press-0", in: app)
        // The entry panel owns the grouped set-type menu. Selecting Drop set
        // must update the chip immediately; the details sheet renders the same
        // selection but is a separate presentation state.
        tapButton("panel-set-type", in: app)
        tapButton("panel-set-type-option-dropSet", in: app)
        XCTAssertTrue(app.buttons["panel-set-type"].label.contains("Drop set"))
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
        app.launchWithGymTrackerUITestArguments()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 45))
        tapButton("settings-data", in: app)
        let lastExport = app.descendants(matching: .any)["settings-data-safety-last-export"]
        let restoreTested = app.descendants(matching: .any)["settings-data-safety-restore-tested"]

        XCTAssertTrue(lastExport.waitForExistence(timeout: 5))
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

        let finishButton = app.buttons["Finish workout"]
        XCTAssertFalse(finishButton.exists)
    }

    func testSavesCompletedWorkoutToHistory() {
        let app = launchFixture("active-partial-save")

        let finishButton = app.buttons["Finish workout"]
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
        app.launchWithGymTrackerUITestArguments()

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
        app.buttons["Finish workout"].tap()
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
        selectTab(.library, in: app)
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
        selectTab(.library, in: app)

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

        // A plan assembled from the Day 1 seed has no linked warm-up today;
        // tolerate the optional preparation sheet if that seed gains one.
        let skipWarmup = app.buttons["skip-linked-warmup"].firstMatch
        if skipWarmup.waitForExistence(timeout: 2) {
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
        tapButton("Finish workout", in: app)
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
        app.launchWithGymTrackerUITestArguments()

        // The launch route intentionally pushes through Settings to Data & Backup.
        // Once pushed, the parent screen is no longer part of the accessibility tree.
        XCTAssertTrue(app.descendants(matching: .any)["settings-data-screen"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["import-preview"].waitForExistence(timeout: 15))

        tapButton("confirm-backup-restore", in: app)
        tapButton("restore-replace-all-data", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["settings-data-screen"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Settings"].tap()
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
        app.launchWithGymTrackerUITestArguments()

        XCTAssertTrue(app.alerts["Import Error"].waitForExistence(timeout: 15))
        tapButton("OK", in: app)

        relaunchPreservingData(app, launchArguments: ["-ui-testing", "-ui-testing-open-history"])
        XCTAssertTrue(app.buttons["history-workout-row"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Sentinel Workout"].waitForExistence(timeout: 5))
    }

    func testDefaultCollectionSeededOnLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launchWithGymTrackerUITestArguments()

        selectTab(.library, in: app)
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
        let accessory = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Accessory Work")
        ).firstMatch
        scrollToElement(accessory, in: app)

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
