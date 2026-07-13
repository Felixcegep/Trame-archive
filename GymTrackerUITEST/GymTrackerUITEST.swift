import XCTest

final class GymTrackerUITEST: XCTestCase {

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

        app.buttons["minimize-workout"].tap()
        app.terminate()

        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["resume-active-workout"].waitForExistence(timeout: 5))
        app.buttons["resume-active-workout"].tap()

        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
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

        let template = app.buttons["plan-template-Jour 1 - Bas du Corps (Squat/Genoux)"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        app.buttons["save-plan"].tap()

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
        XCTAssertTrue(app.staticTexts["Goblet Stiletto Squat"].exists)
    }

    private func assertLibrarySearchResult(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()
        // First launch after a fresh install reseeds the catalogue and can
        // exceed 5 seconds on a cold simulator.
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 15))
        return app
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

    private func enterValidValues(for exercise: String, set: Int, in app: XCUIApplication) {
        let reps = app.textFields["reps-field-\(exercise)-\(set)"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText("8")

        let weight = app.textFields["weight-field-\(exercise)-\(set)"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("50")

        app.buttons["Done"].tap()
    }

    func testCaptureScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()
        let preparedStartButton = app.buttons["start-free-workout"]
        XCTAssertTrue(preparedStartButton.waitForExistence(timeout: 10))
        XCTAssertTrue(preparedStartButton.label.localizedCaseInsensitiveContains("start"))
        
        // Output directory
        let screenshotDir = "/Users/felixlachapelle/Desktop/GymTracker/Screenshots"
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: screenshotDir, withIntermediateDirectories: true)
        
        func saveScreenshot(name: String) {
            // Allow UI to settle
            Thread.sleep(forTimeInterval: 1.0)
            let screenshot = XCUIScreen.main.screenshot()
            let pngData = screenshot.pngRepresentation
            let filePath = "\(screenshotDir)/\(name).png"
            do {
                try pngData.write(to: URL(fileURLWithPath: filePath))
                print("Saved screenshot to \(filePath)")
            } catch {
                print("Failed to save screenshot: \(error)")
            }
        }
        
        // 1. Home Screen
        saveScreenshot(name: "01_Home")
        
        // 2. Library Tab
        app.tabBars.buttons.element(boundBy: 1).tap()
        saveScreenshot(name: "02_Library")
        
        // 3. History Tab (Empty)
        app.tabBars.buttons.element(boundBy: 2).tap()
        saveScreenshot(name: "03_History_Empty")
        
        // 4. Settings Tab
        app.tabBars.buttons.element(boundBy: 3).tap()
        saveScreenshot(name: "04_Settings")

        // Go back to Home
        app.tabBars.buttons.element(boundBy: 0).tap()
        
        // 5. Active Workout Screen (Empty)
        let startButton = app.buttons["start-free-workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        saveScreenshot(name: "05_Active_Workout_Empty")
        
        // Minimize active workout to capture Home With Active Workout
        let minimizeButton = app.buttons["minimize-workout"]
        XCTAssertTrue(minimizeButton.waitForExistence(timeout: 5))
        minimizeButton.tap()
        saveScreenshot(name: "05_Home_With_Active_Workout")
        
        // Resume active workout
        let resumeButton = app.buttons["resume-active-workout"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()
        
        // 6. Add Exercise Picker Sheet
        let addExerciseButton = app.buttons["add-active-exercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5))
        addExerciseButton.tap()
        saveScreenshot(name: "06_Add_Exercise_Sheet")
        
        let exerciseSearch = app.searchFields["Search exercises"]
        XCTAssertTrue(exerciseSearch.waitForExistence(timeout: 5))
        exerciseSearch.tap()
        exerciseSearch.typeText("Bench Press")
        
        // Add Bench Press
        let benchPressButton = app.buttons["add-exercise-Bench Press"]
        XCTAssertTrue(benchPressButton.waitForExistence(timeout: 5))
        benchPressButton.tap()

        let keyboardClose = app.buttons["close"]
        if keyboardClose.waitForExistence(timeout: 2) {
            keyboardClose.tap()
        }

        let closeExercisePicker = app.buttons["close-exercise-picker"]
        XCTAssertTrue(closeExercisePicker.waitForExistence(timeout: 5))
        closeExercisePicker.tap()
        
        // 8. Complete set (marks it completed)
        let completeSetButton = app.buttons["complete-set-Bench Press-0"]
        if !completeSetButton.exists {
            app.buttons["active-exercise-Bench Press"].tap()
        }
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 5))
        enterValidValues(for: "Bench Press", set: 0, in: app)

        // 7. Plate Calculator (after entering weight so the bar-load diagram is populated)
        let plateCalcButton = app.buttons["plate-calculator-Bench Press"].firstMatch
        XCTAssertTrue(plateCalcButton.waitForExistence(timeout: 5))
        plateCalcButton.tap()
        saveScreenshot(name: "07_Plate_Calculator")

        // Dismiss Plate Calculator
        let doneButton = app.buttons["Done"].exists ? app.buttons["Done"] : app.buttons["Terminé"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // 7b. Set details sheet (set type chips + RPE slider), set RPE ≈ 8
        let setMenuButton = app.buttons["set-menu-Bench Press-0"]
        XCTAssertTrue(setMenuButton.waitForExistence(timeout: 5))
        setMenuButton.tap()
        let rpeSlider = app.sliders["rpe-slider"]
        XCTAssertTrue(rpeSlider.waitForExistence(timeout: 5))
        rpeSlider.adjust(toNormalizedSliderPosition: 0.78)
        saveScreenshot(name: "07b_Set_Details")

        let closeSetDetails = app.buttons["close-set-details"]
        XCTAssertTrue(closeSetDetails.waitForExistence(timeout: 5))
        closeSetDetails.tap()

        completeSetButton.tap()
        saveScreenshot(name: "08_Active_Workout_With_Set")

        XCTAssertTrue(app.staticTexts["Rest between sets"].waitForExistence(timeout: 5))
        saveScreenshot(name: "08_Rest_Countdown")

        // 9. Save Workout Screen (Tap finish button)
        app.buttons["Done"].tap()
        let finishButton = app.buttons["Review Workout"].exists ? app.buttons["Review Workout"] : app.buttons["Terminer l'entraînement"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.tap()
        saveScreenshot(name: "09_Save_Workout")
        
        // Tap Save workout
        let saveWorkoutButton = app.buttons["Save workout"]
        XCTAssertTrue(saveWorkoutButton.waitForExistence(timeout: 5))
        saveWorkoutButton.tap()
        
        // Confirm partial save
        let confirmSaveButton = app.buttons["Save completed sets"]
        if confirmSaveButton.waitForExistence(timeout: 3) {
            confirmSaveButton.tap()
        }
        
        // Wait to return to Home
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
        
        // 10. History Tab (With Saved Workout)
        app.tabBars.buttons.element(boundBy: 2).tap()
        saveScreenshot(name: "10_History_With_Workout")
        
        // 11. Workout Detail Screen
        let workoutRow = app.buttons["history-workout-row"].firstMatch
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
        workoutRow.tap()
        saveScreenshot(name: "11_History_Detail")

        // 12. Plan Review
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["Create library item"].tap()
        XCTAssertTrue(app.buttons["New Plan"].waitForExistence(timeout: 5))
        app.buttons["New Plan"].tap()

        let planName = app.textFields["plan-name-field"]
        XCTAssertTrue(planName.waitForExistence(timeout: 5))
        planName.tap()
        planName.typeText("Screenshot Plan")
        app.buttons["save-plan"].tap()

        app.buttons["plans-browser"].tap()
        let screenshotPlan = app.buttons["plan-row-Screenshot Plan"].firstMatch
        XCTAssertTrue(screenshotPlan.waitForExistence(timeout: 5))
        screenshotPlan.tap()
        app.buttons["edit-plan"].tap()
        app.buttons["save-plan-edits"].tap()
        XCTAssertTrue(app.buttons["confirm-plan-changes"].waitForExistence(timeout: 5))
        saveScreenshot(name: "12_Plan_Review")
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
