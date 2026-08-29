import SwiftUI

struct PlanPhaseEditorView: View {
    @Binding var blocks: [PlanBlockDraft]

    var body: some View {
        Form {
            Section {
                Text("Phases organize the plan weeks. A deload reduces the prescribed sets and suggested load only when that planned workout starts; completed workouts stay unchanged.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameSubdued)
                    .padding(.vertical, Spacing.xs)
        } header: {
            TrameDomainSectionRule(title: "Plan phases", color: Color.trameStrength)
        }

            ForEach($blocks) { $block in
                Section {
                    HStack {
                        TextField("Phase name", text: $block.name)
                        Button(role: .destructive) {
                            remove(block.id)
                        } label: {
                            Image(systemName: AppIcon.trash)
                        }
                        .accessibilityLabel("Delete phase")
                    }

                    Picker("Phase", selection: $block.phaseType) {
                        ForEach(PlanPhaseType.allCases, id: \.self) { phase in
                            Text(phase.title).tag(phase)
                        }
                    }

                    if block.phaseType == .deload {
                        Stepper(
                            "Reduce sets by \(block.deloadVolumeReductionPercent)%",
                            value: $block.deloadVolumeReductionPercent,
                            in: 0...90
                        )
                        .accessibilityIdentifier("plan-deload-volume-reduction")

                        Stepper(
                            "Reduce load by \(block.deloadIntensityReductionPercent)%",
                            value: $block.deloadIntensityReductionPercent,
                            in: 0...90
                        )
                        .accessibilityIdentifier("plan-deload-intensity-reduction")
                    }
                } header: {
                    TrameDomainSectionRule(
                        title: LocalizedStringKey(block.weekSummary),
                        color: block.phaseType == .deload ? Color.trameAttention : Color.trameStrength
                    )
                }
            }
            .onMove { source, destination in
                blocks.move(fromOffsets: source, toOffset: destination)
                for (index, _) in blocks.enumerated() {
                    blocks[index].orderIndex = index
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Plan Phases")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private func remove(_ id: UUID) {
        guard blocks.count > 1 else { return }
        blocks.removeAll { $0.id == id }
        for (index, _) in blocks.enumerated() {
            blocks[index].orderIndex = index
        }
    }
}
