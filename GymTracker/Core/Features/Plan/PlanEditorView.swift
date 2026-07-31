import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    @State private var draft: PlanEditorDraft
    @State private var isShowingReview = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _draft = State(initialValue: PlanEditorDraft(plan: plan))
    }

    var body: some View {
        Form {
            Section("Plan overview") {
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
                    LabeledContent("Plan equipment", value: draft.equipmentSummary)
                }
                .accessibilityIdentifier("edit-plan-equipment-picker")
                NavigationLink {
                    PlanPhaseEditorView(blocks: $draft.blocks)
                } label: {
                    LabeledContent("Plan phases", value: draft.phaseSummary)
                }
                .accessibilityIdentifier("edit-plan-phases")
            }

            ForEach($draft.weeks) { $week in
                Section("Week \(week.weekIndex + 1)") {
                    ForEach($week.workouts) { $workout in
                        NavigationLink {
                            PlanWorkoutEditorView(
                                workout: $workout,
                                exercises: exercises
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.name)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.gymText)
                                    Text("Day \(workout.dayOffset + 1) · \(workout.exercises.count) exercises")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.gymSubduedText)
                                }
                                Spacer()
                                Image(systemName: AppIcon.chevronRight)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityIdentifier("edit-plan-workout")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Edit Plan")
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
                        return String(localized: "The plan could not be saved. Please try again.")
                    }
                    isShowingReview = false
                    dismiss()
                    return nil
                }
            }
        }
    }
}
