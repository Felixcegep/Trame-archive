import Foundation
import Observation

/// Whether the bundled system catalogue — exercises, workout templates,
/// programs, and mobility content — is known to have failed to install.
///
/// `AppBootstrap.seedSystemCatalog` used to print the error and move on, so a
/// person staring at an empty exercise library or an empty plan catalogue had
/// no way to tell "you have not created anything yet" from "253 bundled
/// exercises just failed to seed, and none of this is because of anything you
/// did." The empty states that would otherwise lie about that read `failure`
/// here to tell the two apart, and to offer the one recovery action that
/// actually helps — retrying the same install this holds state for.
///
/// A `@MainActor @Observable` singleton rather than something threaded through
/// the view hierarchy: the screens that need to read it — the exercise
/// library, the workout list, the ready-made plan catalogue — sit under
/// separate tabs and separate navigation stacks, several layers below the
/// `RootView` that runs the install. `AppIntentRouteStore` solves the same
/// "one piece of app-level state, read from far-apart screens" shape the same
/// way, so this follows it rather than inventing a second pattern.
@MainActor
@Observable
final class SystemCatalogInstallState {
    static let shared = SystemCatalogInstallState()

    struct Failure: Equatable {
        /// Not shown to the user — empty states name the failure in plain
        /// language, never a Swift error string. This is what a support
        /// conversation or a future diagnostics screen would need to make the
        /// failure actionable instead of just "it didn't work."
        let diagnosticDescription: String
        let occurredAt: Date
    }

    private(set) var failure: Failure?

    private init() {}

    func recordFailure(_ error: Error) {
        failure = Failure(diagnosticDescription: String(describing: error), occurredAt: .now)
    }

    /// Called after a successful install, including a retry, so a screen that
    /// was showing the failure state returns to its normal empty or populated
    /// state on the very next observation pass.
    func clearFailure() {
        failure = nil
    }
}

/// Whether the save `RootView` issues while the app backgrounds is known to
/// have failed.
///
/// This exists to retain retry state across scene transitions — "did the last
/// durability save fail?" RootView retries it on foreground. Deliberately no
/// screen presents the failure while the app is backgrounding, where an alert
/// would disappear before it could be acted on.
@MainActor
@Observable
final class BackgroundSaveFailureState {
    static let shared = BackgroundSaveFailureState()

    struct Failure: Equatable {
        let diagnosticDescription: String
        let occurredAt: Date
    }

    private(set) var lastFailure: Failure?

    private init() {}

    func recordFailure(_ error: Error) {
        lastFailure = Failure(diagnosticDescription: String(describing: error), occurredAt: .now)
    }

    func clearFailure() {
        lastFailure = nil
    }
}
