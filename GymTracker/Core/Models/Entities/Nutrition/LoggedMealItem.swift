import Foundation
import SwiftData

@Model
final class LoggedMealItem {
    var id: UUID
    var orderIndex: Int
    var sourceFoodID: UUID?
    var foodNameSnapshot: String
    var servingNameSnapshot: String
    var quantity: Double
    var portionAmountSnapshot: Double
    var portionUnitRaw: String
    var caloriesSnapshot: Double?
    var proteinGramsSnapshot: Double?
    var carbohydrateGramsSnapshot: Double?
    var fatGramsSnapshot: Double?
    var sourceKindRaw: String
    var confidenceRaw: String
    var preparationStateRaw: String
    var loggedMeal: LoggedMeal?

    var portionUnit: NutritionServingUnit {
        get { NutritionServingUnit(rawValue: portionUnitRaw) ?? .serving }
        set { portionUnitRaw = newValue.rawValue }
    }

    init(
        sourceFoodID: UUID?,
        foodNameSnapshot: String,
        servingNameSnapshot: String,
        quantity: Double,
        portionAmountSnapshot: Double,
        portionUnit: NutritionServingUnit,
        caloriesSnapshot: Double?,
        proteinGramsSnapshot: Double?,
        carbohydrateGramsSnapshot: Double?,
        fatGramsSnapshot: Double?,
        sourceKind: FoodSourceKind,
        confidence: FoodConfidence,
        preparationState: FoodPreparationState,
        orderIndex: Int,
        id: UUID = UUID()
    ) {
        self.id = id
        self.sourceFoodID = sourceFoodID
        self.foodNameSnapshot = foodNameSnapshot
        self.servingNameSnapshot = servingNameSnapshot
        self.quantity = quantity
        self.portionAmountSnapshot = portionAmountSnapshot
        self.portionUnitRaw = portionUnit.rawValue
        self.caloriesSnapshot = caloriesSnapshot
        self.proteinGramsSnapshot = proteinGramsSnapshot
        self.carbohydrateGramsSnapshot = carbohydrateGramsSnapshot
        self.fatGramsSnapshot = fatGramsSnapshot
        self.sourceKindRaw = sourceKind.rawValue
        self.confidenceRaw = confidence.rawValue
        self.preparationStateRaw = preparationState.rawValue
        self.orderIndex = orderIndex
    }
}
