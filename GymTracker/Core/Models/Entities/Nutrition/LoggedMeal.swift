import Foundation
import SwiftData

@Model
final class LoggedMeal {
    var id: UUID
    var dayKey: String
    var slotRaw: String
    var loggedAt: Date
    var nameSnapshot: String
    var sourceMealTemplateID: UUID?
    var sourceMealTemplateName: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \LoggedMealItem.loggedMeal)
    var items: [LoggedMealItem] = []

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .snack }
        set { slotRaw = newValue.rawValue }
    }

    init(
        day: LocalDay = .today,
        slot: MealSlot = .snack,
        loggedAt: Date = .now,
        nameSnapshot: String,
        sourceMealTemplateID: UUID? = nil,
        sourceMealTemplateName: String? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.dayKey = day.rawValue
        self.slotRaw = slot.rawValue
        self.loggedAt = loggedAt
        self.nameSnapshot = nameSnapshot
        self.sourceMealTemplateID = sourceMealTemplateID
        self.sourceMealTemplateName = sourceMealTemplateName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedItems: [LoggedMealItem] {
        items.sorted { $0.orderIndex == $1.orderIndex ? $0.id.uuidString < $1.id.uuidString : $0.orderIndex < $1.orderIndex }
    }
}
