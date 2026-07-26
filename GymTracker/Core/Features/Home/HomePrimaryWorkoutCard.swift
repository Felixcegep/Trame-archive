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
            .accessibilityHint(cardHint)
            .accessibilityIdentifier(cardAccessibilityIdentifier)

            scheduleActions
        }
        .background {
            if hasActiveWorkout {
                LinearGradient(
                    colors: [Color.gymPrimary, Color.gymPrimary.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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

            Text(cardSubtitle)
                .font(AppFont.subheadline)
                .foregroundStyle(hasActiveWorkout ? .white.opacity(0.86) : Color.gymSubduedText)

            if let activeWorkout, activeWorkout.totalSetCount > 0 {
                ProgressView(
                    value: Double(activeWorkout.completedSetCount),
                    total: Double(activeWorkout.totalSetCount)
                )
                .tint(.white.opacity(0.95))
                .padding(.top, Spacing.xxs)
            }

            if !hasActiveWorkout {
                HStack(spacing: Spacing.s) {
                    Text(primaryActionTitle)
                        .font(AppFont.subheadlineBold)
                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.captionBold)
                }
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

            HStack(spacing: Spacing.s) {
                Button(action: onPostpone) {
                    Label("Tomorrow", systemImage: AppIcon.tomorrow)
                }
                .accessibilityIdentifier("today-postpone-planned-workout")

                Button {
                    onReschedule(activePlanProgress)
                } label: {
                    Label("Reschedule", systemImage: AppIcon.reschedule)
                }
                .accessibilityIdentifier("today-reschedule-planned-workout")

                Spacer(minLength: Spacing.s)

                Button(role: .destructive) {
                    onSkip(activePlanProgress)
                } label: {
                    Label("Skip", systemImage: AppIcon.skip)
                }
                .accessibilityIdentifier("today-skip-planned-workout")
            }
            .font(AppFont.subheadlineSemibold)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
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
