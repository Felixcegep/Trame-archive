import SwiftData
import SwiftUI

/// Builds a plan in one screen: name it, say how long it runs, pick the days.
///
/// The form used to open on Goal, Experience, Equipment and a deload toggle
/// before reaching the schedule, then spend seven toggle rows and seven nested
/// pickers on the week. Those four are metadata — a plan works without any of
/// them — so they collapse into Options, and the week became a chip strip.
///
/// "Repeats" lives here as a length, which is what stops a rotation from being
/// a separate kind of object the user has to discover somewhere else.
struct PlanFormView: View {
    enum Length: Hashable, CaseIterable {
        case fixed
        case repeating

        var title: LocalizedStringKey {
            switch self {
            case .fixed: "Fixed length"
            case .repeating: "Repeats"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onSave: (WorkoutPlan) -> Void
    let onSaveRepeating: (RepeatingPlan) -> Void

    @State private var name = ""
    @State private var length: Length = .fixed
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
    @State private var isShowingOptions = false
    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        Form {
            nameSection
            lengthSection
            trainingDaysSection
            optionsSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("New Training Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedWork {
                        isShowingDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-plan")
            }
        }
        // A plan is the longest form in the app — a name, a length, a training
        // week, and a workout per day. All of it was one downward swipe from
        // gone, with no warning and nothing to recover.
        .interactiveDismissDisabled(hasUnsavedWork)
        .confirmationDialog(
            "Discard this plan?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard plan", role: .destructive) { dismiss() }
                .accessibilityIdentifier("confirm-discard-plan")
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("The name, schedule, and workouts you have chosen will not be saved.")
        }
        .onAppear(perform: applyInitialState)
        .onChange(of: durationWeeks) { _, newDuration in
            deloadWeekIndex = min(deloadWeekIndex, max(0, newDuration - 1))
        }
    }
}

// MARK: - Sections

private extension PlanFormView {
    var nameSection: some View {
        Section {
            TextField("Name", text: $name)
                .accessibilityIdentifier("plan-name-field")
        }
    }

