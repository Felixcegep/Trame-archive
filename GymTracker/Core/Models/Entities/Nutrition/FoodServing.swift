import Foundation
import SwiftData

@Model
final class FoodServing {
    var id: UUID
    var name: String
    var amount: Double
    var unitRaw: String
    /// Amount of the food's reference quantity represented by one serving.
    var equivalentReferenceAmount: Double
    var food: FoodItem?

    var unit: NutritionServingUnit {
        get { NutritionServingUnit(rawValue: unitRaw) ?? .serving }
        set { unitRaw = newValue.rawValue }
    }

    init(
        name: String,
        amount: Double,
        unit: NutritionServingUnit,
        equivalentReferenceAmount: Double,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unitRaw = unit.rawValue
        self.equivalentReferenceAmount = equivalentReferenceAmount
    }
}
