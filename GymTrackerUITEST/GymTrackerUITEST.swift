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
        let workoutHistory = app.descendants(matching: .any)["progress-workout-history"]
        scrollToElement(workoutHistory, in: app)
        XCTAssertTrue(workoutHistory.exists)
        let trainingTrends = app.descendants(matching: .any)["progress-training-trends"]
        scrollToElement(trainingTrends, in: app)
        XCTAssertTrue(trainingTrends.exists)
        let tools = app.buttons["More"]
        scrollToElement(tools, in: app)
        tools.tap()
        let muscleGroupVolume = app.descendants(matching: .any)["progress-muscle-group-volume"]
        scrollToElement(muscleGroupVolume, in: app)
        XCTAssertTrue(muscleGroupVolume.exists)
        muscleGroupVolume.tap()
        XCTAssertTrue(app.navigationBars["Muscle-group volume"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        selectTab(.settings, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        tapButton("settings-advanced", in: app)
        let shortcuts = app.descendants(matching: .any)["settings-shortcuts-link"]
        XCTAssertTrue(shortcuts.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["settings-seed-two-years"].exists,
            "Debug Advanced settings should expose the two-year training seed."
        )
    }

    func testAppearanceMenuSupportsSystemDarkAndLightModes() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-testing-open-settings"]
        app.launchWithGymTrackerUITestArguments()

        func assertAppearance(_ expected: String) {
            let current = app.buttons["settings-appearance-picker"].firstMatch
            XCTAssertTrue(current.waitForExistence(timeout: 5))
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value CONTAINS %@", expected),
                object: current
            )
            XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed)
        }

        XCTAssertTrue(app.buttons["settings-appearance-picker"].firstMatch.waitForExistence(timeout: 45))
        assertAppearance("Dark")

        tapButton("settings-appearance-picker", in: app)
        tapButton("Light", in: app)
        assertAppearance("Light")

        tapButton("settings-appearance-picker", in: app)
        tapButton("Dark", in: app)
        assertAppearance("Dark")

        tapButton("settings-appearance-picker", in: app)
        tapButton("System Default", in: app)
        assertAppearance("System Default")
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

    func testLoggedFoodCanBeReviewedAndDeleted() {
        let app = launchFixture(
            "nutrition-today",
            expectsActiveWorkout: false,
            expectedHomeControl: "tab-nutrition"
        )
        selectTab(.nutrition, in: app)
        let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "logged-meal-"))
        XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 5))
        let originalCount = entries.count

        entries.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Food entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["logged-meal-quantity"].exists)
        tapButton("delete-logged-meal", in: app)
        tapButton("Delete entry", in: app)

        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries.count, originalCount - 1)
    }

    func testStartFreeWorkout() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launchWithGymTrackerUITestArguments()

        let startButton = app.buttons["start-free-workout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // The free-state primary command is already unambiguous and starts an
        // empty workout directly. Saved workouts remain a separate Train route.
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    func testBrowsesConfiguresAndActivatesBuiltInProgram() {
        let app = launchFreshApp()
        openPlans(.readyMade, in: app)

        focusPlansSearch(in: app).typeText("Double Progression")
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

    func testCatalogActivationRequiresResolvingAnExistingPlanConflict() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        openPlans(.readyMade, in: app)
        let search = focusPlansSearch(in: app)
        search.typeText("Double Progression")
        search.typeText("\n")
        tapButton("program-catalog-Double Progression Builder", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog-detail"].waitForExistence(timeout: 5))
        tapButton("use-program", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-intake"].waitForExistence(timeout: 5))
        let load = app.textFields["Default starting load"]
        XCTAssertTrue(load.waitForExistence(timeout: 5))
        load.tap()
        load.typeText("20")
        if app.buttons["Done"].waitForExistence(timeout: 2) {
            app.buttons["Done"].tap()
        }
        tapButton("start-program", in: app)

        XCTAssertTrue(
            app.buttons["resolve-guided-conflict-and-continue-plan"].waitForExistence(timeout: 8)
        )
        let cancel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel"))
            .firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()

        let originalPlan = app.buttons["current-plan-card"]
        XCTAssertTrue(originalPlan.waitForExistence(timeout: 5))
        XCTAssertTrue(originalPlan.label.contains("Screenshot Plan Run"))
    }

    func testCatalogActivationConflictCanPauseThePriorPlanAndContinue() {
        let app = launchFixture(
            "plan-active-run",
            expectsActiveWorkout: false,
            expectedHomeControl: "start-planned-workout"
        )

        openPlans(.readyMade, in: app)
        let search = focusPlansSearch(in: app)
        search.typeText("Double Progression")
        search.typeText("\n")
        tapButton("program-catalog-Double Progression Builder", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-catalog-detail"].waitForExistence(timeout: 5))
        tapButton("use-program", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-intake"].waitForExistence(timeout: 5))
        let load = app.textFields["Default starting load"]
        XCTAssertTrue(load.waitForExistence(timeout: 5))
        load.tap()
        load.typeText("20")
        if app.buttons["Done"].waitForExistence(timeout: 2) {
            app.buttons["Done"].tap()
        }
        tapButton("start-program", in: app)

        XCTAssertTrue(
            app.buttons["resolve-guided-conflict-and-continue-plan"].waitForExistence(timeout: 8)
        )
        tapButton("resolve-guided-conflict-and-continue-plan", in: app)

        let replacementPlan = app.buttons["current-plan-card"]
        XCTAssertTrue(replacementPlan.waitForExistence(timeout: 8))
        XCTAssertTrue(replacementPlan.label.contains("Double Progression Builder"))
    }

    func testPlanSearchNoMatchDoesNotShowLibraryOrInstallFailureEmptyStates() {
        let app = launchFreshApp()
        openPlans(.readyMade, in: app)

        let search = focusPlansSearch(in: app)
        search.typeText("not-a-real-plan")

        let noResults = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "No Results for")
        ).firstMatch
        XCTAssertTrue(noResults.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["The built-in plans could not be loaded."].exists)
        XCTAssertFalse(app.buttons["Build a plan"].exists)

        app.buttons["Clear text"].tap()
        app.buttons["Following"].tap()
        search.tap()
        search.typeText("not-a-followed-plan")

        XCTAssertTrue(noResults.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Not following a plan"].exists)
        XCTAssertFalse(app.buttons["Build a plan"].exists)
    }

    func testProgramDiscoveryFiltersCombineWithSearchAndCanBeCleared() {
        let app = launchFreshApp()
        openPlans(.readyMade, in: app)

        tapButton("program-discovery-filter-button", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["program-discovery-filters"].waitForExistence(timeout: 5))
        tapButton("Powerlifting", in: app)
        tapButton("Done", in: app)

        let search = focusPlansSearch(in: app)
        search.typeText("Foundation Barbell")
        XCTAssertTrue(app.staticTexts["No plans match"].waitForExistence(timeout: 5))

        tapButton("program-discovery-clear-filters", in: app)
        XCTAssertTrue(app.buttons["program-catalog-Foundation Barbell 5×5"].waitForExistence(timeout: 5))

        app.buttons["Clear text"].tap()
        XCTAssertTrue(app.buttons["program-catalog-Powerlifting Foundations"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["program-catalog-Foundation Barbell 5×5"].waitForExistence(timeout: 5))
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

    func testTodayShowsOneStartActionWhileWorkoutActive() {
        let app = launchFixture("active-in-progress")
        tapButton("minimize-workout", in: app)

        let resumeActions = app.buttons.matching(identifier: "resume-active-workout")
        XCTAssertTrue(resumeActions.firstMatch.waitForExistence(timeout: 10))
        let duplicateWeekActions = app.buttons.matching(identifier: "today-week-start-session")

        XCTAssertEqual(resumeActions.count + duplicateWeekActions.count, 1)
    }

    func testResumesPersistedRestTimerAfterRelaunch() {
        let app = launchFixture("active-rest-running")

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")
    }

    func testEditsJustLoggedSetWithoutStoppingRest() {
        let app = launchFixture("active-rest-running")

        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["rest-just-logged"].exists)
        tapButton("edit-just-logged-set", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["set-input-panel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["rest-running"].exists)
        XCTAssertTrue(app.buttons["rest-pill"].waitForExistence(timeout: 5))
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
        tapButton("rest-pill", in: app)
        for _ in 0..<10 {
            tapButton("rest-extend", in: app)
        }

        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rest-pause-toggle"].exists)

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

        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rest-pause-toggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bench Press"].exists)
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")

        // Confirm the restored countdown is live, not merely a stale card.
        tapButton("rest-pause-toggle", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        tapButton("rest-pause-toggle", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["rest-running"].waitForExistence(timeout: 5))
    }

    func testPersistsDraftSetValuesAfterTermination() {
        let app = launchFixture("active-draft")

        enterValue("7", field: "reps", for: "Bench Press", set: 0, in: app)
        enterValue("42", field: "weight", for: "Bench Press", set: 0, in: app)

        // Deliberately terminate with the keypad still open. The latest draft
        // must flush at the lifecycle boundary even though keypresses are
        // coalesced instead of saved one by one.
        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.state == .runningBackground },
            object: app
        )
        XCTAssertEqual(XCTWaiter().wait(for: [backgrounded], timeout: 5), .completed)
        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "7")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "42")
    }

    func testResumesPausedRestTimerAfterRelaunch() {
        let app = launchFixture("active-rest-paused")

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["rest-paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rest-pause-toggle"].exists)
    }

    func testStartSeededTemplateIncludesPrescription() {
        let app = launchFreshApp()

        let startFromTemplate = app.buttons["today-open-saved-workouts"]
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

        let startFreeWorkout = app.buttons["today-open-saved-workouts"]
        scrollToElement(startFreeWorkout, in: app)
        startFreeWorkout.tap()
        let search = app.textFields["workout-search"]
        for _ in 0..<4 where !search.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Linked Mobility Screenshot")
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        }
        let template = app.buttons["workout-template-Linked Mobility Screenshot"]
        XCTAssertTrue(template.waitForExistence(timeout: 10))
        XCTAssertTrue(template.isHittable)
        template.tap()

        tapButton("start-linked-warmup", in: app)
        let integratedStage = app.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(integratedStage.waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.buttons["complete-mobility-movement"].exists
                || app.buttons["complete-mobility-phase"].exists
        )
        XCTAssertFalse(app.descendants(matching: .any)["standalone-mobility-stage"].exists)
        XCTAssertFalse(app.staticTexts["active-workout-title"].exists)

        tapButton("linked-mobility-menu", in: app)
        tapButton("stop-mobility-session", in: app)
        tapButton("Stop Session", in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(activeExerciseCard("Bench Press", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["active-workout-mobility-stage"].exists)
        XCTAssertFalse(app.buttons["complete-mobility-movement"].exists)
        XCTAssertFalse(app.buttons["complete-mobility-phase"].exists)
    }

    func testLinkedCooldownContinuesInsideActiveWorkoutAfterSave() {
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
        tapButton("skip-linked-warmup", in: app)

        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        for setIndex in 0..<2 {
            enterValidValues(for: "Bench Press", set: setIndex, in: app)
            completeSet("Bench Press", index: setIndex, dismissRest: true, in: app)
        }
        enterValidValues(for: "Bench Press", set: 2, in: app)
        tapButton("complete-set-Bench Press-2", in: app)
        XCTAssertTrue(app.buttons["finish-workout"].waitForExistence(timeout: 10))
        tapButton("finish-workout", in: app)
        tapButton("save-workout", in: app)

        let cooldownStage = app.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(cooldownStage.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["start-linked-cooldown"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["standalone-mobility-stage"].exists)

        tapButton("linked-mobility-menu", in: app)
        tapButton("stop-mobility-session", in: app)
        tapButton("Stop Session", in: app)
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 10))
    }

    func testMidWorkoutMobilityInsertStartsInsideActiveWorkoutCover() {
        let app = launchFixture("active-in-progress")

        tapButton("active-workout-menu", in: app)
        tapButton("add-active-mobility-menu", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["active-workout-mobility-insert-picker"]
                .waitForExistence(timeout: 10)
        )

        let firstRoutine = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "active-workout-mobility-insert-routine-")
        ).firstMatch
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10))
        firstRoutine.tap()

        let integratedStage = app.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(integratedStage.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DURING"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["standalone-mobility-stage"].exists)
        XCTAssertFalse(app.staticTexts["WARM-UP"].exists)
        XCTAssertFalse(app.staticTexts["COOLDOWN"].exists)

        tapButton("linked-mobility-menu", in: app)
        tapButton("stop-mobility-session", in: app)
        tapButton("Stop Session", in: app)
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["active-workout-mobility-stage"].exists)
    }

    func testMidWorkoutMobilityFixturePresentsLinkedStage() {
        let app = launchFixture("mid-workout-mobility")
        let integratedStage = app.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(integratedStage.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DURING"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["standalone-mobility-stage"].exists)
    }

    func testPushFocusFiltersActiveExercisePicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launchWithGymTrackerUITestArguments()

        startEmptyWorkout(in: app)

        tapButton("active-workout-menu", in: app)
        tapButton("add-active-exercise-menu", in: app)
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))

        let pushFilter = app.buttons["exercise-focus-Push"]
        XCTAssertTrue(pushFilter.waitForExistence(timeout: 5))
        pushFilter.tap()

        XCTAssertTrue(app.buttons["exercise-link-Arnold Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Back Squat"].exists)
    }

    func testActiveExercisePickerSearchAndAddPreservesSelection() {
        let app = launchFixture("active-empty")

        tapButton("add-first-exercise", in: app)
        // The picker prompt is product copy and may evolve; the search field
        // itself is the stable control this flow needs to exercise.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Arnold Press")

        let result = app.buttons["exercise-link-Arnold Press"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        let add = app.buttons["add-exercise-Arnold Press"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let added = app.descendants(matching: .any)["added-exercise-Arnold Press"]
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["add-exercise-Arnold Press"].exists)

        let keyboardSearch = app.keyboards.buttons["Search"].firstMatch
        let keyboardReturn = app.keyboards.buttons["Return"].firstMatch
        if keyboardSearch.waitForExistence(timeout: 1) {
            keyboardSearch.tap()
        } else if keyboardReturn.waitForExistence(timeout: 1) {
            keyboardReturn.tap()
        }
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.descendants(matching: .any)["active-exercise-Arnold Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["add-set-Arnold Press"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["warm-up-section-Arnold Press"].exists)

        // Reopening the picker must preserve the destination's membership
        // state; an already-added exercise must not become removable from a
        // sheet that does not show its working sets.
        tapButton("active-workout-menu", in: app)
        tapButton("add-active-exercise-menu", in: app)
        let reopenedSearch = app.searchFields.firstMatch
        XCTAssertTrue(reopenedSearch.waitForExistence(timeout: 5))
        reopenedSearch.tap()
        reopenedSearch.typeText("Arnold Press")
        XCTAssertTrue(
            app.descendants(matching: .any)["added-exercise-Arnold Press"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["add-exercise-Arnold Press"].exists)
    }

    func testActiveExercisePickerGroupsRecentFavoritesAndAllWithoutDuplicates() {
        let app = launchFixture("active-picker-sections")
        tapButton("add-first-exercise", in: app)

        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All Exercises"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(identifier: "add-exercise-Bench Press").count,
            1,
            "A recent exercise must not be repeated in All Exercises."
        )

        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(identifier: "add-exercise-Arnold Press").count,
            1,
            "A favorite must be excluded from All Exercises when it is featured."
        )
    }

    func testActiveExercisePickerNoResultsRecoversAndCreatesFromQuery() {
        let app = launchFixture("active-empty")
        tapButton("add-first-exercise", in: app)

        let query = "Cobalt Press"
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(query)

        XCTAssertTrue(app.descendants(matching: .any)["exercise-picker-no-results"].waitForExistence(timeout: 5))
        // SwiftUI's Button identifier can be flattened on some simulator
        // runtimes; the user-facing label remains a stable accessibility
        // contract for this query-specific action.
        let create = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        scrollToElement(create, in: app)

        // Clearing the query must recover the browse sections instead of
        // leaving the picker stranded in its empty state.
        let clearSearch = app.buttons["Clear text"]
        XCTAssertTrue(clearSearch.waitForExistence(timeout: 5))
        clearSearch.tap()
        XCTAssertTrue(app.staticTexts["All Exercises"].waitForExistence(timeout: 5))

        search.tap()
        search.typeText(query)
        create.tap()
        XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 5))
        let name = app.textFields["exercise-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, query)
        tapButton("save-exercise", in: app)

        XCTAssertTrue(app.buttons["added-exercise-\(query)"].waitForExistence(timeout: 5))
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

        navigateToActiveExercise("Dumbbell Bench Press", in: app)
        tapButton("weight-field-Dumbbell Bench Press-0", in: app)
        XCTAssertTrue(app.buttons["panel-details"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["panel-chip-plates"].exists)

    }

    func testEditingWeightOnALaterExerciseKeepsThatExerciseVisible() {
        let app = launchFixture("active-all-tracking-types")

        navigateToActiveExercise("Weighted Pull-Up", in: app)

        tapButton("weight-field-Weighted Pull-Up-0", in: app)

        XCTAssertTrue(app.buttons["panel-value-weight"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["panel-value-weight"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["active-exercise-Weighted Pull-Up"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["active-exercise-Bench Press"].exists)
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
        let exactDigits = app.buttons["plate-keypad-digits"].firstMatch
        scrollToElement(exactDigits, in: app)
        exactDigits.tap()
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

    func testExactEntryCommitsValueWithoutCompletingSet() {
        let app = launchFixture("active-draft")

        tapButton("weight-field-Bench Press-0", in: app)
        XCTAssertTrue(app.buttons["panel-chip-plates"].waitForExistence(timeout: 5))

        let exactDigits = app.descendants(matching: .any)["plate-keypad-digits"]
        scrollToElement(exactDigits, in: app)
        XCTAssertTrue(exactDigits.exists)
        exactDigits.tap()
        tapButton("keypad-key-6", in: app)
        tapButton("keypad-key-0", in: app)

        let useValue = app.buttons["panel-use-value"]
        XCTAssertTrue(useValue.waitForExistence(timeout: 5))
        XCTAssertTrue(useValue.label.contains("Use 60"))
        XCTAssertFalse(app.buttons["panel-chip-plates"].exists)
        XCTAssertFalse(app.buttons["panel-complete-set"].exists)

        useValue.tap()

        XCTAssertFalse(app.buttons["panel-use-value"].exists)
        XCTAssertTrue(app.buttons["complete-set-Bench Press-0"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["rest-pill"].waitForExistence(timeout: 5))

        // Completing a set moves the keypad to the next one, which is the set
        // whose details the deletion below belongs to.
        XCTAssertTrue(app.buttons["panel-chip-last set"].waitForExistence(timeout: 5))
        tapButton("panel-details", in: app)
        XCTAssertTrue(app.buttons["delete-set-Bench Press-1"].waitForExistence(timeout: 5))
        app.buttons["delete-set-Bench Press-1"].tap()
        app.buttons["confirm-delete-set-Bench Press-1"].firstMatch.tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["complete-set-Bench Press-4"].exists)

        tapButton("exercise-actions-Bench Press", in: app)
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

    func testAdvancedSegmentedMethodExposesStableStageIdentifiers() {
        let app = launchFixture("active-advanced-set")

        tapButton("reps-field-Bench Press-0", in: app)
        tapButton("panel-details", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["set-advanced-options"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["set-method-stage-hint"].waitForExistence(timeout: 5))

        let methodPicker = app.descendants(matching: .any)["set-method-picker"]
        XCTAssertTrue(methodPicker.waitForExistence(timeout: 5))
        let normalRole = app.buttons["set-type-option-normal"]
        XCTAssertTrue(normalRole.waitForExistence(timeout: 5))
        XCTAssertTrue(normalRole.isSelected, "A dropset method must not masquerade as a set role.")

        // Internal method stages are intentionally edited on the exercise
        // stage, not inside the metadata sheet.
        tapButton("close-set-details", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["active-set-segment-editor"].waitForExistence(timeout: 5))

        // Segment rows are a method stage, not additional working sets. Their
        // method-specific labels and add action are the stable user-facing
        // contract (the surrounding summary may combine child accessibility).
        XCTAssertTrue(app.staticTexts["DROPSET START"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DROP 1"].waitForExistence(timeout: 5))
        let addSegment = app.descendants(matching: .any)["add-set-segment"]
        XCTAssertTrue(addSegment.waitForExistence(timeout: 5))
    }

    func testAdvancedMethodStagesUseMethodLabelsAndPersistAddedSegment() {
        let app = launchFixture("active-advanced-set")

        tapButton("reps-field-Bench Press-0", in: app)
        tapButton("panel-details", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["set-details-screen"].waitForExistence(timeout: 5))
        tapButton("close-set-details", in: app)
        // The set-input keypad remains raised after closing details and covers
        // the live method editor. Dismiss it before scrolling to the add action.
        dismissKeypadIfPresent(in: app)

        let editor = app.descendants(matching: .any)["active-set-segment-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DROPSET START"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DROP 1"].waitForExistence(timeout: 5))

        let addDrop = app.descendants(matching: .any)["add-set-segment"]
        XCTAssertTrue(addDrop.waitForExistence(timeout: 5))
        XCTAssertTrue(addDrop.label.localizedCaseInsensitiveContains("Add drop"))
        scrollToElement(addDrop, in: app)
        XCTAssertTrue(addDrop.isHittable, "Add drop must be hittable after scrolling; frame=\(addDrop.frame)")
        addDrop.tap()
        XCTAssertTrue(app.descendants(matching: .any)["set-segment-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DROP 2"].exists)

        relaunchPreservingData(app)
        resumeActiveWorkout(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["active-set-segment-editor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["set-segment-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DROP 2"].exists)
    }

    func testRemovingWarmupBlockPreservesExerciseAndWorkingSets() {
        let app = launchFixture("active-warmup-expanded")

        XCTAssertTrue(app.buttons["warm-up-section-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["complete-set-Bench Press-2"].waitForExistence(timeout: 5))

        // Use the semantic identifier family rather than a visible label: the
        // action may be rendered as a row control, menu item, or disclosure
        // affordance while the operation remains the same.
        let removeWarmup = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier CONTAINS[c] %@ AND (identifier CONTAINS[c] %@ OR identifier CONTAINS[c] %@)",
                "remove",
                "warmup",
                "warm-up"
            )
        ).firstMatch
        XCTAssertTrue(removeWarmup.waitForExistence(timeout: 5))
        removeWarmup.tap()

        let confirmation = app.buttons["Remove warm-up sets"].firstMatch
        if confirmation.waitForExistence(timeout: 2) {
            confirmation.tap()
        }

        XCTAssertTrue(app.descendants(matching: .any)["active-exercise-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["complete-set-Bench Press-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["warm-up-section-Bench Press"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["complete-set-Bench Press-2"].waitForNonExistence(timeout: 5))
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

        let finishButton = app.buttons["finish-workout"]
        XCTAssertFalse(finishButton.exists)
    }

    func testSavesCompletedWorkoutToHistory() {
        let app = launchFixture("active-partial-save")

        navigateToWorkoutFinish(in: app)
        tapButton("finish-workout", in: app)
        XCTAssertTrue(app.buttons["save-workout"].waitForExistence(timeout: 5))
        app.buttons["save-workout"].tap()

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

    func testLogSetAcceptsAutofilledPreviousPerformance() {
        let app = launchFreshApp()
        startEmptyWorkout(in: app)
        addExercise("Bench Press", in: app)
        enterValidValues(for: "Bench Press", set: 0, in: app)
        app.buttons["complete-set-Bench Press-0"].tap()
        dismissKeypadIfPresent(in: app)
        navigateToWorkoutFinish(in: app)
        app.buttons["finish-workout"].tap()
        app.buttons["save-workout"].tap()

        startEmptyWorkout(in: app)
        addExercise("Bench Press", in: app)

        XCTAssertTrue(app.staticTexts["previous-performance-Bench Press"].waitForExistence(timeout: 5))
        XCTAssertEqual(setValue("reps", for: "Bench Press", set: 0, in: app), "8")
        XCTAssertEqual(setValue("weight", for: "Bench Press", set: 0, in: app), "50")
        app.buttons["complete-set-Bench Press-0"].tap()
        XCTAssertTrue(app.buttons["complete-set-Bench Press-0"].isSelected)
    }

    func testPartialSaveHasNoSecondConfirmation() {
        let app = launchFixture("active-partial-save")
        navigateToWorkoutFinish(in: app)
        tapButton("finish-workout", in: app)
        tapButton("save-workout", in: app)

        XCTAssertFalse(app.buttons["Save completed sets"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["start-free-workout"].waitForExistence(timeout: 5))
    }

    func testProgressToolsDisclosureHidesSpecialistRows() {
        let app = launchFixture("history-bench", expectsActiveWorkout: false)
        selectTab(.progress, in: app)

        XCTAssertTrue(app.descendants(matching: .any)["progress-tools-disclosure"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["progress-weightlifting"].exists)
        tapControl("progress-tools-disclosure", in: app)
        let weightlifting = app.descendants(matching: .any)["progress-weightlifting"]
        scrollToElement(weightlifting, in: app)
        XCTAssertTrue(weightlifting.exists)
    }

    func testDiscardsActiveWorkout() {
        let app = launchFixture("active-in-progress")

        // Discard is no longer a permanent toolbar control: it lives in the
        // workout menu and still requires an explicit destructive confirmation.
        tapButton("active-workout-menu", in: app)
        tapControl("discard-workout", in: app)
        // The dismissed menu item and the dialog action briefly share the
        // identifier, so take the action the dialog is presenting now.
        let confirmDiscard = app.sheets.buttons["confirm-discard-workout"].firstMatch
        XCTAssertTrue(confirmDiscard.waitForExistence(timeout: 8))
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

        tapButton("library-create", in: app)
        tapButton("new-plan", in: app)
        XCTAssertTrue(app.navigationBars["New Training Plan"].waitForExistence(timeout: 5))

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

        navigateToWorkoutFinish(in: app)
        tapButton("finish-workout", in: app)
        tapButton("save-workout", in: app)

        let linkedCooldown = app.descendants(matching: .any)["active-workout-mobility-stage"]
        if linkedCooldown.waitForExistence(timeout: 5) {
            tapButton("linked-mobility-menu", in: app)
            tapButton("stop-mobility-session", in: app)
            tapButton("Stop Session", in: app)
            let nextPlannedWorkout = app.buttons["start-planned-workout"]
            XCTAssertTrue(nextPlannedWorkout.waitForExistence(timeout: 10))
            XCTAssertTrue(nextPlannedWorkout.label.contains("Fixture Day 2"))
        }

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
        XCTAssertTrue(app.descendants(matching: .any)["plate-keypad"].waitForExistence(timeout: 5))
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
        let back = app.navigationBars["Data & backup"].buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
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
