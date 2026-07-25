import SwiftUI

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionExerciseEditor: View {
    @Binding var exercise: ProgramExerciseDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            Picker("Exercise", selection: $exercise.exerciseID) {
                ForEach(exercises, id: \.id) { item in
                    Text(item.name).tag(item.id)
                }
            }
            TextField("Exposure key", text: $exercise.exposureKey)
            Toggle("Optional", isOn: $exercise.isOptional)
            TextField("Initial load", text: initialLoadBinding)
                .keyboardType(.decimalPad)
            TextField("Training Max", text: trainingMaxBinding)
                .keyboardType(.decimalPad)
            TextField("Estimated 1RM", text: estimatedOneRepMaxBinding)
                .keyboardType(.decimalPad)
            TextField("Initial velocity baseline (m/s)", text: velocityBaselineBinding)
                .keyboardType(.decimalPad)
            Toggle("Automatic deload", isOn: automaticDeloadEnabled)
            if exercise.automaticDeload != nil {
                Stepper(
                    "Reduce sets by \(automaticDeloadVolumeReductionPercent.wrappedValue)%",
                    value: automaticDeloadVolumeReductionPercent,
                    in: 0...90
                )
                Stepper(
                    "Reduce load by \(automaticDeloadIntensityReductionPercent.wrappedValue)%",
                    value: automaticDeloadIntensityReductionPercent,
                    in: 0...90
                )
            }
            Toggle("Generated warm-up", isOn: warmupEnabled)

            if exercises.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Approved substitutions")
                        .font(AppFont.captionBold)
                    ForEach(exercises.filter { $0.id != exercise.exerciseID }, id: \.id) { candidate in
                        Toggle(candidate.name, isOn: alternativeBinding(for: candidate.id))
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Variation ladder")
                        .font(AppFont.captionBold)
                    Text("Select rungs in easiest-to-hardest order. Re-add a rung to move it to the end.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                    ForEach(exercises, id: \.id) { candidate in
                        Toggle(candidate.name, isOn: variationBinding(for: candidate.id))
                    }
                    if let ladder = exercise.variationExerciseIDs, !ladder.isEmpty {
                        Picker("Initial variation", selection: initialVariationBinding) {
                            ForEach(ladder, id: \.self) { id in
                               Text(exercises.first(where: { $0.id == id })?.name ?? "Exercise").tag(id)
                            }
                        }
                    }
                }
            }

            ForEach($exercise.plannedSets) { $set in
                ProgramDefinitionSetEditor(
                    set: $set,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys,
                    fallbackExerciseID: exercise.exerciseID
                )
            }
            .onMove { source, destination in
                exercise.plannedSets.move(fromOffsets: source, toOffset: destination)
                normalizeSets()
            }
            .onDelete { offsets in
                exercise.plannedSets.remove(atOffsets: offsets)
                if exercise.plannedSets.isEmpty {
                    exercise.plannedSets.append(SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8)))
                }
                normalizeSets()
            }

            Button("Add set", systemImage: AppIcon.plus) {
                exercise.plannedSets.append(
                    SetPrescriptionDefinition(
                        orderIndex: exercise.plannedSets.count,
                        repetitions: .fixed(8),
                        restSeconds: 90
                    )
                )
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Loading waves")
                    .font(AppFont.captionBold)
                ForEach($exercise.waves) { $wave in
                    ProgramDefinitionWaveEditor(
                        wave: $wave,
                        exercises: exercises,
                        availableExposureKeys: availableExposureKeys,
                        fallbackExerciseID: exercise.exerciseID
                    )
                }
                .onMove { source, destination in
                    exercise.waves.move(fromOffsets: source, toOffset: destination)
                    normalizeWaves()
                }
                .onDelete { offsets in
                    exercise.waves.remove(atOffsets: offsets)
                    normalizeWaves()
                }
                Button("Add wave", systemImage: AppIcon.plus) {
                    addWave()
                }
                .font(AppFont.caption)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Progression stages")
                    .font(AppFont.captionBold)
                if !exercise.stages.isEmpty {
                    Picker("Initial stage", selection: initialStageBinding) {
                        ForEach(exercise.stages) { stage in
                            Text(stage.name ?? stage.stageID).tag(stage.stageID)
                        }
                    }
                }
                ForEach($exercise.stages) { $stage in
                    ProgramDefinitionStageEditor(
                        stage: $stage,
                        initialStageID: $exercise.initialStageID,
                        exercises: exercises,
                        availableExposureKeys: availableExposureKeys,
                        fallbackExerciseID: exercise.exerciseID
                    )
                }
                .onDelete { offsets in
                    exercise.stages.remove(atOffsets: offsets)
                    if !exercise.stages.contains(where: { $0.stageID == exercise.initialStageID }) {
                        exercise.initialStageID = exercise.stages.first?.stageID
                    }
                }
                Button("Add stage", systemImage: AppIcon.plus) { addStage() }
                    .font(AppFont.caption)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Progression rules")
                    .font(AppFont.captionBold)
                ForEach($exercise.progressionRules) { $rule in
                    ProgramDefinitionRuleEditor(rule: $rule)
                }
                .onDelete { offsets in
                    exercise.progressionRules.remove(atOffsets: offsets)
                }
                Button("Add progression rule", systemImage: AppIcon.progression) {
                    exercise.progressionRules.append(
                        ProgressionRuleDefinition(
                            metric: .load,
                            trigger: .allRequiredSetsCompleted,
                            successAction: .addLoad(2.5),
                            failureAction: .repeatPrescription,
                            cadence: .nextExerciseOccurrence,
                            scope: .exerciseExposure,
                            applicationMode: .recommendation
                        )
                    )
                }
                .font(AppFont.caption)
                Menu("Add policy preset", systemImage: AppIcon.chart) {
                    ForEach(ProgramPolicyPreset.allCases) { preset in
                        Button(preset.title) {
                            exercise.progressionRules.append(contentsOf: preset.rules())
                        }
                    }
                }
                .font(AppFont.caption)
            }
            Button("Delete exercise", role: .destructive, action: onDelete)
        } label: {
            HStack {
                Text(exerciseTitle)
                    .font(AppFont.captionBold)
                Spacer()
                Text("\(exercise.plannedSets.count) sets")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var exerciseTitle: String {
        exercises.first(where: { $0.id == exercise.exerciseID })?.name ?? "Exercise"
    }

    private var initialLoadBinding: Binding<String> { optionalDoubleBinding(\ .initialLoad) }
    private var trainingMaxBinding: Binding<String> { optionalDoubleBinding(\ .initialTrainingMax) }
    private var estimatedOneRepMaxBinding: Binding<String> { optionalDoubleBinding(\ .initialEstimatedOneRepMax) }
    private var velocityBaselineBinding: Binding<String> { optionalDoubleBinding(\ .initialVelocityBaseline) }

    private var initialVariationBinding: Binding<UUID> {
        Binding(
            get: { exercise.initialVariationExerciseID ?? exercise.variationExerciseIDs?.first ?? exercise.exerciseID },
            set: { exercise.initialVariationExerciseID = $0 }
        )
    }

    private var automaticDeloadEnabled: Binding<Bool> {
        Binding(
            get: { exercise.automaticDeload != nil },
            set: { enabled in exercise.automaticDeload = enabled ? AutomaticDeloadDefinition() : nil }
        )
    }

    private var automaticDeloadVolumeReductionPercent: Binding<Int> {
        Binding(
            get: { exercise.automaticDeload?.volumeReductionPercent ?? 50 },
            set: { value in
                var policy = exercise.automaticDeload ?? AutomaticDeloadDefinition()
                policy.volumeReductionPercent = min(90, max(0, value))
                exercise.automaticDeload = policy
            }
        )
    }

    private var automaticDeloadIntensityReductionPercent: Binding<Int> {
        Binding(
            get: { exercise.automaticDeload?.intensityReductionPercent ?? 10 },
            set: { value in
                var policy = exercise.automaticDeload ?? AutomaticDeloadDefinition()
                policy.intensityReductionPercent = min(90, max(0, value))
                exercise.automaticDeload = policy
            }
        )
    }

    private var warmupEnabled: Binding<Bool> {
        Binding(
            get: { exercise.warmupScheme != nil },
            set: { enabled in
                exercise.warmupScheme = enabled ? WarmupSchemeDefinition(steps: [
                    WarmupStepDefinition(percentage: 0.4, repetitions: 5),
                    WarmupStepDefinition(percentage: 0.55, repetitions: 3),
                    WarmupStepDefinition(percentage: 0.65, repetitions: 2)
                ]) : nil
            }
        )
    }

    private func optionalDoubleBinding(_ keyPath: WritableKeyPath<ProgramExerciseDefinition, Double?>) -> Binding<String> {
        Binding(
            get: { exercise[keyPath: keyPath].map { String($0) } ?? "" },
            set: { exercise[keyPath: keyPath] = Double($0) }
        )
    }

    private func normalizeSets() {
        for index in exercise.plannedSets.indices {
            exercise.plannedSets[index].orderIndex = index
        }
    }

    private func alternativeBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { exercise.alternativeExerciseIDs.contains(id) },
            set: { enabled in
                if enabled {
                    if !exercise.alternativeExerciseIDs.contains(id) {
                        exercise.alternativeExerciseIDs.append(id)
                    }
                } else {
                    exercise.alternativeExerciseIDs.removeAll { $0 == id }
                }
            }
        )
    }

    private func variationBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { exercise.variationExerciseIDs?.contains(id) == true },
            set: { enabled in
                var ladder = exercise.variationExerciseIDs ?? []
                ladder.removeAll { $0 == id }
                if enabled { ladder.append(id) }
                exercise.variationExerciseIDs = ladder.isEmpty ? nil : ladder
                if let initial = exercise.initialVariationExerciseID, !ladder.contains(initial) {
                    exercise.initialVariationExerciseID = ladder.first
                } else if exercise.initialVariationExerciseID == nil {
                    exercise.initialVariationExerciseID = ladder.first
                }
            }
        )
    }

    private func addWave() {
        exercise.stages = []
        exercise.initialStageID = nil
        let template = exercise.waves.last?.plannedSets ?? exercise.plannedSets
        let sets = template.enumerated().map { index, set in
            var copy = set
            copy.id = UUID()
            copy.orderIndex = index
            return copy
        }
        exercise.waves.append(
            ProgramWaveDefinition(
                orderIndex: exercise.waves.count,
                name: "Wave \(exercise.waves.count + 1)",
                plannedSets: sets.isEmpty
                    ? [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8))]
                    : sets
            )
        )
    }

    private func normalizeWaves() {
        for index in exercise.waves.indices {
            exercise.waves[index].orderIndex = index
            for setIndex in exercise.waves[index].plannedSets.indices {
                exercise.waves[index].plannedSets[setIndex].orderIndex = setIndex
            }
        }
    }

    private var initialStageBinding: Binding<String> {
        Binding(
            get: { exercise.initialStageID ?? exercise.stages.first?.stageID ?? "" },
            set: { exercise.initialStageID = $0 }
        )
    }

    private func addStage() {
        exercise.waves = []
        let index = exercise.stages.count + 1
        let stageID = "stage-\(index)"
        let template = exercise.stages.last?.plannedSets ?? exercise.plannedSets
        let sets = template.enumerated().map { setIndex, set in
            var copy = set
            copy.id = UUID()
            copy.orderIndex = setIndex
            return copy
        }
        exercise.stages.append(
            ProgramStageDefinition(
                stageID: stageID,
                name: "Stage \(index)",
                plannedSets: sets.isEmpty
                    ? [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8))]
                    : sets
            )
        )
        exercise.initialStageID = exercise.initialStageID ?? stageID
    }
}

