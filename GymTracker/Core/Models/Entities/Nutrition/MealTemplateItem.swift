import Foundation
import SwiftData

@Model
final class MealTemplateItem {
    var id: UUID
    var orderIndex: Int
    var servingID: UUID?
    var quantity: Double
    var food: FoodItem
    var mealTemplate: MealTemplate?

    init(food: FoodItem, orderIndex: Int, servingID: UUID? = nil, quantity: Double = 1, id: UUID = UUID()) {
        self.id = id
        self.food = food
        self.orderIndex = orderIndex
        self.servingID = servingID
        self.quantity = quantity
    }
}
