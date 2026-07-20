import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    @Attribute(.unique) var name: String
    var referenceAmount: Double
    var referenceUnitRaw: String
    var calories: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?
    var caffeineMilligrams: Double?
    var npn: String?
    var sourceKindRaw: String
    var confidenceRaw: String
    var preparationStateRaw: String
    var isFavorite: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \FoodServing.food)
    var servings: [FoodServing] = []
    @Relationship(deleteRule: .nullify, inverse: \MealTemplateItem.food)
    var mealTemplateItems: [MealTemplateItem] = []

    var referenceUnit: NutritionServingUnit {
        get { NutritionServingUnit(rawValue: referenceUnitRaw) ?? .grams }
        set { referenceUnitRaw = newValue.rawValue }
    }

    var sourceKind: FoodSourceKind {
        get { FoodSourceKind(rawValue: sourceKindRaw) ?? .userCreated }
        set { sourceKindRaw = newValue.rawValue }
    }

    var confidence: FoodConfidence {
        get { FoodConfidence(rawValue: confidenceRaw) ?? .userProvided }
        set { confidenceRaw = newValue.rawValue }
    }

    var preparationState: FoodPreparationState {
        get { FoodPreparationState(rawValue: preparationStateRaw) ?? .raw }
        set { preparationStateRaw = newValue.rawValue }
    }

    init(
        name: String,
        referenceAmount: Double = 100,
        referenceUnit: NutritionServingUnit = .grams,
        calories: Double? = nil,
        proteinGrams: Double? = nil,
        carbohydrateGrams: Double? = nil,
        fatGrams: Double? = nil,
        caffeineMilligrams: Double? = nil,
        npn: String? = nil,
        sourceKind: FoodSourceKind = .userCreated,
        confidence: FoodConfidence = .userProvided,
        preparationState: FoodPreparationState = .raw,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.referenceAmount = referenceAmount
        self.referenceUnitRaw = referenceUnit.rawValue
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.caffeineMilligrams = caffeineMilligrams
        self.npn = npn
        self.sourceKindRaw = sourceKind.rawValue
        self.confidenceRaw = confidence.rawValue
        self.preparationStateRaw = preparationState.rawValue
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedServings: [FoodServing] {
        servings.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
