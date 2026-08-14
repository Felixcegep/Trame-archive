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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GymEyebrow("End of session")
                    Text("Ready to finish")
                        .font(AppFont.stageTitle)
                        .foregroundStyle(Color.gymText)
                }

                summaryCard

                ForEach(blockers, id: \.self) { blocker in
                    Label(blocker, systemImage: AppIcon.warning)
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.m)
                        .background(
                            Color.gymAccentSurface,
                            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        )
                        .accessibilityIdentifier("finish-blocker")
                }

                exerciseBreakdown
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryMetric(
                value: Text(workout.startTime, style: .timer),
                label: "TIME",
                accessibilityLabel: "Elapsed time"
            )

            Divider().frame(height: 40).overlay(Color.gymBorder)

            summaryMetric(
                value: Text("\(workout.completedSetCount)/\(workout.totalSetCount)"),
                label: "SETS",
                accessibilityLabel: "\(workout.completedSetCount) of \(workout.totalSetCount) sets logged"
            )

            Divider().frame(height: 40).overlay(Color.gymBorder)

            summaryMetric(
                value: Text("\(workout.exercises.count)"),
                label: "EXERCISES",
                accessibilityLabel: CountPhrase.exercises(workout.exercises.count)
            )
        }
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("finish-summary")
    }

    private func summaryMetric(
        value: Text,
        label: String,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            value
                .font(AppFont.titleMedium)
                .monospacedDigit()
                .foregroundStyle(Color.gymText)
            Text(label)
                .font(AppFont.caption2Bold)
                .tracking(0.55)
                .foregroundStyle(Color.gymSubduedText)
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
            GymEyebrow("Session")

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
                            .foregroundStyle(isComplete ? Color.gymSecondary : Color.gymSubduedText)

                        Text(entry.occurrenceDisplayName)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymText)
                            .lineLimit(1)

                        Spacer(minLength: Spacing.s)

                        Text("\(completed)/\(total)")
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.gymSubduedText)

                        Image(systemName: AppIcon.chevronRight)
                            .font(AppFont.caption2Bold)
                            .foregroundStyle(Color.gymSubduedText)
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
