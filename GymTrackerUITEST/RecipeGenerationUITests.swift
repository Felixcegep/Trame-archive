import XCTest

/// Covers the "Generate recipe" prototype inside the New recipe sheet.
/// Apple Intelligence is rarely available on CI simulators, so these tests
/// force a deterministic availability/result via
/// `-ui-test-recipe-generation-availability` and
/// `-ui-test-recipe-generation-result` rather than depending on the live
/// on-device model (see `RecipeGenerationAvailability` and
/// `ScriptedRecipeDraftGenerator`).
final class RecipeGenerationUITests: GymTrackerUITestCase {

    private func openNewRecipeEditor(_ app: XCUIApplication) {
        selectTab(.nutrition, in: app)
        tapButton("open-meal-templates", in: app)
        tapButton("create-meal-template", in: app)
    }

    func testGenerateDisabledWithoutNameOrPhoto() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
        ])
        openNewRecipeEditor(app)

        let generate = app.buttons["generate-recipe"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        XCTAssertFalse(generate.isEnabled)

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        XCTAssertTrue(generate.isEnabled)
    }

    func testNameOnlyGenerationPopulatesFoodsAndShowsNotice() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "success",
        ])
        openNewRecipeEditor(app)

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        tapButton("generate-recipe", in: app)

        let notice = app.descendants(matching: .any)["recipe-generation-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Generated draft. Check the ingredients and quantities."].exists)
        XCTAssertTrue(app.buttons["save-meal-template"].isEnabled)
    }

    func testPartialMatchShowsReviewNotice() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "partial-match",
        ])
        openNewRecipeEditor(app)

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("High-protein breakfast")
        tapButton("generate-recipe", in: app)

        let notice = app.descendants(matching: .any)["recipe-generation-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Some ingredients could not be matched. Review the draft and add missing foods."].exists)
    }

    func testGenerationFailurePreservesManualInput() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "failure",
        ])
        openNewRecipeEditor(app)

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        tapButton("generate-recipe", in: app)

        let notice = app.descendants(matching: .any)["recipe-generation-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The recipe couldn’t be generated. Try again or add foods manually."].exists)
        XCTAssertEqual(app.textFields["Name"].value as? String, "Chicken burrito bowl")
    }

    func testGenerateAgainConfirmsBeforeReplacingAnEditedDraft() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "textOnly",
            "-ui-test-recipe-generation-result", "success",
        ])
        openNewRecipeEditor(app)

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Chicken burrito bowl")
        tapButton("generate-recipe", in: app)
        let notice = app.descendants(matching: .any)["recipe-generation-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))

        // Editing the generated draft (bumping a quantity via the ingredient
        // editor sheet) means "Generate again" must confirm before discarding
        // the user's edit. The ingredient rows sit below the generation
        // controls, so scroll them into view (a lazy List only materializes
        // on-screen rows).
        let ingredientRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recipe-ingredient-'")).firstMatch
        var attempts = 0
        while ingredientRow.exists == false && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(ingredientRow.waitForExistence(timeout: 5))
        ingredientRow.tap()
        // A Stepper with an accessibility identifier exposes its child controls
        // as "<id>-Increment" / "<id>-Decrement".
        let increment = app.buttons["ingredient-editor-stepper-Increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        increment.tap()
        app.buttons["ingredient-editor-done"].tap()

        let generateAgain = app.buttons["generate-recipe"]
        XCTAssertTrue(generateAgain.waitForExistence(timeout: 5))
        generateAgain.tap()

        XCTAssertTrue(app.staticTexts["Replace the current draft?"].waitForExistence(timeout: 5))
        app.buttons["Keep editing"].tap()
    }

    func testManualRecipeEditorFullyFunctionalWithoutGeneration() {
        let app = launchFreshApp(additionalArguments: [
            "-ui-test-recipe-generation-availability", "unsupportedDevice",
        ])
        openNewRecipeEditor(app)

        // Generation controls are hidden entirely on an unsupported device;
        // the manual editor (name, preparation, Save gating) still works.
        XCTAssertFalse(app.buttons["generate-recipe"].exists)

        let save = app.buttons["save-meal-template"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "Save must stay disabled with no name and no foods")

        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Manual chicken bowl")
        XCTAssertFalse(save.isEnabled, "Save must stay disabled until at least one food is added")
    }
}
