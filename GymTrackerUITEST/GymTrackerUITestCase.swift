import XCTest
@testable import GymTracker

/// Promoted surfaces exercised by the UI suite even when a narrower release
/// wave intentionally hides them. Keeping this at file scope lets direct
/// `XCUIApplication` launches use the same deterministic matrix as fixtures.
private let completeGymTrackerUITestFeatureFlags = [
    "today", "mobility", "nutrition", "bodyWeight", "dailyCheckIn",
    "programBuilder", "advancedExecution", "betaFeedback",
    "recipeGeneration", "workoutGeneration", "mobilityAssessment",
    "mobilityProgram", "sportSpecializations"
].joined(separator: ",")

extension XCUIApplication {
    private static let mirroredArgumentsEnvironmentKey = "GYMTRACKER_UI_TEST_ARGUMENTS_JSON"

    /// Mirrors the exact argument array through an environment payload before
    /// launching. The app still supports ordinary command-line delivery, but
    /// this fallback keeps Simulator launch-service argument loss from opening
    /// onboarding or silently skipping a requested fixture.
    func launchWithGymTrackerUITestArguments(mirroring arguments: [String]? = nil) {
        var mirroredArguments = arguments ?? launchArguments
        if !mirroredArguments.contains("-feature-flags") {
            mirroredArguments += ["-feature-flags", completeGymTrackerUITestFeatureFlags]
            launchArguments = mirroredArguments
        }
        if let data = try? JSONEncoder().encode(mirroredArguments),
           let payload = String(data: data, encoding: .utf8) {
            launchEnvironment[Self.mirroredArgumentsEnvironmentKey] = payload
        }
        launch()
    }
}

enum AppTab {
    case today
    case train
    case nutrition
    case progress
    /// Compatibility destinations used by existing tests while their flows
    /// migrate from former tabs to Progress and Today.
    case history
    case settings

    static let home: Self = .today
    static let library: Self = .train

    var title: String {
        switch self {
        case .today: "Today"
        case .train: "Train"
        case .nutrition: "Nutrition"
        case .progress, .history: "Progress"
        case .settings: "Settings"
        }
    }
}

class GymTrackerUITestCase: XCTestCase {
    /// UI and screenshot coverage exercises promoted surfaces even when the
    /// current TestFlight wave intentionally hides them. Tests that verify a
    /// narrower rollout pass their own `-feature-flags` value, which wins by
    /// replacing this default rather than being combined with it.
    private func featureFlagArguments(unlessOverriddenBy arguments: [String]) -> [String] {
        arguments.contains("-feature-flags")
            ? []
            : ["-feature-flags", completeGymTrackerUITestFeatureFlags]
    }

    func selectTab(_ tab: AppTab, in app: XCUIApplication) {
        switch tab {
        case .history:
            selectTab(.progress, in: app)
            let history = app.descendants(matching: .any)["progress-workout-history"]
            XCTAssertTrue(history.waitForExistence(timeout: 5))
            history.tap()
            return
        case .settings:
            selectTab(.today, in: app)
            tapButton("open-settings", in: app)
            return
        case .today, .train, .nutrition, .progress:
            break
        }

        let tabIdentifier: String
        switch tab {
        case .today: tabIdentifier = "tab-today"
        case .train: tabIdentifier = "tab-train"
        case .nutrition: tabIdentifier = "tab-nutrition"
        case .progress: tabIdentifier = "tab-progress"
        case .history, .settings: fatalError("Compatibility destinations are handled above")
        }
        let tabButton = app.buttons[tabIdentifier].firstMatch
        if tabButton.waitForExistence(timeout: 5) {
            tabButton.tap()
            return
        }

        // iOS 26 bridges a SwiftUI TabView's accessibility identifier from
        // the Label child onto the tab-item content inconsistently: the same
        // item may appear as an identifier-bearing Button on one launch and
        // as a plain tab-bar Button labelled by its title on another. The
        // native tab-bar element is the stable fallback and still exercises
        // the user-visible navigation path.
        let title = tab.title
        let nativeTabButton = app.tabBars.buttons[title].firstMatch
        XCTAssertTrue(nativeTabButton.waitForExistence(timeout: 5))
        nativeTabButton.tap()
    }

    /// Ready-made, saved and repeating plans all live behind the single Plans
    /// row on Train, separated by a scope control rather than by three sibling
    /// browsers. Tests pick the scope they need after opening it.
    enum PlansScope: String {
        case following = "Following"
        case mine = "Mine"
        case readyMade = "Ready-made"
    }

