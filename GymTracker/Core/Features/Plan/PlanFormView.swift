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
    @State private var selectedDayOffsets: Set<Int> = [0, 2, 4]
    @State private var templateIDByDay: [Int: PersistentIdentifier] = [:]

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
                Text("Choose each training day and the workout template assigned to it.")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)

                ForEach(weekdayOptions, id: \.offset) { day in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Toggle(day.name, isOn: binding(for: day.offset))
                            .accessibilityIdentifier("plan-day-\(day.offset)")

                        if selectedDayOffsets.contains(day.offset), !availableTemplates.isEmpty {
                            Picker("Workout", selection: templateBinding(for: day.offset)) {
                                ForEach(availableTemplates, id: \.persistentModelID) { template in
                                    VStack(alignment: .leading) {
                                        Text(template.name)
                                        Text(exerciseCountText(for: template))
                                            .font(AppFont.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .tag(template.persistentModelID)
                                }
                            }
                            .pickerStyle(.navigationLink)
                            .accessibilityIdentifier("plan-day-template-\(day.offset)")
                        }
                    }
                }

                if availableTemplates.isEmpty {
                    Text("Create a non-empty workout template before creating a plan.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("New Plan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        PlanCoordinator.createPlan(
                            name: trimmedName,
                            goal: goal,
                            experienceLevel: experienceLevel,
                            durationWeeks: durationWeeks,
                            dayAssignments: selectedDayAssignments
                        )
                    )
                    dismiss()
                }
                .disabled(!canSave)
                .accessibilityIdentifier("save-plan")
            }
        }
        .onAppear {
            if let firstTemplateID = availableTemplates.first?.persistentModelID {
                for dayOffset in selectedDayOffsets where templateIDByDay[dayOffset] == nil {
                    templateIDByDay[dayOffset] = firstTemplateID
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableTemplates: [WorkoutTemplate] {
        templates
            .filter { !$0.orderedTemplateExercises.isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedDayAssignments: [PlanCoordinator.DayAssignment] {
        selectedDayOffsets.sorted().compactMap { dayOffset in
            guard
                let templateID = templateIDByDay[dayOffset],
                let template = availableTemplates.first(where: { $0.persistentModelID == templateID })
            else {
                return nil
            }
            return PlanCoordinator.DayAssignment(dayOffset: dayOffset, template: template)
        }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && !selectedDayOffsets.isEmpty
            && selectedDayAssignments.count == selectedDayOffsets.count
    }

    private func binding(for dayOffset: Int) -> Binding<Bool> {
        Binding(
            get: { selectedDayOffsets.contains(dayOffset) },
            set: { isSelected in
                if isSelected {
                    selectedDayOffsets.insert(dayOffset)
                    if templateIDByDay[dayOffset] == nil {
                        templateIDByDay[dayOffset] = availableTemplates.first?.persistentModelID
                    }
                } else {
                    selectedDayOffsets.remove(dayOffset)
                    templateIDByDay.removeValue(forKey: dayOffset)
                }
            }
        )
    }

    private func templateBinding(for dayOffset: Int) -> Binding<PersistentIdentifier> {
        Binding(
            get: {
                templateIDByDay[dayOffset]
                    ?? availableTemplates.first!.persistentModelID
            },
            set: { templateIDByDay[dayOffset] = $0 }
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
