import SwiftUI

#if !GYMTRACKER_EXTENSION

enum ProgramBuilderRepKind: String, CaseIterable, Identifiable {
    case fixed
    case range
    case amrap
    case duration
    case distance
    case calories
    case sequence
    case open

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: return "Fixed reps"
        case .range: return "Rep range"
        case .amrap: return "AMRAP"
        case .duration: return "Duration"
        case .distance: return "Distance"
        case .calories: return "Calories"
        case .sequence: return "Complex"
        case .open: return "Open"
        }
    }
}

struct ProgramDefinitionSetEditor: View {
    @Binding var set: SetPrescriptionDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let fallbackExerciseID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Picker("Role", selection: roleBinding) {
                    ForEach(ProgramSetRole.allCases, id: \.self) { role in
                        Text(role.title).tag(role)
                    }
                }
                Spacer()
                Text("Set \(set.orderIndex + 1)")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Picker("Target", selection: repKindBinding) {
                ForEach(ProgramBuilderRepKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            repFields

            TextField("Fixed load", text: fixedLoadBinding)
                .keyboardType(.decimalPad)
            Picker("Load reference", selection: loadReferenceBinding) {
                ForEach(LoadReferenceKind.allCases, id: \.self) { reference in
                    Text(reference.title).tag(reference)
                }
            }
            if requiresExposureKey {
                if availableExposureKeys.isEmpty {
                    Text("Add an exercise exposure before choosing a source.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                } else {
                    Picker("Source exposure", selection: exposureKeyBinding) {
                        ForEach(availableExposureKeys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .accessibilityIdentifier("definition-source-exposure-key")
                }
            }
            TextField("Percentage (0–3)", text: percentageBinding)
                .keyboardType(.decimalPad)
            if canGenerateAfterSourceCompletion {
                Toggle("Generate after source completes", isOn: generatesAfterSourceCompletionBinding)
                    .accessibilityIdentifier("definition-defer-source-backoff")
                    .accessibilityHint("Creates this back-off set only after its referenced source set is completed.")
                Text("Available after the referenced \(set.load.reference.kind.title.lowercased()) is completed.")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            TextField("Rest seconds", text: restBinding)
                .keyboardType(.numberPad)
            TextField("Target RPE", text: rpeBinding)
                .keyboardType(.decimalPad)
            TextField("Target RIR", text: rirBinding)
                .keyboardType(.numberPad)
            TextField("Tempo", text: tempoBinding)
            Toggle("Velocity prescription", isOn: velocityEnabledBinding)
            if set.velocity != nil {
                Toggle("Readiness probe", isOn: velocityProbeBinding)
                HStack {
                    TextField("Minimum m/s", text: velocityMinimumBinding)
                        .keyboardType(.decimalPad)
                    TextField("Maximum m/s", text: velocityMaximumBinding)
                        .keyboardType(.decimalPad)
                }
                TextField("Velocity-loss stop %", text: velocityLossBinding)
                    .keyboardType(.decimalPad)
            }
            Toggle("Eligible for progression", isOn: $set.progressionEligible)
            Toggle("Optional", isOn: $set.isOptional)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var repKind: ProgramBuilderRepKind {
        switch set.repetitions {
        case .fixed: return .fixed
        case .range: return .range
        case .amrap: return .amrap
        case .duration: return .duration
        case .distance: return .distance
        case .calories: return .calories
        case .sequence: return .sequence
        case .open: return .open
        }
    }

    private var repKindBinding: Binding<ProgramBuilderRepKind> {
        Binding(
            get: { repKind },
            set: { kind in
                switch kind {
                case .fixed: set.repetitions = .fixed(8)
                case .range: set.repetitions = .range(minimum: 8, maximum: 12)
                case .amrap: set.repetitions = .amrap(minimum: 5, maximum: nil)
                case .duration: set.repetitions = .duration(seconds: 30)
                case .distance: set.repetitions = .distance(meters: 20)
                case .calories: set.repetitions = .calories(10)
                case .sequence: set.repetitions = .sequence([RepComponent(exerciseID: fallbackExerciseID, repetitions: 1)])
                case .open: set.repetitions = .open
                }
            }
        )
    }

    @ViewBuilder
    private var repFields: some View {
        switch set.repetitions {
        case .fixed:
            TextField("Repetitions", text: fixedRepsBinding)
                .keyboardType(.numberPad)
        case .range:
            HStack {
                TextField("Minimum reps", text: minimumRepsBinding)
                    .keyboardType(.numberPad)
                TextField("Maximum reps", text: maximumRepsBinding)
                    .keyboardType(.numberPad)
            }
        case .amrap:
            TextField("Minimum reps (optional)", text: amrapMinimumBinding)
                .keyboardType(.numberPad)
            TextField("Maximum reps (optional)", text: amrapMaximumBinding)
                .keyboardType(.numberPad)
        case .duration:
            TextField("Seconds", text: durationBinding)
                .keyboardType(.decimalPad)
        case .distance:
            TextField("Meters", text: distanceBinding)
                .keyboardType(.decimalPad)
        case .calories:
            TextField("Calories", text: caloriesBinding)
                .keyboardType(.decimalPad)
        case .sequence(let components):
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Complex components")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                ForEach(components.indices, id: \.self) { index in
                    HStack {
                        Picker("Exercise \(index + 1)", selection: componentExerciseBinding(at: index)) {
                            ForEach(exercises, id: \.id) { exercise in
                                Text(exercise.name).tag(exercise.id)
                            }
                        }
                        TextField("Reps", text: componentRepetitionsBinding(at: index))
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 84)
                        if components.count > 1 {
                            Button("Remove component", systemImage: AppIcon.minus, role: .destructive) {
                                removeComponent(at: index)
                            }
                            .accessibilityLabel("Remove complex component \(index + 1)")
                        }
                    }
                }
                Button("Add component", systemImage: AppIcon.plus) {
                    addComponent()
                }
                .font(AppFont.caption)
            }
        case .open:
            Text("Open target")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var loadReferenceBinding: Binding<LoadReferenceKind> {
        Binding(
            get: { set.load.reference.kind },
            set: { reference in
                set.load.reference.kind = reference
                if !canGenerateAfterSourceCompletion {
                    set.generatesAfterSourceCompletion = false
                }
            }
        )
    }

    private var roleBinding: Binding<ProgramSetRole> {
        Binding(
            get: { set.role },
            set: { role in
                set.role = role
                if !canGenerateAfterSourceCompletion {
                    set.generatesAfterSourceCompletion = false
                }
            }
        )
    }

    private var canGenerateAfterSourceCompletion: Bool {
        guard set.role == .backOff else { return false }
        return set.load.reference.kind == .topSet || set.load.reference.kind == .dailyMaximum
    }

    private var generatesAfterSourceCompletionBinding: Binding<Bool> {
        Binding(
            get: { set.generatesAfterSourceCompletion },
            set: { set.generatesAfterSourceCompletion = $0 }
        )
    }

    private var requiresExposureKey: Bool {
        switch set.load.reference.kind {
        case .trainingMax, .estimatedOneRepMax, .previousWorkout, .previousSuccessfulSet,
                .previousOccurrence, .topSet, .dailyMaximum, .anotherPlannedExercise:
            return true
        default:
            return false
        }
    }

    private var exposureKeyBinding: Binding<String> {
        Binding(
            get: { set.load.reference.exposureKey ?? availableExposureKeys.first ?? "" },
            set: { set.load.reference.exposureKey = $0.isEmpty ? nil : $0 }
        )
    }

    private func textBinding(_ get: @escaping () -> String, _ setValue: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: get, set: setValue)
    }

    private var fixedRepsBinding: Binding<String> {
        textBinding(
            { if case .fixed(let value) = set.repetitions { return String(value) }; return "" },
            { set.repetitions = .fixed(max(1, Int($0) ?? 1)) }
        )
    }

    private var minimumRepsBinding: Binding<String> {
        textBinding(
            { if case .range(let minimum, _) = set.repetitions { return String(minimum) }; return "" },
            { value in
                if case .range(_, let maximum) = set.repetitions { set.repetitions = .range(minimum: max(1, Int(value) ?? 1), maximum: maximum) }
            }
        )
    }

    private var maximumRepsBinding: Binding<String> {
        textBinding(
            { if case .range(_, let maximum) = set.repetitions { return String(maximum) }; return "" },
            { value in
                if case .range(let minimum, _) = set.repetitions { set.repetitions = .range(minimum: minimum, maximum: max(minimum, Int(value) ?? minimum)) }
            }
        )
    }

    private var amrapMinimumBinding: Binding<String> {
        textBinding(
            { if case .amrap(let minimum, _) = set.repetitions { return minimum.map { String($0) } ?? "" }; return "" },
            { value in
                if case .amrap(_, let maximum) = set.repetitions { set.repetitions = .amrap(minimum: Int(value), maximum: maximum) }
            }
        )
    }

    private var amrapMaximumBinding: Binding<String> {
        textBinding(
            { if case .amrap(_, let maximum) = set.repetitions { return maximum.map { String($0) } ?? "" }; return "" },
            { value in
                if case .amrap(let minimum, _) = set.repetitions { set.repetitions = .amrap(minimum: minimum, maximum: Int(value)) }
            }
        )
    }

    private func doubleRepBinding(_ value: @escaping (Double?) -> Void, read: @escaping () -> Double?) -> Binding<String> {
        textBinding({ read().map { String($0) } ?? "" }, { value($0.isEmpty ? nil : Double($0)) })
    }

    private var durationBinding: Binding<String> {
        doubleRepBinding({ if case .duration = set.repetitions { set.repetitions = .duration(seconds: $0) } }, read: { if case .duration(let value) = set.repetitions { return value }; return nil })
    }

    private var distanceBinding: Binding<String> {
        doubleRepBinding({ if case .distance = set.repetitions { set.repetitions = .distance(meters: $0) } }, read: { if case .distance(let value) = set.repetitions { return value }; return nil })
    }

    private var caloriesBinding: Binding<String> {
        doubleRepBinding({ if case .calories = set.repetitions { set.repetitions = .calories($0) } }, read: { if case .calories(let value) = set.repetitions { return value }; return nil })
    }

    private var fixedLoadBinding: Binding<String> {
        textBinding({ set.load.fixedValue.map { String($0) } ?? "" }, { set.load.fixedValue = $0.isEmpty ? nil : Double($0) })
    }

    private var percentageBinding: Binding<String> {
        textBinding({ set.load.percentage.map { String($0) } ?? "" }, { set.load.percentage = $0.isEmpty ? nil : Double($0) })
    }

    private var restBinding: Binding<String> {
        textBinding({ set.restSeconds.map { String($0) } ?? "" }, { set.restSeconds = $0.isEmpty ? nil : Int($0) })
    }

    private var rpeBinding: Binding<String> {
        textBinding({ set.targetRPE.map { String($0) } ?? "" }, { set.targetRPE = $0.isEmpty ? nil : Double($0) })
    }

    private var rirBinding: Binding<String> {
        textBinding({ set.targetRIR.map { String($0) } ?? "" }, { set.targetRIR = $0.isEmpty ? nil : Int($0) })
    }

    private var tempoBinding: Binding<String> {
        textBinding({ set.tempo ?? "" }, { set.tempo = $0.isEmpty ? nil : $0 })
    }

    private var velocityEnabledBinding: Binding<Bool> {
        Binding(
            get: { set.velocity != nil },
            set: { set.velocity = $0 ? .init() : nil }
        )
    }

    private var velocityProbeBinding: Binding<Bool> {
        Binding(
            get: { set.velocity?.isProbe ?? false },
            set: { value in
                var prescription = set.velocity ?? .init()
                prescription.isProbe = value
                set.velocity = prescription
            }
        )
    }

    private func velocityValueBinding(_ keyPath: WritableKeyPath<SetPrescriptionDefinition.VelocityPrescription, Double?>) -> Binding<String> {
        textBinding(
            { set.velocity?[keyPath: keyPath].map { String($0) } ?? "" },
            { value in
                var prescription = set.velocity ?? .init()
                prescription[keyPath: keyPath] = value.isEmpty ? nil : Double(value)
                set.velocity = prescription
            }
        )
    }

    private var velocityMinimumBinding: Binding<String> { velocityValueBinding(\.targetMinimum) }
    private var velocityMaximumBinding: Binding<String> { velocityValueBinding(\.targetMaximum) }
    private var velocityLossBinding: Binding<String> { velocityValueBinding(\.lossStopPercent) }

    private func componentExerciseBinding(at index: Int) -> Binding<UUID> {
        Binding(
            get: {
                guard case .sequence(let components) = set.repetitions,
                      components.indices.contains(index) else { return fallbackExerciseID }
                return components[index].exerciseID
            },
            set: { value in
                guard case .sequence(var components) = set.repetitions,
                      components.indices.contains(index) else { return }
                components[index].exerciseID = value
                components[index].exerciseNameSnapshot = exercises.first(where: { $0.id == value })?.name
                set.repetitions = .sequence(components)
            }
        )
    }

    private func componentRepetitionsBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard case .sequence(let components) = set.repetitions,
                      components.indices.contains(index) else { return "" }
                return String(components[index].repetitions)
            },
            set: { value in
                guard case .sequence(var components) = set.repetitions,
                      components.indices.contains(index) else { return }
                components[index].repetitions = max(1, Int(value) ?? 1)
                set.repetitions = .sequence(components)
            }
        )
    }

    private func addComponent() {
        guard case .sequence(var components) = set.repetitions else { return }
        let exercise = exercises.first
        components.append(RepComponent(
            exerciseID: exercise?.id ?? fallbackExerciseID,
            repetitions: 1,
            exerciseNameSnapshot: exercise?.name
        ))
        set.repetitions = .sequence(components)
    }

    private func removeComponent(at index: Int) {
        guard case .sequence(var components) = set.repetitions,
              components.indices.contains(index), components.count > 1 else { return }
        components.remove(at: index)
        set.repetitions = .sequence(components)
    }
}

#endif
