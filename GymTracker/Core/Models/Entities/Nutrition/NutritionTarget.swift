import Foundation
import SwiftData

@Model
final class NutritionTarget {
    var id: UUID
    var phaseRaw: String
    var effectiveStartDayKey: String
    var effectiveEndDayKey: String?
    var trainingCalories: Double?
    var trainingProteinGrams: Double?
    var trainingCarbohydrateGrams: Double?
    var trainingFatGrams: Double?
    var restCalories: Double?
    var restProteinGrams: Double?
    var restCarbohydrateGrams: Double?
    var restFatGrams: Double?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var phase: NutritionGoalPhase {
        get { NutritionGoalPhase(rawValue: phaseRaw) ?? .maintenance }
        set { phaseRaw = newValue.rawValue }
    }

    init(
        phase: NutritionGoalPhase = .maintenance,
        effectiveStartDay: LocalDay = .today,
        effectiveEndDay: LocalDay? = nil,
        training: NutritionTargetValues = .empty,
        rest: NutritionTargetValues = .empty,
        isArchived: Bool = false,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.phaseRaw = phase.rawValue
        self.effectiveStartDayKey = effectiveStartDay.rawValue
        self.effectiveEndDayKey = effectiveEndDay?.rawValue
        self.trainingCalories = training.calories
        self.trainingProteinGrams = training.protein
        self.trainingCarbohydrateGrams = training.carbohydrates
        self.trainingFatGrams = training.fat
        self.restCalories = rest.calories
        self.restProteinGrams = rest.protein
        self.restCarbohydrateGrams = rest.carbohydrates
        self.restFatGrams = rest.fat
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func values(for kind: NutritionDayKind) -> NutritionTargetValues {
        switch kind {
        case .training:
            NutritionTargetValues(calories: trainingCalories, protein: trainingProteinGrams, carbohydrates: trainingCarbohydrateGrams, fat: trainingFatGrams)
        case .rest:
            NutritionTargetValues(calories: restCalories, protein: restProteinGrams, carbohydrates: restCarbohydrateGrams, fat: restFatGrams)
        }
    }
}
