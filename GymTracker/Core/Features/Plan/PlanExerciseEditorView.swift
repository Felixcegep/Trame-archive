import SwiftData
import SwiftUI

struct PlanExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercise: PlanExerciseDraft

    var body: some View {
        Form {
            exerciseSection
            prescriptionSection
            coachingSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Prescription")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var exerciseSection: some View {
        Section("Exercise") {
            Text(exercise.exercise.name)
                .font(AppFont.headline)
            Picker("Role", selection: $exercise.role) {
                ForEach(ExerciseRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            Toggle("Optional exercise", isOn: $exercise.isOptional)
        }
    }

    private var prescriptionSection: some View {
        Section("Prescription") {
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...20)
            Stepper("Minimum reps: \(exercise.repRangeMinimum)", value: $exercise.repRangeMinimum, in: 1...100)
            Stepper("Maximum reps: \(exercise.repRangeMaximum)", value: $exercise.repRangeMaximum, in: exercise.repRangeMinimum...100)
            Stepper("Rest: \(exercise.restSeconds) sec", value: $exercise.restSeconds, in: 0...600, step: 15)
            TextField("Suggested load", text: $exercise.suggestedLoadText)
                .keyboardType(.decimalPad)
            Picker("Load unit", selection: $exercise.suggestedLoadType) {
                Text("Metric (kg)").tag(WeightType.kg)
                Text("Imperial (lb)").tag(WeightType.lbs)
            }
            if exercise.supportsDoubleProgression {
                Toggle("Double progression", isOn: $exercise.doubleProgressionEnabled)
                    .accessibilityIdentifier("plan-double-progression-toggle")
            }
        }
    }

    private var coachingSection: some View {
        Section("Coaching") {
            TextField("Notes", text: $exercise.notes, axis: .vertical)
                .lineLimit(2...5)
            TextField("Target RPE (optional)", text: $exercise.targetRPEText)
                .keyboardType(.decimalPad)
            Stepper("Target RIR: \(exercise.targetRIR)", value: $exercise.targetRIR, in: 0...10)
        }
    }
}
