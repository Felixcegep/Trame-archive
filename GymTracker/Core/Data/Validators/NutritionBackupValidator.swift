import Foundation

/// Validates nutrition domain entities within a backup archive:
/// food items, servings, meal templates, logged meals, and nutrition targets.
nonisolated enum NutritionBackupValidator {
    static func validate(_ dto: BackupDTO) throws {
        let foodIDs = Set(dto.foods.map { $0.id.lowercased() })

        for meal in dto.loggedMeals {
            for item in meal.items {
                if let sourceFoodID = item.sourceFoodID?.lowercased() {
                    guard foodIDs.contains(sourceFoodID) else {
                        throw BackupValidationError.missingExercise(item.foodNameSnapshot)
                    }
                }
            }
        }
    }
}
