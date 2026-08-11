import Foundation

struct DefaultsKey {
    static let darkMode = "darkMode"
    static let appearance = "appearance"
    static let hasCompletedWelcome = "hasCompletedWelcome"
    /// The in-progress onboarding answers, so leaving the app mid-flow resumes
    /// on the same question rather than restarting it. Cleared once the flow
    /// finishes or is dismissed for good. See `OnboardingDraftStore`.
    static let onboardingDraft = "onboardingDraft.v1"
    /// Set when the personalization prompt has been answered for good — either
    /// a profile was completed, or the lifter asked not to be asked again.
    /// Separate from `hasCompletedWelcome`, which only records that the routing
    /// choice was made: a Free Workout user has completed the welcome and has
    /// deliberately not completed a profile.
    static let hasDeclinedPersonalization = "hasDeclinedPersonalization"
    /// The number of workouts saved since the personalization prompt was last
    /// deferred, so "Not now" means later rather than never.
    static let personalizationPromptDeferralCount = "personalizationPromptDeferralCount"
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
    /// Apple Health workout export is opt-in. Saving locally never depends on
    /// this value or on HealthKit availability/authorization.
    static let healthKitWorkoutExportEnabled = "healthKitWorkoutExportEnabled"
    static let effortMeasure = "effortMeasure"
    /// How the ready-made catalogue is ordered. The *mode* is remembered; the
    /// ranked order itself never is — it is recomputed from the current profile
    /// on every appearance, so it cannot go stale the way a cached order could.
    static let catalogueOrdering = "catalogueOrdering.v1"
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
