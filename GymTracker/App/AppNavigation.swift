import Foundation

/// Stable identities for GymTracker's four major destinations.
///
/// Active workout and mobility execution are deliberately excluded: they are
/// root-owned full-screen flows rather than tabs.
enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today
    case train
    case nutrition
    case progress

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .train: "Train"
        case .nutrition: "Nutrition"
        case .progress: "Progress"
        }
    }

    var icon: String {
        switch self {
        case .today: AppIcon.home
        case .train: AppIcon.workout
        case .nutrition: AppIcon.nutrition
        case .progress: AppIcon.history
        }
    }

    var accessibilityIdentifier: String { "tab-\(rawValue)" }
}

enum TodayRoute: Hashable {
    case trainingCalendar
    case settings
    /// The backup group inside Settings. A route of its own because export and
    /// import are the one part of Settings something outside it needs to reach
    /// directly — a restore prompt, or a test driving an import.
    case settingsData
    /// The plan Today says you are following. Reachable from the header chip so
    /// pausing or stopping a plan does not require hunting through the Train tab.
    case plan(UUID)
    case repeatingPlan(UUID)
    case programPath(ProgramPathRoute)
    case weeklyReview(WeeklyProgramReviewRoute)
}

enum NutritionRoute: Hashable {
    case foodLibrary
    case mealTemplates
    case targets
}

enum ProgressRoute: Hashable {
    case workoutHistory
    case records
    case trainingTrends
    case muscleGroupVolume
    case mobilityHistory
    /// Recorded observations, kept separate from `mobilityHistory`: performed
    /// routine work and measured evidence are two different kinds of record.
    case mobilityAssessmentHistory
    case nutritionHistory
    case journalHistory
}
