import SwiftData
import SwiftUI

/// Focused execution surface for a shared block. The timer and next action
/// stay visually dominant while configuration and score editing remain
/// secondary actions below the one-handed controls.
struct WorkoutExecutionBlockEyesUpView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: WorkoutExecutionBlock
    let workout: Workout
    let onPersist: () -> Void
    let onRoundCompleted: () -> Void
    let onRecordScore: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    @State private var currentComponentOrder = 0

    var body: some View {
        Group {
            if block.clockMode != .none {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    surface(at: context.date)
                        .onChange(of: context.date) { _, date in
                            guard WorkoutExecutionBlockService.enforceClock(block, at: date) else { return }
                            let componentCount = WorkoutExecutionBlockService.entries(
                                in: block,
                                workout: workout
                            ).count
                            try? WorkoutExecutionBlockSplitService.recordEnforcedTerminalIfNeeded(
                                block: block,
                                componentCount: componentCount,
                                at: date,
                                using: modelContext
                            )
                            onPersist()
                        }
                }
            } else {
                surface(at: .now)
            }
        }
        .task(id: block.id) { refreshCursor() }
    }

    private func surface(at date: Date) -> some View {
        let presentation = WorkoutExecutionBlockPresentation.make(block: block, workout: workout, at: date)
        return GymCard(variant: presentation.phase == .running || presentation.phase == .paused ? .current : .standard) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header(presentation)
                if presentation.timerText != nil {
                    timer(presentation)
                }
                movementSequence(presentation)
                progressSummary(presentation)
                controls(presentation)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("execution-block-eyes-up-\(block.id.uuidString)")
    }

    private func header(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: AppIcon.relationship)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(block.name ?? presentation.formatTitle)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(presentation.formatTitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: 0)
            GymStatusBadge(
                title: phaseTitle(presentation.phase),
                systemImage: phaseIcon(presentation.phase),
                tint: phaseTint(presentation.phase)
            )
        }
    }

    private func timer(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        VStack(spacing: Spacing.xs) {
                Text(presentation.timerText ?? String(localized: "—"))
                .font(AppFont.displayLarge)
                .foregroundStyle(presentation.phase == .capped ? Color.gymDestructive : Color.gymText)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(presentation.timerAccessibilityText ?? String(localized: "Time unavailable"))

            if let intervalText = presentation.intervalText {
                Text(intervalText)
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
    }

    private func movementSequence(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(localized: "ORDERED SEQUENCE"))
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)

            if presentation.movementSequence.isEmpty {
                Text(String(localized: "No movements assigned"))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                ForEach(Array(presentation.movementSequence.enumerated()), id: \.offset) { index, movement in
                    let isCurrent = index == currentComponentOrder
                    HStack(spacing: Spacing.s) {
                        Image(systemName: isCurrent ? AppIcon.currentPointer : AppIcon.chevronRight)
                            .foregroundStyle(isCurrent ? Color.gymPrimary : Color.gymSubduedText)
                            .accessibilityHidden(true)
                        Text(isCurrent
                            ? String(format: String(localized: "Current: %@"), movement)
                            : sequencePhrase(index: index, movement: movement))
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(isCurrent ? Color.gymText : Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
        }
        .padding(Spacing.s)
        .background(Color.gymMutedSurface, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sequenceAccessibilityLabel(presentation.movementSequence))
    }

    private func sequenceAccessibilityLabel(_ movements: [String]) -> String {
        guard !movements.isEmpty else { return String(localized: "Ordered sequence, no movements assigned") }
        let sequence = movements.enumerated().map { index, movement in
            sequencePhrase(index: index, movement: movement)
        }.joined(separator: ". ")
        return String(format: String(localized: "Ordered sequence. %@"), sequence)
    }

    private func sequencePhrase(index: Int, movement: String) -> String {
        if index == 0 {
            return String(format: String(localized: "Start with %@"), movement)
        }
        return String(format: String(localized: "Then %@"), movement)
    }

    private func progressSummary(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        HStack(spacing: Spacing.m) {
            if let progressText = presentation.progressText {
                Label(progressText, systemImage: AppIcon.number)
            }
            if let scoreText = presentation.scoreText {
                Label(
                    String(format: String(localized: "Score %@"), scoreText),
                    systemImage: AppIcon.checkmarkCircle
                )
            }
        }
        .font(AppFont.captionSemiboldMonospaced)
        .foregroundStyle(Color.gymSubduedText)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func controls(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        if presentation.primaryAction != .none {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Button(action: primaryAction) {
                        Label(
                            presentation.primaryActionTitle ?? String(localized: "Advance"),
                            systemImage: primaryIcon(presentation.primaryAction)
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.gymPrimary)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityHint(
                        presentation.primaryActionHint ?? String(localized: "Starts the shared block clock")
                    )

                    if let capTitle = presentation.capActionTitle {
                        Button(action: cap) {
                            Label(capTitle, systemImage: AppIcon.stop)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.gymSubduedText)
                        .frame(minHeight: ComponentSize.minimumTouchTarget)
                    }
                }

                HStack(spacing: Spacing.m) {
                    if let pauseTitle = presentation.pauseActionTitle, presentation.canPause {
                        Button(pauseTitle, action: toggleClockPause)
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.gymPrimary)
                            .frame(minHeight: ComponentSize.minimumTouchTarget)
                    }
                    secondaryActions
                }
            }
        } else {
            HStack(spacing: Spacing.m) {
                secondaryActions
            }
        }
    }

    private var secondaryActions: some View {
        Menu {
            Button(String(localized: "Edit block"), action: onEdit)
            if block.scoreKind != .none {
                Button(
                    block.status == .inProgress
                        ? String(localized: "Record score")
                        : String(localized: "Edit score"),
                    action: onRecordScore
                )
            }
            Divider()
            Button(String(localized: "Remove block"), role: .destructive, action: onRemove)
        } label: {
            Label(String(localized: "More"), systemImage: AppIcon.ellipsis)
        }
        .font(AppFont.captionBold)
        .foregroundStyle(Color.gymPrimary)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
    }

    private func primaryAction() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            let action = WorkoutExecutionBlockPresentation.make(block: block, workout: workout).primaryAction
            switch action {
            case .start:
                _ = WorkoutExecutionBlockService.apply(.start(at: .now), to: block)
            case .advance:
                let entries = WorkoutExecutionBlockService.entries(in: block, workout: workout)
                do {
                    let split = try WorkoutExecutionBlockSplitService.advance(
                        block: block,
                        componentCount: entries.count,
                        commandID: UUID(),
                        at: .now,
                        using: modelContext
                    )
                    refreshCursor()
                    if split.kind == .roundCompleted { onRoundCompleted() }
                    onPersist()
                    return
                } catch {
                    return
                }
            case .complete:
                let count = WorkoutExecutionBlockService.entries(in: block, workout: workout).count
                _ = try? WorkoutExecutionBlockSplitService.complete(
                    block: block,
                    componentCount: count,
                    commandID: UUID(),
                    at: .now,
                    using: modelContext
                )
            case .none:
                return
            }
            onPersist()
        }
    }

    private func refreshCursor() {
        let count = WorkoutExecutionBlockService.entries(in: block, workout: workout).count
        guard count > 0,
              let cursor = try? WorkoutExecutionBlockSplitService.cursor(
                for: block.id,
                componentCount: count,
                using: modelContext
              )
        else {
            currentComponentOrder = 0
            return
        }
        currentComponentOrder = cursor.componentOrder
    }

    private func cap() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            if block.timeCapSeconds == nil {
                WorkoutExecutionBlockService.stop(block)
            } else {
                let count = WorkoutExecutionBlockService.entries(in: block, workout: workout).count
                _ = try? WorkoutExecutionBlockSplitService.cap(
                    block: block,
                    componentCount: count,
                    commandID: UUID(),
                    at: .now,
                    using: modelContext
                )
            }
            onPersist()
        }
    }

    private func toggleClockPause() {
        withAnimation(reduceMotion ? nil : AppMotion.compact) {
            if block.elapsedStartedAt == nil {
                _ = WorkoutExecutionBlockService.apply(.resume(at: .now), to: block)
            } else {
                _ = WorkoutExecutionBlockService.apply(.pause(at: .now), to: block)
            }
            onPersist()
        }
    }

    private func primaryIcon(_ action: WorkoutExecutionBlockPrimaryAction) -> String {
        switch action {
        case .start: AppIcon.play
        case .advance, .complete: AppIcon.checkmark
        case .none: AppIcon.circle
        }
    }

    private func phaseTitle(_ phase: WorkoutExecutionBlockExecutionPhase) -> String {
        switch phase {
        case .ready: String(localized: "Not started")
        case .running: String(localized: "In progress")
        case .paused: String(localized: "Paused")
        case .completed: String(localized: "Complete")
        case .capped: String(localized: "Time capped")
        case .partial: String(localized: "Partial")
        case .stopped: String(localized: "Stopped")
        case .skipped: String(localized: "Skipped")
        }
    }

    private func phaseIcon(_ phase: WorkoutExecutionBlockExecutionPhase) -> String {
        switch phase {
        case .ready: AppIcon.circle
        case .running: AppIcon.play
        case .paused: AppIcon.pause
        case .completed: AppIcon.checkmarkCircle
        case .capped: AppIcon.timer
        case .partial, .stopped: AppIcon.stop
        case .skipped: AppIcon.skip
        }
    }

    private func phaseTint(_ phase: WorkoutExecutionBlockExecutionPhase) -> Color {
        switch phase {
        case .completed: .gymSecondary
        case .capped, .stopped: .gymDestructive
        case .paused: .gymAccent
        default: .gymPrimary
        }
    }
}