    var lengthSection: some View {
        Section("Structure") {
            Picker("Structure", selection: $length) {
                ForEach(Length.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plan-length")

            if length == .fixed {
                Stepper("\(durationWeeks) weeks", value: $durationWeeks, in: 1...52)
                    .accessibilityIdentifier("plan-duration-weeks")
                Text("Program — my sessions are scheduled across weeks.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                Text("Rotation — I always do the next workout, regardless of weekday.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    var trainingDaysSection: some View {
        Section("Training days") {
            if availableTemplates.isEmpty {
                Text("Create a workout with at least one exercise before building a plan.")
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                WeekdayStrip(selection: daySelectionBinding)
                    .listRowInsets(EdgeInsets(
                        top: Spacing.m,
                        leading: Spacing.l,
                        bottom: Spacing.m,
                        trailing: Spacing.l
                    ))

                ForEach(selectedDayOffsets.sorted(), id: \.self) { dayOffset in
                    Picker(selection: templateBinding(for: dayOffset)) {
                        ForEach(availableTemplates, id: \.persistentModelID) { template in
                            VStack(alignment: .leading) {
                                Text(template.name)
                                Text(exerciseCountText(for: template))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            .tag(Optional(template.persistentModelID))
                        }
                    } label: {
                        Text(WeekdayStrip.shortName(for: dayOffset))
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("plan-day-template-\(dayOffset)")
                }

                if selectedDayOffsets.isEmpty {
                    Text("Pick at least one day to train.")
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
    }

    /// Goal, experience, equipment, scheduling mode and the deload are all
    /// optional refinements. Collapsed by default, they stop standing between
    /// the user and a working plan.
    var optionsSection: some View {
        Section {
            DisclosureGroup("Options", isExpanded: $isShowingOptions) {
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

                NavigationLink {
                    PlanEquipmentPickerView(selectedEquipment: $requiredEquipment)
                } label: {
                    LabeledContent("Equipment", value: equipmentSummary)
                }
                .accessibilityIdentifier("plan-equipment-picker")

                if length == .fixed {
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

                    deloadControls
                }
            }
        }
    }

    @ViewBuilder
    var deloadControls: some View {
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
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityIdentifier("plan-deload-description")
        }
    }
}

// MARK: - Saving

private extension PlanFormView {
    func save() {
        switch length {
        case .fixed:
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
        case .repeating:
            onSaveRepeating(repeatingPlan)
        }
        dismiss()
    }

    /// Day order becomes rotation order: a Mon/Wed/Fri selection rotates through
    /// those three workouts indefinitely, in that sequence.
    var repeatingPlan: RepeatingPlan {
        let slots = selectedDayAssignments.enumerated().map { index, assignment in
            RepeatingPlanSlot(orderIndex: index, workoutTemplate: assignment.template)
        }
        return RepeatingPlan(
            name: trimmedName,
            goal: goal,
            experienceLevel: experienceLevel,
            requiredEquipment: requiredEquipment,
            slots: slots
        )
    }

    /// Whether dismissing would lose something the lifter chose.
    ///
    /// Deliberately coarse: a name or any assigned workout. The form has
    /// fourteen pieces of state and most carry defaults, so comparing all of
    /// them would be fragile and would treat merely opening the options section
    /// as an edit. These two are what a person would describe as "the work".
    var hasUnsavedWork: Bool {
        !trimmedName.isEmpty || !templateIDByDay.isEmpty
    }

    var canSave: Bool {
        !trimmedName.isEmpty
            && !selectedDayOffsets.isEmpty
            && selectedDayAssignments.count == selectedDayOffsets.count
    }
}

// MARK: - State

private extension PlanFormView {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var availableTemplates: [WorkoutTemplate] {
        templates
            .filter { !$0.orderedTemplateExercises.isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var selectedDayAssignments: [PlanCoordinator.DayAssignment] {
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

    var deloadConfiguration: PlanCoordinator.DeloadConfiguration? {
        guard includesDeload, length == .fixed else { return nil }
        return PlanCoordinator.DeloadConfiguration(
            weekIndex: deloadWeekIndex,
            volumeReductionPercent: deloadVolumeReductionPercent,
            intensityReductionPercent: deloadIntensityReductionPercent
        )
    }

    var equipmentSummary: String {
        requiredEquipment.isEmpty
            ? "None selected"
            : requiredEquipment.map(\.rawValue).joined(separator: ", ")
    }

    var suggestedEquipment: [EquipmentType] {
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

    /// Selecting a day assigns the first available workout immediately, so a
    /// half-configured day never blocks Save without saying why.
    var daySelectionBinding: Binding<Set<Int>> {
        Binding(
            get: { selectedDayOffsets },
            set: { newSelection in
                for added in newSelection.subtracting(selectedDayOffsets) where templateIDByDay[added] == nil {
                    templateIDByDay[added] = availableTemplates.first?.persistentModelID
                }
                for removed in selectedDayOffsets.subtracting(newSelection) {
                    templateIDByDay.removeValue(forKey: removed)
                }
                selectedDayOffsets = newSelection
            }
        )
    }

    func templateBinding(for dayOffset: Int) -> Binding<PersistentIdentifier?> {
        Binding(
            get: {
                templateIDByDay[dayOffset]
                    ?? availableTemplates.first?.persistentModelID
            },
            set: { selectedID in
                if let selectedID {
                    templateIDByDay[dayOffset] = selectedID
                } else {
                    templateIDByDay.removeValue(forKey: dayOffset)
                }
            }
        )
    }

    func exerciseCountText(for template: WorkoutTemplate) -> String {
        "\(template.templateExercises.count) exercises"
    }

    func applyInitialState() {
        if let firstTemplateID = availableTemplates.first?.persistentModelID {
            for dayOffset in selectedDayOffsets where templateIDByDay[dayOffset] == nil {
                templateIDByDay[dayOffset] = firstTemplateID
            }
        }
        if requiredEquipment.isEmpty {
            requiredEquipment = suggestedEquipment
        }
        if AppLaunchArguments.current.contains("-ui-testing-plan-deload") {
            includesDeload = true
            isShowingOptions = true
        }
    }
}
