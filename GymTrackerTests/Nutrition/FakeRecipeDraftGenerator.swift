import Foundation
@testable import GymTracker

/// Deterministic `RecipeDraftGenerator` double so recipe-generation tests
/// never depend on the live on-device Apple model.
final class FakeRecipeDraftGenerator: RecipeDraftGenerator, @unchecked Sendable {
    enum Behavior {
        case success(GeneratedRecipeDraft)
        case failure(RecipeDraftGeneratorError)
        /// Sleeps until the calling task is cancelled, for cancellation tests.
        case hang
    }

    private let behavior: Behavior
    private(set) var receivedInput: RecipeGenerationInput?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func generateDraft(from input: RecipeGenerationInput) async throws -> GeneratedRecipeDraft {
        receivedInput = input
        switch behavior {
        case .success(let draft):
            return draft
        case .failure(let error):
            throw error
        case .hang:
            try await Task.sleep(for: .seconds(60))
            throw RecipeDraftGeneratorError.generationFailed
        }
    }
}
