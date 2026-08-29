import XCTest

final class LinkedMobilityAccessibilityUITests: GymTrackerUITestCase {
    func testLinkedWarmupRemainsActionableInFrenchAtAccessibilitySize() {
        let app = launchFixture(
            "linked-mobility-workout",
            additionalArguments: [
                "-AppleLanguages", "(fr)",
                "-AppleLocale", "fr_CA",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
            ],
            expectsActiveWorkout: false
        )

        let savedWorkouts = app.buttons["today-open-saved-workouts"]
        scrollToElement(savedWorkouts, in: app)
        savedWorkouts.tap()

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
        tapButton("start-linked-warmup", in: app)

        let stage = app.descendants(matching: .any)["active-workout-mobility-stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ÉCHAUFFEMENT"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["minimize-workout"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["linked-mobility-menu"].exists)

        let completeMovement = app.buttons["complete-mobility-movement"].firstMatch
        let completePhase = app.buttons["complete-mobility-phase"].firstMatch
        let primaryAction = completeMovement.exists ? completeMovement : completePhase
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isHittable)
        XCTAssertTrue(primaryAction.label.localizedCaseInsensitiveContains("termin"))

        let partialMovement = app.buttons["save-partial-mobility-movement"].firstMatch
        let partialPhase = app.buttons["save-partial-mobility-phase"].firstMatch
        XCTAssertTrue(partialMovement.exists || partialPhase.exists)
        XCTAssertFalse(app.descendants(matching: .any)["standalone-mobility-stage"].exists)
    }
}
