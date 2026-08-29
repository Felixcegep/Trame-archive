import SwiftData
import SwiftUI

struct PlanExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercise: PlanExerciseDraft
    let availableExercises: [Exercise]
    @State private var isShowingAlternativePicker = false

    var body: some View {
        Form {
            exerciseSection
            prescriptionSection
            setPrescriptionsSection
            alternativesSection
            coachingSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Prescription")
        .onAppear {
            exercise.normalizeRepRangeForEditing()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var exerciseSection: some View {
        Section {
            Text(exercise.exercise.name)
                .font(AppFont.headline)
            Picker("Role", selection: $exercise.role) {
                ForEach(ExerciseRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            Toggle("Optional exercise", isOn: $exercise.isOptional)
            Picker("Primary stimulus", selection: $exercise.stimulus) {
                ForEach(TrainingStimulus.allCases, id: \.self) { stimulus in
                    Text(stimulus.title).tag(stimulus)
                }
            }
        } header: {
            TrameDomainSectionRule(title: "Exercise", color: Color.trameStrength)
        }
    }

    private var alternativesSection: some View {
        Section {
            if exercise.alternatives.isEmpty {
                Text("No alternatives selected")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            } else {
                ForEach(exercise.alternatives, id: \.persistentModelID) { alternative in
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(alternative.name)
                                .font(AppFont.bodyMedium)
                            Text(alternative.subtitle)
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            exercise.alternatives.removeAll { $0.persistentModelID == alternative.persistentModelID }
                        } label: {
                            Image(systemName: AppIcon.trash)
                        }
                        .accessibilityLabel("Remove \(alternative.name) alternative")
                    }
                }
            }

            Button("Add Alternative", systemImage: AppIcon.plus) {
                isShowingAlternativePicker = true
            }
            .accessibilityIdentifier("add-plan-exercise-alternative")
        } header: {
            TrameDomainSectionRule(title: "Alternatives", color: Color.trameStrength)
        } footer: {
            Text("Alternatives are explicit plan options. They never replace this prescription automatically.")
        }
        .sheet(isPresented: $isShowingAlternativePicker) {
            NavigationStack {
                PlanExerciseAlternativePickerView(
                    sourceExercise: exercise.exercise,
                    selectedAlternatives: exercise.alternatives,
                    availableExercises: availableExercises
                ) { alternative in
                    exercise.alternatives.append(alternative)
                }
            }
        }
    }

    private var prescriptionSection: some View {
        Section {
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
        } header: {
            TrameDomainSectionRule(title: "Prescription", color: Color.trameStrength)
        }
    }

    private var setPrescriptionsSection: some View {
        Section {
            if exercise.plannedSets.isEmpty {
                Text("This exercise currently uses the uniform prescription above for every set.")
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            } else {
                ForEach($exercise.plannedSets) { $set in
                    NavigationLink {
                        PlanSetEditorView(set: $set)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(set.setType.title)
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(Color.trameText)
                            Text(set.summary)
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                        }
                    }
                    .accessibilityIdentifier("plan-set-prescription-row")
                }
                .onDelete { exercise.plannedSets.remove(atOffsets: $0) }
                .onMove { exercise.plannedSets.move(fromOffsets: $0, toOffset: $1) }
            }

            Button("Add set prescription", systemImage: AppIcon.plus) {
                exercise.addPlannedSet()
            }
            .accessibilityIdentifier("add-plan-set-prescription")
        } header: {
            TrameDomainSectionRule(title: "Set prescriptions", color: Color.trameStrength)
        } footer: {
            Text("Ordered set prescriptions replace the uniform target when this workout starts. Remove every set here to use the uniform target again.")
        }
    }

    private var coachingSection: some View {
        Section {
            TextField("Notes", text: $exercise.notes, axis: .vertical)
                .lineLimit(2...5)
            TextField("Target RPE (optional)", text: $exercise.targetRPEText)
                .keyboardType(.decimalPad)
            Stepper("Target RIR: \(exercise.targetRIR)", value: $exercise.targetRIR, in: 0...10)
        } header: {
            TrameDomainSectionRule(title: "Coaching", color: Color.trameAttention)
        }
    }
}

private struct PlanSetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var set: PlanSetDraft

    var body: some View {
        Form {
            Section {
                Picker("Set type", selection: $set.setType) {
                    ForEach(SetType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                Toggle("Optional set", isOn: $set.isOptional)
            } header: {
                TrameDomainSectionRule(title: "Set", color: Color.trameStrength)
            }

            Section {
                TextField("Exact reps (optional)", text: $set.repetitionsText)
                    .keyboardType(.numberPad)
                TextField("Minimum reps (optional)", text: $set.repRangeMinimumText)
                    .keyboardType(.numberPad)
                TextField("Maximum reps (optional)", text: $set.repRangeMaximumText)
                    .keyboardType(.numberPad)
            } header: {
                TrameDomainSectionRule(title: "Repetitions", color: Color.trameStrength)
            } footer: {
                Text("An exact rep target takes precedence over a range.")
            }

            Section {
                TextField("Suggested load (optional)", text: $set.suggestedLoadText)
                    .keyboardType(.decimalPad)
                Picker("Load unit", selection: $set.suggestedLoadType) {
                    Text("Metric (kg)").tag(WeightType.kg)
                    Text("Imperial (lb)").tag(WeightType.lbs)
                }
                TextField("Rest seconds (optional)", text: $set.restSecondsText)
                    .keyboardType(.numberPad)
            } header: {
                TrameDomainSectionRule(title: "Load and rest", color: Color.trameAttention)
            }

            Section {
                TextField("Target RPE (optional)", text: $set.targetRPEText)
                    .keyboardType(.decimalPad)
                TextField("Target RIR (optional)", text: $set.targetRIRText)
                    .keyboardType(.numberPad)
                TextField("Tempo (optional)", text: $set.tempoText)
                Toggle("Eligible for progression", isOn: $set.progressionEligible)
                TextField("Notes", text: $set.notes, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                TrameDomainSectionRule(title: "Coaching", color: Color.trameAttention)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Set prescription")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct PlanExerciseAlternativePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceExercise: Exercise
    let selectedAlternatives: [Exercise]
    let availableExercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""

    private var candidates: [PlanExerciseAlternativeCandidate] {
        let selectedIDs = Set(selectedAlternatives.map(\.persistentModelID))
        return PlanExerciseAlternativeScoringService
            .rankedCandidates(
                for: sourceExercise,
                from: availableExercises.filter {
                    $0.persistentModelID != sourceExercise.persistentModelID && !selectedIDs.contains($0.persistentModelID)
                }
            )
            .filter { searchText.isEmpty || $0.exercise.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(candidates, id: \.exercise.persistentModelID) { candidate in
                Button {
                    onSelect(candidate.exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(candidate.exercise.name)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameText)
                        Text(candidate.reason)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                .accessibilityIdentifier("plan-alternative-\(candidate.exercise.name)")
            }
        }
        .searchable(text: $searchText, prompt: "Search alternatives")
        .navigationTitle("Add Alternative")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
