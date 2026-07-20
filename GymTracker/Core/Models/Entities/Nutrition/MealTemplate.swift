import Foundation
import SwiftData

@Model
final class MealTemplate {
    var id: UUID
    var lineageID: UUID
    var version: Int
    var name: String
    var preparationStateRaw: String
    var finalCookedWeightGrams: Double?
    var isCurrent: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MealTemplateItem.mealTemplate)
    var items: [MealTemplateItem] = []

    var preparationState: FoodPreparationState {
        get { FoodPreparationState(rawValue: preparationStateRaw) ?? .cooked }
        set { preparationStateRaw = newValue.rawValue }
    }

    init(
        name: String,
        preparationState: FoodPreparationState = .cooked,
        finalCookedWeightGrams: Double? = nil,
        lineageID: UUID = UUID(),
        version: Int = 1,
        isCurrent: Bool = true,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.lineageID = lineageID
        self.version = version
        self.name = name
        self.preparationStateRaw = preparationState.rawValue
        self.finalCookedWeightGrams = finalCookedWeightGrams
        self.isCurrent = isCurrent
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedItems: [MealTemplateItem] {
        items.sorted { $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex }
    }
}
