import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class RecipeGenerationTests: XCTestCase {

    // MARK: - Input shape reaches the generator unchanged

    /// Covers name-only, image-only, and name+image inputs. All three cases
    /// assert the same postcondition (the coordinator forwards the input
    /// untouched to the generator), so they are table-driven rather than
    /// three near-identical methods.
    func testInputShapeReachesGeneratorUnchanged() async throws {
        struct Case {
            let label: String
            let name: String?
            let imageData: Data?
        }
        let cases: [Case] = [
            Case(label: "name only", name: "Chicken burrito bowl", imageData: nil),
            Case(label: "image only", name: nil, imageData: Data([0x01, 0x02, 0x03])),
            Case(label: "name and image", name: "High-protein breakfast", imageData: Data([0x0A]))
        ]
        for testCase in cases {
            let fake = FakeRecipeDraftGenerator(behavior: .success(GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])))
            let input = RecipeGenerationInput(name: testCase.name, imageData: testCase.imageData, availableFoods: [])
            _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
            XCTAssertEqual(fake.receivedInput?.name, testCase.name, testCase.label)
            XCTAssertEqual(fake.receivedInput?.imageData, testCase.imageData, testCase.label)
        }
    }

    // MARK: - Validator ingredient matching rules

    /// Four distinct invalid-ingredient shapes (unknown food id, archived
    /// food, unknown serving id, non-positive quantity) all resolve to the
    /// same postcondition: nothing validates and the draft is reported as
    /// having unmatched ingredients. Table-driven to avoid repeating that
    /// assertion pair four times.
    func testValidatorRejectsInvalidIngredientsAndReportsUnmatched() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let unknownIDFood = FoodItem(name: "Chicken")
        let archivedFood = FoodItem(name: "Archived Chicken", isArchived: true)
        let riceWithServing = FoodItem(name: "Rice")
        riceWithServing.servings = [FoodServing(name: "1 cup", amount: 1, unit: .serving, equivalentReferenceAmount: 150)]
        let salsa = FoodItem(name: "Salsa")
        context.insert(unknownIDFood)
        context.insert(archivedFood)
        context.insert(riceWithServing)
        context.insert(salsa)
        try context.save()

        struct Case {
            let label: String
            let draft: GeneratedRecipeDraft
            let against: [FoodItem]
        }
        let cases: [Case] = [
            Case(
                label: "unknown food identifier",
                draft: GeneratedRecipeDraft(name: "Bowl", preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: UUID(), servingID: nil, quantity: 1)], unmatchedIngredientHints: []),
                against: [unknownIDFood]
            ),
            Case(
                label: "archived food",
                draft: GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: archivedFood.id, servingID: nil, quantity: 1)], unmatchedIngredientHints: []),
                against: [archivedFood]
            ),
            Case(
                label: "unknown serving identifier",
                draft: GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: riceWithServing.id, servingID: UUID(), quantity: 1)], unmatchedIngredientHints: []),
                against: [riceWithServing]
            ),
            Case(
                label: "non-positive quantity",
                draft: GeneratedRecipeDraft(name: nil, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [GeneratedRecipeIngredient(foodID: salsa.id, servingID: nil, quantity: 0)], unmatchedIngredientHints: []),
                against: [salsa]
            )
        ]
        for testCase in cases {
            let validated = RecipeDraftValidator.validate(testCase.draft, against: testCase.against)
            XCTAssertTrue(validated.items.isEmpty, testCase.label)
            XCTAssertTrue(validated.hasUnmatchedIngredients, testCase.label)
        }
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

    /// `.modelUnavailable` and `.imageUnsupported` both exercise the same
    /// direct-throw path through the coordinator; cancellation is a distinct
    /// concern (task cancellation racing the generator) and keeps its own test.
    func testGeneratorErrorsPropagateDirectly() async throws {
        let cases: [RecipeDraftGeneratorError] = [.modelUnavailable, .imageUnsupported]
        for expected in cases {
            let fake = FakeRecipeDraftGenerator(behavior: .failure(expected))
            let input = RecipeGenerationInput(name: "Bowl", imageData: expected == .imageUnsupported ? Data([0x01]) : nil, availableFoods: [])
            do {
                _ = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: [], using: fake)
                XCTFail("Expected \(expected) to propagate")
            } catch let error as RecipeDraftGeneratorError {
                XCTAssertEqual(error, expected)
            }
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

    /// Every case here is a one-line, stateless mapping check; merged into a
    /// single method rather than four near-identical ones.
    func testAvailabilityMapsPlainStates() {
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .available, supportsLocale: false), .unsupportedLocale)
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .available, supportsLocale: true), .fullyAvailable)
        XCTAssertEqual(RecipeGenerationAvailability.map(availability: .unavailable(.modelNotReady), supportsLocale: true), .modelDownloading)
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
