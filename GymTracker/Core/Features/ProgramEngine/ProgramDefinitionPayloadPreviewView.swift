import SwiftUI

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionPayloadPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let definition: ProgramDefinitionPayload
    let exerciseName: (UUID) -> String

    var body: some View {
        List {
            Section {
                Text("Every row below is generated from the typed recipe. Missing starting values are shown as explanations rather than silently guessed.")
                    .font(AppFont.subheadline)
                    .accessibilityIdentifier("definition-preview-summary")
            }

            ForEach(groupedRows, id: \.key) { group in
                Section("Week \(group.key + 1)") {
                    ForEach(group.rows) { row in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("\(row.workoutName) · \(exerciseName(row.exerciseID))")
                                .font(AppFont.subheadlineSemibold)
                            Text("\(row.exposureKey) · \(row.setCount) sets · \(row.progressionRuleCount) progression rules")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                            if !row.stageNames.isEmpty {
                                Text("Stages: \(row.stageNames.joined(separator: " → "))")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            ForEach(row.sets) { set in
                                Text(previewSetText(set))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            ForEach(row.transitions) { transition in
                                Text(transitionText(transition))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymPrimary)
                            }
                        }
                        .padding(.vertical, Spacing.xxs)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Generated Preview")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismissPreview() }
            }
        }
    }

    private var rows: [ProgramDefinitionPreviewRow] {
        (try? ProgramDefinitionPreview.rows(for: definition)) ?? []
    }

    private var groupedRows: [(key: Int, rows: [ProgramDefinitionPreviewRow])] {
        Dictionary(grouping: rows, by: \.weekIndex)
            .map { (key: $0.key, rows: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private func previewSetText(_ set: ProgramDefinitionPreviewSet) -> String {
        var text = "Set \(set.orderIndex + 1) · \(set.role.rawValue) · \(repText(set.repetitions))"
        if set.generatesAfterSourceCompletion {
            text += " · generated after source completion"
        }
        if let prescribedLoad = set.prescribedLoad {
            text += " · \(prescribedLoad.formatted(.number.precision(.fractionLength(0...2))))"
        }
        if let rpe = set.targetRPE { text += " · RPE \(rpe)" }
        if let rir = set.targetRIR { text += " · RIR \(rir)" }
        if let tempo = set.tempo { text += " · Tempo \(tempo)" }
        return text
    }

    private func transitionText(_ transition: ProgramDefinitionPreviewTransition) -> String {
        var text = "If \(transition.trigger) → \(transition.successAction)"
        if let failure = transition.failureAction {
            text += " · failure: \(failure)"
        }
        text += " · \(transition.cadence.rawValue) · \(transition.scope.rawValue)"
        if transition.applicationMode == .recommendation {
            text += " · recommendation"
        }
        return text
    }

    private func repText(_ repetitions: RepPrescription) -> String {
        switch repetitions {
        case .fixed(let value): return "\(value) reps"
        case .range(let minimum, let maximum): return "\(minimum)–\(maximum) reps"
        case .amrap(let minimum, let maximum): return "\(minimum.map { String($0) } ?? "")+\(maximum.map { String($0) } ?? "")"
        case .duration(let seconds): return "\(seconds ?? 0)s"
        case .distance(let meters): return "\(meters ?? 0)m"
        case .calories(let calories): return "\(calories ?? 0) cal"
        case .sequence(let components): return components.map { "\($0.repetitions)" }.joined(separator: "+")
        case .open: return "open"
        }
    }

    private func dismissPreview() {
        dismiss()
    }
}

extension ProgramSetRole {
    var title: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working"
        case .topSet: return "Top set"
        case .backOff: return "Back-off"
        case .amrap: return "AMRAP"
        case .dropSet: return "Drop set"
        case .technique: return "Technique"
        case .dailyMaximum: return "Daily maximum"
        case .test: return "Test"
        case .recovery: return "Recovery"
        }
    }
}

extension LoadReferenceKind {
    var title: String {
        switch self {
        case .manual: return "Manual"
        case .fixedLoad: return "Fixed load"
        case .exerciseOneRepMax: return "Exercise 1RM"
        case .estimatedOneRepMax: return "Estimated 1RM"
        case .trainingMax: return "Training Max"
        case .referenceExercise: return "Reference exercise"
        case .previousWorkout: return "Previous workout"
        case .previousSuccessfulSet: return "Previous successful set"
        case .previousOccurrence: return "Previous occurrence"
        case .topSet: return "Top set"
        case .dailyMaximum: return "Daily maximum"
        case .anotherPlannedExercise: return "Another exercise"
        }
    }
}

#endif
