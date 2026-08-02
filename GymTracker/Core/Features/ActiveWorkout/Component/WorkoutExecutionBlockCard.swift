import SwiftUI

/// Compact controls for a shared execution context. Individual set evidence
/// remains on each exercise card, while time, rounds, and score belong here.
struct WorkoutExecutionBlockCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var block: WorkoutExecutionBlock
    let workout: Workout
    let onPersist: () -> Void
    let onRoundCompleted: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var isShowingScoreSheet = false
    @State private var isShowingRemovalConfirmation = false

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                if block.clockMode != .none || block.scoreKind != .none { metrics }
                controls
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("execution-block-\(block.id.uuidString)")
        .sheet(isPresented: $isShowingScoreSheet) {
            BlockScoreEntrySheet(block: block, onPersist: onPersist)
        }
        .confirmationDialog(
            "Remove execution block?",
            isPresented: $isShowingRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove block", role: .destructive, action: onRemove)
        } message: {
            Text("Exercises stay in the workout, but their shared block configuration and score will be removed.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: AppIcon.relationship)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(block.name ?? block.kind.title)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(summary)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: 0)
            Label(block.status.title, systemImage: block.status.icon)
                .font(AppFont.captionBold)
                .foregroundStyle(block.status == .completed ? Color.gymSecondary : Color.gymPrimary)
                .accessibilityLabel("Block status \(block.status.title)")
        }
    }

    private var summary: String {
        let components = WorkoutExecutionBlockService.entries(in: block, workout: workout)
            .map(\.occurrenceDisplayName)
            .joined(separator: " · ")
        let rounds = block.targetRounds.map { "\($0) rounds" }
        let scheme: String?
        switch block.repetitionScheme {
        case .ascendingLadder, .descendingLadder:
            if let start = block.repetitionStart,
               let end = block.repetitionEnd,
               let step = block.repetitionStep {
                scheme = "\(start)–\(end) by \(step)"
            } else {
                scheme = "Ladder"
            }
        case .chipper: scheme = "Chipper"
        case .fixed: scheme = nil
        }
        return [rounds, scheme, components].compactMap { $0 }.joined(separator: " · ")
    }

    private var metrics: some View {
        HStack(spacing: Spacing.l) {
            if block.clockMode != .none {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("TIME")
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymSubduedText)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(timeText(at: context.date))
                                .font(AppFont.subheadlineSemiboldMonospaced)
                                .foregroundStyle(isTimeCapped(at: context.date) ? Color.gymDestructive : Color.gymText)
                            if let interval = block.currentInterval(at: context.date) {
                                Text("Interval \(interval)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .onChange(of: context.date) { _, date in
                            guard WorkoutExecutionBlockService.enforceClock(block, at: date) else { return }
                            onPersist()
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Block time")
            }

            if block.scoreKind == .roundsAndRepetitions {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("SCORE")
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymSubduedText)
                    Text("\(block.completedRounds) + \(block.additionalRepetitions)")
                        .font(AppFont.subheadlineSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score \(block.completedRounds) rounds plus \(block.additionalRepetitions) repetitions")
            } else if let score = block.scoreValue, block.scoreKind != .none {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("SCORE")
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymSubduedText)
                    Text(score.formatted())
                        .font(AppFont.subheadlineSemiboldMonospaced)
                        .foregroundStyle(Color.gymText)
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch block.status {
        case .notStarted:
            Button(action: start) {
                Label("Start block", systemImage: AppIcon.play)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymPrimary)
            .accessibilityHint("Starts the shared block clock")
        case .inProgress:
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Button(action: completePrimaryAction) {
                        Label(primaryActionTitle, systemImage: AppIcon.checkmark)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimary)

                    Button(action: cap) {
                        Label(block.timeCapSeconds == nil ? "Stop block" : "End capped", systemImage: AppIcon.stop)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.gymSubduedText)
                }

                HStack(spacing: Spacing.m) {
                    if block.clockMode != .none {
                        Button(isClockPaused ? "Resume clock" : "Pause clock", action: toggleClockPause)
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.gymPrimary)
                    }
                    Button("Edit block", action: onEdit)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymPrimary)
                    if block.scoreKind != .none {
                        Button("Record score") { isShowingScoreSheet = true }
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.gymPrimary)
                    }
                    Button("Remove block", role: .destructive) {
                        isShowingRemovalConfirmation = true
                    }
                    .font(AppFont.captionBold)
                }
            }
        case .completed, .capped, .partial, .stopped, .skipped:
            HStack(spacing: Spacing.m) {
                Button("Edit block", action: onEdit)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
                if block.scoreKind != .none {
                    Button("Edit score") { isShowingScoreSheet = true }
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymPrimary)
                }
            }
        }
    }

    private var primaryActionTitle: String {
        block.targetRounds != nil || block.scoreKind == .roundsAndRepetitions ? "Complete round" : "Complete block"
    }

    private func start() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            WorkoutExecutionBlockService.start(block)
            onPersist()
        }
    }

    private func completePrimaryAction() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            if block.targetRounds != nil || block.scoreKind == .roundsAndRepetitions {
                WorkoutExecutionBlockService.completeRound(in: block)
                if block.status == .inProgress {
                    onRoundCompleted()
                }
            } else {
                WorkoutExecutionBlockService.complete(block)
            }
            onPersist()
        }
    }

    private func cap() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            if block.timeCapSeconds == nil {
                WorkoutExecutionBlockService.stop(block)
            } else {
                WorkoutExecutionBlockService.cap(block)
            }
            onPersist()
        }
    }

    private var isClockPaused: Bool {
        block.clockMode != .none && block.elapsedStartedAt == nil
    }

    private func toggleClockPause() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            if isClockPaused {
                WorkoutExecutionBlockService.start(block)
            } else {
                WorkoutExecutionBlockService.pause(block)
            }
            onPersist()
        }
    }

    private func timeText(at date: Date) -> String {
        let elapsed = block.elapsedDuration(at: date)
        let displayed = block.clockMode == .countdown
            ? max(0, Double(block.prescribedDurationSeconds ?? 0) - elapsed)
            : elapsed
        return String(format: "%d:%02d", Int(displayed) / 60, Int(displayed) % 60)
    }

    private func isTimeCapped(at date: Date) -> Bool {
        guard let cap = block.timeCapSeconds else { return false }
        return block.elapsedDuration(at: date) >= Double(cap)
    }
}

private extension WorkoutBlockStatus {
    var icon: String {
        switch self {
        case .notStarted: AppIcon.circle
        case .inProgress: AppIcon.play
        case .completed: AppIcon.checkmarkCircle
        case .capped: AppIcon.timer
        case .partial, .stopped: AppIcon.stop
        case .skipped: AppIcon.skip
        }
    }
}
