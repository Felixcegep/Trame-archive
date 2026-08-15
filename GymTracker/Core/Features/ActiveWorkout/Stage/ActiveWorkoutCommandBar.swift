import SwiftUI

/// The one bar at the bottom of Active Workout, and the one place the session's
/// next action lives.
///
/// Before this, completing a set had three entry points and no obvious one: a
/// left-swipe on the card (undiscoverable, unreachable with VoiceOver), a
/// checkmark circle at the end of a row (44pt, at the edge of a one-handed
/// reach), and a "Complete set" button that only existed while the keypad was
/// raised. The most frequent action in the app — performed eight to thirty
/// times a session, often without looking — had no fixed location.
///
/// It has one now. The centre slot always holds whatever the session needs
/// next, and only one thing at a time.
struct ActiveWorkoutCommandBar: View {
    /// What the centre slot is currently for.
    enum PrimaryAction: Equatable {
        /// A set on this page is ready to be marked done.
        case logSet(isEnabled: Bool)
        /// Rest is running and the takeover is collapsed; the pill is the way
        /// back to it.
        case resting
        /// Rest has ended and the next set is waiting.
        case startNextSet
        /// This page is finished and there is work further along.
        case nextExercise
        /// Every set is logged.
        case finish(isEnabled: Bool)
        /// The workout has no exercises yet. This is the session's first and
        /// only meaningful action, so it belongs in the fixed primary slot.
        case addExercise
        /// Nothing to offer — an empty workout, or a page with no sets.
        ///
        /// Named `idle` rather than `none` so it can never be mistaken for
        /// `Optional.none` at a call site that switches over it.
        case idle
    }

    let primaryAction: PrimaryAction
    let restEndDate: Date?
    let isRestPaused: Bool
    let pausedRemaining: TimeInterval
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            arrowButton(
                systemImage: AppIcon.chevronLeft,
                label: "Previous exercise",
                identifier: "stage-previous",
                isEnabled: canGoBack,
                action: onBack
            )

            primarySlot

            arrowButton(
                systemImage: AppIcon.chevronRight,
                label: "Next exercise",
                identifier: "stage-next",
                isEnabled: canGoForward,
                action: onForward
            )
        }
        .padding(.horizontal, Spacing.screenInset)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.s)
        .background(Color.trameSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-workout-command-bar")
    }

    @ViewBuilder
    private var primarySlot: some View {
        switch primaryAction {
        case .logSet(let isEnabled):
            primaryButton(
                title: "Log",
                systemImage: nil,
                identifier: "log-set",
                isEnabled: isEnabled,
                hint: String(localized: "Marks the current set complete and starts rest.")
            )

        case .startNextSet:
            primaryButton(
                title: "Start next set",
                systemImage: AppIcon.play,
                identifier: "start-next-set-bar",
                isEnabled: true,
                hint: nil
            )

        case .nextExercise:
            primaryButton(
                title: "Next exercise",
                systemImage: AppIcon.chevronRight,
                identifier: "advance-exercise",
                isEnabled: true,
                hint: nil
            )

        case .finish(let isEnabled):
            primaryButton(
                title: "Finish workout",
                systemImage: AppIcon.checkmarkCircle,
                identifier: "finish-workout",
                isEnabled: isEnabled,
                hint: isEnabled
                    ? nil
                    : String(localized: "Complete at least one set before finishing.")
            )

        case .addExercise:
            primaryButton(
                title: "Add exercise",
                systemImage: AppIcon.plus,
                identifier: "add-first-exercise",
                isEnabled: true,
                hint: String(localized: "Opens the exercise library for this workout.")
            )

        case .resting:
            ActiveWorkoutRestPill(
                restEndDate: restEndDate,
                isRestPaused: isRestPaused,
                pausedRemaining: pausedRemaining,
                action: onPrimary
            )

        case .idle:
            // Holds the slot open so the arrows do not slide inward and back
            // out as pages change — a bar whose controls move is a bar you
            // have to look at.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .accessibilityHidden(true)
        }
    }

    private func primaryButton(
        title: LocalizedStringKey,
        systemImage: String?,
        identifier: String,
        isEnabled: Bool,
        hint: String?
    ) -> some View {
        Button(action: onPrimary) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
                    .tracking(0.7)
                    .textCase(.uppercase)
            }
        }
        .buttonStyle(.tramePrimaryAction)
        .disabled(!isEnabled)
        .accessibilityHint(Text(hint ?? ""))
        .accessibilityIdentifier(identifier)
    }

}

/// The collapsed form of the rest takeover. It is shared by the command bar
/// and the focused-input panel so opening the keypad never hides an active
/// timer or removes the route back to its full-screen controls.
struct ActiveWorkoutRestPill: View {
    let restEndDate: Date?
    let isRestPaused: Bool
    let pausedRemaining: TimeInterval
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: isRestPaused ? AppIcon.pause : AppIcon.timer)
                    .font(AppFont.subheadlineBold)

                if isRestPaused {
                    Text(clockText(pausedRemaining))
                        .font(AppFont.titleSmallSemiboldMonospaced)
                } else if let restEndDate,
                          let interval = LiveActivityTimeRange.restInterval(now: .now, end: restEndDate) {
                    Text(timerInterval: interval, countsDown: true)
                        .font(AppFont.titleSmallSemiboldMonospaced)
                        .monospacedDigit()
                } else {
                    Text("Ready")
                        .font(AppFont.titleSmallSemibold)
                }
            }
            .foregroundStyle(Color.gymAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        // The countdown re-reads every second if it is part of the label, which
        // is exactly what a VoiceOver user does not want from a status control.
        .accessibilityLabel(Text(isRestPaused ? "Rest paused" : "Resting"))
        .accessibilityHint(Text("Show the full rest timer"))
        .accessibilityIdentifier("rest-pill")
    }

    private func clockText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private extension ActiveWorkoutCommandBar {
    func arrowButton(
        systemImage: String,
        label: LocalizedStringKey,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(isEnabled ? Color.trameText : Color.trameSubdued)
                .frame(width: ComponentSize.minimumTouchTarget, height: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

}
