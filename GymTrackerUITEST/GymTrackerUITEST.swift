import XCTest

final class GymTrackerUITEST: GymTrackerUITestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartFreeWorkout() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        let startButton = app.buttons["start-free-workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        startButton.tap()

        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    func testBrowsesConfiguresAndActivatesBuiltInProgram() {
        let app = launchFreshApp()
        selectTab(.library, in: app)
        tapButton("program-catalog-browser", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog"].waitForExistence(timeout: 8))

        app.searchFields["Search programs"].tap()
        app.searchFields["Search programs"].typeText("Double Progression")
        let program = app.descendants(matching: .any)["program-catalog-Double Progression Builder"]
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
        app.buttons["Done"].tap()
        tapButton("start-program", in: app)
        XCTAssertTrue(app.buttons["use-program"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["use-program"].label.contains("Program added"))
    }

    func testResumesPersistedActiveWorkoutAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        let startButton = app.buttons["start-free-workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
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

        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["reps-field-Bench Press-0"].value as? String, "8")
        XCTAssertEqual(app.textFields["weight-field-Bench Press-0"].value as? String, "50")
    }

    // This is intentionally only the first phase of the reboot test. The
    // runner script restarts the simulator between this test and its matching
    // verification test, because an XCTest process cannot survive a simulator
    // shutdown itself.
    func testPrepareRunningRestForSimulatorReboot() {
        let app = launchFreshApp()

        tapButton("start-free-workout", in: app)
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: false, in: app)

        // The default rest period is short. Add five minutes so the timer
        // remains unexpired throughout a cold simulator restart.
        for _ in 0..<10 {
            tapButton("+30s", in: app)
        }

        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause rest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bench Press"].exists)
        XCTAssertEqual(app.textFields["reps-field-Bench Press-0"].value as? String, "8")
        XCTAssertEqual(app.textFields["weight-field-Bench Press-0"].value as? String, "50")

        // Confirm the restored countdown is live, not merely a stale card.
        tapButton("Pause rest", in: app)
        XCTAssertTrue(app.staticTexts["Rest paused."].waitForExistence(timeout: 5))
        tapButton("Resume rest", in: app)
        XCTAssertTrue(app.buttons["Pause rest"].waitForExistence(timeout: 5))
    }

    func testPersistsDraftSetValuesAfterTermination() {
        let app = launchFixture("active-draft")

        let reps = app.textFields["reps-field-Bench Press-0"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText("7")

        let weight = app.textFields["weight-field-Bench Press-0"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("42")

        // Deliberately terminate with the field still being edited. Each input
        // binding must persist independently of keyboard dismissal or scene phase.
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertEqual(reps.value as? String, "7")
        XCTAssertEqual(weight.value as? String, "42")
    }

    func testResumesPausedRestTimerAfterRelaunch() {
        let app = launchFixture("active-rest-paused")

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.staticTexts["Rest paused."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Resume rest"].exists)
    }

    func testStartSeededTemplateIncludesPrescription() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        let startFromTemplate = app.buttons["start-from-template"]
        XCTAssertTrue(startFromTemplate.waitForExistence(timeout: 5))
        startFromTemplate.tap()

        let template = app.buttons["workout-template-Day 1 – Lower Body (Squat Focus)"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

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

        let startWorkout = app.buttons["start-free-workout"]
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5))
        startWorkout.tap()

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

    func testPlateCalculatorMatchesExerciseLoadingStyle() {
        let app = launchFixture("active-loading-styles")

        tapButton("set-menu-Bench Press-0", in: app)
        tapButton("plate-calculator-Bench Press", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["plate-calculator-screen"].waitForExistence(timeout: 5))
        tapButton("Done", in: app)

        let dumbbellExercise = activeExerciseCard("Dumbbell Bench Press", in: app)
        scrollToElement(dumbbellExercise, in: app)
        dumbbellExercise.tap()
        tapButton("set-menu-Dumbbell Bench Press-0", in: app)
        XCTAssertFalse(app.buttons["plate-calculator-Dumbbell Bench Press"].exists)

        // Relaunch the deterministic fixture so the open context menu and
        // disclosure scroll position cannot obscure the final style check.
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        let legPressExercise = activeExerciseCard("Leg Press", in: app)
        scrollToElement(legPressExercise, in: app)
        legPressExercise.tap()
        tapButton("set-menu-Leg Press-0", in: app)
        XCTAssertTrue(app.buttons["plate-calculator-Leg Press"].waitForExistence(timeout: 5))
    }

    func testKeyboardOffersCopyLastSetValuesForFocusedSet() {
        let app = launchFixture("active-in-progress")

        let secondWeightField = app.textFields["weight-field-Bench Press-1"]
        XCTAssertTrue(secondWeightField.waitForExistence(timeout: 5))
        secondWeightField.tap()

        let copyButton = app.buttons["Copy last set values"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        XCTAssertTrue(copyButton.isEnabled)
        copyButton.tap()
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
        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))

        let setMenu = app.buttons["set-menu-Bench Press-1"]
        XCTAssertTrue(setMenu.waitForExistence(timeout: 5))
        setMenu.tap()
        tapButton("Set details", in: app)
        XCTAssertTrue(app.buttons["delete-set-Bench Press-1"].waitForExistence(timeout: 5))
        app.buttons["delete-set-Bench Press-1"].tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["complete-set-Bench Press-4"].exists)

        let exerciseMenu = app.buttons["exercise-menu-Bench Press"]
        XCTAssertTrue(exerciseMenu.waitForExistence(timeout: 5))
        exerciseMenu.tap()
        XCTAssertTrue(app.buttons["remove-exercise-Bench Press"].waitForExistence(timeout: 5))
        app.buttons["remove-exercise-Bench Press"].tap()
        XCTAssertFalse(app.staticTexts["Bench Press"].exists)
    }

    func testCompletedSetRequiresExplicitEditingAction() {
        let app = launchFixture("active-completed-set")

        let weightField = app.textFields["weight-field-Bench Press-0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        XCTAssertFalse(weightField.isEnabled)

        tapButton("edit-completed-set-Bench Press-0", in: app)
        XCTAssertTrue(weightField.isEnabled)
    }

    func testRejectsEmptyWorkoutSave() {
        let app = launchFreshApp()
        app.buttons["start-free-workout"].tap()

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
        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()
        app.buttons["Done"].tap()
        app.buttons["Review Workout"].tap()
        app.buttons["save-workout"].tap()
        if app.buttons["Save completed sets"].waitForExistence(timeout: 2) {
            app.buttons["Save completed sets"].tap()
        }

        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)

        XCTAssertTrue(app.staticTexts["previous-performance-Bench Press"].waitForExistence(timeout: 5))
        let usePrevious = app.buttons["use-previous-set-Bench Press-0"]
        XCTAssertTrue(usePrevious.waitForExistence(timeout: 5))
        usePrevious.tap()

        XCTAssertEqual(app.textFields["reps-field-Bench Press-0"].value as? String, "8")
        XCTAssertEqual(app.textFields["weight-field-Bench Press-0"].value as? String, "50")
    }

    func testDiscardsActiveWorkout() {
        let app = launchFixture("active-in-progress")

        app.buttons["active-workout-menu"].tap()
        // The toolbar trash button and the dialog action share the
        // "Discard workout" label; the dialog action appears second.
        let confirmDiscard = app.buttons.matching(identifier: "Discard workout").element(boundBy: 1)
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
        XCTAssertTrue(app.buttons["New Program"].waitForExistence(timeout: 5))
        app.buttons["New Program"].tap()

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

        let plansBrowser = app.buttons["plans-browser"]
        XCTAssertTrue(plansBrowser.waitForExistence(timeout: 5))
        plansBrowser.tap()

        let plan = app.buttons["plan-row-Four Week Integration Plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()

        app.buttons["start-plan"].tap()
        XCTAssertTrue(app.buttons["confirm-start-plan"].waitForExistence(timeout: 5))
        app.buttons["confirm-start-plan"].tap()

        let startWorkout = app.buttons["start-planned-workout"]
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5))
        startWorkout.tap()

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

        selectTab(.library, in: app)
        tapButton("plans-browser", in: app)
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
        let firstIncompleteWeight = app.textFields["weight-field-Bench Press-0"]
        XCTAssertTrue(firstIncompleteWeight.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(firstIncompleteWeight.value(forKey: "hasKeyboardFocus") as? Bool, true)
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

        let workoutsRow = app.staticTexts["Workouts"].firstMatch
        XCTAssertTrue(workoutsRow.waitForExistence(timeout: 5))
        workoutsRow.tap()

        let seededCollection = app.staticTexts["Upper/Lower Program – 4 Days"]
        XCTAssertTrue(seededCollection.waitForExistence(timeout: 5))
    }

}
