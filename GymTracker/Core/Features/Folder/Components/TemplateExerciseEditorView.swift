import SwiftData
import SwiftUI

struct TemplateExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var templateExercise: TemplateExercise
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Primary stimulus", selection: $templateExercise.stimulus) {
                    Text("Not specified").tag(TrainingStimulus?.none)
                    ForEach(selectableStimuli, id: \.self) { stimulus in
                        Text(stimulus.title).tag(Optional(stimulus))
                    }
                }
                .accessibilityIdentifier("template-stimulus-picker")
            } header: {
                Text("Classification")
            } footer: {
                Text("Not specified keeps this prescription unclassified. Workouts started from this template only record a stimulus when one is chosen here or the exercise implies one unambiguously.")
            }

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
                    Text("When every set reaches the top of the rep range, Trame recommends adding 2.5 kg / 5 lb next time. Recommendations are suggestions — your logged weights always win.")
                }
            }

            Section("Notes") {
                TextEditor(text: notes)
                    .frame(minHeight: 96)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(templateExercise.exercise.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if save() {
                        dismiss()
                    }
                }
            }
        }
        .alert(
            Text("Incompatible tracking"),
            isPresented: isShowingValidationError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var selectableStimuli: [TrainingStimulus] {
        // Offering only compatible stimuli keeps an invalid combination from
        // ever being written through this editor; the save-time check still
        // guards state that arrived invalid from elsewhere.
        TrackingProfileValidator.compatibleStimuli(
            for: templateExercise.resolvedTrackingType
        )
    }

    private var isShowingValidationError: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )
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

    @discardableResult
    private func save() -> Bool {
        let issues = TrackingProfileValidator.validate(templateExercise: templateExercise)
        guard issues.isEmpty else {
            let message = issues.map(\.message).joined(separator: "\n")
            validationMessage = message
            AccessibilityNotification.Announcement(message).post()
            return false
        }
        saveModelContext(modelContext)
        return true
    }
}