struct ProgramDefinitionStageEditor: View {
    @Binding var stage: ProgramStageDefinition
    @Binding var initialStageID: String?
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let fallbackExerciseID: UUID

    var body: some View {
        DisclosureGroup {
            TextField("Stage identifier", text: stageIDBinding)
            TextField("Stage name", text: stageNameBinding)
            Toggle("Carry load into this stage", isOn: $stage.carriesLoad)
            ForEach($stage.plannedSets) { $set in
                ProgramDefinitionSetEditor(
                    set: $set,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys,
                    fallbackExerciseID: fallbackExerciseID
                )
            }
            .onDelete { offsets in
                stage.plannedSets.remove(atOffsets: offsets)
                if stage.plannedSets.isEmpty {
                    stage.plannedSets.append(SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8)))
                }
                normalizeSets()
            }
            Button("Add set", systemImage: AppIcon.plus) {
                stage.plannedSets.append(
                    SetPrescriptionDefinition(orderIndex: stage.plannedSets.count, repetitions: .fixed(8), restSeconds: 90)
                )
            }
        } label: {
            HStack {
                Text(stage.name ?? stage.stageID)
                    .font(AppFont.captionBold)
                Spacer()
                Text("\(stage.plannedSets.count) sets")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var stageNameBinding: Binding<String> {
        Binding(
            get: { stage.name ?? "" },
            set: { stage.name = $0.isEmpty ? nil : $0 }
        )
    }

    private var stageIDBinding: Binding<String> {
        Binding(
            get: { stage.stageID },
            set: { value in
                let previous = stage.stageID
                stage.stageID = value
                if initialStageID == previous { initialStageID = value }
            }
        )
    }

    private func normalizeSets() {
        for index in stage.plannedSets.indices { stage.plannedSets[index].orderIndex = index }
    }
}

struct ProgramDefinitionWaveEditor: View {
    @Binding var wave: ProgramWaveDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let fallbackExerciseID: UUID

    var body: some View {
        DisclosureGroup {
            TextField("Wave name", text: waveNameBinding)
            ForEach($wave.plannedSets) { $set in
                ProgramDefinitionSetEditor(
                    set: $set,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys,
                    fallbackExerciseID: fallbackExerciseID
                )
            }
            .onMove { source, destination in
                wave.plannedSets.move(fromOffsets: source, toOffset: destination)
                normalizeSets()
            }
            .onDelete { offsets in
                wave.plannedSets.remove(atOffsets: offsets)
                if wave.plannedSets.isEmpty {
                    wave.plannedSets.append(SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8)))
                }
                normalizeSets()
            }
            Button("Add set", systemImage: AppIcon.plus) {
                wave.plannedSets.append(
                    SetPrescriptionDefinition(
                        orderIndex: wave.plannedSets.count,
                        repetitions: .fixed(8),
                        restSeconds: 90
                    )
                )
            }
        } label: {
            HStack {
                Text(wave.name ?? "Wave \(wave.orderIndex + 1)")
                    .font(AppFont.captionBold)
                Spacer()
                Text("\(wave.plannedSets.count) sets")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var waveNameBinding: Binding<String> {
        Binding(
            get: { wave.name ?? "" },
            set: { wave.name = $0.isEmpty ? nil : $0 }
        )
    }

    private func normalizeSets() {
        for index in wave.plannedSets.indices {
            wave.plannedSets[index].orderIndex = index
        }
    }
}

#endif
