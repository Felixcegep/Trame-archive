import Foundation

/// Scripted photo-estimate results for UI tests, requested via
/// `-ui-test-meal-photo-estimate-result`. Live Gemini is never available in a
/// deterministic simulator, so these stand in for the network path the same
/// way `-ui-test-recipe-generation-result` stands in for on-device generation.
enum UITestMealPhotoEstimateResult: String {
    case success
    case unclear
    case failure
    /// Holds in the loading state briefly before succeeding, so a screenshot
    /// scene can capture "Estimating…" deterministically.
    case slow

    static var launchOverride: UITestMealPhotoEstimateResult? {
        guard
            let index = AppLaunchArguments.current.firstIndex(of: "-ui-test-meal-photo-estimate-result"),
            AppLaunchArguments.current.indices.contains(index + 1)
        else {
            return nil
        }
        return UITestMealPhotoEstimateResult(rawValue: AppLaunchArguments.current[index + 1])
    }
}

struct ScriptedMealPhotoEstimator: MealPhotoEstimator {
    let result: UITestMealPhotoEstimateResult

    func estimate(imageJPEG: Data) async throws -> MealPhotoEstimateDraft {
        switch result {
        case .success:
            return .fixturePlate
        case .unclear:
            return MealPhotoEstimateDraft(unclear: true, items: [])
        case .failure:
            throw MealPhotoEstimatorError.requestFailed
        case .slow:
            try await Task.sleep(for: .seconds(5))
            return .fixturePlate
        }
    }
}

extension MealPhotoEstimateDraft {
    static let fixturePlate = MealPhotoEstimateDraft(
        unclear: false,
        items: [
            MealPhotoEstimateItem(
                name: "Chicken",
                grams: 180,
                calories: 280,
                proteinGrams: 40,
                carbohydrateGrams: 0,
                fatGrams: 8
            ),
            MealPhotoEstimateItem(
                name: "Rice",
                grams: 200,
                calories: 260,
                proteinGrams: 5,
                carbohydrateGrams: 56,
                fatGrams: 1
            )
        ]
    )
}

enum MealPhotoEstimatorFactory {
    static func make() -> any MealPhotoEstimator {
        if let scripted = UITestMealPhotoEstimateResult.launchOverride {
            return ScriptedMealPhotoEstimator(result: scripted)
        }
        return GeminiMealPhotoEstimator()
    }
}
