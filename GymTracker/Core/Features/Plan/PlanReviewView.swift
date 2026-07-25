import SwiftData
import SwiftUI

struct PlanReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: PlanEditorDraft
    /// Applies the draft; returns a user-facing message when persistence
    /// refused the changes so the sheet can stay open with edits preserved.
    let onConfirm: () -> String?

    @State private var confirmErrorMessage: String?

    var body: some View {
        List {
            Section {
                Label {
                    Text("These changes update future prescriptions only. Completed workouts and their recorded history are not changed.")
                        .font(AppFont.subheadline)
                } icon: {
                    Image(systemName: AppIcon.info)
                        .foregroundStyle(Color.gymPrimary)
                }
                .accessibilityIdentifier("plan-review-future-only")
            }

            Section("Schedule summary") {
                LabeledContent("Plan", value: draft.name)
                LabeledContent("Weeks", value: "\(draft.weeks.count)")
                LabeledContent("Training days", value: trainingDaysText)
                LabeledContent("Equipment", value: draft.equipmentSummary)
                LabeledContent("Phases", value: draft.phaseSummary)
            }

            Section("Plan phases") {
                ForEach(draft.blocks) { block in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("\(block.normalizedName) · \(block.weekSummary)")
                            .font(AppFont.subheadlineSemibold)
                        Text(block.phaseType.title)
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        if block.phaseType == .deload {
                            Text(block.deloadSummary)
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
                }
            }

            if !warnings.isEmpty {
                Section("Needs attention") {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: AppIcon.warning)
                            .foregroundStyle(Color.gymDestructive)
                    }
                }
            }

            Section("Upcoming workouts") {
                ForEach(draft.weeks) { week in
                    DisclosureGroup("Week \(week.weekIndex + 1)") {
                        ForEach(week.workouts) { workout in
                            PlanReviewWorkoutRow(
                                workout: workout,
                                dayName: dayName(for: workout.dayOffset)
                            )
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Review Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm Changes") {
                    if let message = onConfirm() {
                        confirmErrorMessage = message
                        AccessibilityNotification.Announcement(message).post()
                    }
                }
                .disabled(!warnings.isEmpty)
                .accessibilityIdentifier("confirm-plan-changes")
            }
        }
        .alert(
            Text("Changes not saved"),
            isPresented: Binding(
                get: { confirmErrorMessage != nil },
                set: { if !$0 { confirmErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(confirmErrorMessage ?? "")
        }
    }

    private var warnings: [String] {
        var results: [String] = []
        for week in draft.weeks {
            for workout in week.workouts {
                if workout.exercises.isEmpty {
                    results.append("Week \(week.weekIndex + 1), \(workout.name) needs at least one exercise.")
                }
                for exercise in workout.exercises where exercise.repRangeMinimum > exercise.repRangeMaximum {
                    results.append("\(exercise.exercise.name) has an invalid rep range.")
                }
            }
        }
        results += draft.trackingProfileIssues.map(\.message)
        return results
    }

    private var trainingDaysText: String {
        let days = Set(draft.weeks.flatMap { $0.workouts.map(\.dayOffset) }).sorted()
        return days.map(dayName(for:)).joined(separator: ", ")
    }

    private func dayName(for offset: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][max(0, min(offset, 6))]
    }
}

struct PlanReviewWorkoutRow: View {
    let workout: PlanWorkoutDraft
    let dayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(workout.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Text(dayName)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            if workout.exercises.isEmpty {
                Text("No exercises prescribed")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymDestructive)
            } else {
                ForEach(workout.exercises) { exercise in
                    PlanReviewExerciseRow(exercise: exercise)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

struct PlanReviewExerciseRow: View {
    let exercise: PlanExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if exercise.supersetGroupID != nil {
                Label("Superset", systemImage: "link")
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymPrimary)
            }
            Text(exercise.displayName)
                .font(AppFont.captionBold)
            Text(exercise.summary)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
            if !exercise.plannedSets.isEmpty {
                ForEach(Array(exercise.plannedSets.enumerated()), id: \.element.id) { index, set in
                    Label("Set \(index + 1) · \(set.summary)", systemImage: set.setType.icon)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("plan-review-set-\(index + 1)-\(exercise.id.uuidString)")
                }
            }
            Text("\(exercise.stimulus.title) stimulus")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            if let alternatives = exercise.alternativesSummary {
                Text("Alternatives: \(alternatives)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }
}
