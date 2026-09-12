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
    /// Starts a mid-session stretch from the empty-session page. Nil when
    /// mobility is unavailable; the command bar still adds the first exercise.
    let onAddMobility: (() -> Void)?

    init(
        workout: Workout,
        blockers: [String],
        onJumpToPage: @escaping (WorkoutStagePage) -> Void,
        onAdjustDuration: @escaping (TimeInterval) -> Void,
        onAddMobility: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.blockers = blockers
        self.onJumpToPage = onJumpToPage
        self.onAdjustDuration = onAdjustDuration
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
            Text("Add your first exercise")
                .font(AppFont.stageTitle)
                .foregroundStyle(Color.trameText)
                .accessibilityAddTraits(.isHeader)
            Text(emptyWorkoutGuidance)
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)

            if let onAddMobility {
                Button(action: onAddMobility) {
                    Label("Add stretch", systemImage: AppIcon.mobility)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameMobility)
                        .frame(
                            minHeight: ComponentSize.minimumTouchTarget,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Adds a stretch after this exercise.")
                .accessibilityIdentifier("add-first-mobility-empty")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empty-workout-state")
    }

    private var emptyWorkoutGuidance: LocalizedStringKey {
        onAddMobility == nil
            ? "Add exercises as you go. Reorder from More."
            : "Add exercises as you go. A stretch sits between them."
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

                        Text(entry.occurrenceDisplayName)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.trameText)
                            .lineLimit(1)

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
                    Text("\(entry.occurrenceDisplayName), \(completed) of \(total) sets logged")
                )
                .accessibilityHint(Text("Go to this exercise"))
                .accessibilityIdentifier("finish-breakdown-\(entry.exercise.name)")
            }
        }
    }
}
