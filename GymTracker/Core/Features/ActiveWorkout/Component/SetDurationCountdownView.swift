import SwiftUI
import SwiftData

struct SetDurationCountdownView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let focusedInput: FocusState<SetInputFocus?>.Binding
    @Binding var completionValidationMessage: String?
    @Binding var isTimerRunning: Bool

    @State private var countdownEndDate: Date?
    @State private var pausedCountdownRemaining: TimeInterval?
    @State private var countdownFinished = false

    private var setFocus: SetInputFocus {
        SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID
        )
    }

    private var countdownTargetSeconds: Int {
        max(0, Int(exerciseSet.duration ?? 0))
    }

    var body: some View {
        Group {
            if countdownFinished {
                countdownStrip(surface: Color.gymMutedSurface) {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymSecondary)

                    Text("Time complete")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymSecondary)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.reset,
                        label: "Restart timer",
                        tint: Color.gymSecondary,
                        action: startCountdown
                    )
                }
            } else if let countdownEndDate {
                countdownStrip(surface: Color.gymPrimarySurface) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymPrimary)

                    Text(timerInterval: Date.now...max(Date.now, countdownEndDate), countsDown: true)
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymPrimary)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.pause,
                        label: "Pause timer",
                        tint: Color.gymPrimary,
                        action: pauseCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.gymPrimary,
                        action: resetCountdown
                    )
                }
            } else if let pausedCountdownRemaining, pausedCountdownRemaining > 0 {
                countdownStrip(surface: Color.gymAccentSurface) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymAccent)

                    Text(formatCountdown(pausedCountdownRemaining))
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.gymAccent)

                    Text("Paused")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.play,
                        label: "Resume timer",
                        tint: Color.gymAccent,
                        action: resumeCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.gymAccent,
                        action: resetCountdown
                    )
                }
            } else {
                Button(action: startCountdown) {
                    Label(
                        countdownTargetSeconds > 0 ? "Start \(countdownTargetSeconds) sec timer" : "Start timer",
                        systemImage: AppIcon.play
                    )
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.gymPrimarySurface, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("start-countdown-\(exerciseEntry.exercise.name)-\(index)")
            }
        }
        .padding(.leading, 45)
        .accessibilityElement(children: .contain)
        .task(id: countdownEndDate) {
            guard let countdownEndDate else { return }
            let delay = max(0, countdownEndDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, self.countdownEndDate == countdownEndDate else { return }
            self.countdownEndDate = nil
            pausedCountdownRemaining = 0
            countdownFinished = true
            isTimerRunning = false
        }
        .sensoryFeedback(.success, trigger: countdownFinished) { _, newValue in
            newValue
        }
    }

    private func countdownStrip(surface: Color, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Spacing.s) {
            content()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs + Spacing.xxs)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private func countdownControlButton(
        _ icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(AppFont.captionBold)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Color.gymCard, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private func startCountdown() {
        guard countdownTargetSeconds > 0 else {
            completionValidationMessage = "Enter seconds before starting the timer."
            focusedInput.wrappedValue = setFocus
            return
        }
        focusedInput.wrappedValue = nil
        completionValidationMessage = nil
        countdownFinished = false
        pausedCountdownRemaining = nil
        countdownEndDate = Date.now.addingTimeInterval(TimeInterval(countdownTargetSeconds))
        isTimerRunning = true
    }

    private func pauseCountdown() {
        guard let countdownEndDate else { return }
        pausedCountdownRemaining = max(0, countdownEndDate.timeIntervalSinceNow)
        self.countdownEndDate = nil
        isTimerRunning = false
    }

    private func resumeCountdown() {
        guard let pausedCountdownRemaining, pausedCountdownRemaining > 0 else { return }
        countdownFinished = false
        countdownEndDate = Date.now.addingTimeInterval(pausedCountdownRemaining)
        self.pausedCountdownRemaining = nil
        isTimerRunning = true
    }

    private func resetCountdown() {
        countdownEndDate = nil
        pausedCountdownRemaining = nil
        countdownFinished = false
        isTimerRunning = false
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let roundedSeconds = Int(ceil(seconds))
        return String(format: "%d:%02d", roundedSeconds / 60, roundedSeconds % 60)
    }
}
