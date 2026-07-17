import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let restTimer = "restTimer"
    static let useMetric = "useMetric"
    static let orphanCleanupVersion = "orphanCleanupVersion"
    static let planRemindersEnabled = "planRemindersEnabled"
    static let planReminderHour = "planReminderHour"
    static let planReminderMinute = "planReminderMinute"
}

extension UserDefaults {
    var unitSystem: UnitSystem {
        guard let stringValue = string(forKey: DefaultsKey.useMetric) else {
            return .metric
        }
        return UnitSystem(rawValue: stringValue) ?? .metric
    }
}
