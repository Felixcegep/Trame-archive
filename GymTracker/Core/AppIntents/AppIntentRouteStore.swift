import Foundation
import Observation

/// The single foreground handoff surface for discoverable App Intents.
/// The intent persists workout truth first, then RootView consumes this route
/// exactly once to present the appropriate execution UI.
@MainActor
@Observable
final class AppIntentRouteStore {
    static let shared = AppIntentRouteStore()

    enum Destination: Equatable {
        case activeWorkout(UUID)
        case today
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
