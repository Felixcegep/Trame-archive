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
        case .train: AppIcon.train
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

/// Which record `ProgressRoute.supportingHistory` opens on.
///
/// Ordered as the picker presents them: the two always-available scopes first,
/// then the gated one, so hiding nutrition never leaves a hole in the middle.
enum SupportingHistoryScope: String, CaseIterable, Hashable, Identifiable {
    case mobility
    case journal
    case nutrition

    var id: Self { self }

    var title: String {
        switch self {
        case .mobility: String(localized: "Mobility")
        case .journal: String(localized: "Journal")
        case .nutrition: String(localized: "Nutrition")
        }
    }

    var accessibilityIdentifier: String { "supporting-history-scope-\(rawValue)" }
}

enum NutritionRoute: Hashable {
    case foodLibrary
    case mealTemplates
    case targets
}

enum ProgressRoute: Hashable {
    case workoutHistory
    /// Training history read across plans. Distinct from `workoutHistory`,
    /// which lists sessions, and from Program Path, which stays inside one run.
    case trainingJourney
    case records
    case trainingTrends
    case muscleGroupVolume
    case weightlifting
    case trainingLedger
    case coachExchange
    /// Mobility routines, journal check-ins and logged meals — one screen with
    /// a scope picker rather than three rows opening three near-identical
    /// lists. The scope travels in the route so a deep link (a calendar day, a
    /// notification) still lands on the record it meant.
    case supportingHistory(SupportingHistoryScope)
    /// Recorded observations, kept separate from `supportingHistory`: performed
    /// routine work and measured evidence are two different kinds of record,
    /// and this one is feature-gated where those are not.
    case mobilityAssessmentHistory
}
