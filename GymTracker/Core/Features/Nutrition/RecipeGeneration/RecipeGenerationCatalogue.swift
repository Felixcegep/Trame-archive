import Foundation

/// Builds the immutable food catalogue a `RecipeDraftGenerator` is allowed to
/// reference. Runs on the main actor because `FoodItem`/`FoodServing` are
/// live SwiftData models; the output is a plain `Sendable` snapshot so
/// generation itself never touches a `ModelContext`.
@MainActor
enum RecipeGenerationCatalogue {
    static func build(from foods: [FoodItem]) -> [RecipeGenerationFoodOption] {
        foods
            .filter { !$0.isArchived }
            .map { food in
                RecipeGenerationFoodOption(
                    foodID: food.id,
                    name: food.name,
                    frenchName: food.frenchName,
                    aliases: food.searchAliases,
                    preparationState: food.preparationState,
                    servings: FoodLibraryService.portions(for: food).map {
                        RecipeGenerationServingOption(
                            servingID: $0.id,
                            name: $0.name,
                            amount: $0.amount,
                            unit: $0.unit,
                            equivalentReferenceAmount: $0.equivalentReferenceAmount
                        )
                    },
                    calories: food.calories,
                    proteinGrams: food.proteinGrams,
                    carbohydrateGrams: food.carbohydrateGrams,
                    fatGrams: food.fatGrams
                )
            }
    }
}
