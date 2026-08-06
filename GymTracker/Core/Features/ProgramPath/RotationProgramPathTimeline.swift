import SwiftUI

/// A rotation has no end to draw, so its path is "where the cursor is now" plus
/// "what the rotation actually did", newest first.
///
/// The current cycle is shown as ordered slots because that is the shape the
/// user chose. Everything before it is history grouped by cycle, which keeps
/// completed-cycle context available without pretending the rotation is finite.
struct RotationProgramPathTimeline: View {
    let projection: RotationProgramPathProjection

    var body: some View {
        Section {
            RotationCursorView(projection: projection)

            ForEach(projection.currentCycleSlots) { slot in
                RotationSlotRow(
                    slot: slot,
                    isCurrentCycle: true
                )
            }
        } header: {
            Text(ProgramPathPresentation.cycleTitle(projection.currentCycleIndex))
                .accessibilityIdentifier("program-path-current-cycle")
        } footer: {
            if projection.currentCycleSlots.isEmpty {
                Text("This rotation has no workouts yet.")
            }
        }

        ForEach(historyCycles, id: \.cycleIndex) { cycle in
            Section {
                ForEach(cycle.occurrences) { occurrence in
                    RotationOccurrenceRow(occurrence: occurrence)
                }
            } header: {
                HStack(spacing: Spacing.s) {
                    Text(ProgramPathPresentation.cycleTitle(cycle.cycleIndex))
                    Spacer(minLength: 0)
                    if cycle.cycleIndex < projection.currentCycleIndex {
                        Text("Completed")
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .accessibilityIdentifier("program-path-history-cycle-\(cycle.cycleIndex)")
            }
        }
    }

    private struct HistoryCycle {
        let cycleIndex: Int
        let occurrences: [RotationProgramPathOccurrence]
    }

    /// Newest cycle first, and newest event first inside each cycle. Ties break
    /// on the occurrence identifier so the order is stable across launches and
    /// screenshot runs rather than dependent on fetch order.
    private var historyCycles: [HistoryCycle] {
        Dictionary(grouping: projection.history, by: \.cycleIndex)
            .map { cycleIndex, occurrences in
                HistoryCycle(
                    cycleIndex: cycleIndex,
                    occurrences: occurrences.sorted { lhs, rhs in
                        if lhs.createdAt != rhs.createdAt {
                            return lhs.createdAt > rhs.createdAt
                        }
                        return lhs.id.uuidString > rhs.id.uuidString
                    }
                )
            }
            .sorted { $0.cycleIndex > $1.cycleIndex }
    }
}

/// Where the rotation stands: cycle number, cursor position, and how much has
/// already been completed. The invalid-cursor case says so plainly instead of
/// showing a position that does not exist.
struct RotationCursorView: View {
    let projection: RotationProgramPathProjection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(ProgramPathPresentation.rotationPosition(projection))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)

            if projection.currentSlotIndex == nil, projection.slotCount > 0 {
                Text("The saved rotation position is unavailable.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(ProgramPathPresentation.completedCyclesSummary(projection.completedCycleCount))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("program-path-rotation-cursor")
    }
}

/// One ordered position in the rotation.
///
/// The cursor badge and this cycle's outcome are independent: an alternate can
/// already be completed in a slot the cursor has not reached, so both are shown
/// rather than collapsed into a single status.
struct RotationSlotRow: View {
    let slot: RotationProgramPathSlot
    let isCurrentCycle: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            GymIconChip(
                systemImage: AppIcon.routine,
                tint: slot.isTemplateAvailable ? Color.gymAccent : Color.gymSubduedText
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(slot.workoutName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProgramPathPresentation.slotTitle(slot.slotIndex))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)

                if !slot.isTemplateAvailable {
                    Label("Workout unavailable", systemImage: AppIcon.warning)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymAccent)
                        .accessibilityIdentifier("program-path-slot-unavailable")
                }

                if isCurrentCycle, let state = slot.occurrenceState {
                    Label(stateTitle(state), systemImage: stateIcon(state))
                        .font(AppFont.captionBold)
                        .foregroundStyle(stateTint(state))
                        .accessibilityIdentifier("program-path-slot-\(stateIdentifier(state))")
                }
            }

            Spacer(minLength: Spacing.s)

            if slot.isCursor {
                GymStatusBadge(
                    title: String(localized: "Next"),
                    systemImage: AppIcon.play,
                    tint: Color.gymPrimary
                )
                .accessibilityIdentifier("program-path-slot-cursor")
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(slot.isCursor ? .isSelected : [])
    }

    private func stateTitle(_ state: RotationProgramPathSlotOccurrenceState) -> String {
        switch state {
        case .inProgress: String(localized: "In progress")
        case .completed: String(localized: "Completed this cycle")
        case .skipped: String(localized: "Skipped this cycle")
        }
    }

    private func stateIcon(_ state: RotationProgramPathSlotOccurrenceState) -> String {
        switch state {
        case .inProgress: AppIcon.workout
        case .completed: AppIcon.checkmarkCircle
        case .skipped: AppIcon.skip
        }
    }

    private func stateTint(_ state: RotationProgramPathSlotOccurrenceState) -> Color {
        switch state {
        case .inProgress: Color.gymPrimary
        case .completed: Color.gymSuccess
        case .skipped: Color.gymSubduedText
        }
    }

    private func stateIdentifier(_ state: RotationProgramPathSlotOccurrenceState) -> String {
        switch state {
        case .inProgress: "in-progress"
        case .completed: "completed"
        case .skipped: "skipped"
        }
    }
}

/// One recorded rotation decision, read back in plain language: what was done,
/// what it replaced, and what it did to the rotation position.
struct RotationOccurrenceRow: View {
    let occurrence: RotationProgramPathOccurrence

    var body: some View {
        if let workoutID = occurrence.completedWorkoutID {
            NavigationLink {
                ProgramPathCompletedWorkoutDestination(workoutID: workoutID)
            } label: {
                content
            }
            .accessibilityIdentifier("program-path-occurrence-completed")
            .accessibilityHint(Text("Opens the completed workout."))
        } else {
            content
                .accessibilityIdentifier("program-path-occurrence")
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: ProgramPathPresentation.occurrenceKindIcon(occurrence.kind))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isUndone ? Color.gymSubduedText : Color.gymAccent)
                .frame(width: Spacing.xxl, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(ProgramPathPresentation.occurrenceKindTitle(occurrence.kind))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(isUndone ? Color.gymSubduedText : Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProgramPathPresentation.occurrenceWorkoutName(occurrence))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                if let substitution = ProgramPathPresentation.occurrenceSubstitution(occurrence) {
                    Text(substitution)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(ProgramPathPresentation.occurrenceEffect(occurrence))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProgramPathPresentation.occurrenceTimestamp(occurrence))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer(minLength: Spacing.s)

            if isUndone {
                GymStatusBadge(
                    title: ProgramPathPresentation.occurrenceStatusTitle(occurrence.status),
                    systemImage: AppIcon.restore,
                    tint: Color.gymSubduedText
                )
                .accessibilityIdentifier("program-path-occurrence-undone")
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var isUndone: Bool { occurrence.status == .undone }
}
