import Foundation

enum NutritionServingUnit: String, Codable, CaseIterable, Hashable {
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

enum FoodSourceKind: String, Codable, CaseIterable, Hashable {
    case curated
    case userCreated

    var displayName: String { self == .curated ? "Curated" : "Custom" }
}

enum FoodConfidence: String, Codable, CaseIterable, Hashable {
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

enum FoodPreparationState: String, Codable, CaseIterable, Hashable {
    case raw
    case cooked

    var displayName: String { self == .raw ? "Raw" : "Cooked" }
}

enum MealSlot: String, Codable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String { rawValue.capitalized }
}

enum NutritionGoalPhase: String, Codable, CaseIterable, Hashable {
    case maintenance
    case bulk
    case cut

    var displayName: String { rawValue.capitalized }
}

enum NutritionDayKind: String, Codable, Hashable {
    case training
    case rest

    var displayName: String { self == .training ? "Training day" : "Rest day" }
}

struct NutritionMacroTotals: Equatable, Sendable {
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var unknownCaloriesCount: Int = 0
    var unknownProteinCount: Int = 0
    var unknownCarbohydratesCount: Int = 0
    var unknownFatCount: Int = 0

    var hasUnknownValues: Bool {
        unknownCaloriesCount + unknownProteinCount + unknownCarbohydratesCount + unknownFatCount > 0
    }
}

struct NutritionTargetValues: Equatable, Sendable {
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?

    static let empty = NutritionTargetValues(calories: nil, protein: nil, carbohydrates: nil, fat: nil)
}
