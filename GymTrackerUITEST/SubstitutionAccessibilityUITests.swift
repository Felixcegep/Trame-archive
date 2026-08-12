import XCTest

final class SubstitutionAccessibilityUITests: GymTrackerUITestCase {
    func testDecisionAwareSwapExposesSeparateVerdictsWhySectionsAndTodayDefault() {
        let app = launchFixture(
            "active-draft",
            additionalArguments: ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"]
        )

        tapButton("swap-exercise-Bench Press", in: app)
        XCTAssertTrue(app.buttons["swap-reason-preference"].waitForExistence(timeout: 5))
        tapButton("swap-reason-preference", in: app)

        let option = app.buttons["swap-option-Dumbbell Bench Press"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        let optionLabel = option.label.lowercased()
        XCTAssertTrue(optionLabel.contains("fit") || optionLabel.contains("choix") || optionLabel.contains("adapt"), "Suitability must be exposed in the option label")
        XCTAssertTrue(optionLabel.contains("history") || optionLabel.contains("historique"), "Comparability must be exposed separately in the option label")
        XCTAssertFalse(optionLabel.contains("%"))
        XCTAssertFalse(optionLabel.contains("star"))

        tapButton("swap-why-Dumbbell Bench Press", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["why-section-evidenceUsed"].waitForExistence(timeout: 5))
        for identifier in [
            "why-section-evidenceUsed",
            "why-section-whatDiffers",
            "why-section-effectOnHistory",
            "why-section-effectOnPlan",
            "why-section-confidence",
            "why-section-override"
        ] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].exists, "Missing Why? section \(identifier)")
        }
        tapButton("why-explanation-done", in: app)

        tapButton("swap-option-Dumbbell Bench Press", in: app)
        let today = app.buttons["swap-scope-today"]
        let future = app.buttons["swap-scope-future"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(future.exists)
        XCTAssertTrue(today.isSelected || today.value as? String == "1", "Today-only must be preselected")
        XCTAssertFalse(future.isSelected)

        let confirmation = app.descendants(matching: .any)["substitution-confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        // The root TabView remains present behind the active-workout sheet and
        // contains unrelated mobility copy (including the word “programs”).
        // Scope this vocabulary assertion to the substitution confirmation
        // surface so it verifies the flow's own user-facing copy.
        let allVisibleText = confirmation.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ").lowercased()
        XCTAssertFalse(allVisibleText.contains("program"), "User-facing substitution copy must say plan, never program")
        XCTAssertFalse(allVisibleText.contains("%"), "The swap flow must not present an equivalence percentage")
    }
}
