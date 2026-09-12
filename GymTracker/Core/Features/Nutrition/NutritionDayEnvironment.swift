import SwiftUI

private struct NutritionSelectedDayKey: EnvironmentKey {
    static let defaultValue = LocalDay.today
}

extension EnvironmentValues {
    var nutritionSelectedDay: LocalDay {
        get { self[NutritionSelectedDayKey.self] }
        set { self[NutritionSelectedDayKey.self] = newValue }
    }
}
