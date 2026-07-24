import Foundation
import FoundationModels

/// On-device recipe draft generator backed by Apple's Foundation Models
/// framework. Never receives a live `ModelContext`: `RecipeGenerationInput`
/// and `GeneratedRecipeDraft` are both plain `Sendable` value types, and the
/// generated food/serving identifiers are validated separately by
/// `RecipeDraftValidator` before anything reaches the editor.
///
/// The installed Foundation Models framework has no image/multimodal
/// attachment API yet, so a supplied photo can never be used for generation
/// today; `RecipeGenerationAvailability` keeps the UI from offering one for
/// generation in the first place, and this generator refuses defensively if
/// one arrives anyway (e.g. from a test).
struct FoundationRecipeDraftGenerator: RecipeDraftGenerator {
    func generateDraft(from input: RecipeGenerationInput) async throws -> GeneratedRecipeDraft {
        guard input.isEmpty == false else { throw RecipeDraftGeneratorError.generationFailed }
        guard await MainActor.run(body: { RecipeGenerationAvailability.status().allowsGeneration }) else {
            throw RecipeDraftGeneratorError.modelUnavailable
        }
        guard input.imageData == nil else { throw RecipeDraftGeneratorError.imageUnsupported }

        let session = LanguageModelSession(instructions: Self.instructions(for: input.availableFoods))
        let promptText = Self.promptText(for: input)

        do {
            let response = try await session.respond(generating: RecipeDraftResponse.self) {
                promptText
            }
            return Self.draft(from: response.content)
        } catch is CancellationError {
            throw RecipeDraftGeneratorError.cancelled
        } catch let error as RecipeDraftGeneratorError {
            throw error
        } catch {
            throw RecipeDraftGeneratorError.generationFailed
        }
    }

    private static func instructions(for foods: [RecipeGenerationFoodOption]) -> String {
        var lines = [
            "You draft a simple recipe for a nutrition-tracking app.",
            "Only reference foods from the list below, using their exact id.",
            "Never invent a food that is not in the list.",
            "If a likely ingredient is not in the list, add its name to unmatchedIngredientHints instead of guessing a substitute.",
            "Quantities are counts of servings, between 0.25 and 20.",
            "Available foods:",
        ]
        for food in foods {
            var descriptor = "- id: \(food.foodID.uuidString), name: \(food.name)"
            if let frenchName = food.frenchName { descriptor += ", frenchName: \(frenchName)" }
            if food.aliases.isEmpty == false { descriptor += ", aliases: \(food.aliases.joined(separator: ", "))" }
            descriptor += ", preparation: \(food.preparationState.rawValue)"
            let servingDescriptions = food.servings.map { serving -> String in
                if let servingID = serving.servingID {
                    return "\(servingID.uuidString)=\(serving.name)"
                }
                return "(default \"\(serving.name)\" — omit servingID for this one)"
            }.joined(separator: "; ")
            descriptor += ", servings: [\(servingDescriptions)]"
            lines.append(descriptor)
        }
        return lines.joined(separator: "\n")
    }

    private static func promptText(for input: RecipeGenerationInput) -> String {
        if let name = input.name {
            return "Recipe name: \(name). Propose likely ingredients and quantities using only the available foods."
        }
        return "Propose a simple recipe using only the available foods."
    }

    private static func draft(from response: RecipeDraftResponse) -> GeneratedRecipeDraft {
        let preparationRaw = response.preparationState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return GeneratedRecipeDraft(
            name: response.recipeName,
            preparationState: FoodPreparationState(rawValue: preparationRaw),
            finalCookedWeightGrams: response.estimatedCookedWeightGrams,
            ingredients: response.ingredients.compactMap { ingredient in
                guard let foodID = UUID(uuidString: ingredient.foodID) else { return nil }
                let servingID = ingredient.servingID.flatMap(UUID.init(uuidString:))
                return GeneratedRecipeIngredient(foodID: foodID, servingID: servingID, quantity: ingredient.quantity)
            },
            unmatchedIngredientHints: response.unmatchedIngredientHints
        )
    }
}

@Generable
private struct RecipeDraftResponse: Sendable {
    @Guide(description: "A short recipe name. Leave nil if the user already provided one.")
    var recipeName: String?
    @Guide(description: "Either \"raw\" or \"cooked\".")
    var preparationState: String
    @Guide(description: "Estimated final cooked weight in grams, only when it can be reasonably estimated.")
    var estimatedCookedWeightGrams: Double?
    var ingredients: [RecipeDraftIngredientResponse]
    @Guide(description: "Names of likely ingredients that were not present in the supplied food list.")
    var unmatchedIngredientHints: [String]
}

@Generable
private struct RecipeDraftIngredientResponse: Sendable {
    @Guide(description: "Must exactly match one of the supplied food ids.")
    var foodID: String
    @Guide(description: "One of the supplied serving ids for this food, omitted to use the default serving.")
    var servingID: String?
    @Guide(description: "Quantity in servings, between 0.25 and 20.")
    var quantity: Double
}
