import XCTest

/// Covers the beta UX-hardening flows: the searchable food picker, concrete
/// ingredient amounts, recipe detail + Add to today, and locale-tolerant
/// decimal entry.
final class RecipeAndDecimalUITests: GymTrackerUITestCase {

    private func openNewRecipeEditor(_ app: XCUIApplication) {
        selectTab(.nutrition, in: app)
        tapButton("open-meal-templates", in: app)
        tapButton("create-meal-template", in: app)
    }

    func testFoodPickerAddsMultipleFoodsInOneVisit() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditor(app)

        tapButton("recipe-add-foods", in: app)
        XCTAssertTrue(app.navigationBars["Add foods"].waitForExistence(timeout: 5))

        // Selecting foods does not dismiss the sheet; several can be chosen.
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-picker-row-'"))
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()

        let done = app.buttons["food-picker-done"]
        XCTAssertTrue(done.isEnabled)
        done.tap()

        // Both foods now appear as concrete-amount ingredient rows in the recipe.
        let ingredientRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recipe-ingredient-'"))
        XCTAssertTrue(ingredientRows.element(boundBy: 1).waitForExistence(timeout: 5))
    }

    func testEditingIngredientAmountAcceptsDecimal() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditor(app)
        tapButton("recipe-add-foods", in: app)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'food-picker-row-'"))
        XCTAssertTrue(rows.element(boundBy: 0).waitForExistence(timeout: 5))
        rows.element(boundBy: 0).tap()
        app.buttons["food-picker-done"].tap()

        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recipe-ingredient-'")).firstMatch.tap()
        let amount = app.textFields["ingredient-editor-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        // Clearing then typing a leading-dot value must survive (the decimal bug).
        amount.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        amount.typeText(".5")
        XCTAssertTrue(app.buttons["ingredient-editor-done"].isEnabled)
        app.buttons["ingredient-editor-done"].tap()
    }

    func testRecipeDetailLogsToTodayWithoutOpeningEditor() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        selectTab(.nutrition, in: app)
        tapButton("open-meal-templates", in: app)

        let firstRecipe = app.cells.firstMatch
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 5))
        firstRecipe.tap()

        let addToToday = app.buttons["recipe-add-to-today"]
        XCTAssertTrue(addToToday.waitForExistence(timeout: 5))
        addToToday.tap()

        XCTAssertTrue(app.navigationBars["Add to today"].waitForExistence(timeout: 5))
        tapButton("confirm-log-recipe", in: app)

        // Returns to the recipe detail; the editor was never opened.
        XCTAssertTrue(addToToday.waitForExistence(timeout: 5))
    }
}
