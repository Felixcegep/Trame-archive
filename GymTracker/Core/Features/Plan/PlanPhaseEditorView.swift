import SwiftUI

struct PlanPhaseEditorView: View {
    @Binding var blocks: [PlanBlockDraft]

    var body: some View {
        Form {
            Section {
                Text("Phases organize the program weeks. A deload reduces the prescribed sets and suggested load only when that planned workout starts; completed workouts stay unchanged.")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach($blocks) { $block in
                Section(block.weekSummary) {
                    TextField("Phase name", text: $block.name)

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
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Program Phases")
    }
}
