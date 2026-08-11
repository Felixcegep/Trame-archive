import SwiftUI

/// Rest state, pinned above the workout list.
///
/// This used to be a card at the top of the scrolling content, which meant it
/// was visible exactly when the workout was short enough not to need scrolling.
/// The moment a session had enough exercises for the lifter to scroll — the
/// moment rest matters — the countdown, the "what's next" line, and every
/// control went off screen together. Reading the next exercise and watching the
/// clock were mutually exclusive.
///
/// It is the same reasoning that gave the set-entry panel its own context
/// header: a surface the user depends on cannot be attached to a scroll
/// position they are going to change.
///
/// **It collapses during set entry.** With the keypad raised, the panel and
/// keypad already own most of the screen, and the lifter is typing a value
/// rather than adjusting rest. In that state this keeps the countdown and the
/// next set — the two things worth knowing — and drops the controls, which
/// return when the keypad closes.
struct RestStatusStrip: View {
    let viewModel: ActiveWorkoutViewModel
    let activeLoggingMetrics: ActiveLoggingMetricsRecorder
    /// Falls back to a placeholder for the paused case, which has no end date.
    let endDate: Date
    let nextSetDescription: String?
    /// True while the keypad is up.
    let isCompact: Bool
    let onStartNextSet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.s) {
            summaryRow

            // A determinate progress bar belongs here — the countdown is read at
            // arm's length mid-set, where the question is "nearly done?" and
            // answering it should not require parsing digits. It is deliberately
            // *not* implemented yet: rendering elapsed-versus-total needs a rest
            // duration, and nothing stores one. `Workout.restEndDate` is the only
            // persisted rest state, and `RestTimerController` tracks an end date
            // alone. Adding the total means changing a component CE-01 has just
            // certified, so it waits for a pass that can run those tests.
            if !isCompact {
                controlRow
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Color.gymAccentSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gymBorder)
                .frame(height: 1)
        }
        .animation(reduceMotion ? nil : AppMotion.compact, value: isCompact)
        .animation(reduceMotion ? nil : AppMotion.compact, value: viewModel.isRestReady)
        // One element carrying purpose and state, so VoiceOver reads it as a
        // status rather than walking a countdown that changes every second.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var summaryRow: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.timer)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(Color.gymText)
                if let nextSetDescription {
                    Text(nextSetDescription)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.s)

            remainingTime
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    @ViewBuilder
    private var remainingTime: some View {
        if viewModel.isRestReady {
            Text("Ready")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymSecondary)
        } else if viewModel.isTimerPaused {
            // The most time-critical number on the screen, so it is the
            // largest thing in the strip rather than smaller than the
            // workout title as it used to be.
            Text(formattedRemaining(viewModel.pausedTimeRemaining))
                .font(AppFont.titleSmallSemiboldMonospaced)
                .foregroundStyle(Color.gymAccent)
        } else if let interval = LiveActivityTimeRange.restInterval(now: .now, end: endDate) {
            Text(timerInterval: interval, countsDown: true)
                .font(AppFont.titleSmallSemiboldMonospaced)
                .foregroundStyle(Color.gymAccent)
                .monospacedDigit()
        } else {
            // A persisted deadline can expire while SwiftUI waits for the
            // rest-state task to mark it ready. Never build an invalid range.
            Text("Ready")
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymSecondary)
        }
    }

    @ViewBuilder
    private var controlRow: some View {
        if viewModel.isRestReady {
            Button("Start next set", action: onStartNextSet)
                .buttonStyle(.borderedProminent)
                .tint(Color.gymPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("start-next-set")
        } else {
            // Each control carries the touch-target minimum itself.
            //
            // These four are what a lifter reaches for between sets: one-handed,
            // frequently with chalk or sweat on their fingers, sometimes without
            // looking away from the rack. They were `.controlSize(.small)`, which
            // renders around 28pt against a 44pt minimum — the tightest targets
            // in the app, on the screen least able to afford them.
            //
            // The height is applied per button rather than to the row: unlike
            // `buttonStyle` and `tint`, `frame` does not propagate to children,
            // so sizing the `HStack` would have grown the strip and left every
            // hit area exactly as small as it was.
            HStack(spacing: Spacing.s) {
                Button("+15s") { viewModel.addRestTime(15) }
                    .restControlSize()
                Button("+30s") { viewModel.addRestTime(30) }
                    .restControlSize()

                Spacer(minLength: 0)

                Button {
                    if viewModel.isTimerPaused {
                        viewModel.resumeTimer()
                    } else {
                        viewModel.pauseTimer()
                    }
                } label: {
                    Image(systemName: viewModel.isTimerPaused ? "play.fill" : "pause.fill")
                }
                .restControlSize()
                .accessibilityLabel(viewModel.isTimerPaused ? "Resume rest" : "Pause rest")

                Button {
                    activeLoggingMetrics.restSkipped()
                    viewModel.cancelTimer()
                } label: {
                    Image(systemName: AppIcon.fastForward)
                }
                .restControlSize()
                .accessibilityLabel("Skip rest")
            }
            .buttonStyle(.bordered)
            .tint(Color.gymAccent)
        }
    }

    private var title: String {
        if viewModel.isRestReady { return String(localized: "Rest complete") }
        if viewModel.isTimerPaused { return String(localized: "Rest paused") }
        return String(localized: "Rest between sets")
    }

    /// Spoken as one sentence. The countdown is deliberately excluded from the
    /// running case: it changes every second, and re-reading it on each tick is
    /// exactly what `Documentation/Accessibility.md` warns against.
    private var summaryAccessibilityLabel: String {
        var parts = [title]
        if viewModel.isTimerPaused {
            parts.append(String(localized: "\(Int(viewModel.pausedTimeRemaining)) seconds remaining"))
        }
        if let nextSetDescription {
            parts.append(nextSetDescription)
        }
        return parts.joined(separator: ". ")
    }

    private var accessibilityIdentifier: String {
        if viewModel.isRestReady { return "rest-ready" }
        return viewModel.isTimerPaused ? "rest-paused" : "rest-running"
    }

    private func formattedRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private extension View {
    /// The rest controls' shared sizing: at least the minimum touch target in
    /// both axes, with the tappable area filling the frame rather than hugging
    /// the glyph.
    func restControlSize() -> some View {
        frame(
            minWidth: ComponentSize.minimumTouchTarget,
            minHeight: ComponentSize.minimumTouchTarget
        )
        .contentShape(Rectangle())
    }
}
