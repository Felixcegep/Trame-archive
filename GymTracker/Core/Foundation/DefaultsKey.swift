import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let restTimer = "restTimer"
    static let useMetric = "useMetric"
}

extension UserDefaults {
    var unitSystem: UnitSystem {
        guard let stringValue = string(forKey: DefaultsKey.useMetric) else {
            return .metric
        }
        return UnitSystem(rawValue: stringValue) ?? .metric
    }
}
