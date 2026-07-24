import Foundation

/// One serving choice offered to the generator for a given food, mirroring
/// `FoodLibraryService.portions(for:)` so generated quantities line up with
/// what the editor's Stepper already understands.
struct RecipeGenerationServingOption: Sendable, Hashable {
    let servingID: UUID?
    let name: String
    let amount: Double
    let unit: NutritionServingUnit
    let equivalentReferenceAmount: Double
}

/// A compact, immutable snapshot of one non-archived food the generator is
/// allowed to reference. Built away from SwiftData so generation never holds
/// a live `ModelContext`.
struct RecipeGenerationFoodOption: Sendable, Hashable {
    let foodID: UUID
    let name: String
    let frenchName: String?
    let aliases: [String]
    let preparationState: FoodPreparationState
    let servings: [RecipeGenerationServingOption]
    let calories: Double?
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
}

/// Immutable input to a generation request: the user's recipe name, an
/// optional single photo, and the food catalogue the draft must be built
/// from. Nothing here is persisted.
struct RecipeGenerationInput: Sendable {
    let name: String?
    let imageData: Data?
    let availableFoods: [RecipeGenerationFoodOption]

    var isEmpty: Bool { name == nil && imageData == nil }
}

/// One ingredient line in a generated draft, referencing only identifiers
/// supplied in `RecipeGenerationInput.availableFoods`.
struct GeneratedRecipeIngredient: Sendable, Hashable {
    let foodID: UUID
    let servingID: UUID?
    let quantity: Double
}

/// The raw, unvalidated structured result from a `RecipeDraftGenerator`.
/// `RecipeDraftValidator` turns this into something safe to show.
struct GeneratedRecipeDraft: Sendable {
    var name: String?
    var preparationState: FoodPreparationState?
    var finalCookedWeightGrams: Double?
    var ingredients: [GeneratedRecipeIngredient]
    /// Ingredient names the model wanted to include but that were not present
    /// in the supplied catalogue.
    var unmatchedIngredientHints: [String]
}
