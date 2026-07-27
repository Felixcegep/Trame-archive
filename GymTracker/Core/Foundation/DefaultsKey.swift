import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let hasCompletedWelcome = "hasCompletedWelcome"
    static let restTimer = "restTimer"
    static let useMetric = "useMetric"
    static let orphanCleanupVersion = "orphanCleanupVersion"
    static let workoutNormalizationVersion = "workoutNormalizationVersion"
    static let planRemindersEnabled = "planRemindersEnabled"
    static let planReminderHour = "planReminderHour"
    static let planReminderMinute = "planReminderMinute"
    static let checkInRemindersEnabled = "checkInRemindersEnabled"
    static let checkInReminderHour = "checkInReminderHour"
    static let checkInReminderMinute = "checkInReminderMinute"
    static let bodyWeightPromptCadence = "bodyWeightPromptCadence"
    static let caffeineBirthdateTimestamp = "caffeineBirthdateTimestamp"
    static let effortMeasure = "effortMeasure"
    static let activeLoggingMetrics = "activeLoggingMetrics.v1"
}

enum EffortMeasure: String, CaseIterable {
    case rir
    case rpe

    var title: String {
        switch self {
        case .rir: "Reps in reserve (RIR)"
        case .rpe: "Rate of perceived exertion (RPE)"
        }
    }
}

extension UserDefaults {
    var unitSystem: UnitSystem {
        guard let stringValue = string(forKey: DefaultsKey.useMetric) else {
            return .metric
        }
        return UnitSystem(rawValue: stringValue) ?? .metric
    }
}
