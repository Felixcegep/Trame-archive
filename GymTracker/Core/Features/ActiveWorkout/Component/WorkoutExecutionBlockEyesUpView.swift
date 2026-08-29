import SwiftData
import SwiftUI

/// Focused execution surface for a shared block. The timer and next action
/// stay visually dominant while configuration and score editing remain
/// secondary actions below the one-handed controls.
struct WorkoutExecutionBlockEyesUpView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        let isLive = presentation.phase == .running || presentation.phase == .paused
        return TrameColorField(
            fill: isLive ? Color.trameCurrent : Color.trameSurface,
            ink: Color.trameText,
            border: isLive ? Color.trameActionOutline : Color.trameSeparator
        ) {
            // Glance is the clock, Read is the component being performed, and
            // Inspect — configuration, score, removal — stays in the rail's
            // menu. The block's own identity is not repeated here: the stage
            // page names the block above this field.
            VStack(alignment: .leading, spacing: Spacing.m) {
                clock(presentation)
                movementSequence(presentation)
                progressSummary(presentation)
                controls(presentation)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("execution-block-eyes-up-\(block.id.uuidString)")
    }

    /// The clock owns the field. The phase is a rule-marked line above it and
    /// takes full ink only while the block is running, so a settled state never
    /// competes with the number that is moving.
    private func clock(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                Rectangle()
                    .fill(phaseTint(presentation.phase))
                    .frame(width: 18, height: 3)
                    .accessibilityHidden(true)

                Text(phaseTitle(presentation.phase))
                    .font(AppFont.micro)
                    .tracking(0.55)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        presentation.phase == .running ? Color.trameText : Color.trameSubdued
                    )

                Spacer(minLength: Spacing.s)

                if let intervalText = presentation.intervalText {
                    Text(intervalText)
                        .font(AppFont.captionSemiboldMonospaced)
                        .foregroundStyle(Color.trameSubdued)
                }
            }

            if let timerText = presentation.timerText {
                Text(timerText)
                    .font(AppFont.timer)
                    .foregroundStyle(
                        presentation.phase == .capped ? Color.trameDestructiveText : Color.trameText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel(
                        presentation.timerAccessibilityText ?? String(localized: "Time unavailable")
                    )
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The component the lifter is inside gets the stage's focus treatment — a
    /// Strength rail and full ink at title weight — rather than a chevron that
    /// reads the same as the rows it is meant to be distinguished from. The
    /// remaining components stay on the same leading edge as one subdued list.
    private func movementSequence(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if presentation.movementSequence.isEmpty {
                Text(String(localized: "No movements assigned"))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .padding(.leading, Spacing.m)
            } else {
                ForEach(Array(presentation.movementSequence.enumerated()), id: \.offset) { index, movement in
                    if index == currentComponentOrder {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(String(localized: "NOW"))
                                .font(AppFont.micro)
                                .tracking(0.55)
                                .foregroundStyle(Color.trameStrength)
                            Text(movement)
                                .font(AppFont.titleSmallSemibold)
                                .foregroundStyle(Color.trameText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, Spacing.m)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.trameStrength)
                                .frame(width: 3)
                                .accessibilityHidden(true)
                        }
                    } else {
                        Text(movement)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, Spacing.m)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sequenceAccessibilityLabel(presentation.movementSequence))
    }

    private func sequenceAccessibilityLabel(_ movements: [String]) -> String {
        guard !movements.isEmpty else { return String(localized: "Ordered sequence, no movements assigned") }
        let sequence = movements.enumerated().map { index, movement in
            index == currentComponentOrder
                ? String(format: String(localized: "Current: %@"), movement)
                : sequencePhrase(index: index, movement: movement)
        }.joined(separator: ". ")
        return String(format: String(localized: "Ordered sequence. %@"), sequence)
    }

    private func sequencePhrase(index: Int, movement: String) -> String {
        if index == 0 {
            return String(format: String(localized: "Start with %@"), movement)
        }
        return String(format: String(localized: "Then %@"), movement)
    }

    /// Round and score are context for the clock, so they read as one subdued
    /// tabular line. The two icons they used to carry named nothing the words
    /// did not already say.
    @ViewBuilder
    private func progressSummary(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        let parts = [
            presentation.progressText,
            presentation.scoreText.map { String(format: String(localized: "Score %@"), $0) }
        ].compactMap { $0 }

        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(AppFont.captionSemiboldMonospaced)
                .foregroundStyle(Color.trameSubdued)
                .padding(.leading, Spacing.m)
        }
    }

    /// One dominant command at full width, then a rail of quiet ones. The cap
    /// action used to sit beside the primary as a bordered pill, which halved
    /// the width of the button pressed every round and gave a block-ending
    /// action the same visual rank as advancing through it.
    private func controls(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if presentation.primaryAction != .none {
                Button(action: primaryAction) {
                    Label(
                        primaryTitle(presentation),
                        systemImage: primaryIcon(presentation.primaryAction)
                    )
                }
                // `.borderedProminent` tinted with `trameAction` painted
                // cream on cream: the label was legible only as an absence.
                // The shared style owns the inverse ink pairing.
                .buttonStyle(.tramePrimaryAction)
                .accessibilityHint(
                    presentation.primaryActionHint ?? String(localized: "Starts the shared block clock")
                )
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    secondaryRail(presentation)
                }
            } else {
                HStack(spacing: 0) {
                    secondaryRail(presentation)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func secondaryRail(_ presentation: WorkoutExecutionBlockPresentation) -> some View {
        if let pauseTitle = presentation.pauseActionTitle, presentation.canPause {
            railButton(
                pauseTitle,
                systemImage: block.elapsedStartedAt == nil ? AppIcon.play : AppIcon.pause,
                action: toggleClockPause
            )
        }

        if let capTitle = presentation.capActionTitle {
            railButton(
                capTitle,
                systemImage: AppIcon.stop,
                tint: Color.trameDestructiveText,
                action: cap
            )
        }

        secondaryActions
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
            railLabel(String(localized: "More"), systemImage: AppIcon.ellipsis)
        }
        .buttonStyle(.plain)
    }

    private func railButton(
        _ title: String,
        systemImage: String,
        tint: Color = .trameSubdued,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            railLabel(title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.gymPress)
    }

    private func railLabel(
        _ title: String,
        systemImage: String,
        tint: Color = .trameSubdued
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppFont.metadata)
            .foregroundStyle(tint)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .padding(.horizontal, Spacing.s)
            .contentShape(Rectangle())
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

    /// The dominant control never renders as a bare icon. An empty or
    /// whitespace-only title from the presentation falls back to the verb.
    private func primaryTitle(_ presentation: WorkoutExecutionBlockPresentation) -> String {
        let title = presentation.primaryActionTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? String(localized: "Advance") : title
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

    /// The colour of the phase rule only. The phase word beside it carries the
    /// same state, so the mark never has to be read as colour alone — and a
    /// block nobody has started paints no domain hue at all.
    private func phaseTint(_ phase: WorkoutExecutionBlockExecutionPhase) -> Color {
        switch phase {
        case .ready: .trameSeparator
        case .running: .trameStrength
        case .paused: .trameAttention
        case .completed: .trameCompleted
        case .capped, .stopped: .trameDestructiveText
        case .partial, .skipped: .trameSubdued
        }
    }
}
