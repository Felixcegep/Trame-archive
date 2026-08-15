import SwiftUI
import SwiftData

struct SetDurationCountdownView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let viewModel: ActiveWorkoutViewModel
    let coordinator: SetInputCoordinator
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
                countdownStrip(surface: Color.trameRow) {
                    Image(systemName: AppIcon.checkmarkCircle)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameCompleted)

                    Text("Time complete")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.reset,
                        label: "Restart timer",
                        tint: Color.trameCompleted,
                        action: startCountdown
                    )
                }
            } else if let countdownEndDate {
                countdownStrip(surface: Color.trameCurrent) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameText)

                    Text(timerInterval: Date.now...max(Date.now, countdownEndDate), countsDown: true)
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.trameText)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.pause,
                        label: "Pause timer",
                        tint: Color.trameText,
                        action: pauseCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.trameText,
                        action: resetCountdown
                    )
                }
            } else if let pausedCountdownRemaining, pausedCountdownRemaining > 0 {
                countdownStrip(surface: Color.trameAttention) {
                    Image(systemName: AppIcon.timer)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.trameAttentionInk)

                    Text(formatCountdown(pausedCountdownRemaining))
                        .font(AppFont.headlineMonospaced)
                        .foregroundStyle(Color.trameAttentionInk)

                    Text("Paused")
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.trameAttentionInk)

                    Spacer(minLength: 0)

                    countdownControlButton(
                        AppIcon.play,
                        label: "Resume timer",
                        tint: Color.trameAttentionInk,
                        action: resumeCountdown
                    )
                    countdownControlButton(
                        AppIcon.reset,
                        label: "Reset timer",
                        tint: Color.trameAttentionInk,
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
                    .foregroundStyle(Color.trameText)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .background(
                        Color.trameCurrent,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .contentShape(Rectangle())
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
        .gymFeedback(.timedTargetReached, trigger: countdownFinished) { _, newValue in
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
                .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                .background(Color.trameSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private func startCountdown() {
        guard countdownTargetSeconds > 0 else {
            completionValidationMessage = "Enter seconds before starting the timer."
            coordinator.focus = setFocus
            return
        }
        coordinator.focus = nil
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
