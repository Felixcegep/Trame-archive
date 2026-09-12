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
                        .font(AppFont.body)
                } icon: {
                    Image(systemName: AppIcon.info)
                        .foregroundStyle(Color.trameActionDeep)
                }
                .accessibilityIdentifier("plan-review-future-only")
                .padding(.vertical, Spacing.xs)
            } header: {
                TrameDomainSectionRule(title: "Change boundary", color: Color.trameAction)
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxl) {
                        TrameMetric(
                            value: "\(draft.weeks.count)",
                            label: "Weeks",
                            accessibilityLabel: "\(draft.weeks.count) weeks"
                        )
                        TrameMetric(
                            value: "\(Set(draft.weeks.flatMap { $0.workouts.map(\.dayOffset) }).count)",
                            label: "Training days",
                            accessibilityLabel: "\(trainingDaysText) training days"
                        )
                    }

                    planField(title: "Plan", value: draft.name)
                    planField(title: "Training days", value: trainingDaysText)
                    planField(title: "Equipment", value: draft.equipmentSummary)
                    planField(title: "Phases", value: draft.phaseSummary)
                }
                .padding(.vertical, Spacing.s)
            } header: {
                TrameDomainSectionRule(title: "Schedule summary", color: Color.trameStrength)
            }

            Section {
                ForEach(draft.blocks) { block in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("\(block.normalizedName) · \(block.weekSummary)")
                            .font(AppFont.sectionTitle)
                            .foregroundStyle(Color.trameText)
                        Text(block.phaseType.title)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                        if block.phaseType == .deload {
                            Text(block.deloadSummary)
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                        }
                    }
                    .padding(.vertical, Spacing.s)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.trameSeparator)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            } header: {
                TrameDomainSectionRule(title: "Plan phases", color: Color.trameStrength)
            }

            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: AppIcon.warning)
                            .foregroundStyle(Color.trameDestructiveText)
                            .padding(.vertical, Spacing.xs)
                    }
                } header: {
                    TrameDomainSectionRule(title: "Needs attention", color: Color.trameAttention)
                }
            }

            Section {
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
            } header: {
                TrameDomainSectionRule(title: "Upcoming workouts", color: Color.trameStrength)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
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
        if draft.scheduleMode.usesFlexibleWeekWindow {
            let count = draft.weeks.first?.workouts.count ?? 0
            return count == 1
                ? String(localized: "1 workout a week")
                : String(localized: "\(count) workouts a week")
        }
        if !draft.scheduleMode.pinsWeekdays {
            return draft.scheduleMode.title
        }
        let days = Set(draft.weeks.flatMap { $0.workouts.map(\.dayOffset) }).sorted()
        return days.map(dayName(for:)).joined(separator: ", ")
    }

    private func dayName(for offset: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][max(0, min(offset, 6))]
    }

    @ViewBuilder
    private func planField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title.uppercased())
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PlanReviewWorkoutRow: View {
    let workout: PlanWorkoutDraft
    let dayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.name)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                Spacer()
                Text(dayName)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }

            if workout.exercises.isEmpty {
                Text("No exercises prescribed")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameDestructiveText)
            } else {
                ForEach(workout.exercises) { exercise in
                    PlanReviewExerciseRow(exercise: exercise)
                }
            }
        }
        .padding(.vertical, Spacing.s)
    }
}

struct PlanReviewExerciseRow: View {
    let exercise: PlanExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if exercise.supersetGroupID != nil {
                Label("Superset", systemImage: "link")
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameActionDeep)
            }
            Text(exercise.displayName)
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.trameText)
            Text(exercise.summary)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
            if !exercise.plannedSets.isEmpty {
                ForEach(Array(exercise.plannedSets.enumerated()), id: \.element.id) { index, set in
                    Label("Set \(index + 1) · \(set.summary)", systemImage: set.setType.icon)
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .accessibilityIdentifier("plan-review-set-\(index + 1)-\(exercise.id.uuidString)")
                }
            }
            Text("\(exercise.stimulus.title) stimulus")
                .font(AppFont.micro)
                .foregroundStyle(Color.trameStrength)
            if let alternatives = exercise.alternativesSummary {
                Text("Alternatives: \(alternatives)")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
        .padding(.vertical, Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}
