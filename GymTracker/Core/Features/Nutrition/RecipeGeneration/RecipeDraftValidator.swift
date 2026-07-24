import Foundation

/// Result of validating a `GeneratedRecipeDraft` against the food library
/// that is actually current right now. Only entries that resolve to a real,
/// non-archived `FoodItem` and a real serving survive. Nutrition values are
/// never copied onto the item itself, so an unknown macro on the underlying
/// `FoodItem` simply stays unknown when totals are later computed.
@MainActor
struct ValidatedRecipeDraft {
    var name: String?
    var preparationState: FoodPreparationState?
    var finalCookedWeightGrams: Double?
    var items: [(food: FoodItem, servingID: UUID?, quantity: Double)]
    /// True when the model proposed at least one ingredient that didn't
    /// survive validation (unknown/archived food, unknown serving, or a
    /// catalogue miss the generator itself reported).
    var hasUnmatchedIngredients: Bool

    var isEmpty: Bool { items.isEmpty }
}

/// Enforces the recipe-generation prototype's ingredient-matching rules: the
/// model may only reference identifiers it was given, it can never invent a
/// new `FoodItem`, and every surviving quantity fits the editor's existing
/// Stepper range in quarter-serving steps.
@MainActor
enum RecipeDraftValidator {
    static let quantityRange: ClosedRange<Double> = 0.25...20
    private static let quantityStep = 0.25

    static func validate(_ draft: GeneratedRecipeDraft, against foods: [FoodItem]) -> ValidatedRecipeDraft {
        let currentFoods = Dictionary(uniqueKeysWithValues: foods.filter { !$0.isArchived }.map { ($0.id, $0) })
        var seenFoodIDs = Set<UUID>()
        var items: [(food: FoodItem, servingID: UUID?, quantity: Double)] = []
        var hasUnmatched = !draft.unmatchedIngredientHints.isEmpty

        for ingredient in draft.ingredients {
            guard let food = currentFoods[ingredient.foodID] else { hasUnmatched = true; continue }
            guard seenFoodIDs.insert(food.id).inserted else { continue }
            let portionIDs = Set(FoodLibraryService.portions(for: food).map(\.id))
            guard ingredient.servingID == nil || portionIDs.contains(ingredient.servingID) else {
                hasUnmatched = true
                continue
            }
            guard ingredient.quantity > 0 else { hasUnmatched = true; continue }
            items.append((food, ingredient.servingID, clampToStep(ingredient.quantity)))
        }

        return ValidatedRecipeDraft(
            name: draft.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            preparationState: draft.preparationState,
            finalCookedWeightGrams: draft.finalCookedWeightGrams.flatMap { $0 > 0 ? $0 : nil },
            items: items,
            hasUnmatchedIngredients: hasUnmatched
        )
    }

    private static func clampToStep(_ quantity: Double) -> Double {
        let stepped = (quantity / quantityStep).rounded() * quantityStep
        return min(max(stepped, quantityRange.lowerBound), quantityRange.upperBound)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
