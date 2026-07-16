import SwiftUI

struct PlanEquipmentPickerView: View {
    @Binding var selectedEquipment: [EquipmentType]

    var body: some View {
        List {
            Section {
                Text("Choose the equipment this program uses. You can change this later; completed workouts stay unchanged.")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Equipment") {
                ForEach(EquipmentType.allCases, id: \.self) { equipment in
                    Button {
                        toggle(equipment)
                    } label: {
                        HStack {
                            Text(equipment.rawValue)
                                .foregroundStyle(Color.gymText)
                            Spacer()
                            if selectedEquipment.contains(equipment) {
                                Image(systemName: AppIcon.checkmark)
                                    .foregroundStyle(Color.gymPrimary)
                            }
                        }
                    }
                    .accessibilityIdentifier("plan-equipment-\(equipment.accessibilityIdentifier)")
                    .accessibilityValue(
                        selectedEquipment.contains(equipment) ? "Selected" : "Not selected"
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Program Equipment")
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
