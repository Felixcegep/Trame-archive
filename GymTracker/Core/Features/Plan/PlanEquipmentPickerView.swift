import SwiftUI

struct PlanEquipmentPickerView: View {
    @Binding var selectedEquipment: [EquipmentType]

    var body: some View {
        List {
            Section {
                Text("Choose the equipment this plan uses. You can change this later; completed workouts stay unchanged.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameSubdued)
                    .padding(.vertical, Spacing.xs)
        } header: {
            TrameDomainSectionRule(title: "Plan equipment", color: Color.trameStrength)
        }

            Section {
                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                    Button {
                        toggle(equipment)
                    } label: {
                        HStack {
                            Text(equipment.rawValue)
                                .foregroundStyle(Color.trameText)
                            Spacer()
                            if selectedEquipment.contains(equipment) {
                                Image(systemName: AppIcon.checkmark)
                                    .foregroundStyle(Color.trameActionDeep)
                            }
                        }
                    }
                    .accessibilityIdentifier("plan-equipment-\(equipment.accessibilityIdentifier)")
                    .accessibilityValue(
                        selectedEquipment.contains(equipment) ? "Selected" : "Not selected"
                    )
                }
            } header: {
                TrameDomainSectionRule(title: "Equipment", color: Color.trameStrength)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Plan Equipment")
    }

    private func toggle(_ equipment: EquipmentType) {
        if let index = selectedEquipment.firstIndex(of: equipment) {
            selectedEquipment.remove(at: index)
        } else {
            selectedEquipment.append(equipment)
            selectedEquipment.sort { $0.rawValue < $1.rawValue }
        }
    }
}

private extension EquipmentType {
    var accessibilityIdentifier: String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}
