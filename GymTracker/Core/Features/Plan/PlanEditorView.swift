import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @State private var draft: PlanEditorDraft
    @State private var selectedWeekIndex: Int?
    @State private var selectedWorkoutIndex: Int?
    @State private var isShowingWorkoutEditor = false
    @State private var isShowingReview = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _draft = State(initialValue: PlanEditorDraft(plan: plan))
    }

    var body: some View {
        Form {
            Section("Program overview") {
                TextField("Name", text: $draft.name)
                Picker("Goal", selection: $draft.goal) {
                    ForEach(PlanGoal.allCases, id: \.self) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                Picker("Experience", selection: $draft.experienceLevel) {
                    ForEach(PlanExperienceLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                NavigationLink {
                    PlanEquipmentPickerView(selectedEquipment: $draft.requiredEquipment)
                } label: {
                    LabeledContent("Program equipment", value: draft.equipmentSummary)
                }
                .accessibilityIdentifier("edit-plan-equipment-picker")
                NavigationLink {
                    PlanPhaseEditorView(blocks: $draft.blocks)
                } label: {
                    LabeledContent("Program phases", value: draft.phaseSummary)
                }
                .accessibilityIdentifier("edit-plan-phases")
            }

            ForEach($draft.weeks) { $week in
                Section("Week \(week.weekIndex + 1)") {
                    ForEach($week.workouts) { $workout in
                        Button {
                            selectedWeekIndex = week.weekIndex
                            selectedWorkoutIndex = week.workouts.firstIndex { $0.id == workout.id }
                            isShowingWorkoutEditor = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.name)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.gymText)
                                    Text("Day \(workout.dayOffset + 1) · \(workout.exercises.count) exercises")
                                        .font(AppFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: AppIcon.chevronRight)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("edit-plan-workout")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Edit Program")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    isShowingReview = true
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("save-plan-edits")
            }
        }
        .sheet(isPresented: $isShowingWorkoutEditor) {
            if let weekIndex = selectedWeekIndex,
               let workoutIndex = selectedWorkoutIndex,
               let weekIndexInDraft = draft.weeks.firstIndex(where: { $0.weekIndex == weekIndex }) {
                NavigationStack {
                    PlanWorkoutEditorView(
                        workout: $draft.weeks[weekIndexInDraft].workouts[workoutIndex],
                        exercises: exercises
                    )
                }
            }
        }
        .sheet(isPresented: $isShowingReview) {
            NavigationStack {
                PlanReviewView(draft: draft) {
                    do {
                        try draft.apply(to: plan, using: modelContext)
                    } catch let failure as TrackingProfileValidationFailure {
                        modelContext.rollback()
                        return failure.errorDescription
                    } catch {
                        modelContext.rollback()
                        return error.localizedDescription
                    }
                    guard saveModelContext(modelContext) else {
                        return String(localized: "The program could not be saved. Please try again.")
                    }
                    isShowingReview = false
                    dismiss()
                    return nil
                }
            }
        }
    }
}
