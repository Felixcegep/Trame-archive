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
    @State private var scheduleMode: PlanScheduleMode = .fixedWeekdays
    @State private var scheduleIntervalDays = 2
    @State private var templateIDByDay: [Int: PersistentIdentifier] = [:]
    @State private var requiredEquipment: [EquipmentType] = []
    @State private var includesDeload = false
    @State private var deloadWeekIndex = 3
    @State private var deloadVolumeReductionPercent = 50
    @State private var deloadIntensityReductionPercent = 10

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

            Section("Plan equipment") {
                NavigationLink {
                    PlanEquipmentPickerView(selectedEquipment: $requiredEquipment)
                } label: {
                    LabeledContent("Equipment", value: equipmentSummary)
                }
                .accessibilityIdentifier("plan-equipment-picker")

                Text("This records the equipment this plan needs. It does not change your saved workouts or completed history.")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Recovery") {
                Toggle("Schedule a deload week", isOn: $includesDeload)
                    .accessibilityIdentifier("plan-deload-toggle")

                if includesDeload {
                    Picker("Deload week", selection: $deloadWeekIndex) {
                        ForEach(0..<durationWeeks, id: \.self) { weekIndex in
                            Text("Week \(weekIndex + 1)").tag(weekIndex)
                        }
                    }
                    .accessibilityIdentifier("plan-deload-week")

                    Stepper(
                        "Reduce sets by \(deloadVolumeReductionPercent)%",
                        value: $deloadVolumeReductionPercent,
                        in: 0...90
                    )
                    .accessibilityIdentifier("plan-deload-volume-reduction")

                    Stepper(
                        "Reduce load by \(deloadIntensityReductionPercent)%",
                        value: $deloadIntensityReductionPercent,
                        in: 0...90
                    )
                    .accessibilityIdentifier("plan-deload-intensity-reduction")

                    Text("The deload changes only the prescription snapshot for that future week's workouts. Your completed workouts stay unchanged.")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("plan-deload-description")
                }
            }

            Section("Weekly schedule") {
                Picker("Schedule", selection: $scheduleMode) {
                    ForEach(PlanScheduleMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .accessibilityIdentifier("plan-schedule-mode")

                if scheduleMode == .everyNDays {
                    Stepper("Every \(scheduleIntervalDays) days", value: $scheduleIntervalDays, in: 1...14)
                        .accessibilityIdentifier("plan-schedule-interval")
                }

                Text(scheduleMode == .fixedWeekdays
                    ? "Choose each training day and the saved workout assigned to it."
                    : "Choose the session sequence. Calendar dates are derived from session order.")
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
                    Text("Create a workout with at least one exercise before building a plan.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("New Training Plan")
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
                            requiredEquipment: requiredEquipment,
                            durationWeeks: durationWeeks,
                            dayAssignments: selectedDayAssignments,
                            deload: deloadConfiguration,
                            scheduleMode: scheduleMode,
                            scheduleIntervalDays: scheduleIntervalDays
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
            if requiredEquipment.isEmpty {
                requiredEquipment = suggestedEquipment
            }
            if CommandLine.arguments.contains("-ui-testing-plan-deload") {
                includesDeload = true
            }
        }
        .onChange(of: durationWeeks) { _, newDuration in
            deloadWeekIndex = min(deloadWeekIndex, max(0, newDuration - 1))
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

    private var deloadConfiguration: PlanCoordinator.DeloadConfiguration? {
        guard includesDeload else { return nil }
        return PlanCoordinator.DeloadConfiguration(
            weekIndex: deloadWeekIndex,
            volumeReductionPercent: deloadVolumeReductionPercent,
            intensityReductionPercent: deloadIntensityReductionPercent
        )
    }

    private var equipmentSummary: String {
        requiredEquipment.isEmpty
            ? "None selected"
            : requiredEquipment.map(\.rawValue).joined(separator: ", ")
    }

    private var suggestedEquipment: [EquipmentType] {
        Array(
            Set(
                selectedDayAssignments.compactMap { assignment in
                    assignment.template.orderedTemplateExercises
                        .compactMap { $0.exercise.equipmentType }
                }
                .flatMap { $0 }
            )
        )
        .sorted { $0.rawValue < $1.rawValue }
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
