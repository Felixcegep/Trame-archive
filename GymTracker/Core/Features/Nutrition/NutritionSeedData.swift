import SwiftData

enum NutritionSeedData {
    static func seedIfNeeded(using context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        guard existing.isEmpty else { return }

        let foods = [
            FoodItem(name: "Greek yogurt", referenceAmount: 100, referenceUnit: .grams, calories: 59, proteinGrams: 10, carbohydrateGrams: 3.6, fatGrams: 0.4, sourceKind: .curated, confidence: .verified, preparationState: .raw, isFavorite: true),
            FoodItem(name: "Cooked chicken breast", referenceAmount: 100, referenceUnit: .grams, calories: 165, proteinGrams: 31, carbohydrateGrams: 0, fatGrams: 3.6, sourceKind: .curated, confidence: .verified, preparationState: .cooked, isFavorite: true),
            FoodItem(name: "Cooked rice", referenceAmount: 100, referenceUnit: .grams, calories: 130, proteinGrams: 2.7, carbohydrateGrams: 28, fatGrams: 0.3, sourceKind: .curated, confidence: .verified, preparationState: .cooked),
            FoodItem(name: "Banana", referenceAmount: 1, referenceUnit: .count, calories: 105, proteinGrams: 1.3, carbohydrateGrams: 27, fatGrams: 0.4, sourceKind: .curated, confidence: .verified, preparationState: .raw)
        ]
        foods[0].servings = [FoodServing(name: "170 g cup", amount: 170, unit: .grams, equivalentReferenceAmount: 170)]
        foods[1].servings = [FoodServing(name: "150 g portion", amount: 150, unit: .grams, equivalentReferenceAmount: 150)]
        foods[2].servings = [FoodServing(name: "1 cup", amount: 158, unit: .grams, equivalentReferenceAmount: 158)]
        foods[3].servings = [FoodServing(name: "1 medium", amount: 1, unit: .count, equivalentReferenceAmount: 1)]
        for food in foods { context.insert(food) }
        try? context.save()
    }
}
