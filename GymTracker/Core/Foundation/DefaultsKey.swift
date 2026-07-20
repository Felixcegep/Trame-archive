import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let restTimer = "restTimer"
    static let useMetric = "useMetric"
    static let orphanCleanupVersion = "orphanCleanupVersion"
    static let planRemindersEnabled = "planRemindersEnabled"
    static let planReminderHour = "planReminderHour"
    static let planReminderMinute = "planReminderMinute"
    static let checkInRemindersEnabled = "checkInRemindersEnabled"
    static let checkInReminderHour = "checkInReminderHour"
    static let checkInReminderMinute = "checkInReminderMinute"
}

extension UserDefaults {
    var unitSystem: UnitSystem {
        guard let stringValue = string(forKey: DefaultsKey.useMetric) else {
            return .metric
        }
        return UnitSystem(rawValue: stringValue) ?? .metric
    }
}
