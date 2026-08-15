import SwiftUI

struct HomePrimaryWorkoutCard: View {
    let activeWorkout: Workout?
    let activePlanRun: PlanRun?
    let activePlanProgress: PlanWorkoutProgress?
    let summary: TodayWorkoutSummary
    let onOpen: () -> Void
    let onOpenSavedWorkouts: () -> Void
    let onPostpone: () -> Void
    let onReschedule: (PlanWorkoutProgress) -> Void
    let onSkip: (PlanWorkoutProgress) -> Void

    private var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    var body: some View {
        TrameColorField(
            fill: .gymTodayHero,
            ink: .gymTodayHeroInk,
            border: .gymTodayHeroDivider,
            radius: Radius.hero
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onOpen) {
                    cardContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.l)
                }
                .buttonStyle(.gymPress)
                .disabled(summary.kind == .unavailable)
                // Stated explicitly rather than left to the automatic combination
                // of five child views, which read the eyebrow, title, subtitle, and
                // progress bar in layout order and repeated the set count twice.
                .accessibilityLabel(cardAccessibilityLabel)
                .accessibilityHint(cardHint)
                .accessibilityIdentifier(cardAccessibilityIdentifier)

                if showsSavedWorkoutsFooter {
                    Divider()
                        .overlay(Color.gymTodayHeroDivider)

                    Button(action: onOpenSavedWorkouts) {
                        Text("Saved workouts")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.gymTodayHeroSecondaryText)
                            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityHint("Opens your saved workouts.")
                    .accessibilityIdentifier("today-open-saved-workouts")
                }

                scheduleActions
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if showsEyebrow {
                Text(cardLabel)
                    .font(AppFont.eyebrow)
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.gymTodayHeroSecondaryText)
            }

            cardTitleText
                .font(AppFont.displayMedium)
                .foregroundStyle(Color.gymTodayHeroInk)
                .fixedSize(horizontal: false, vertical: true)

            if showsSubtitle {
                Text(cardSubtitle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.gymTodayHeroSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let activeWorkout, activeWorkout.totalSetCount > 0 {
                ProgressView(
                    value: Double(activeWorkout.completedSetCount),
                    total: Double(activeWorkout.totalSetCount)
                )
                .tint(Color.trameAction)
                // The subtitle already states the same progress in words, so
                // the bar is a visual restatement rather than a second stop.
                .accessibilityHidden(true)
            }

            Text(primaryActionTitle)
                .font(AppFont.titleSmallSemibold)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.todayActionHeight)
                .foregroundStyle(primaryActionInk)
                .background(primaryActionFill)
                .clipShape(RoundedRectangle(cornerRadius: Radius.editorialAction, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.editorialAction, style: .continuous)
                        .stroke(Color.gymActionOutline, lineWidth: summary.kind == .unavailable ? 0 : 1)
                }
        }
    }

    private var showsEyebrow: Bool {
        summary.kind != .free
    }

    private var showsSubtitle: Bool {
        summary.kind != .free
    }

    private var showsSavedWorkoutsFooter: Bool {
        summary.kind == .free
    }

    private var primaryActionFill: Color {
        summary.kind == .unavailable ? Color.gymRowSurface : Color.gymAction
    }

    private var primaryActionInk: Color {
        summary.kind == .unavailable ? Color.gymSubduedText : Color.gymActionInk
    }

    @ViewBuilder
    private var scheduleActions: some View {
        if let activePlanRun, let activePlanProgress,
           !hasActiveWorkout,
           PlanCoordinator.canEditSchedule(activePlanProgress, in: activePlanRun) {
            Divider()
                .overlay(Color.gymTodayHeroDivider)
                .padding(.horizontal, Spacing.l)

            // The vertical padding used to sit on this HStack, which put it
            // outside every button's hit region and left three ~20pt targets —
            // two of which mutate the plan schedule, eight points apart. Each
            // label now carries its own 44pt box.
            HStack(spacing: Spacing.s) {
                scheduleActionButton(
                    "Tomorrow",
                    systemImage: AppIcon.tomorrow,
                    identifier: "today-postpone-planned-workout",
                    action: onPostpone
                )

                scheduleActionButton(
                    "Reschedule",
                    systemImage: AppIcon.reschedule,
                    identifier: "today-reschedule-planned-workout"
                ) {
                    onReschedule(activePlanProgress)
                }

                Spacer(minLength: Spacing.m)

                scheduleActionButton(
                    "Skip",
                    systemImage: AppIcon.skip,
                    identifier: "today-skip-planned-workout",
                    role: .destructive
                ) {
                    onSkip(activePlanProgress)
                }
            }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(Color.gymTodayHeroSecondaryText)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
        }
    }

    private func scheduleActionButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        identifier: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    private var cardTitleText: Text {
        guard summary.kind == .active else {
            return Text(LocalizedStringKey(summary.title))
        }
        guard let name = activeWorkout?.name, !name.isEmpty else {
            return Text("Workout")
        }
        return Text(verbatim: name)
    }

    private var cardSubtitle: LocalizedStringKey {
        if let activeWorkout {
            guard activeWorkout.totalSetCount > 0 else {
                return "No exercises yet · Pick your first exercise"
            }
            return "\(activeWorkout.completedSetCount) / \(activeWorkout.totalSetCount) sets · \(nextExerciseDescription(in: activeWorkout))"
        }
        return LocalizedStringKey(summary.subtitle)
    }

    private var cardLabel: LocalizedStringKey {
        switch summary.kind {
        case .active: return "Active"
        case .planned: return "Planned"
        case .repeating: return "Next"
        case .guidedConflict: return "Needs attention"
        case .unavailable: return "Unavailable"
        case .free: return "Start"
        }
    }

    /// Subject first, then state, then what is next — the order the lifter
    /// needs it, rather than the order the card happens to lay it out in.
    private var cardAccessibilityLabel: String {
        var parts = [summary.title]
        if let activeWorkout, activeWorkout.totalSetCount > 0 {
            parts.append(String(
                localized: "\(activeWorkout.completedSetCount) of \(activeWorkout.totalSetCount) sets complete"
            ))
            parts.append(nextExerciseDescription(in: activeWorkout))
        } else if !summary.subtitle.isEmpty {
            parts.append(summary.subtitle)
        }
        return parts.joined(separator: ". ")
    }

    private var cardHint: String {
        switch summary.kind {
        case .active:
            return "Returns to your active workout."
        case .planned:
            return "Starts the next workout in your active plan."
        case .repeating:
            return String(localized: "Starts the next workout in your active rotation.")
        case .guidedConflict:
            return String(localized: "Choose which guided training source should remain active.")
        case .unavailable:
            return String(localized: "This workout cannot start until you repair it in the Train tab.")
        case .free:
            return "Starts an empty workout."
        }
    }

    private var cardAccessibilityIdentifier: String {
        switch summary.kind {
        case .active: return "resume-active-workout"
        case .planned: return "start-planned-workout"
        case .repeating: return "start-repeating-workout"
        case .guidedConflict: return "resolve-guided-source-conflict"
        case .unavailable: return "guided-workout-unavailable"
        case .free: return "start-free-workout"
        }
    }

    private var primaryActionTitle: LocalizedStringKey {
        switch summary.kind {
        case .active: return "Resume"
        case .planned, .repeating, .free: return "Start"
        case .guidedConflict: return "Choose"
        case .unavailable: return "Unavailable"
        }
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
              let setIndex = exercise.orderedSets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next: %@ · Set %lld")
        return String(format: format, exercise.exercise.name, Int64(setIndex + 1))
    }
}
