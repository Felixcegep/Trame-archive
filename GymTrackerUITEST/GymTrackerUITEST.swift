import XCTest

final class GymTrackerUITEST: XCTestCase {

    private enum AppTab: Int {
        case home
        case library
        case history
        case settings
    }

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
        let app = launchFreshApp()

        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()
        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))

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
        let app = launchFreshApp()

        tapButton("start-free-workout", in: app)
        addExercise("Bench Press", in: app)

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
        let app = launchFreshApp()

        tapButton("start-free-workout", in: app)
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: false, in: app)
        tapButton("Pause rest", in: app)
        XCTAssertTrue(app.staticTexts["Rest paused."].waitForExistence(timeout: 5))

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

        let template = app.buttons["workout-template-Jour 1 - Bas du Corps (Squat/Genoux)"]
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
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        app.buttons["start-free-workout"].tap()

        addExercise("Bench Press", in: app)
        XCTAssertTrue(app.buttons["Open plate calculator"].waitForExistence(timeout: 5))

        addExercise("Dumbbell Bench Press", in: app)
        XCTAssertFalse(app.buttons["Open plate calculator"].exists)

        addExercise("Leg Press", in: app)
        XCTAssertTrue(app.buttons["Open plate calculator"].waitForExistence(timeout: 5))
    }

    func testKeyboardOffersCopyLastSetValuesForFocusedSet() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)

        let secondWeightField = app.textFields["weight-field-Bench Press-1"]
        XCTAssertTrue(secondWeightField.waitForExistence(timeout: 5))
        secondWeightField.tap()

        let copyButton = app.buttons["Copy last set values"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        XCTAssertTrue(copyButton.isEnabled)
        copyButton.tap()
    }

    func testActiveWorkoutSetMutationsAndRestTimer() {
        let app = launchFreshApp()
        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)

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
        let app = launchFreshApp()
        tapButton("start-free-workout", in: app)
        addExercise("Bench Press", in: app)

        enterValidValues(for: "Bench Press", set: 0, in: app)
        completeSet("Bench Press", index: 0, dismissRest: true, in: app)

        let weightField = app.textFields["weight-field-Bench Press-0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        XCTAssertFalse(weightField.isEnabled)

        tapButton("set-menu-Bench Press-0", in: app)
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
        let app = launchFreshApp()
        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()

        app.buttons["Done"].tap()

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

        XCTAssertTrue(app.otherElements["history-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history-workout-row"].waitForExistence(timeout: 5))
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
        let app = launchFreshApp()
        app.buttons["start-free-workout"].tap()
        addExercise("Bench Press", in: app)

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

    func testCaptureHiddenExercisesScreenshot() {
        let app = launchFreshApp()
        selectTab(.library, in: app)

        let exercises = app.staticTexts["Exercises"].firstMatch
        XCTAssertTrue(exercises.waitForExistence(timeout: 5))
        exercises.tap()

        let benchPress = app.buttons["exercise-row-Bench Press"]
        XCTAssertTrue(benchPress.waitForExistence(timeout: 5))
        benchPress.swipeLeft()
        tapButton("Hide", in: app)

        let hiddenExercises = app.buttons["hidden-exercises"]
        XCTAssertTrue(hiddenExercises.waitForExistence(timeout: 5))
        hiddenExercises.tap()
        XCTAssertTrue(app.navigationBars["Hidden Exercises"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restore-exercise-Bench Press"].exists)
        let historyNote = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "History remains unchanged")
        ).firstMatch
        XCTAssertTrue(historyNote.exists)

        saveScreenshot("exercises/16_Hidden_Exercises")
    }

    func testCreatesWorkoutTemplate() {
        let app = launchFreshApp()
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["Create library item"].tap()
        XCTAssertTrue(app.buttons["New Workout Template"].waitForExistence(timeout: 5))
        app.buttons["New Workout Template"].tap()

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
        XCTAssertTrue(app.buttons["New Plan"].waitForExistence(timeout: 5))
        app.buttons["New Plan"].tap()

        let nameField = app.textFields["plan-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Four Week Integration Plan")
        nameField.typeText("\n")
        selectPlanTemplate(
            "Jour 1 - Bas du Corps (Squat/Genoux)",
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

    private func assertLibrarySearchResult(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func assertRestDuration(_ expected: String, in app: XCUIApplication) {
        let duration = app.descendants(matching: .any)["settings-rest-duration"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        let value = duration.value as? String ?? duration.label
        XCTAssertTrue(value.contains(expected), "Expected rest duration to contain '\(expected)', got '\(value)'")
    }

    private func assertUnitSystem(_ expected: String, in app: XCUIApplication) {
        let picker = app.buttons["settings-units-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let value = picker.value as? String ?? picker.label
        XCTAssertTrue(value.localizedCaseInsensitiveContains(expected), "Expected units to contain '\(expected)', got '\(value)'")
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)

        // A reset clears and reseeds SwiftData before the tab content becomes
        // interactive. Wait on that real state transition instead of guessing
        // how long a cold simulator needs.
        let preparing = app.descendants(matching: .any)["app-preparing"]
        if preparing.exists {
            XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
        }
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 15))
        return app
    }

    private func launchFixture(
        _ fixture: String,
        additionalArguments: [String] = [],
        expectsActiveWorkout: Bool = true,
        expectedHomeControl: String = "start-free-workout"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-test-fixture", fixture] + additionalArguments
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)

        let preparing = app.descendants(matching: .any)["app-preparing"]
        if preparing.exists {
            XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
        }
        if expectsActiveWorkout {
            XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 15))
        } else {
            XCTAssertTrue(app.buttons[expectedHomeControl].waitForExistence(timeout: 15))
        }
        return app
    }

    private func relaunchPreservingData(
        _ app: XCUIApplication,
        launchArguments: [String] = ["-ui-testing"]
    ) {
        app.terminate()
        app.launchArguments = launchArguments
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func resumeActiveWorkout(in app: XCUIApplication) {
        tapButton("resume-active-workout", in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    private func selectPlanTemplate(
        _ name: String,
        forDayOffset dayOffset: Int,
        in app: XCUIApplication
    ) {
        let picker = app.buttons["plan-day-template-\(dayOffset)"]
        scrollToElement(picker, in: app)
        picker.tap()

        let template = app.staticTexts[name].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    private func activeExerciseCard(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func addExercise(_ name: String, in app: XCUIApplication) {
        let addExercise = app.buttons["add-active-exercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 5))
        addExercise.tap()

        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)

        let exercise = app.buttons["add-exercise-\(name)"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()

        let keyboardClose = app.buttons["close"]
        if keyboardClose.waitForExistence(timeout: 2) {
            keyboardClose.tap()
        }

        let closeExercisePicker = app.buttons["close-exercise-picker"]
        XCTAssertTrue(closeExercisePicker.waitForExistence(timeout: 5))
        closeExercisePicker.tap()
    }

    private func enterValidValues(
        for exercise: String,
        set: Int,
        repsValue: String = "8",
        in app: XCUIApplication
    ) {
        let reps = app.textFields["reps-field-\(exercise)-\(set)"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText(XCUIKeyboardKey.delete.rawValue)
        reps.typeText(repsValue)

        let weight = app.textFields["weight-field-\(exercise)-\(set)"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText(XCUIKeyboardKey.delete.rawValue)
        weight.typeText("50")

        app.buttons["Done"].tap()
    }

    private func enterReps(_ value: String, for exercise: String, set: Int, in app: XCUIApplication) {
        let reps = app.textFields["reps-field-\(exercise)-\(set)"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText(XCUIKeyboardKey.delete.rawValue)
        reps.typeText(value)
        app.buttons["Done"].tap()
    }

    private func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    func testCaptureOverviewScreenshots() {
        let app = launchFreshApp()

        saveScreenshot("overview/01_Home")
        selectTab(.library, in: app)
        saveScreenshot("overview/02_Library")
        selectTab(.history, in: app)
        saveScreenshot("overview/03_History_Empty")
        selectTab(.settings, in: app)
        saveScreenshot("overview/04_Settings")
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
        saveScreenshot("active-workout/06_Add_Exercise_Sheet")
        tapButton("close-exercise-picker", in: inProgress)
        tapButton("plate-calculator-Bench Press", in: inProgress)
        saveScreenshot("active-workout/07_Plate_Calculator")
        tapFirstAvailableButton(["Done", "Terminé"], in: inProgress)
        tapButton("set-menu-Bench Press-0", in: inProgress)
        tapButton("Set details", in: inProgress)
        XCTAssertTrue(inProgress.buttons["close-set-details"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/07b_Set_Details")
    }

    func testCaptureCompletedSetScreenshot() {
        let completedSet = launchFixture("active-completed-set")
        XCTAssertTrue(completedSet.buttons["complete-set-Bench Press-1"].waitForExistence(timeout: 5))
        saveScreenshot("active-workout/08_Active_Workout_With_Set")
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
        app.buttons["history-workout-row"].firstMatch.tap()
        saveScreenshot("history/11_History_Detail")
    }

    func testCaptureExerciseDetailInsightsScreenshot() {
        let app = launchFixture("exercise-insights", expectsActiveWorkout: false)

        selectTab(.library, in: app)
        let exercisesBrowser = app.staticTexts["Exercises"].firstMatch
        XCTAssertTrue(exercisesBrowser.waitForExistence(timeout: 5))
        exercisesBrowser.tap()

        tapButton("exercise-row-Bench Press", in: app)
        tapButton("exercise-stats", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-last-session"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["exercise-insights-volume"].exists)

        saveScreenshot("exercises/17_Exercise_Insights")
    }

    func testCaptureMuscleBalanceScreenshot() {
        let app = launchFixture("muscle-balance", expectsActiveWorkout: false)
        selectTab(.history, in: app)

        let balanceTab = app.buttons["Balance"]
        XCTAssertTrue(balanceTab.waitForExistence(timeout: 5))
        balanceTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-chart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["muscle-balance-callouts"].exists)

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

    func testCapturePerformanceComparisonScreenshots() {
        let app = launchFixture("performance-comparison")

        tapButton("Review Workout", in: app)
        let comparison = app.descendants(matching: .any)["performance-comparison"].firstMatch
        scrollToElement(comparison, in: app)
        app.swipeUp()
        app.swipeUp()
        saveScreenshot("review/14_Save_Performance_Comparison")

        tapButton("save-workout", in: app)
        let partialSave = app.buttons["Save completed sets"]
        if partialSave.waitForExistence(timeout: 2) {
            partialSave.tap()
        }

        selectTab(.history, in: app)
        tapButton("history-workout-row", in: app)
        let historyComparison = app.descendants(matching: .any)["performance-comparison"].firstMatch
        scrollToElement(historyComparison, in: app)
        saveScreenshot("history/15_History_Performance_Comparison")
    }

    func testCaptureHomeTemplateSheetScreenshot() {
        let templatePicker = launchFreshApp()
        tapButton("start-from-template", in: templatePicker)
        XCTAssertTrue(templatePicker.navigationBars["Start from template"].waitForExistence(timeout: 5))
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

    func testCaptureLibrarySecondaryStatesScreenshots() {
        let library = launchFreshApp()
        selectTab(.library, in: library)
        let templatesBrowser = library.staticTexts["Workout Templates"].firstMatch
        XCTAssertTrue(templatesBrowser.waitForExistence(timeout: 5))
        templatesBrowser.tap()
        saveScreenshot("overview/02b_Library_Templates")
        library.navigationBars.buttons.firstMatch.tap()
        tapButton("plans-browser", in: library)
        saveScreenshot("overview/02c_Library_Plans")
        library.navigationBars.buttons.firstMatch.tap()
        let search = library.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("not-a-real-library-item")
        saveScreenshot("overview/02d_Library_Empty_Search")
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

    func testCapturePlanReviewScreenshot() {
        let app = launchFreshApp()
        selectTab(.library, in: app)

        tapButton("Create library item", in: app)
        tapButton("New Plan", in: app)

        let planName = app.textFields["plan-name-field"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("Screenshot Plan")
        planName.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let mondayTemplate = app.buttons["plan-day-template-0"]
        scrollToElement(mondayTemplate, in: app)
        saveScreenshot("plans/13_Plan_Day_Assignments")
        tapButton("save-plan", in: app)

        tapButton("plans-browser", in: app)
        tapButton("plan-row-Screenshot Plan", in: app)
        tapButton("edit-plan", in: app)
        tapButton("save-plan-edits", in: app)
        XCTAssertTrue(app.buttons["confirm-plan-changes"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13_Plan_Review")

    }

    func testCaptureActivePlanRunScreenshot() {
        let activeRun = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )
        selectTab(.library, in: activeRun)
        tapButton("plans-browser", in: activeRun)
        tapButton("plan-row-Screenshot Plan Run", in: activeRun)
        XCTAssertTrue(activeRun.buttons["start-planned-workout"].waitForExistence(timeout: 5))
        saveScreenshot("plans/13b_Plan_Active_Run")
    }

    private func selectTab(_ tab: AppTab, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
    }

    @discardableResult
    private func tapButton(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(
            button.waitForExistence(timeout: timeout),
            "Expected button '\(identifier)' to exist",
            file: file,
            line: line
        )
        button.tap()
        return button
    }

    private func tapFirstAvailableButton(
        _ identifiers: [String],
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for identifier in identifiers {
            let button = app.buttons[identifier].firstMatch
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return
            }
        }
        XCTFail("None of the expected buttons existed: \(identifiers)", file: file, line: line)
    }

    private func selectExerciseFromOpenPicker(_ name: String, in app: XCUIApplication) {
        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        tapButton("add-exercise-\(name)", in: app)

        let keyboardClose = app.buttons["close"]
        if keyboardClose.waitForExistence(timeout: 2) {
            keyboardClose.tap()
        }
        tapButton("close-exercise-picker", in: app)
    }

    private func completeSet(
        _ exercise: String,
        index: Int,
        dismissRest: Bool,
        in app: XCUIApplication
    ) {
        tapButton("complete-set-\(exercise)-\(index)", in: app)
        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
        if dismissRest {
            dismissRestIfPresent(in: app)
        }
    }

    private func dismissRestIfPresent(in app: XCUIApplication) {
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
        }
    }

    private func openUpperBodyTemplateEditor(in app: XCUIApplication) {
        selectTab(.library, in: app)
        let templatesBrowser = app.staticTexts["Workout Templates"].firstMatch
        XCTAssertTrue(templatesBrowser.waitForExistence(timeout: 5))
        templatesBrowser.tap()

        let template = app.staticTexts["Jour 2 - Haut du Corps (Poussée/Tirage)"].firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
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

    func testDefaultCollectionSeededOnLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()

        app.tabBars.buttons.element(boundBy: 1).tap()

        let collectionsRow = app.staticTexts["Collections"]
        XCTAssertTrue(collectionsRow.waitForExistence(timeout: 5))
        collectionsRow.tap()

        let seededCollection = app.staticTexts["Programme Haut/Bas - 4 Jours"]
        XCTAssertTrue(seededCollection.waitForExistence(timeout: 5))
    }

}
