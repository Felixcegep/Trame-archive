import Foundation
import Observation

/// A deliberately compact, immutable handoff from Siri or Shortcuts into the
/// personalized-workout builder. It is not a generated draft and is never
/// persisted: the builder owns all validation, review, saving, and workout
/// start decisions after the app is foregrounded.
struct WorkoutGenerationLaunchRequest: Equatable, Sendable {
    let request: String?
    let durationMinutes: Int?
    let focus: String?

    init(request: String? = nil, durationMinutes: Int? = nil, focus: String? = nil) {
        self.request = Self.normalizedText(request)
        self.durationMinutes = durationMinutes.flatMap { (10...180).contains($0) ? $0 : nil }
        self.focus = Self.normalizedText(focus)
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              normalized.isEmpty == false
        else { return nil }
        return normalized
    }
}

/// The single foreground handoff surface for discoverable App Intents.
/// The intent persists workout truth first, then RootView consumes this route
/// exactly once to present the appropriate execution UI.
@MainActor
@Observable
final class AppIntentRouteStore {
    static let shared = AppIntentRouteStore()

    enum Destination: Equatable {
        case activeWorkout(UUID)
        case activeMobility(UUID)
        case today
        /// Opens the editable workout-drafting request flow. This route never
        /// starts generation or writes workout/template data by itself.
        case personalizedWorkout(WorkoutGenerationLaunchRequest)
    }

    private(set) var pendingDestination: Destination?

    private init() {}

    func submit(_ destination: Destination) {
        pendingDestination = destination
    }

    func consume() -> Destination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }
}
