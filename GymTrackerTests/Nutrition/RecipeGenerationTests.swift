import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class RecipeGenerationTests: XCTestCase {

    // MARK: - Input shape reaches the generator unchanged

    func testNameOnlyInputReachesGenerator() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .success(GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])))
        let input = RecipeGenerationInput(name: "Chicken burrito bowl", imageData: nil, availableFoods: [])
        _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
        XCTAssertEqual(fake.receivedInput?.name, "Chicken burrito bowl")
        XCTAssertNil(fake.receivedInput?.imageData)
    }

    func testImageOnlyInputReachesGenerator() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .success(GeneratedRecipeDraft(name: "Detected recipe", preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])))
        let imageData = Data([0x01, 0x02, 0x03])
        let input = RecipeGenerationInput(name: nil, imageData: imageData, availableFoods: [])
        _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
        XCTAssertNil(fake.receivedInput?.name)
        XCTAssertEqual(fake.receivedInput?.imageData, imageData)
    }

    func testNameAndImageInputReachesGenerator() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .success(GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])))
        let imageData = Data([0x0A])
        let input = RecipeGenerationInput(name: "High-protein breakfast", imageData: imageData, availableFoods: [])
        _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
        XCTAssertEqual(fake.receivedInput?.name, "High-protein breakfast")
        XCTAssertEqual(fake.receivedInput?.imageData, imageData)
    }

    // MARK: - Validator ingredient matching rules

    func testValidatorRejectsUnknownFoodIdentifier() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Chicken")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: "Bowl", preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: UUID(), servingID: nil, quantity: 1)], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertTrue(validated.items.isEmpty)
        XCTAssertTrue(validated.hasUnmatchedIngredients)
    }

    func testValidatorRejectsArchivedFood() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Chicken", isArchived: true)
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 1)], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertTrue(validated.items.isEmpty)
        XCTAssertTrue(validated.hasUnmatchedIngredients)
    }

    func testValidatorRejectsUnknownServingIdentifier() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice")
        food.servings = [FoodServing(name: "1 cup", amount: 1, unit: .serving, equivalentReferenceAmount: 150)]
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: food.id, servingID: UUID(), quantity: 1)], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertTrue(validated.items.isEmpty)
        XCTAssertTrue(validated.hasUnmatchedIngredients)
    }

    func testValidatorAcceptsNilServingIdentifierAsDefaultPortion() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 1)], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertEqual(validated.items.count, 1)
        XCTAssertFalse(validated.hasUnmatchedIngredients)
    }

    func testValidatorRemovesDuplicateFoodSelections() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Beans")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(
            name: nil,
            preparationState: nil,
            finalCookedWeightGrams: nil,
            ingredients: [
                GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 1),
                GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 2),
            ],
            unmatchedIngredientHints: []
        )
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertEqual(validated.items.count, 1)
        XCTAssertEqual(validated.items.first?.quantity, 1)
    }

    func testValidatorRejectsNonPositiveQuantity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Salsa")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 0)], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertTrue(validated.items.isEmpty)
        XCTAssertTrue(validated.hasUnmatchedIngredients)
    }

    func testValidatorClampsQuantityToSupportedRange() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let low = FoodItem(name: "Low")
        let high = FoodItem(name: "High")
        context.insert(low)
        context.insert(high)
        try context.save()

        let draft = GeneratedRecipeDraft(
            name: nil,
            preparationState: nil,
            finalCookedWeightGrams: nil,
            ingredients: [
                GeneratedRecipeIngredient(foodID: low.id, servingID: nil, quantity: 0.1),
                GeneratedRecipeIngredient(foodID: high.id, servingID: nil, quantity: 100),
            ],
            unmatchedIngredientHints: []
        )
        let validated = RecipeDraftValidator.validate(draft, against: [low, high])
        let quantities = Dictionary(uniqueKeysWithValues: validated.items.map { ($0.food.id, $0.quantity) })
        XCTAssertEqual(quantities[low.id], RecipeDraftValidator.quantityRange.lowerBound)
        XCTAssertEqual(quantities[high.id], RecipeDraftValidator.quantityRange.upperBound)
    }

    func testValidatorReportsPartialMatchWhenGeneratorFlagsUnmatchedHints() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Eggs")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: food.id, servingID: nil, quantity: 1)], unmatchedIngredientHints: ["Toast"])
        let validated = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertEqual(validated.items.count, 1)
        XCTAssertTrue(validated.hasUnmatchedIngredients)
    }

    func testEmptyDraftProducesEmptyValidatedResult() throws {
        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])
        let validated = RecipeDraftValidator.validate(draft, against: [])
        XCTAssertTrue(validated.isEmpty)
        XCTAssertFalse(validated.hasUnmatchedIngredients)
    }

    func testValidatorNeverCreatesAFoodItem() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Oats")
        context.insert(food)
        try context.save()

        let draft = GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: UUID(), servingID: nil, quantity: 1)], unmatchedIngredientHints: [])
        _ = RecipeDraftValidator.validate(draft, against: [food])
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItem>()).count, 1)
    }

    // MARK: - Generator error propagation

    func testModelUnavailableErrorPropagates() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .failure(.modelUnavailable))
        let input = RecipeGenerationInput(name: "Bowl", imageData: nil, availableFoods: [])
        do {
            _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
            XCTFail("Expected modelUnavailable to propagate")
        } catch let error as RecipeDraftGeneratorError {
            XCTAssertEqual(error, .modelUnavailable)
        }
    }

    func testImageUnsupportedErrorPropagates() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .failure(.imageUnsupported))
        let input = RecipeGenerationInput(name: nil, imageData: Data([0x01]), availableFoods: [])
        do {
            _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
            XCTFail("Expected imageUnsupported to propagate")
        } catch let error as RecipeDraftGeneratorError {
            XCTAssertEqual(error, .imageUnsupported)
        }
    }

    func testCancellationPropagatesFromGenerator() async throws {
        let fake = FakeRecipeDraftGenerator(behavior: .hang)
        let input = RecipeGenerationInput(name: "Bowl", imageData: nil, availableFoods: [])
        let task = Task {
            try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // expected
        }
    }

    // MARK: - Availability mapping (pure, no live SystemLanguageModel)

    func testAvailabilityMapsUnsupportedLocale() {
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .available, supportsLocale: false), .unsupportedLocale)
    }

    func testAvailabilityMapsFullyAvailable() {
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .available, supportsLocale: true), .fullyAvailable)
    }

    func testAvailabilityMapsModelDownloading() {
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .unavailable(.modelNotReady), supportsLocale: true), .modelDownloading)
    }

    func testAvailabilityMapsUnsupportedDevice() {
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .unavailable(.deviceNotEligible), supportsLocale: true), .unsupportedDevice)
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .unavailable(.appleIntelligenceNotEnabled), supportsLocale: true), .unsupportedDevice)
    }

    func testAvailabilityCapsFullyAvailableWhenImageInputUnsupported() {
        XCTAssertEqual(RecipeGenerationAvailability.capped(.fullyAvailable, imageInputSupported: false), .textOnly)
        XCTAssertEqual(RecipeGenerationAvailability.capped(.fullyAvailable, imageInputSupported: true), .fullyAvailable)
        XCTAssertEqual(RecipeGenerationAvailability.capped(.unsupportedLocale, imageInputSupported: false), .unsupportedLocale)
    }

    // MARK: - Catalogue

    func testCatalogueExcludesArchivedFoods() {
        let visible = FoodItem(name: "Visible")
        let archived = FoodItem(name: "Archived", isArchived: true)
        let catalogue = RecipeGenerationCatalogue.build(from: [visible, archived])
        XCTAssertEqual(catalogue.map(\.name), ["Visible"])
    }
}
