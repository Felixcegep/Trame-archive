import SwiftUI
import SwiftData

/// The pager's last page: what the session amounted to, and what still stands
/// between it and being saved.
///
/// It is deliberately *not* the review form. Effort, notes, and the save itself
/// live in `WorkoutSaveView`, which is a committing step and belongs on its own
/// screen where a back gesture means "not yet" rather than "swipe to the
/// previous exercise". This page is the last thing in the swipe sequence, so
/// reaching the end of the workout by swiping arrives somewhere that makes
/// sense instead of at a dead stop on the final exercise.
struct StageFinishPage: View {
    let workout: Workout
    /// Reasons the session cannot be finished yet, already phrased for the
    /// lifter. Empty when it can.
    let blockers: [String]
    let onJumpToPage: (WorkoutStagePage) -> Void
    let onAdjustDuration: (TimeInterval) -> Void
    /// Opens the exercise library from the empty-session chooser. The command
    /// bar keeps the same action for one-handed reach.
    let onAddExercise: () -> Void
    /// Starts a mid-session stretch from the empty-session page. Nil when
    /// mobility is unavailable; the command bar still adds the first exercise.
    let onAddMobility: (() -> Void)?

    init(
        workout: Workout,
        blockers: [String],
        onJumpToPage: @escaping (WorkoutStagePage) -> Void,
        onAdjustDuration: @escaping (TimeInterval) -> Void,
        onAddExercise: @escaping () -> Void,
        onAddMobility: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.blockers = blockers
        self.onJumpToPage = onJumpToPage
        self.onAdjustDuration = onAdjustDuration
        self.onAddExercise = onAddExercise
        self.onAddMobility = onAddMobility
    }

    @State private var isEditingDuration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if workout.exercises.isEmpty {
                    emptyWorkoutState
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(blockers.isEmpty ? "SESSION COMPLETE" : "REVIEW SESSION")
                            .font(AppFont.eyebrow)
                            .tracking(0.9)
                            .foregroundStyle(Color.trameSubdued)
                        Text(blockers.isEmpty ? "Ready to save" : "Finish the remaining work")
                            .font(AppFont.stageTitle)
                            .foregroundStyle(Color.trameText)
                    }

                    summaryCard

                    ForEach(blockers, id: \.self) { blocker in
                        Label(blocker, systemImage: AppIcon.warning)
                            .font(AppFont.footnote)
                            .foregroundStyle(Color.trameText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(Color.trameAttention).frame(width: 4)
                            }
                            .accessibilityIdentifier("finish-blocker")
                    }

