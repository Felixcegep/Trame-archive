import Foundation

/// Coarse, privacy-safe product destinations reported to beta feedback
/// diagnostics. Never extend this with workout names, exercise names, plan
/// names, search text, dates, IDs, or any other user-authored content.
enum AppScreen: String, CaseIterable, Sendable {
    case today
    case train
    case nutrition
    case progress
    case settings
    case activeWorkout
    case workoutSave
    case activeMobility

    var diagnosticLabel: String {
        switch self {
        case .today: "Today"
        case .train: "Train"
        case .nutrition: "Nutrition"
        case .progress: "Progress"
        case .settings: "Settings"
        case .activeWorkout: "Active Workout"
        case .workoutSave: "Workout Save"
        case .activeMobility: "Active Mobility"
        }
    }

    /// Derives the current logical screen from root-owned navigation state.
    /// A pure function so the resolution rules (Active Workout supersedes its
    /// underlying tab, a dismissed sheet restores the correct destination)
    /// are unit-testable without a live view hierarchy.
    static func current(
        selectedTab: AppTab,
        isSettingsPresented: Bool,
        isShowingActiveWorkout: Bool,
        isShowingWorkoutSave: Bool,
        isShowingActiveMobility: Bool
    ) -> AppScreen {
        if isShowingActiveWorkout {
            return isShowingWorkoutSave ? .workoutSave : .activeWorkout
        }
        if isShowingActiveMobility {
            return .activeMobility
        }
        if isSettingsPresented {
            return .settings
        }
        switch selectedTab {
        case .today: return .today
        case .train: return .train
        case .nutrition: return .nutrition
        case .progress: return .progress
        }
    }
}
