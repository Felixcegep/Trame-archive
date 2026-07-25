import SwiftUI

struct HomePrimaryWorkoutCard: View {
    let activeWorkout: Workout?
    let activePlanRun: PlanRun?
    let activePlanProgress: PlanWorkoutProgress?
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
            if !hasActiveWorkout {
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
                    Text("Start workout")
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
        if let activeWorkout {
            if let name = activeWorkout.name, !name.isEmpty {
                return "Resume \(name)"
            }
            return "Resume workout"
        }
        if let activePlanProgress {
            return LocalizedStringKey(activePlanProgress.plannedWorkoutName)
        }
        return "Start a workout"
    }

    private var cardSubtitle: LocalizedStringKey {
        if let activeWorkout {
            guard activeWorkout.totalSetCount > 0 else {
                return "No exercises yet · Pick your first exercise"
            }
            return "\(activeWorkout.completedSetCount) / \(activeWorkout.totalSetCount) sets · \(nextExerciseDescription(in: activeWorkout))"
        }
        if let activePlanProgress {
            let week = activePlanProgress.weekIndex + 1
            if let scheduledDate = activePlanProgress.scheduledDate,
               Calendar.current.isDateInToday(scheduledDate) {
                return "Week \(week) · Today"
            }
            return "Week \(week) · Start early when you are ready"
        }
        return "Pick a saved workout or start fresh."
    }

    private var cardLabel: LocalizedStringKey {
        if hasActiveWorkout { return "ACTIVE WORKOUT" }
        if activePlanProgress != nil { return "PLANNED WORKOUT" }
        return "START WORKOUT"
    }

    private var cardIcon: String {
        hasActiveWorkout || activePlanProgress != nil
            ? "figure.strengthtraining.traditional"
            : "bolt.fill"
    }

    private var cardHint: String {
        if hasActiveWorkout { return "Returns to your active workout." }
        if activePlanProgress != nil { return "Starts the next workout in your active plan." }
        return "Opens your saved workouts, or start an empty one."
    }

    private var cardAccessibilityIdentifier: String {
        if hasActiveWorkout { return "resume-active-workout" }
        if activePlanProgress != nil { return "start-planned-workout" }
        return "start-free-workout"
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
