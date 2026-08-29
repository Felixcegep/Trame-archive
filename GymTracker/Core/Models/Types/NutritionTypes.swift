import Foundation

nonisolated enum NutritionServingUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case grams
    case milliliters
    case count
    case serving

    var displayName: String {
        switch self {
        case .grams: "g"
        case .milliliters: "mL"
        case .count: "count"
        case .serving: "serving"
        }
    }
}

nonisolated enum FoodSourceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case curated
    case userCreated

    var displayName: String { self == .curated ? "Curated" : "Custom" }
}

nonisolated enum FoodConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    case verified
    case userProvided
    case estimated

    var displayName: String {
        switch self {
        case .verified: "Verified"
        case .userProvided: "User provided"
        case .estimated: "Estimated"
        }
    }
}

nonisolated enum FoodPreparationState: String, Codable, CaseIterable, Hashable, Sendable {
    case raw
    case cooked

    var displayName: String { self == .raw ? "Raw" : "Cooked" }
}

nonisolated enum MealSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String { rawValue.capitalized }

    static func suggested(at date: Date = .now, calendar: Calendar = .current) -> MealSlot {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

nonisolated enum NutritionGoalPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case maintenance
    case bulk
    case cut

    var displayName: String { rawValue.capitalized }
}

nonisolated enum NutritionDayKind: String, Codable, Hashable, Sendable {
    case training
    case rest

    var displayName: String { self == .training ? "Training day" : "Rest day" }
}

nonisolated struct NutritionMacroTotals: Equatable, Sendable {
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var caffeineMilligrams: Double = 0
    var unknownCaloriesCount: Int = 0
    var unknownProteinCount: Int = 0
    var unknownCarbohydratesCount: Int = 0
    var unknownFatCount: Int = 0
    var unknownCaffeineCount: Int = 0

    var hasUnknownValues: Bool {
        unknownCaloriesCount + unknownProteinCount + unknownCarbohydratesCount + unknownFatCount > 0
    }
}

nonisolated struct NutritionTargetValues: Equatable, Sendable {
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?

    static let empty = NutritionTargetValues(calories: nil, protein: nil, carbohydrates: nil, fat: nil)
}
