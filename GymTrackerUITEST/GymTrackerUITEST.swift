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

        let resumeButton = app.buttons["start-free-workout"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(resumeButton.label.contains("Resume"))
        resumeButton.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
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
    }

    func testCaptureScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()
        
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
        
        // 4. Analytics Tab (Placeholder)
        app.tabBars.buttons.element(boundBy: 3).tap()
        saveScreenshot(name: "04_Analytics")
        
        // Go back to Home and open Settings
        app.tabBars.buttons.element(boundBy: 0).tap()
        let settingsButton = app.buttons["settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        saveScreenshot(name: "04_Settings")
        
        // Dismiss Settings sheet
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        
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
        startButton.tap()
        
        // 6. Add Exercise Picker Sheet
        let addExerciseButton = app.buttons["add-active-exercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5))
        addExerciseButton.tap()
        saveScreenshot(name: "06_Add_Exercise_Sheet")
        
        // Swipe up to bring Bench Press into view
        app.swipeUp()
        
        // Add Bench Press
        let benchPressButton = app.buttons["add-exercise-Bench Press"]
        XCTAssertTrue(benchPressButton.waitForExistence(timeout: 5))
        benchPressButton.tap()
        
        // 7. Plate Calculator
        let plateCalcButton = app.buttons["plate-calculator-Bench Press"].firstMatch
        XCTAssertTrue(plateCalcButton.waitForExistence(timeout: 5))
        plateCalcButton.tap()
        saveScreenshot(name: "07_Plate_Calculator")
        
        // Dismiss Plate Calculator
        let doneButton = app.buttons["Done"].exists ? app.buttons["Done"] : app.buttons["Terminé"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
        
        // 8. Complete set (marks it completed)
        let completeSetButton = app.buttons["complete-set-Bench Press-0"]
        if !completeSetButton.exists {
            app.buttons["active-exercise-Bench Press"].tap()
        }
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 5))
        completeSetButton.tap()
        saveScreenshot(name: "08_Active_Workout_With_Set")
        
        // 9. Save Workout Screen (Tap finish button)
        let finishButton = app.buttons["Finish workout"].exists ? app.buttons["Finish workout"] : app.buttons["Terminer l'entraînement"]
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
        let workoutRow = app.staticTexts["Workout"].firstMatch
        XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
        workoutRow.tap()
        saveScreenshot(name: "11_History_Detail")
    }

}
