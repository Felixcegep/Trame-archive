import SwiftData
import SwiftUI

struct TemplateExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var templateExercise: TemplateExercise

    var body: some View {
        Form {
            Section("Prescription") {
                Stepper("Sets: \(templateExercise.targetSets)", value: $templateExercise.targetSets, in: 1...12)
                Stepper("Minimum reps: \(templateExercise.repRangeMinimum)", value: minimumReps, in: 1...30)
                Stepper("Maximum reps: \(templateExercise.repRangeMaximum)", value: maximumReps, in: 1...30)
                Stepper("Rest: \(templateExercise.restSeconds) sec", value: $templateExercise.restSeconds, in: 0...300, step: 15)
            }

            Section("Effort") {
                Picker("Target RPE", selection: $templateExercise.targetRPE) {
                    Text("Not set").tag(Double?.none)
                    ForEach(Array(stride(from: 1.0, through: 10.0, by: 0.5)), id: \.self) { value in
                        Text("\(Formatters.formatFloat(Float(value))) - \(rpeDescription(for: value))")
                            .tag(Optional(value))
                    }
                }

                Picker("Target RIR", selection: $templateExercise.targetRIR) {
                    Text("Not set").tag(Int?.none)
                    ForEach(0...5, id: \.self) { value in
                        Text("\(value) reps in reserve").tag(Optional(value))
                    }
                }
            }

            if progressionIsEligible {
                Section {
                    Toggle("Double progression", isOn: doubleProgressionEnabled)
                        .accessibilityIdentifier("double-progression-toggle")
                } header: {
                    Text("Progression")
                } footer: {
                    Text("When every set reaches the top of the rep range, GymTracker recommends adding 2.5 kg / 5 lb next time. Recommendations are suggestions — your logged weights always win.")
                }
            }

            Section("Notes") {
                TextEditor(text: notes)
                    .frame(minHeight: 96)
            }
        }
        .navigationTitle(templateExercise.exercise.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    save()
                    dismiss()
                }
            }
        }
    }

    private var minimumReps: Binding<Int> {
        Binding(
            get: { templateExercise.repRangeMinimum },
            set: { templateExercise.repRangeMinimum = min($0, templateExercise.repRangeMaximum) }
        )
    }

    private var maximumReps: Binding<Int> {
        Binding(
            get: { templateExercise.repRangeMaximum },
            set: { templateExercise.repRangeMaximum = max($0, templateExercise.repRangeMinimum) }
        )
    }

    private var notes: Binding<String> {
        Binding(
            get: { templateExercise.notes ?? "" },
            set: { templateExercise.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private var progressionIsEligible: Bool {
        templateExercise.exercise.trackingType.usesWeight
            && templateExercise.exercise.trackingType != .assistedBodyweight
    }

    private var doubleProgressionEnabled: Binding<Bool> {
        Binding(
            get: { templateExercise.progressionRule == .doubleProgression },
            set: { templateExercise.progressionRule = $0 ? .doubleProgression : .none }
        )
    }

    private func rpeDescription(for value: Double) -> String {
        switch value {
        case 10: "Maximum effort"
        case 9...: "One rep left"
        case 8...: "Two reps left"
        case 7...: "Three reps left"
        default: "Moderate effort"
        }
    }

    private func save() {
        saveModelContext(modelContext)
    }
}
