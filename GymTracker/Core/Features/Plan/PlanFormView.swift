import SwiftData
import SwiftUI

struct PlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onSave: (WorkoutPlan) -> Void

    @State private var name = ""
    @State private var durationWeeks = 4
    @State private var goal: PlanGoal = .generalStrength
    @State private var experienceLevel: PlanExperienceLevel = .beginner
    @State private var selectedTemplateID: PersistentIdentifier?
    @State private var selectedDayOffsets: Set<Int> = [0, 2, 4]

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("plan-name-field")

                Picker("Goal", selection: $goal) {
                    ForEach(PlanGoal.allCases, id: \.self) { goal in
                        Text(goal.title).tag(goal)
                    }
                }

                Picker("Experience", selection: $experienceLevel) {
                    ForEach(PlanExperienceLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }

                Stepper("\(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
            }

            Section("Weekly schedule") {
                Text("Choose the days this workout repeats. You can add week-specific programming in a later release.")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)

                ForEach(weekdayOptions, id: \.offset) { day in
                    Toggle(day.name, isOn: binding(for: day.offset))
                        .accessibilityIdentifier("plan-day-\(day.offset)")
                }
            }

            Section("Workout template") {
                if templates.isEmpty {
                    Text("Create a workout template before creating a plan.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates, id: \.persistentModelID) { template in
                        Button {
                            selectedTemplateID = template.persistentModelID
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(template.name)
                                        .foregroundStyle(Color.gymText)
                                    Text(exerciseCountText(for: template))
                                        .font(AppFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedTemplateID == template.persistentModelID ? AppIcon.checkmarkCircle : AppIcon.circle)
                                    .foregroundStyle(Color.gymPrimary)
                            }
                        }
                        .accessibilityIdentifier("plan-template-\(template.name)")
                    }
                }
            }
        }
        .navigationTitle("New Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let template = selectedTemplate else { return }
                    onSave(
                        PlanCoordinator.createRepeatedPlan(
                            name: trimmedName,
                            goal: goal,
                            experienceLevel: experienceLevel,
                            durationWeeks: durationWeeks,
                            template: template,
                            dayOffsets: Array(selectedDayOffsets)
                        )
                    )
                    dismiss()
                }
                .disabled(trimmedName.isEmpty || selectedTemplate?.templateExercises.isEmpty != false || selectedDayOffsets.isEmpty)
                .accessibilityIdentifier("save-plan")
            }
        }
        .onAppear {
            if selectedTemplateID == nil {
                selectedTemplateID = templates.first?.persistentModelID
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTemplate: WorkoutTemplate? {
        templates.first(where: { $0.persistentModelID == selectedTemplateID })
    }

    private func binding(for dayOffset: Int) -> Binding<Bool> {
        Binding(
            get: { selectedDayOffsets.contains(dayOffset) },
            set: { isSelected in
                if isSelected {
                    selectedDayOffsets.insert(dayOffset)
                } else {
                    selectedDayOffsets.remove(dayOffset)
                }
            }
        )
    }

    private func exerciseCountText(for template: WorkoutTemplate) -> String {
        "\(template.templateExercises.count) exercises"
    }

    private var weekdayOptions: [(name: String, offset: Int)] {
        [
            ("Monday", 0),
            ("Tuesday", 1),
            ("Wednesday", 2),
            ("Thursday", 3),
            ("Friday", 4),
            ("Saturday", 5),
            ("Sunday", 6)
        ]
    }
}
