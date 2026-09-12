import Foundation

struct MealPhotoEstimateDraft: Equatable, Sendable {
    var unclear: Bool
    var items: [MealPhotoEstimateItem]

    var hasLoggableItems: Bool {
        items.contains { $0.sanitized != nil }
    }
}

struct MealPhotoEstimateItem: Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var grams: Double?
    var calories: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double? = nil,
        calories: Double? = nil,
        proteinGrams: Double? = nil,
        carbohydrateGrams: Double? = nil,
        fatGrams: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
    }

    var sanitized: MealPhotoEstimateItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return MealPhotoEstimateItem(
            id: id,
            name: trimmed,
            grams: grams.map { max($0, 0) },
            calories: calories.map { max($0, 0) },
            proteinGrams: proteinGrams.map { max($0, 0) },
            carbohydrateGrams: carbohydrateGrams.map { max($0, 0) },
            fatGrams: fatGrams.map { max($0, 0) }
        )
    }

    var loggingName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let grams, grams > 0 else { return trimmed }
        let amount = grams.formatted(.number.precision(.fractionLength(0...1)))
        return "\(trimmed) (\(amount) g)"
    }

    var asLoggingDraft: NutritionEstimateDraftItem? {
        guard let item = sanitized else { return nil }
        return NutritionEstimateDraftItem(
            name: item.loggingName,
            calories: item.calories,
            proteinGrams: item.proteinGrams,
            carbohydrateGrams: item.carbohydrateGrams,
            fatGrams: item.fatGrams
        )
    }
}

enum MealPhotoEstimateParser {
    static func parse(_ raw: String) throws -> MealPhotoEstimateDraft {
        let json = extractJSONObject(from: raw)
        guard let data = json.data(using: .utf8) else {
            throw MealPhotoEstimatorError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload: Payload
        do {
            payload = try decoder.decode(Payload.self, from: data)
        } catch {
            throw MealPhotoEstimatorError.invalidResponse
        }
        let items = (payload.items ?? []).compactMap { item -> MealPhotoEstimateItem? in
            MealPhotoEstimateItem(
                name: item.name ?? "",
                grams: item.grams,
                calories: item.calories,
                proteinGrams: item.proteinGrams,
                carbohydrateGrams: item.carbohydrateGrams,
                fatGrams: item.fatGrams
            ).sanitized
        }
        return MealPhotoEstimateDraft(unclear: payload.unclear ?? false, items: items)
    }

    /// Gemini sometimes wraps JSON in markdown fences or leading commentary.
    static func extractJSONObject(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return trimmed }
        let stripped = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("{") { return stripped }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else {
            return trimmed
        }
        return String(trimmed[start...end])
    }

    private struct Payload: Decodable {
        var unclear: Bool?
        var items: [Item]?

        struct Item: Decodable {
            var name: String?
            var grams: Double?
            var calories: Double?
            var proteinGrams: Double?
            var carbohydrateGrams: Double?
            var fatGrams: Double?
        }
    }
}

enum MealPhotoLibraryHint {
    @MainActor
    static func matchingFoodName(for query: String, in foods: [FoodItem]) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return foods.first { food in
            food.isArchived == false
                && SearchNormalization.matches(
                    query: trimmed,
                    primaryName: food.name,
                    alternateName: food.frenchName,
                    aliases: food.searchAliases
                )
        }?.name
    }
}
