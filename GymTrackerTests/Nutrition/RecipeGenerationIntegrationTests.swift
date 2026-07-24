import XCTest
import SwiftData
@testable import GymTracker

/// Exercises the recipe-generation pipeline against a real in-memory
/// SwiftData store, mirroring how `MealTemplateEditorView` uses
/// `RecipeGenerationCoordinator` output to save or revise a recipe.
/// Generation itself still uses a fake generator (see
/// `FakeRecipeDraftGenerator`) — only the persistence side is real here.
@MainActor
final class RecipeGenerationIntegrationTests: XCTestCase {

    func testGeneratedDraftSavesAsNormalRecipe() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let chicken = FoodItem(name: "Chicken", calories: 165, proteinGrams: 31, carbohydrateGrams: 0, fatGrams: 3.6)
        chicken.servings = [FoodServing(name: "150 g", amount: 150, unit: .grams, equivalentReferenceAmount: 150)]
        context.insert(chicken)
        try context.save()

        let draft = GeneratedRecipeDraft(
            name: "Chicken bowl",
            preparationState: .cooked,
            finalCookedWeightGrams: 450,
            ingredients: [GeneratedRecipeIngredient(foodID: chicken.id, servingID: chicken.servings.first?.id, quantity: 2)],
            unmatchedIngredientHints: []
        )
        let fake = FakeRecipeDraftGenerator(behavior: .success(draft))
        let input = RecipeGenerationInput(name: nil, imageData: nil, availableFoods: RecipeGenerationCatalogue.build(from: [chicken]))
        let validated = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [chicken], using: fake)
        XCTAssertFalse(validated.isEmpty)

        // Mirrors MealTemplateEditorView.save() for a brand-new recipe.
        let template = MealTemplate(name: try XCTUnwrap(validated.name), preparationState: try XCTUnwrap(validated.preparationState), finalCookedWeightGrams: validated.finalCookedWeightGrams)
        template.items = validated.items.enumerated().map { MealTemplateItem(food: $0.element.food, orderIndex: $0.offset, servingID: $0.element.servingID, quantity: $0.element.quantity) }
        context.insert(template)
        try context.save()

        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<MealTemplate>()).first)
        XCTAssertEqual(saved.name, "Chicken bowl")
        XCTAssertEqual(saved.preparationState, .cooked)
        XCTAssertEqual(saved.finalCookedWeightGrams, 450)
        XCTAssertEqual(saved.items.count, 1)
        XCTAssertEqual(saved.items.first?.quantity, 2)
    }

    func testRevisingFromAGeneratedDraftKeepsLoggedHistoryStable() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let chicken = FoodItem(name: "Chicken", calories: 165, proteinGrams: 31, carbohydrateGrams: 0, fatGrams: 3.6)
        chicken.servings = [FoodServing(name: "150 g", amount: 150, unit: .grams, equivalentReferenceAmount: 150)]
        context.insert(chicken)
        let original = MealTemplate(name: "Chicken bowl")
        original.items = [MealTemplateItem(food: chicken, orderIndex: 0, servingID: chicken.servings.first?.id, quantity: 1)]
        context.insert(original)
        try context.save()

        let logged = try XCTUnwrap(NutritionLoggingService.log(template: original, using: context))
        let originalProtein = try XCTUnwrap(logged.items.first?.proteinGramsSnapshot)

        let draft = GeneratedRecipeDraft(
            name: "Chicken bowl",
            preparationState: .cooked,
            finalCookedWeightGrams: 450,
            ingredients: [GeneratedRecipeIngredient(foodID: chicken.id, servingID: chicken.servings.first?.id, quantity: 3)],
            unmatchedIngredientHints: []
        )
        let fake = FakeRecipeDraftGenerator(behavior: .success(draft))
        let input = RecipeGenerationInput(name: "Chicken bowl", imageData: nil, availableFoods: RecipeGenerationCatalogue.build(from: [chicken]))
        let validated = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [chicken], using: fake)

        let revision = try XCTUnwrap(MealTemplateService.revise(
            original,
            name: try XCTUnwrap(validated.name),
            preparationState: try XCTUnwrap(validated.preparationState),
            finalCookedWeightGrams: validated.finalCookedWeightGrams,
            photoIdentifier: nil,
            items: validated.items.map { ($0.food, $0.servingID, $0.quantity) },
            using: context
        ))

        XCTAssertFalse(original.isCurrent)
        XCTAssertTrue(original.isArchived)
        XCTAssertEqual(revision.version, 2)
        XCTAssertEqual(revision.items.first?.quantity, 3)
        // The already-logged meal keeps its original immutable snapshot.
        XCTAssertEqual(try XCTUnwrap(logged.items.first?.proteinGramsSnapshot), originalProtein, accuracy: 0.001)
    }

    func testGenerationNeverPersistsAnythingUntilSaveIsCalled() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let chicken = FoodItem(name: "Chicken")
        context.insert(chicken)
        try context.save()

        let draft = GeneratedRecipeDraft(name: "Chicken bowl", preparationState: .cooked, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: chicken.id, servingID: nil, quantity: 1)], unmatchedIngredientHints: [])
        let fake = FakeRecipeDraftGenerator(behavior: .success(draft))
        let input = RecipeGenerationInput(name: "Chicken bowl", imageData: nil, availableFoods: RecipeGenerationCatalogue.build(from: [chicken]))
        _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [chicken], using: fake)

        XCTAssertTrue(try context.fetch(FetchDescriptor<MealTemplate>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItem>()).count, 1)
    }

    func testGenerationFailurePreservesFoodLibraryAndCreatesNoRecipe() async throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let chicken = FoodItem(name: "Chicken")
        context.insert(chicken)
        try context.save()

        let fake = FakeRecipeDraftGenerator(behavior: .failure(.generationFailed))
        let input = RecipeGenerationInput(name: "Chicken bowl", imageData: nil, availableFoods: RecipeGenerationCatalogue.build(from: [chicken]))
        do {
            _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [chicken], using: fake)
            XCTFail("Expected generation failure to propagate")
        } catch {
            // expected
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<MealTemplate>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItem>()).count, 1)
    }
}
