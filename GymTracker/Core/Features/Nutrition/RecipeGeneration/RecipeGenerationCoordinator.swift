import Foundation

/// Runs generation then immediately validates the result against the food
/// library that is current right now, so callers always receive something
/// already safe to show. Kept separate from `MealTemplateEditorView` so unit
/// tests can drive the whole generate-then-validate path with a fake
/// `RecipeDraftGenerator` and no SwiftUI involved.
@MainActor
enum RecipeGenerationCoordinator {
    static func generateAndValidate(
        input: RecipeGenerationInput,
        currentFoods: [FoodItem],
        using generator: RecipeDraftGenerator
    ) async throws -> ValidatedRecipeDraft {
        let draft = try await generator.generateDraft(from: input)
        try Task.checkCancellation()
        return RecipeDraftValidator.validate(draft, against: currentFoods)
    }
}
