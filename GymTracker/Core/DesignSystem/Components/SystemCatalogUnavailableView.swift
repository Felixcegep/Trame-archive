import SwiftUI

/// The empty state shown in place of "create your first one" when the
/// bundled system catalogue failed to install.
///
/// The exercise library, the workout list, and the ready-made plan catalogue
/// all lose their content the exact same way when this happens — none of them
/// caused it, and none of them can tell the person anything more specific than
/// "the built-in content did not install." Sharing one view keeps that wording
/// identical across all three instead of drifting into three slightly
/// different explanations of the same failure.
///
/// `.gymAccent` is this design system's token for "an attention fact, not a
/// hazard" — see its doc comment in `Colors.swift`. Nothing here is a hazard:
/// the person's own workouts, plans and exercises are untouched, and retrying
/// is always available.
struct SystemCatalogUnavailableView: View {
    let onRetry: () -> Void

    @State private var isRetrying = false

    var body: some View {
        ContentUnavailableView {
            Label("Built-in content unavailable", systemImage: AppIcon.warningCircle)
                .foregroundStyle(Color.gymAccent)
        } description: {
            Text("Trame's built-in exercises, workouts, and plans couldn't be installed. Your own data is unaffected.")
        } actions: {
            Button(action: retry) {
                if isRetrying {
                    ProgressView()
                } else {
                    Text("Retry")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymAccent)
            .disabled(isRetrying)
            .accessibilityIdentifier("retry-system-catalog-install")
        }
        .accessibilityIdentifier("system-catalog-unavailable")
    }

    /// `onRetry` calls back into `AppBootstrap.seedSystemCatalog`, the same
    /// synchronous, `@MainActor` entry point launch uses — there is no second
    /// installation path to keep in sync with this one. It has no `await`
    /// inside it, so wrapping it in a `Task` would not free the main thread
    /// during the reinstall; `isRetrying` exists to block a double-tap and
    /// give the button something to show, not to prove the work is async.
    private func retry() {
        isRetrying = true
        onRetry()
        isRetrying = false
    }
}
