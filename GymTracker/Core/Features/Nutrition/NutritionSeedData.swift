import Foundation
import SwiftData

enum NutritionSeedData {
    static func seedIfNeeded(using context: ModelContext) {
        do {
            try stage(using: context, registry: SystemSeedRegistry(context: context))
            try context.save()
        } catch {
            context.rollback()
            print("Failed to seed nutrition data: \(error)")
        }
    }

    static func stage(using context: ModelContext, registry: SystemSeedRegistry) throws {
        var existing = try context.fetch(FetchDescriptor<FoodItem>())


        struct FoodSeed {
            let name: String
            let refAmount: Double
            let refUnit: NutritionServingUnit
            let calories: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let prep: FoodPreparationState
            let servingName: String
            let servingAmount: Double
            let servingUnit: NutritionServingUnit
            let equivalentRefAmount: Double

            init(
                name: String,
                refAmount: Double = 100,
                refUnit: NutritionServingUnit = .grams,
                calories: Double,
                protein: Double,
                carbs: Double,
                fat: Double,
                prep: FoodPreparationState = .raw,
                servingName: String,
                servingAmount: Double,
                servingUnit: NutritionServingUnit = .grams,
                equivalentRefAmount: Double
            ) {
                self.name = name
                self.refAmount = refAmount
                self.refUnit = refUnit
                self.calories = calories
                self.protein = protein
                self.carbs = carbs
                self.fat = fat
                self.prep = prep
                self.servingName = servingName
                self.servingAmount = servingAmount
                self.servingUnit = servingUnit
                self.equivalentRefAmount = equivalentRefAmount
            }
        }

        let seedList: [FoodSeed] = [
            // Dairy & Yogurt
            FoodSeed(name: "Greek yogurt", calories: 59, protein: 10, carbs: 3.6, fat: 0.4, servingName: "170 g cup", servingAmount: 170, equivalentRefAmount: 170),
            FoodSeed(name: "Low-fat cottage cheese", calories: 81, protein: 11, carbs: 4.7, fat: 2.3, servingName: "1 cup", servingAmount: 225, equivalentRefAmount: 225),
            FoodSeed(name: "Whole milk", calories: 61, protein: 3.2, carbs: 4.8, fat: 3.3, servingName: "1 cup", servingAmount: 244, equivalentRefAmount: 244),
            FoodSeed(name: "Skim milk", calories: 35, protein: 3.4, carbs: 5.0, fat: 0.1, servingName: "1 cup", servingAmount: 245, equivalentRefAmount: 245),
            FoodSeed(name: "Firm tofu", calories: 83, protein: 10, carbs: 2.0, fat: 5.0, servingName: "1/5 block", servingAmount: 85, equivalentRefAmount: 85),

            // Poultry & Meats
            FoodSeed(name: "Cooked chicken breast", calories: 165, protein: 31, carbs: 0, fat: 3.6, prep: .cooked, servingName: "150 g portion", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Cooked turkey breast", calories: 135, protein: 30, carbs: 0, fat: 1.0, prep: .cooked, servingName: "150 g portion", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Cooked lean ground beef (90/10)", calories: 215, protein: 26, carbs: 0, fat: 11.0, prep: .cooked, servingName: "150 g patty", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Cooked lean ground turkey (93/7)", calories: 170, protein: 24, carbs: 0, fat: 8.0, prep: .cooked, servingName: "150 g portion", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Cooked sirloin steak", calories: 200, protein: 27, carbs: 0, fat: 9.5, prep: .cooked, servingName: "200 g steak", servingAmount: 200, equivalentRefAmount: 200),
            FoodSeed(name: "Cooked pork tenderloin", calories: 145, protein: 26, carbs: 0, fat: 3.5, prep: .cooked, servingName: "150 g portion", servingAmount: 150, equivalentRefAmount: 150),

            // Fish & Seafood
            FoodSeed(name: "Cooked salmon fillet", calories: 206, protein: 22, carbs: 0, fat: 12.0, prep: .cooked, servingName: "150 g fillet", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Canned tuna in water", calories: 116, protein: 26, carbs: 0, fat: 1.0, servingName: "1 can drained", servingAmount: 120, equivalentRefAmount: 120),
            FoodSeed(name: "Cooked shrimp", calories: 99, protein: 24, carbs: 0.2, fat: 0.3, prep: .cooked, servingName: "100 g serving", servingAmount: 100, equivalentRefAmount: 100),
            FoodSeed(name: "Cooked cod fillet", calories: 105, protein: 23, carbs: 0, fat: 0.9, prep: .cooked, servingName: "150 g fillet", servingAmount: 150, equivalentRefAmount: 150),

            // Eggs & Protein Powders
            FoodSeed(name: "Whole egg", refAmount: 1, refUnit: .count, calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, servingName: "1 large egg", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Liquid egg whites", calories: 52, protein: 11, carbs: 0.7, fat: 0.2, servingName: "1/2 cup", servingAmount: 120, equivalentRefAmount: 120),
            FoodSeed(name: "Whey protein powder", refAmount: 1, refUnit: .count, calories: 120, protein: 24, carbs: 2, fat: 1.5, servingName: "1 scoop", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Casein protein powder", refAmount: 1, refUnit: .count, calories: 120, protein: 24, carbs: 1, fat: 1.0, servingName: "1 scoop", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),

            // Grains & Carbs
            FoodSeed(name: "Cooked rice", calories: 130, protein: 2.7, carbs: 28, fat: 0.3, prep: .cooked, servingName: "1 cup", servingAmount: 158, equivalentRefAmount: 158),
            FoodSeed(name: "Cooked brown rice", calories: 112, protein: 2.3, carbs: 24, fat: 0.8, prep: .cooked, servingName: "1 cup", servingAmount: 195, equivalentRefAmount: 195),
            FoodSeed(name: "Dry rolled oats", calories: 389, protein: 16.9, carbs: 66, fat: 6.9, servingName: "1/2 cup", servingAmount: 40, equivalentRefAmount: 40),
            FoodSeed(name: "Cooked sweet potato", calories: 86, protein: 1.6, carbs: 20, fat: 0.1, prep: .cooked, servingName: "1 medium", servingAmount: 130, equivalentRefAmount: 130),
            FoodSeed(name: "Cooked white potato", calories: 87, protein: 1.9, carbs: 20, fat: 0.1, prep: .cooked, servingName: "1 medium", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Cooked quinoa", calories: 120, protein: 4.4, carbs: 21.3, fat: 1.9, prep: .cooked, servingName: "1 cup", servingAmount: 185, equivalentRefAmount: 185),
            FoodSeed(name: "Whole wheat bread", refAmount: 1, refUnit: .count, calories: 100, protein: 4.0, carbs: 18, fat: 1.5, servingName: "1 slice", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "White bread", refAmount: 1, refUnit: .count, calories: 80, protein: 2.5, carbs: 14, fat: 1.0, servingName: "1 slice", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Cooked pasta", calories: 131, protein: 5.0, carbs: 25, fat: 1.1, prep: .cooked, servingName: "1 cup", servingAmount: 140, equivalentRefAmount: 140),
            FoodSeed(name: "Whole wheat tortilla", refAmount: 1, refUnit: .count, calories: 130, protein: 4.0, carbs: 22, fat: 3.0, servingName: "1 tortilla", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Dry cream of rice", calories: 360, protein: 7.0, carbs: 78, fat: 1.0, servingName: "1/4 cup dry", servingAmount: 45, equivalentRefAmount: 45),

            // Fruits & Berries
            FoodSeed(name: "Banana", refAmount: 1, refUnit: .count, calories: 105, protein: 1.3, carbs: 27, fat: 0.4, servingName: "1 medium", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Apple", refAmount: 1, refUnit: .count, calories: 95, protein: 0.5, carbs: 25, fat: 0.3, servingName: "1 medium", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Blueberries", calories: 57, protein: 0.7, carbs: 14, fat: 0.3, servingName: "1 cup", servingAmount: 148, equivalentRefAmount: 148),
            FoodSeed(name: "Strawberries", calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, servingName: "1 cup", servingAmount: 144, equivalentRefAmount: 144),
            FoodSeed(name: "Orange", refAmount: 1, refUnit: .count, calories: 62, protein: 1.2, carbs: 15, fat: 0.2, servingName: "1 medium", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Raspberries", calories: 52, protein: 1.2, carbs: 12, fat: 0.6, servingName: "1 cup", servingAmount: 123, equivalentRefAmount: 123),
            FoodSeed(name: "Pineapple chunks", calories: 50, protein: 0.5, carbs: 13, fat: 0.1, servingName: "1 cup", servingAmount: 165, equivalentRefAmount: 165),
            FoodSeed(name: "Watermelon", calories: 30, protein: 0.6, carbs: 7.5, fat: 0.2, servingName: "1 cup diced", servingAmount: 152, equivalentRefAmount: 152),

            // Healthy Fats & Seeds
            FoodSeed(name: "Peanut butter", calories: 588, protein: 25, carbs: 20, fat: 50.0, servingName: "2 tbsp", servingAmount: 32, equivalentRefAmount: 32),
            FoodSeed(name: "Almonds", calories: 579, protein: 21, carbs: 22, fat: 50.0, servingName: "1 oz / 28 nuts", servingAmount: 28, equivalentRefAmount: 28),
            FoodSeed(name: "Avocado", refAmount: 1, refUnit: .count, calories: 160, protein: 2.0, carbs: 8.5, fat: 14.7, servingName: "1 medium", servingAmount: 1, servingUnit: .count, equivalentRefAmount: 1),
            FoodSeed(name: "Extra virgin olive oil", calories: 884, protein: 0, carbs: 0, fat: 100.0, servingName: "1 tbsp", servingAmount: 14, equivalentRefAmount: 14),
            FoodSeed(name: "Chia seeds", calories: 486, protein: 17, carbs: 42, fat: 31.0, servingName: "1 tbsp", servingAmount: 12, equivalentRefAmount: 12),
            FoodSeed(name: "Dark chocolate (85%)", calories: 580, protein: 8, carbs: 36, fat: 46.0, servingName: "30 g portion", servingAmount: 30, equivalentRefAmount: 30),
            FoodSeed(name: "Walnuts", calories: 654, protein: 15, carbs: 14, fat: 65.0, servingName: "1 oz / 14 halves", servingAmount: 28, equivalentRefAmount: 28),

            // Vegetables & Legumes
            FoodSeed(name: "Cooked broccoli", calories: 35, protein: 2.4, carbs: 7.0, fat: 0.4, prep: .cooked, servingName: "1 cup florets", servingAmount: 150, equivalentRefAmount: 150),
            FoodSeed(name: "Raw spinach", calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, servingName: "2 cups raw", servingAmount: 60, equivalentRefAmount: 60),
            FoodSeed(name: "Cooked green beans", calories: 35, protein: 1.9, carbs: 7.9, fat: 0.3, prep: .cooked, servingName: "1 cup", servingAmount: 125, equivalentRefAmount: 125),
            FoodSeed(name: "Cooked black beans", calories: 132, protein: 8.9, carbs: 23.7, fat: 0.5, prep: .cooked, servingName: "1 cup", servingAmount: 172, equivalentRefAmount: 172),
            FoodSeed(name: "Cooked chickpeas", calories: 164, protein: 8.9, carbs: 27.0, fat: 2.6, prep: .cooked, servingName: "1 cup", servingAmount: 164, equivalentRefAmount: 164)
        ]

        var didInsert = false
        for seed in seedList {
            let key = SystemSeedKey.make(namespace: "food", legacyName: seed.name)
            let food: FoodItem
            let ownsSystemFields: Bool
            if let record = try registry.record(for: key, expectedKind: .foodItem) {
                guard let matched = existing.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                food = matched
                ownsSystemFields = record.isSystemProvided
            } else if let matched = existing.first(where: {
                $0.name.compare(seed.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }) {
                food = matched
                ownsSystemFields = matched.sourceKind == .curated
                try registry.register(
                    key: key,
                    kind: .foodItem,
                    entityID: matched.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy,
                    isSystemProvided: ownsSystemFields
                )
            } else {
                food = FoodItem(name: seed.name, sourceKind: .curated, confidence: .verified)
                context.insert(food)
                existing.append(food)
                ownsSystemFields = true
                try registry.register(
                    key: key,
                    kind: .foodItem,
                    entityID: food.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
                didInsert = true
            }
            guard ownsSystemFields else { continue }
            food.name = seed.name
            food.referenceAmount = seed.refAmount
            food.referenceUnit = seed.refUnit
            food.calories = seed.calories
            food.proteinGrams = seed.protein
            food.carbohydrateGrams = seed.carbs
            food.fatGrams = seed.fat
            food.sourceKind = .curated
            food.confidence = .verified
            food.preparationState = seed.prep
            food.updatedAt = .now
            // isFavorite and isArchived are user-owned.

            let servingKey = "food-serving.\(key.dropFirst("food.".count)).primary"
            let serving: FoodServing
            if let record = try registry.record(for: servingKey, expectedKind: .foodServing) {
                guard let matched = food.servings.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: servingKey, entityID: record.entityID)
                }
                serving = matched
            } else if let existingServing = food.servings.first {
                serving = existingServing
                try registry.register(
                    key: servingKey,
                    kind: .foodServing,
                    entityID: serving.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy
                )
            } else {
                serving = FoodServing(
                    name: seed.servingName,
                    amount: seed.servingAmount,
                    unit: seed.servingUnit,
                    equivalentReferenceAmount: seed.equivalentRefAmount
                )
                food.servings.append(serving)
                try registry.register(
                    key: servingKey,
                    kind: .foodServing,
                    entityID: serving.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
            }
            serving.name = seed.servingName
            serving.amount = seed.servingAmount
            serving.unit = seed.servingUnit
            serving.equivalentReferenceAmount = seed.equivalentRefAmount
        }

        _ = didInsert

        let existingTemplates = try context.fetch(FetchDescriptor<MealTemplate>())
        let allFoods = try context.fetch(FetchDescriptor<FoodItem>())
        let foodByName: [String: FoodItem] = Dictionary(uniqueKeysWithValues: allFoods.map { ($0.name.lowercased(), $0) })


        struct RecipeSeed {
            let name: String
            let prepState: FoodPreparationState
            let finalWeight: Double?
            let items: [(foodName: String, qty: Double)]
        }

        let recipeList: [RecipeSeed] = [
            RecipeSeed(
                name: "Chicken, Rice & Broccoli Bowl",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked chicken breast", 1.5),
                    ("Cooked rice", 1.25),
                    ("Cooked broccoli", 1.0)
                ]
            ),
            RecipeSeed(
                name: "High-Protein Oatmeal Bowl",
                prepState: .raw,
                finalWeight: nil,
                items: [
                    ("Dry rolled oats", 2.0),
                    ("Whey protein powder", 1.0),
                    ("Banana", 1.0),
                    ("Peanut butter", 1.0)
                ]
            ),
            RecipeSeed(
                name: "Steak & Sweet Potato Recovery Meal",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked sirloin steak", 1.0),
                    ("Cooked sweet potato", 1.5),
                    ("Cooked green beans", 1.0)
                ]
            ),
            RecipeSeed(
                name: "Greek Yogurt & Berry Bowl",
                prepState: .raw,
                finalWeight: nil,
                items: [
                    ("Greek yogurt", 1.2),
                    ("Blueberries", 0.7),
                    ("Chia seeds", 1.0),
                    ("Whey protein powder", 0.5)
                ]
            ),
            RecipeSeed(
                name: "Egg White & Avocado Wrap",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Whole wheat tortilla", 1.0),
                    ("Liquid egg whites", 1.25),
                    ("Whole egg", 1.0),
                    ("Avocado", 0.5)
                ]
            ),
            RecipeSeed(
                name: "Salmon & Quinoa Bowl",
                prepState: .cooked,
                finalWeight: nil,
                items: [
                    ("Cooked salmon fillet", 1.0),
                    ("Cooked quinoa", 1.0),
                    ("Raw spinach", 1.0)
                ]
            )
        ]

        var didInsertRecipe = false
        for recipe in recipeList {
            var templateItems: [MealTemplateItem] = []
            for (idx, item) in recipe.items.enumerated() {
                if let food = foodByName[item.foodName.lowercased()] {
                    let servingID = food.servings.first?.id
                    templateItems.append(MealTemplateItem(food: food, orderIndex: idx, servingID: servingID, quantity: item.qty))
                }
            }
            guard !templateItems.isEmpty else { continue }
            let key = SystemSeedKey.make(namespace: "meal-template", legacyName: recipe.name)
            if let record = try registry.record(for: key, expectedKind: .mealTemplate) {
                guard existingTemplates.contains(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                continue
            }
            let expectedFoodIDs = templateItems.map { $0.food.id }
            let candidates = existingTemplates.filter {
                $0.name == recipe.name && $0.orderedItems.map { $0.food.id } == expectedFoodIDs
            }
            guard candidates.count <= 1 else {
                throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
            }
            if let adopted = candidates.first {
                try registry.register(
                    key: key,
                    kind: .mealTemplate,
                    entityID: adopted.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .migratedLegacy
                )
            } else {
                let template = MealTemplate(name: recipe.name, preparationState: recipe.prepState, finalCookedWeightGrams: recipe.finalWeight)
                template.items = templateItems
                context.insert(template)
                try registry.register(
                    key: key,
                    kind: .mealTemplate,
                    entityID: template.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
                didInsertRecipe = true
            }
        }

        _ = didInsertRecipe
    }
}
