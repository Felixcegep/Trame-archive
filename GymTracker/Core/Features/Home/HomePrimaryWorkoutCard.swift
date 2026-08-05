import SwiftUI

struct HomePrimaryWorkoutCard: View {
    let activeWorkout: Workout?
    let activePlanRun: PlanRun?
    let activePlanProgress: PlanWorkoutProgress?
    let summary: TodayWorkoutSummary
    let onOpen: () -> Void
    let onPostpone: () -> Void
    let onReschedule: (PlanWorkoutProgress) -> Void
    let onSkip: (PlanWorkoutProgress) -> Void

    private var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    var body: some View {
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

            scheduleActions
        }
        .background {
            if hasActiveWorkout {
                // Flat, not a gradient. The gradient faded toward transparency,
                // which over the cream background made the *lower* half lighter
                // — exactly where the subtitle sits — and left white text at
                // 2.89:1 there. Deepening it instead still left the top stop at
                // 4.46:1, so any gradient across this hue has one end failing.
                // The gradient carried no information, so the fill is uniform
                // and every point of the card clears 4.5:1.
                Color.gymPrimaryDeep
            } else {
                Color.gymCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.03), radius: 6, x: 0, y: 3)
        .overlay {
            if !hasActiveWorkout && summary.kind != .unavailable {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.gymPrimary.opacity(0.16), lineWidth: 1.5)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Label(cardLabel, systemImage: cardIcon)
                    .font(AppFont.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(hasActiveWorkout ? .white : Color.gymPrimary)

                Spacer()

                if hasActiveWorkout {
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(.white)
                }
            }

            Text(cardTitle)
                .font(AppFont.titleMedium)
                .foregroundStyle(hasActiveWorkout ? .white : Color.gymText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Full white, not 86%. This line carries "3 / 12 sets · Next: Bench
            // Press · Set 2" — the most useful sentence on the screen while a
            // workout is running — and at 86% on the old gradient it computed
            // to 3.74:1, the least legible text on the app's most important
            // card.
            Text(cardSubtitle)
                .font(AppFont.subheadline)
                .foregroundStyle(hasActiveWorkout ? .white : Color.gymSubduedText)

            if let activeWorkout, activeWorkout.totalSetCount > 0 {
                ProgressView(
                    value: Double(activeWorkout.completedSetCount),
                    total: Double(activeWorkout.totalSetCount)
                )
                .tint(.white)
                .padding(.top, Spacing.xxs)
                // The subtitle already states the same progress in words, so
                // the bar is a visual restatement rather than a second stop.
                .accessibilityHidden(true)
            }

            if !hasActiveWorkout {
                // Full width rather than hugging its label: the capsule used to
                // leave most of the card's width as dead space beside the one
                // action the screen exists for, and a wider target is faster to
                // hit with a phone in one hand.
                HStack(spacing: Spacing.s) {
                    Text(primaryActionTitle)
                        .font(AppFont.subheadlineBold)
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.captionBold)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.xl)
                .background(Color.gymPrimary, in: Capsule())
                .padding(.top, Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var scheduleActions: some View {
        if let activePlanRun, let activePlanProgress,
           !hasActiveWorkout,
           PlanCoordinator.canEditSchedule(activePlanProgress, in: activePlanRun) {
            Divider()
                .overlay(Color.gymBorder)
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

    private var cardTitle: LocalizedStringKey {
        LocalizedStringKey(summary.title)
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
        case .active: return "ACTIVE WORKOUT"
        case .planned: return "PLANNED WORKOUT"
        case .repeating: return "NEXT WORKOUT"
        case .guidedConflict: return "CHOOSE TRAINING SOURCE"
        case .unavailable: return "WORKOUT UNAVAILABLE"
        case .free: return "START WORKOUT"
        }
    }

    private var cardIcon: String {
        switch summary.kind {
        case .active, .planned, .repeating:
            return AppIcon.workout
        case .guidedConflict, .unavailable:
            return AppIcon.warning
        case .free:
            return AppIcon.play
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
            return "Opens your saved workouts, or start an empty one."
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
        case .active: return "Resume workout"
        case .planned, .repeating: return "Start workout"
        case .guidedConflict: return "Resolve conflict"
        case .unavailable: return "Unavailable"
        case .free: return "Start workout"
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
