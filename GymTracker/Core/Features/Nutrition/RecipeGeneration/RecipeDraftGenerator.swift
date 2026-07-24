import Foundation

/// Failure modes a `RecipeDraftGenerator` can surface. The UI maps each case
/// to one of the copy strings in the recipe-generation prototype plan.
enum RecipeDraftGeneratorError: Error, Sendable, Equatable {
    case modelUnavailable
    case imageUnsupported
    case unclearImage
    case unsafeImage
    case cancelled
    case generationFailed
}

/// Seam between the editable recipe UI and whatever produces a structured
/// draft. The real implementation (`FoundationRecipeDraftGenerator`) calls
/// into Apple's on-device Foundation Models; tests inject a deterministic
/// stub instead so they never depend on the live model.
protocol RecipeDraftGenerator: Sendable {
    func generateDraft(from input: RecipeGenerationInput) async throws -> GeneratedRecipeDraft
}
