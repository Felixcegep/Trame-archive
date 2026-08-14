import Foundation

/// The seam between the personalized-workout flow and an implementation that
/// creates a structured draft. Tests and previews can inject a deterministic
/// generator instead of invoking the system model.
nonisolated protocol WorkoutDraftGenerator: Sendable {
    func generateDraft(from input: WorkoutGenerationInput) async throws -> GeneratedWorkoutDraft
}

nonisolated enum WorkoutDraftGeneratorError: Error, Sendable, Equatable {
    case modelUnavailable
    case noEligibleExercises
    case cancelled
    case generationFailed
}
