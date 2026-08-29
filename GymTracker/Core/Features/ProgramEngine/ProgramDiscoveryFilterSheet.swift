import SwiftUI

struct ProgramDiscoveryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: ProgramDiscoveryFilters
    let disciplines: [TrainingDisciplinePreference]
    let goals: [PlanGoal]
    let experienceLevels: [PlanExperienceLevel]
    let daysPerWeek: [Int]
    let durationWeeks: [Int]
    let scheduleModes: [PlanScheduleMode]
    let equipment: [EquipmentType]
    let capabilityIDs: [String]

    var body: some View {
        NavigationStack {
            List {
                filterSection("Discipline", values: disciplines, selection: $filters.disciplines) { $0.title }
                filterSection("Goal", values: goals, selection: $filters.goals) { $0.onboardingTitle }
                filterSection("Experience", values: experienceLevels, selection: $filters.experienceLevels) { $0.onboardingTitle }
                filterSection("Days per week", values: daysPerWeek, selection: $filters.daysPerWeek) {
                    CountPhrase.days($0)
                }
                filterSection("Program duration", values: durationWeeks, selection: $filters.durationWeeks) {
                    String(localized: "\($0) weeks")
                }
                filterSection("Schedule style", values: scheduleModes, selection: $filters.scheduleModes) {
                    scheduleTitle($0)
                }

                Section {
                    ForEach(equipment, id: \.self) { item in
                        choiceRow(
                            title: item.onboardingTitle,
                            isSelected: filters.availableEquipment.contains(item)
                        ) { toggle(item, in: &filters.availableEquipment) }
                    }
                    ForEach(capabilityIDs, id: \.self) { id in
                        choiceRow(
                            title: SpecializedEquipmentCapability.title(for: id),
                            isSelected: filters.availableCapabilityIDs.contains(id)
                        ) { toggle(id, in: &filters.availableCapabilityIDs) }
                    }
                } header: {
                    Text("Equipment I have")
                } footer: {
                    Text("Select everything available to you. Plans stay visible until you choose equipment.")
                }
            }
            .font(AppFont.body)
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Refine plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { filters.clear() }
                        .disabled(filters.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.bodyMedium)
                }
            }
        }
        .accessibilityIdentifier("program-discovery-filters")
    }

    @ViewBuilder
    private func filterSection<Value: Hashable>(
        _ title: LocalizedStringKey,
        values: [Value],
        selection: Binding<Set<Value>>,
        label: @escaping (Value) -> String
    ) -> some View {
        Section(title) {
            ForEach(values, id: \.self) { value in
                choiceRow(title: label(value), isSelected: selection.wrappedValue.contains(value)) {
                    var updated = selection.wrappedValue
                    toggle(value, in: &updated)
                    selection.wrappedValue = updated
                }
            }
        }
    }

    private func choiceRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Text(title)
                    .foregroundStyle(Color.gymText)
                Spacer()
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                        .foregroundStyle(Color.trameAction)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle<Value: Hashable>(_ value: Value, in set: inout Set<Value>) {
        if !set.insert(value).inserted { set.remove(value) }
    }

    private func scheduleTitle(_ mode: PlanScheduleMode) -> String {
        switch mode {
        case .fixedWeekdays: String(localized: "Fixed weekdays")
        case .sequential: String(localized: "In order")
        case .everyNDays: String(localized: "Every few days")
        }
    }
}