    func openPlans(_ scope: PlansScope, in app: XCUIApplication) {
        selectTab(.library, in: app)
        tapButton("plans-browser", in: app)
        let control = app.buttons[scope.rawValue].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 8), "Expected the '\(scope.rawValue)' plans scope")
        control.tap()
    }

    @discardableResult
    func tapButton(
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

    /// SwiftUI `Menu` and picker-backed controls can bridge as Button or
    /// PopUpButton depending on the simulator OS. Their accessibility identity
    /// is stable even when XCTest's legacy element type is not.
    @discardableResult
    func tapControl(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let control = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: timeout), "Expected control '\(identifier)' to exist", file: file, line: line)
        control.tap()
        return control
    }

    func tapFirstAvailableButton(
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

    func selectExerciseFromOpenPicker(_ name: String, in app: XCUIApplication) {
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

    func completeSet(
        _ exercise: String,
        index: Int,
        dismissRest: Bool,
        in app: XCUIApplication
    ) {
        tapButton("complete-set-\(exercise)-\(index)", in: app)
        let expandedRest = app.descendants(matching: .any)["rest-running"]
        let collapsedRest = app.buttons["rest-pill"]
        let restPresented = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in expandedRest.exists || collapsedRest.exists },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [restPresented], timeout: 5),
            .completed,
            "Completing a set should present rest as either the takeover or its focused-input pill."
        )
        if dismissRest {
            dismissRestIfPresent(in: app)
        }
    }

    /// Completing a set moves the keypad on to the next one, so "dismissing
    /// rest" means closing that panel to get the workout list back.
    func dismissRestIfPresent(in app: XCUIApplication) {
        dismissKeypadIfPresent(in: app)
    }

    func openUpperBodyTemplateEditor(in app: XCUIApplication) {
        selectTab(.library, in: app)
        tapButton("workouts-browser", in: app)
        let template = app.buttons["edit-workout-Day 2 – Upper Body (Push/Pull)"].firstMatch
        scrollToElement(template, in: app)
        template.tap()
    }


    func assertLibrarySearchResult(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["library-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    func assertRestDuration(_ expected: String, in app: XCUIApplication) {
        var duration = app.descendants(matching: .any)["settings-rest-duration"]
        if !duration.exists {
            let workoutSettings = app.buttons["settings-workout"]
            XCTAssertTrue(workoutSettings.waitForExistence(timeout: 5))
            workoutSettings.tap()
            XCTAssertTrue(app.descendants(matching: .any)["settings-workout-screen"].waitForExistence(timeout: 5))
            duration = app.descendants(matching: .any)["settings-rest-duration"]
        }
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        let value = duration.value as? String ?? duration.label
        XCTAssertTrue(value.contains(expected), "Expected rest duration to contain '\(expected)', got '\(value)'")
    }

    func assertUnitSystem(_ expected: String, in app: XCUIApplication) {
        let picker = app.buttons["settings-units-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let value = picker.value as? String ?? picker.label
        XCTAssertTrue(value.localizedCaseInsensitiveContains(expected), "Expected units to contain '\(expected)', got '\(value)'")
    }

    func launchFreshApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // A simulator may retain a stale automation session immediately after
        // a test process has been restarted. Give the test-only reset one
        // clean relaunch, but never continue unless the fresh Home state is
        // actually present.
        for attempt in 0..<2 {
            app.launchArguments = ["-ui-testing", "-reset-data"]
                + featureFlagArguments(unlessOverriddenBy: additionalArguments)
                + additionalArguments
            app.launchWithGymTrackerUITestArguments()
            XCTAssertEqual(app.state, .runningForeground)

            // A reset clears and reseeds SwiftData before the tab content
            // becomes interactive. Wait on that real state transition instead
            // of guessing how long a cold simulator needs.
            let preparing = app.descendants(matching: .any)["app-preparing"]
            if preparing.exists {
                XCTAssertTrue(preparing.waitForNonExistence(timeout: 60))
            }
            if app.buttons["start-free-workout"].waitForExistence(timeout: 45) {
                return app
            }
            if attempt == 0 {
                app.terminate()
            }
        }

        XCTFail("Fresh UI-test launch did not reach the Home state after one reset retry")
        return app
    }

    /// Starts a blank session from Home. The primary card now opens the unified
    /// "Start a workout" sheet, so an empty workout is one tap deeper: open the
    /// sheet, then choose "Start empty workout".
    func startEmptyWorkout(in app: XCUIApplication) {
        let card = app.buttons["start-free-workout"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let empty = app.buttons["start-empty-workout"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
    }

    func launchFixture(
        _ fixture: String,
        additionalArguments: [String] = [],
        expectsActiveWorkout: Bool = true,
        expectsMobilitySession: Bool = false,
        expectedHomeControl: String = "start-free-workout"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data", "-ui-test-fixture", fixture]
            + featureFlagArguments(unlessOverriddenBy: additionalArguments)
            + additionalArguments
        app.launchWithGymTrackerUITestArguments()
        XCTAssertEqual(app.state, .runningForeground)

        let preparing = app.descendants(matching: .any)["app-preparing"]
        XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
        if expectsMobilitySession {
            XCTAssertTrue(app.buttons["complete-mobility-movement"].waitForExistence(timeout: 30))
        } else if expectsActiveWorkout {
            let title = app.staticTexts["active-workout-title"]
            if !title.waitForExistence(timeout: 30) {
                // The fixture graph is durable even if a full-screen-cover
                // presentation is dropped during cold-launch hand-off.
                let resume = app.buttons["resume-active-workout"]
                XCTAssertTrue(resume.waitForExistence(timeout: 5))
                resume.tap()
                XCTAssertTrue(title.waitForExistence(timeout: 10))
            }
        } else {
            XCTAssertTrue(app.descendants(matching: .any)[expectedHomeControl].waitForExistence(timeout: 15))
        }
        return app
    }

    func relaunchPreservingData(
        _ app: XCUIApplication,
        launchArguments: [String] = ["-ui-testing"]
    ) {
        app.terminate()
        app.launchArguments = launchArguments
        app.launchWithGymTrackerUITestArguments()
        XCTAssertEqual(app.state, .runningForeground)

        let preparing = app.descendants(matching: .any)["app-preparing"]
        XCTAssertTrue(preparing.waitForNonExistence(timeout: 30))
    }

    func resumeActiveWorkout(in app: XCUIApplication) {
        let resumeButton = app.buttons["resume-active-workout"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 15))
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: resumeButton
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 10), .completed)
        resumeButton.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
    }

    func selectPlanTemplate(
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

        // This is a `.pickerStyle(.navigationLink)` picker in a Form: selecting
        // a row automatically pops back to the plan form, the same way a
        // Settings-style picker does. Tapping the nav bar's first button here
        // (as this helper used to) lands on the *form's* Cancel button instead
        // and dismisses the whole sheet.
        let nameField = app.textFields["plan-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    }

    func activeExerciseCard(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func addExercise(_ name: String, in app: XCUIApplication) {
        let emptyStateAction = app.buttons["add-active-exercise"]
        if emptyStateAction.waitForExistence(timeout: 2) {
            emptyStateAction.tap()
        } else {
            tapButton("active-workout-menu", in: app)
            tapButton("add-active-exercise-menu", in: app)
        }

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

    /// Stage presents one exercise or grouped unit per page. Move forward until
    /// the requested exercise page is visible instead of scrolling a removed
    /// all-exercises list.
    func navigateToActiveExercise(_ name: String, in app: XCUIApplication) {
        let exercise = app.descendants(matching: .any)["active-exercise-\(name)"]
        if !exercise.exists {
            let stageDot = app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
                    "stage-dot-",
                    name
                )
            ).firstMatch
            XCTAssertTrue(stageDot.waitForExistence(timeout: 5))
            stageDot.tap()
        }
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
    }

    /// Finish is a terminal Stage page, not a toolbar action repeated on every
    /// exercise page.
    func navigateToWorkoutFinish(in app: XCUIApplication) {
        let finish = app.buttons["finish-workout"]
        if !finish.exists {
            let finishDot = app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label == %@",
                    "stage-dot-",
                    "Finish and review"
                )
            ).firstMatch
            XCTAssertTrue(finishDot.waitForExistence(timeout: 5))
            finishDot.tap()
        }
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
    }

    /// Set values are buttons that select themselves, and the panel's keypad is
    /// what writes them. Selecting a value starts a fresh entry, so typing
    /// replaces whatever was there without a delete key.
    func enterValue(
        _ value: String,
        field: String,
        for exercise: String,
        set: Int,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = app.buttons["\(field)-field-\(exercise)-\(set)"]
        XCTAssertTrue(
            target.waitForExistence(timeout: 5),
            "Expected \(field) value for \(exercise) set \(set)",
            file: file,
            line: line
        )
        target.tap()

        for character in value {
            let key = character == "." || character == ","
                ? "keypad-key-decimal"
                : "keypad-key-\(character)"
            tapButton(key, in: app, file: file, line: line)
        }
    }

    func enterValidValues(
        for exercise: String,
        set: Int,
        repsValue: String = "8",
        in app: XCUIApplication
    ) {
        enterValue(repsValue, field: "reps", for: exercise, set: set, in: app)
        enterValue("50", field: "weight", for: exercise, set: set, in: app)
        dismissKeypadIfPresent(in: app)
    }

    func enterReps(_ value: String, for exercise: String, set: Int, in app: XCUIApplication) {
        enterValue(value, field: "reps", for: exercise, set: set, in: app)
        dismissKeypadIfPresent(in: app)
    }

    func dismissKeypadIfPresent(in app: XCUIApplication) {
        let dismiss = app.buttons["panel-dismiss"]
        if dismiss.waitForExistence(timeout: 2) {
            dismiss.tap()
        }
    }

    /// The displayed value of a set field. Reads the button's accessibility
    /// value, which is `nil`-safe for an untouched input announced as "—".
    func setValue(
        _ field: String,
        for exercise: String,
        set: Int,
        in app: XCUIApplication
    ) -> String? {
        app.buttons["\(field)-field-\(exercise)-\(set)"].value as? String
    }

    func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
        // The target may sit above the current offset (or above a previous
        // scroll position), so sweep back up before failing. Only when the
        // element already exists: a blind downward swipe on a sheet drags it
        // toward interactive dismissal instead of scrolling.
        if !element.isHittable && element.exists {
            for _ in 0..<8 where !element.isHittable {
                app.swipeDown()
            }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

}
