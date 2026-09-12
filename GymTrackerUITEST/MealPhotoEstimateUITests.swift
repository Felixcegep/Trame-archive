import XCTest

/// Covers BYOK photo estimates. Live Gemini is never used; `-ui-test-meal-photo-estimate-result`
/// supplies a scripted draft the same way recipe generation uses a scripted generator.
final class MealPhotoEstimateUITests: GymTrackerUITestCase {
    private func openPhotoEstimate(_ app: XCUIApplication) {
        selectTab(.nutrition, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["photo-estimate-screen"].waitForExistence(timeout: 8),
            "Expected the photo estimate sheet after a scripted launch"
        )
    }

    func testScriptedEstimateReviewCanLogAMultiItemMeal() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-meal-photo-estimate-result", "success",
        ])
        openPhotoEstimate(app)
        let add = app.buttons["confirm-photo-estimate"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 5))
        let loggedMeal = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "logged-meal-")
        ).firstMatch
        scrollToElement(loggedMeal, in: app)
        XCTAssertTrue(loggedMeal.waitForExistence(timeout: 5))
    }

    func testUnclearPhotoShowsFailureWithoutLogging() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-meal-photo-estimate-result", "unclear",
        ])
        openPhotoEstimate(app)
        XCTAssertTrue(app.staticTexts["This photo isn’t clear enough to estimate. Try another."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["confirm-photo-estimate"].exists)
    }

    func testEstimateFailureCanRetry() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-meal-photo-estimate-result", "failure",
        ])
        openPhotoEstimate(app)
        XCTAssertTrue(app.staticTexts["Estimate failed. Check the key and try again."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["photo-estimate-retry"].waitForExistence(timeout: 2))
    }
}
