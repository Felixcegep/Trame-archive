import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let appearance = "appearance"
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
    /// Comma-joined `SetType` raw values, most recent first. See `RecentSetTypes`.
    static let recentSetTypes = "recentSetTypes.v1"
    static let activeLoggingMetrics = "activeLoggingMetrics.v1"
    /// When a backup file was last produced, and when one was last restored.
    ///
    /// Local-first only reassures a user who can see their own exposure, so these
    /// two dates are what the Data Safety section reports. Deliberately
    /// preference-shaped rather than user data: they describe this installation's
    /// safety state, so a restored backup must not carry another device's dates in.
    static let lastBackupExportTimestamp = "lastBackupExportTimestamp"
    static let lastBackupRestoreTimestamp = "lastBackupRestoreTimestamp"
}

enum AppAppearance: String, CaseIterable {
    case system
    case dark
    case light

    var title: String {
        switch self {
        case .system: String(localized: "System Default")
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        }
    }

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
