import XCTest
@testable import GymTracker

/// Promoted surfaces exercised by the UI suite even when a narrower release
/// wave intentionally hides them. Keeping this at file scope lets direct
/// `XCUIApplication` launches use the same deterministic matrix as fixtures.
private let completeGymTrackerUITestFeatureFlags = [
    "today", "mobility", "nutrition", "bodyWeight", "dailyCheckIn",
    "programBuilder", "advancedExecution", "betaFeedback",
    "recipeGeneration", "workoutGeneration", "mobilityAssessment",
    "mobilityProgram", "sportSpecializations", "mealPhotoAnalysis"
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
            // A previous screenshot process can still be foregrounded between
            // separately-invoked xcodebuild runs. Terminating explicitly keeps
            // launch services from reactivating it with its old onboarding
            // payload instead of creating the fixture process requested here.
            if state != .notRunning {
                terminate()
            }
            launchEnvironment = [Self.mirroredArgumentsEnvironmentKey: payload]
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
            scrollToElement(history, in: app)
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
    func focusPlansSearch(in app: XCUIApplication) -> XCUIElement {
        let search = app.searchFields["Search plans"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        return search
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

    /// The iOS 26 Simulator alphabetic keyboard does not consistently expose a
    /// queryable Search or Done key. Prefer the form's keyboard toolbar Done,
    /// then submit the field the same way Train search does.
    func dismissTemplateExerciseSearchKeyboard(
        _ search: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let toolbarDone = app.buttons["dismiss-template-search-keyboard"].firstMatch
        if toolbarDone.waitForExistence(timeout: 2) {
            toolbarDone.tap()
        } else {
            search.typeText("\n")
        }

        if app.keyboards.firstMatch.waitForNonExistence(timeout: 2) {
            return
        }

        let keyboardSearch = app.keyboards.buttons["Search"].firstMatch
        let keyboardReturn = app.keyboards.buttons["Return"].firstMatch
        if keyboardSearch.exists {
            keyboardSearch.tap()
        } else if keyboardReturn.exists {
            keyboardReturn.tap()
        }

        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
            "Expected the New Workout search keyboard to dismiss",
            file: file,
            line: line
        )
    }

    /// The workout menu and its destructive confirmation can briefly expose the
    /// same accessibility identifier. Query the sheet the dialog presents.
    func XCTAssertDiscardConfirmationVisible(
        in app: XCUIApplication,
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let confirm = app.sheets.buttons["confirm-discard-workout"].firstMatch
        XCTAssertTrue(
            confirm.waitForExistence(timeout: timeout),
            "Expected discard confirmation sheet",
            file: file,
            line: line
        )
    }

    func dismissDiscardConfirmation(in app: XCUIApplication) {
        let cancelByID = app.descendants(matching: .any)["cancel-discard-workout"].firstMatch
        if cancelByID.waitForExistence(timeout: 2) {
            cancelByID.tap()
            return
        }
        let cancelByLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Cancel'"))
            .firstMatch
        if cancelByLabel.waitForExistence(timeout: 2) {
            cancelByLabel.tap()
        }
    }

    func selectExerciseFromOpenPicker(_ name: String, in app: XCUIApplication) {
        let search = exerciseLibrarySearchField(in: app)
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

    /// Starts a blank session from Home. The free-state primary command is
    /// intentionally direct; saved-workout selection has its own Today route.
    func startEmptyWorkout(in app: XCUIApplication) {
        let card = app.buttons["start-free-workout"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["active-workout-title"].waitForExistence(timeout: 5))
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
        let onboarding = app.descendants(matching: .any)["onboarding"]
        if onboarding.exists {
            // Simulator launch services can reactivate the previous app
            // process with its stale welcome payload. Relaunching the same
            // fixture once mirrors `launchFreshApp` and keeps ordinary fixture
            // tests deterministic without ever tapping through onboarding.
            app.terminate()
            app.launchWithGymTrackerUITestArguments()
            XCTAssertTrue(
                app.descendants(matching: .any)["app-preparing"]
                    .waitForNonExistence(timeout: 30)
            )
        }
        XCTAssertTrue(
            onboarding.waitForNonExistence(timeout: 5),
            "Ordinary fixture launches must not be covered by onboarding."
        )
        if expectsMobilitySession {
            XCTAssertTrue(app.buttons["complete-mobility-movement"].waitForExistence(timeout: 30))
        } else if expectsActiveWorkout {
            let title = app.staticTexts["active-workout-title"]
            if !title.waitForExistence(timeout: 30) {
                // The fixture graph is durable even if a full-screen-cover
                // presentation is dropped during cold-launch hand-off.
                let resume = app.buttons["resume-active-workout"]
                XCTAssertTrue(resume.waitForExistence(timeout: 5))
                resumeActiveWorkout(in: app)
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

    /// The exercise picker prompt is a full search hint, not the older
    /// "Search exercises" label still used on template/plan forms.
    func exerciseLibrarySearchField(in app: XCUIApplication) -> XCUIElement {
        app.searchFields["Search by exercise, muscle, or equipment"]
    }

    func addExercise(_ name: String, in app: XCUIApplication) {
        let emptyStateAction = app.buttons["add-active-exercise"]
        if emptyStateAction.waitForExistence(timeout: 2) {
            emptyStateAction.tap()
        } else {
            tapButton("active-workout-menu", in: app)
            tapButton("add-active-exercise-menu", in: app)
        }

        let search = exerciseLibrarySearchField(in: app)
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
        let stageDot = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
                "stage-dot-",
                name
            )
        ).firstMatch
        XCTAssertTrue(stageDot.waitForExistence(timeout: 5))
        if !stageDot.isSelected {
            stageDot.tap()
        }
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: stageDot
        )
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed)
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: exercise
        )
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 5), .completed)
    }

    /// Walks to the terminal review page. `finish-workout` is a header control
    /// available from every page, so the page itself — its summary, or the
    /// empty-session state — is what identifies arrival.
    func navigateToWorkoutFinish(in app: XCUIApplication) {
        let summary = app.descendants(matching: .any)["finish-summary"]
        let emptySession = app.descendants(matching: .any)["empty-workout-state"]

        // The progress rail intentionally contains work stages only. Advance
        // through the command bar—the same accessible path available to the
        // lifter—until the terminal review stage appears.
        for _ in 0..<20 where !summary.exists && !emptySession.exists {
            let next = app.buttons["stage-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            XCTAssertTrue(next.isEnabled)
            next.tap()
        }

        XCTAssertTrue(
            summary.waitForExistence(timeout: 5) || emptySession.exists,
            "Expected the terminal review stage"
        )
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

        if field == "weight" {
            let plateKeypad = app.descendants(matching: .any)["plate-keypad"]
            if plateKeypad.waitForExistence(timeout: 1) {
                let plateDigits = app.buttons["Enter an exact weight"]
                scrollToElement(plateDigits, in: app, file: file, line: line)
                plateDigits.tap()
            } else {
                let assistKeypad = app.descendants(matching: .any)["assist-keypad"]
                if assistKeypad.waitForExistence(timeout: 1) {
                    let assistDigits = app.buttons["Enter an exact amount"]
                    scrollToElement(assistDigits, in: app, file: file, line: line)
                    assistDigits.tap()
                }
            }
        }

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

    /// Scrolls static evidence into the viewport without requiring it to be
    /// hittable. Small lazy-list rows can be skipped by a full `swipeUp()`, and
    /// labels intentionally never become hittable even when plainly visible.
    func scrollToVisibleElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            if element.exists,
               !element.frame.isEmpty,
               app.frame.intersects(element.frame) {
                break
            }
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(
                    forDuration: 0.05,
                    thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
                )
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(element.frame.isEmpty, file: file, line: line)
        XCTAssertTrue(app.frame.intersects(element.frame), file: file, line: line)
    }

}
