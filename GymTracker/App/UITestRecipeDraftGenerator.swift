import Foundation

/// Scripted results for the `Generate recipe` UI, requested via
/// `-ui-test-recipe-generation-result`. Apple Intelligence is rarely
/// available on CI simulators, so UI tests that need a deterministic
/// generation outcome ask for one of these instead of depending on the live
/// on-device model (mirrors `UITestFixture`'s `-ui-test-fixture` pattern).
enum UITestRecipeDraftGenerationResult: String {
    case success
    case partialMatch = "partial-match"
    case noMatches = "no-matches"
    case failure
    /// Holds in the loading state briefly before succeeding, so a screenshot
    /// scene can capture "Generating recipe…" deterministically.
    case slow

    static var launchOverride: UITestRecipeDraftGenerationResult? {
        guard
            let index = CommandLine.arguments.firstIndex(of: "-ui-test-recipe-generation-result"),
            CommandLine.arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return UITestRecipeDraftGenerationResult(rawValue: CommandLine.arguments[index + 1])
    }
}

struct ScriptedRecipeDraftGenerator: RecipeDraftGenerator {
    let result: UITestRecipeDraftGenerationResult

    func generateDraft(from input: RecipeGenerationInput) async throws -> GeneratedRecipeDraft {
        switch result {
        case .success:
            let matched = input.availableFoods.prefix(2)
            return GeneratedRecipeDraft(
                name: input.name ?? "Scripted recipe",
                preparationState: .cooked,
                finalCookedWeightGrams: 400,
                ingredients: matched.map { GeneratedRecipeIngredient(foodID: $0.foodID, servingID: $0.servings.first?.servingID, quantity: 1) },
                unmatchedIngredientHints: []
            )
        case .partialMatch:
            let matched = input.availableFoods.prefix(1)
            return GeneratedRecipeDraft(
                name: input.name ?? "Scripted recipe",
                preparationState: .cooked,
                finalCookedWeightGrams: nil,
                ingredients: matched.map { GeneratedRecipeIngredient(foodID: $0.foodID, servingID: $0.servings.first?.servingID, quantity: 1) },
                unmatchedIngredientHints: ["Mystery ingredient"]
            )
        case .noMatches:
            return GeneratedRecipeDraft(name: input.name, preparationState: nil, finalCookedWeightGrams: nil, ingredients: [], unmatchedIngredientHints: [])
        case .failure:
            throw RecipeDraftGeneratorError.generationFailed
        case .slow:
            try await Task.sleep(for: .seconds(5))
            let matched = input.availableFoods.prefix(2)
            return GeneratedRecipeDraft(
                name: input.name ?? "Scripted recipe",
                preparationState: .cooked,
                finalCookedWeightGrams: 400,
                ingredients: matched.map { GeneratedRecipeIngredient(foodID: $0.foodID, servingID: $0.servings.first?.servingID, quantity: 1) },
                unmatchedIngredientHints: []
            )
        }
    }
}