                    exerciseBreakdown
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isEditingDuration) {
            SessionDurationEditor(
                duration: max(Constants.Session.minimumDuration, workout.elapsedDuration()),
                onSave: { duration in
                    onAdjustDuration(duration)
                    isEditingDuration = false
                },
                onCancel: { isEditingDuration = false }
            )
        }
    }

    private var emptyWorkoutState: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("NEW WORKOUT")
                .font(AppFont.eyebrow)
                .tracking(0.9)
                .foregroundStyle(Color.trameSubdued)
            Text(emptyWorkoutTitle)
                .font(AppFont.stageTitle)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if onAddMobility == nil {
                Text("Add exercises as you go. Reorder from More.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                emptyWorkoutChooser
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empty-workout-state")
    }

    private var emptyWorkoutTitle: LocalizedStringKey {
        onAddMobility == nil
            ? "Add your first exercise"
            : "Add an exercise or a stretch"
    }

    /// Two first actions as an Open Group. Strength and mobility stay siblings
    /// rather than a primary lift plus a leftover stretch link.
    private var emptyWorkoutChooser: some View {
        VStack(spacing: 0) {
            emptyWorkoutChoice(
                title: "Exercise",
                icon: AppIcon.exercise,
                rail: Color.trameStrength,
                identifier: "add-first-exercise-empty",
                accessibilityLabel: "Add exercise",
                hint: "Opens the exercise library for this workout.",
                action: onAddExercise
            )

            if let onAddMobility {
                emptyWorkoutChoice(
                    title: "Stretch",
                    icon: AppIcon.mobility,
                    rail: Color.trameMobility,
                    identifier: "add-first-mobility-empty",
                    accessibilityLabel: "Add stretch",
                    hint: "Adds a stretch to this workout.",
                    action: onAddMobility
                )
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empty-workout-chooser")
    }

    private func emptyWorkoutChoice(
        title: LocalizedStringKey,
        icon: String,
        rail: Color,
        identifier: String,
        accessibilityLabel: LocalizedStringKey,
        hint: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: icon)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                    .frame(width: 26)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.trameText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.plus)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.md)
            .padding(.leading, Spacing.m)
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(rail)
                    .frame(width: 4)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(hint))
        .accessibilityIdentifier(identifier)
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            Button {
                isEditingDuration = true
            } label: {
                VStack(spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xxs) {
                        Text(workout.startTime, style: .timer)
                            .font(AppFont.metricLarge)
                            .monospacedDigit()
                            .foregroundStyle(Color.trameText)
                        Image(systemName: AppIcon.edit)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    Text("TIME")
                        .font(AppFont.caption2Bold)
                        .tracking(0.55)
                        .foregroundStyle(Color.trameSubdued)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Time at the gym"))
            .accessibilityHint(Text("Changes how long this session has lasted."))
            .accessibilityIdentifier("finish-duration")

            Divider().frame(height: 48).overlay(Color.trameSeparator)

            summaryMetric(
                value: Text("\(workout.completedSetCount)/\(workout.totalSetCount)"),
                label: "SETS",
                accessibilityLabel: "\(workout.completedSetCount) of \(workout.totalSetCount) sets logged"
            )

            Divider().frame(height: 48).overlay(Color.trameSeparator)

            summaryMetric(
                value: Text("\(workout.exercises.count)"),
                label: "EXERCISES",
                accessibilityLabel: CountPhrase.exercises(workout.exercises.count)
            )
        }
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
        .accessibilityIdentifier("finish-summary")
    }

    private func summaryMetric(
        value: Text,
        label: String,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            value
                .font(AppFont.metricLarge)
                .monospacedDigit()
                .foregroundStyle(Color.trameText)
            Text(label)
                .font(AppFont.caption2Bold)
                .tracking(0.55)
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    /// Every exercise with its completion count, and each row jumps back to
    /// that exercise. This is where the scrolling card list's one genuine
    /// advantage — seeing the whole session at once — comes back, at the point
    /// in the flow where seeing the whole session is the actual task.
    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Exercises")

            ForEach(workout.orderedExercises, id: \.persistentModelID) { entry in
                let completed = entry.orderedSets.filter(\.done).count
                let total = entry.orderedSets.count
                let isComplete = total > 0 && completed == total

                Button {
                    onJumpToPage(WorkoutStagePlan.page(containing: entry))
                } label: {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: isComplete ? AppIcon.checkmarkCircle : AppIcon.circle)
                            .font(AppFont.subheadline)
                            .foregroundStyle(isComplete ? Color.trameCompleted : Color.trameSubdued)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(entry.occurrenceDisplayName)
                                .font(AppFont.subheadline)
                                .foregroundStyle(Color.trameText)
                                .lineLimit(1)

                            if let summary = finishRowSummary(for: entry) {
                                Text(summary)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.trameSubdued)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: Spacing.s)

                        Text("\(completed)/\(total)")
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.trameSubdued)

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.caption2Bold)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(finishAccessibilityLabel(entry: entry, completed: completed, total: total))
                )
                .accessibilityHint(Text("Go to this exercise"))
                .accessibilityIdentifier("finish-breakdown-\(entry.exercise.name)")
            }
        }
    }

    private func finishRowSummary(for entry: ExerciseEntry) -> String? {
        var parts: [String] = []
        if let olympic = entry.olympicAttemptSummary {
            parts.append(olympic)
        }
        if entry.hasUnansweredEffort {
            parts.append(String(localized: "Effort missing"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func finishAccessibilityLabel(entry: ExerciseEntry, completed: Int, total: Int) -> String {
        var label = String(localized: "\(entry.occurrenceDisplayName), \(completed) of \(total) sets logged")
        if let summary = finishRowSummary(for: entry) {
            label += ", \(summary)"
        }
        return label
    }
}
