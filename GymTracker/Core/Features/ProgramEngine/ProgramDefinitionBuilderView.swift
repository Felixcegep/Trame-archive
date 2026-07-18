import SwiftUI
import UniformTypeIdentifiers

#if !GYMTRACKER_EXTENSION

/// The first user-facing authoring surface for the universal program recipe.
/// It intentionally edits the Codable definition directly; compiling a recipe
/// remains a separate, validated operation owned by the caller.
struct ProgramDefinitionBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [Exercise]
    let onSave: (ProgramDefinitionPayload) throws -> Void

    @State private var definition: ProgramDefinitionPayload
    @State private var validationMessages: [String] = []
    @State private var isShowingPreview = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument: ProgramDefinitionDocument?

    init(
        exercises: [Exercise],
        onSave: @escaping (ProgramDefinitionPayload) throws -> Void
    ) {
        self.exercises = exercises.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.onSave = onSave

        var initial = ProgramDefinitionPayload(
            name: "",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: []
        )
        initial.blocks = [
            ProgramBlockDefinition(
                orderIndex: 0,
                name: "Build",
                weeks: [
                    ProgramWeekDefinition(
                        weekIndex: 0,
                        name: nil,
                        workouts: [
                            ProgramWorkoutDefinition(
                                orderIndex: 0,
                                name: "Workout A",
                                dayOffset: 0,
                                plannedExercises: []
                            )
                        ]
                    )
                ]
            )
        ]
        _definition = State(initialValue: initial)
    }

    var body: some View {
        Form {
            Section("Program") {
                TextField("Name", text: binding(\.name))
                    .accessibilityIdentifier("definition-name-field")

                TextField("Description", text: optionalBinding(\.description))

                Picker("Goal", selection: binding(\.goal)) {
                    ForEach(PlanGoal.allCases, id: \.self) { goal in
                        Text(goal.title).tag(goal)
                    }
                }

                Picker("Experience", selection: binding(\.experienceLevel)) {
                    ForEach(PlanExperienceLevel.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }

                Stepper("\(definition.durationWeeks) weeks", value: binding(\.durationWeeks), in: 1...52)
            }

            Section("Schedule") {
                Picker("Mode", selection: binding(\.scheduleMode)) {
                    ForEach(PlanScheduleMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if definition.scheduleMode == .everyNDays {
                    Stepper(
                        "Every \(definition.scheduleIntervalDays) days",
                        value: binding(\.scheduleIntervalDays),
                        in: 1...14
                    )
                }

                ForEach(1...7, id: \.self) { day in
                    Toggle("Day \(day)", isOn: supportedDayBinding(day))
                }
            }

            Section("Phases") {
                ForEach($definition.blocks) { $block in
                    ProgramDefinitionBlockEditor(
                        block: $block,
                        exercises: exercises,
                        availableExposureKeys: availableExposureKeys,
                        onDelete: {
                            removeBlock(block.id)
                        }
                    )
                }
                .onMove { source, destination in
                    definition.blocks.move(fromOffsets: source, toOffset: destination)
                    normalizeBlockOrder()
                }

                Button("Add phase", systemImage: AppIcon.plus) {
                    addBlock()
                }
                .accessibilityIdentifier("definition-add-phase")
            }

            if !validationMessages.isEmpty {
                Section("Needs attention") {
                    ForEach(validationMessages, id: \.self) { message in
                        Label(message, systemImage: AppIcon.warning)
                            .foregroundStyle(Color.gymDestructive)
                    }
                }
            }

            Section("Preview") {
                Button {
                    isShowingPreview = true
                } label: {
                    Label("Preview generated prescriptions", systemImage: AppIcon.chart)
                }
                .disabled(ProgramDefinitionValidator.validate(definition).isEmpty == false)
                .accessibilityIdentifier("definition-preview")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Custom Program")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Import JSON", systemImage: AppIcon.import) {
                        isImporting = true
                    }
                    Button("Export JSON", systemImage: AppIcon.export) {
                        exportDocument = try? ProgramDefinitionDocument(definition: definition)
                        isExporting = exportDocument != nil
                    }
                } label: {
                    Image(systemName: AppIcon.ellipsis)
                }
                .accessibilityLabel("Recipe actions")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("definition-save")
            }
        }
        .sheet(isPresented: $isShowingPreview) {
            NavigationStack {
                ProgramDefinitionPayloadPreviewView(
                    definition: definition,
                    exerciseName: { id in exercises.first(where: { $0.id == id })?.name ?? "Exercise" }
                )
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importDefinition(result)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: definition.name.isEmpty ? "program-definition" : definition.name
        ) { _ in
            exportDocument = nil
        }
        .onChange(of: definition.durationWeeks) { _, newDuration in
            syncWeeksToDuration(newDuration)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ProgramDefinitionPayload, Value>) -> Binding<Value> {
        Binding(
            get: { definition[keyPath: keyPath] },
            set: { definition[keyPath: keyPath] = $0 }
        )
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<ProgramDefinitionPayload, String?>) -> Binding<String> {
        Binding(
            get: { definition[keyPath: keyPath] ?? "" },
            set: { definition[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var availableExposureKeys: [String] {
        Array(Set(
            definition.blocks
                .flatMap(\.weeks)
                .flatMap(\.workouts)
                .flatMap(\.plannedExercises)
                .map(\.exposureKey)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        ))
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func addBlock() {
        let index = definition.blocks.count
        definition.blocks.append(
            ProgramBlockDefinition(
                orderIndex: index,
                name: "Phase \(index + 1)",
                weeks: [
                    ProgramWeekDefinition(
                        weekIndex: 0,
                        workouts: [
                            ProgramWorkoutDefinition(
                                orderIndex: 0,
                                name: "Workout \(index + 1)",
                                dayOffset: 0,
                                plannedExercises: []
                            )
                        ]
                    )
                ]
            )
        )
    }

    private func supportedDayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { definition.supportedDaysPerWeek.contains(day) },
            set: { enabled in
                if enabled {
                    definition.supportedDaysPerWeek = Array(Set(definition.supportedDaysPerWeek + [day])).sorted()
                } else if definition.supportedDaysPerWeek.count > 1 {
                    definition.supportedDaysPerWeek.removeAll { $0 == day }
                }
            }
        )
    }

    private func syncWeeksToDuration(_ duration: Int) {
        for blockIndex in definition.blocks.indices {
            while definition.blocks[blockIndex].weeks.count < duration {
                let index = definition.blocks[blockIndex].weeks.count
                let template = definition.blocks[blockIndex].weeks.last
                definition.blocks[blockIndex].weeks.append(
                    ProgramWeekDefinition(
                        weekIndex: index,
                        name: nil,
                        workouts: template?.workouts.map { workout in
                            ProgramWorkoutDefinition(
                                orderIndex: workout.orderIndex,
                                name: workout.name,
                                dayOffset: workout.dayOffset,
                                role: workout.role,
                                plannedExercises: workout.plannedExercises.map { exercise in
                                    var copy = exercise
                                    copy.id = UUID()
                                    copy.plannedSets = exercise.plannedSets.map { set in
                                        var copy = set
                                        copy.id = UUID()
                                        return copy
                                    }
                                    return copy
                                }
                            )
                        } ?? []
                    )
                )
            }
            if definition.blocks[blockIndex].weeks.count > duration {
                definition.blocks[blockIndex].weeks.removeLast(definition.blocks[blockIndex].weeks.count - duration)
            }
            for weekIndex in definition.blocks[blockIndex].weeks.indices {
                definition.blocks[blockIndex].weeks[weekIndex].weekIndex = weekIndex
            }
        }
    }

    private func removeBlock(_ id: UUID) {
        definition.blocks.removeAll { $0.id == id }
        if definition.blocks.isEmpty { addBlock() }
        normalizeBlockOrder()
    }

    private func normalizeBlockOrder() {
        for index in definition.blocks.indices {
            definition.blocks[index].orderIndex = index
        }
    }

    private func save() {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else {
            validationMessages = issues.map(\.message)
            return
        }
        do {
            try onSave(definition)
            dismiss()
        } catch {
            validationMessages = [error.localizedDescription]
        }
    }

    private func importDefinition(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let data = try Data(contentsOf: url)
            definition = try ProgramDefinitionCodec.decode(data)
            validationMessages = []
        } catch {
            validationMessages = [error.localizedDescription]
        }
    }
}

private struct ProgramDefinitionDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(definition: ProgramDefinitionPayload) throws {
        data = try ProgramDefinitionCodec.encode(definition)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ProgramDefinitionCodecError.malformed
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct ProgramDefinitionBlockEditor: View {
    @Binding var block: ProgramBlockDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                TextField("Phase name", text: $block.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Button(role: .destructive, action: onDelete) {
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
                    "Reduce sets by \(block.deloadVolumeReductionPercent ?? 50)%",
                    value: Binding(
                        get: { block.deloadVolumeReductionPercent ?? 50 },
                        set: { block.deloadVolumeReductionPercent = $0 }
                    ),
                    in: 0...90
                )
                Stepper(
                    "Reduce load by \(block.deloadIntensityReductionPercent ?? 10)%",
                    value: Binding(
                        get: { block.deloadIntensityReductionPercent ?? 10 },
                        set: { block.deloadIntensityReductionPercent = $0 }
                    ),
                    in: 0...90
                )
            } else {
                Text("\(block.weeks.count) weeks")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach($block.weeks) { $week in
                ProgramDefinitionWeekEditor(
                    week: $week,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeWeek(week.id)
                }
            }
            .onMove { source, destination in
                block.weeks.move(fromOffsets: source, toOffset: destination)
                normalizeWeeks()
            }

            Button("Add week", systemImage: AppIcon.plus) {
                addWeek()
            }
            .font(AppFont.captionBold)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func addWeek() {
        let index = block.weeks.count
        block.weeks.append(
            ProgramWeekDefinition(
                weekIndex: index,
                name: nil,
                workouts: [
                    ProgramWorkoutDefinition(
                        orderIndex: 0,
                        name: "Workout \(index + 1)",
                        dayOffset: 0,
                        plannedExercises: []
                    )
                ]
            )
        )
    }

    private func removeWeek(_ id: UUID) {
        block.weeks.removeAll { $0.id == id }
        if block.weeks.isEmpty { addWeek() }
        normalizeWeeks()
    }

    private func normalizeWeeks() {
        for index in block.weeks.indices {
            block.weeks[index].weekIndex = index
        }
    }
}

private struct ProgramDefinitionWeekEditor: View {
    @Binding var week: ProgramWeekDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            TextField("Week name", text: optionalNameBinding)
            ForEach($week.workouts) { $workout in
                ProgramDefinitionWorkoutEditor(
                    workout: $workout,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeWorkout(workout.id)
                }
            }
            .onMove { source, destination in
                week.workouts.move(fromOffsets: source, toOffset: destination)
                normalizeWorkouts()
            }
            Button("Add workout", systemImage: AppIcon.plus) {
                addWorkout()
            }
            Button("Delete week", role: .destructive, action: onDelete)
        } label: {
            Text("Week \(week.weekIndex + 1)")
                .font(AppFont.subheadlineSemibold)
        }
    }

    private var optionalNameBinding: Binding<String> {
        Binding(
            get: { week.name ?? "" },
            set: { week.name = $0.isEmpty ? nil : $0 }
        )
    }

    private func addWorkout() {
        let index = week.workouts.count
        week.workouts.append(
            ProgramWorkoutDefinition(
                orderIndex: index,
                name: "Workout \(index + 1)",
                dayOffset: index % 7,
                plannedExercises: []
            )
        )
    }

    private func removeWorkout(_ id: UUID) {
        week.workouts.removeAll { $0.id == id }
        if week.workouts.isEmpty { addWorkout() }
        normalizeWorkouts()
    }

    private func normalizeWorkouts() {
        for index in week.workouts.indices {
            week.workouts[index].orderIndex = index
        }
    }
}

private struct ProgramDefinitionWorkoutEditor: View {
    @Binding var workout: ProgramWorkoutDefinition
    let exercises: [Exercise]
    let availableExposureKeys: [String]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            TextField("Workout name", text: $workout.name)
            Stepper("Day \(workout.dayOffset + 1)", value: $workout.dayOffset, in: 0...6)
            TextField("Role", text: $workout.role)

            ForEach($workout.plannedExercises) { $exercise in
                ProgramDefinitionExerciseEditor(
                    exercise: $exercise,
                    exercises: exercises,
                    availableExposureKeys: availableExposureKeys
                ) {
                    removeExercise(exercise.id)
                }
            }
            .onMove { source, destination in
                workout.plannedExercises.move(fromOffsets: source, toOffset: destination)
                normalizeExercises()
            }

            Button("Add exercise", systemImage: AppIcon.plus) {
                addExercise()
            }
            Button("Delete workout", role: .destructive, action: onDelete)
        } label: {
            HStack {
                Text(workout.name.isEmpty ? "Workout" : workout.name)
                    .font(AppFont.subheadlineSemibold)
                Spacer()
                Text("Day \(workout.dayOffset + 1)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addExercise() {
        guard let first = exercises.first else { return }
        let index = workout.plannedExercises.count
        workout.plannedExercises.append(
            ProgramExerciseDefinition(
                exerciseID: first.id,
                exposureKey: "\(first.name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(index + 1)",
                orderIndex: index,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        repetitions: .fixed(8),
                        load: LoadPrescription(reference: LoadReference(kind: .manual)),
                        restSeconds: 90
                    )
                ]
            )
        )
    }

    private func removeExercise(_ id: UUID) {
        workout.plannedExercises.removeAll { $0.id == id }
        if workout.plannedExercises.isEmpty, let first = exercises.first {
            workout.plannedExercises.append(
                ProgramExerciseDefinition(
                    exerciseID: first.id,
                    exposureKey: "\(first.name.lowercased().replacingOccurrences(of: " ", with: "-"))-1",
                    orderIndex: 0,
                    plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(8))]
                )
            )
        }
        normalizeExercises()
    }

    private func normalizeExercises() {
        for index in workout.plannedExercises.indices {
            workout.plannedExercises[index].orderIndex = index
        }
    }
}

private struct ProgramDefinitionExerciseEditor: View {
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
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exerciseTitle: String {
        exercises.first(where: { $0.id == exercise.exerciseID })?.name ?? "Exercise"
    }

    private var initialLoadBinding: Binding<String> { optionalDoubleBinding(\ .initialLoad) }
    private var trainingMaxBinding: Binding<String> { optionalDoubleBinding(\ .initialTrainingMax) }
    private var estimatedOneRepMaxBinding: Binding<String> { optionalDoubleBinding(\ .initialEstimatedOneRepMax) }

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

    private func addWave() {
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
}

private struct ProgramDefinitionWaveEditor: View {
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
                    .foregroundStyle(.secondary)
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

private enum ProgramBuilderRepKind: String, CaseIterable, Identifiable {
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

private enum ProgramBuilderTriggerKind: String, CaseIterable, Identifiable {
    case allRequiredSetsCompleted
    case allRequiredRepetitionsCompleted
    case allSetsReachedUpperRepBound
    case totalRepetitionsReached
    case totalCaloriesReached
    case totalVolumeReached
    case amrapResultReached
    case extraRepetitionsCompleted
    case targetRPEMatched
    case actualRPEBelowTarget
    case actualRPEAboveTarget
    case targetRIRMatched
    case failureCountReached
    case technicalQualityReached
    case workoutCompleted
    case weekCompleted
    case waveCompleted
    case blockCompleted
    case cycleCompleted
    case scheduledDateReached
    case manualApproval
    case successfulAttemptRatioReached

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allRequiredSetsCompleted: return "All required sets"
        case .allRequiredRepetitionsCompleted: return "All required repetitions"
        case .allSetsReachedUpperRepBound: return "All sets reach upper reps"
        case .totalRepetitionsReached: return "Total repetitions"
        case .totalCaloriesReached: return "Total calories"
        case .totalVolumeReached: return "Total volume"
        case .amrapResultReached: return "AMRAP result"
        case .extraRepetitionsCompleted: return "Extra AMRAP repetitions"
        case .targetRPEMatched: return "Target RPE matched"
        case .actualRPEBelowTarget: return "RPE below target"
        case .actualRPEAboveTarget: return "RPE above target"
        case .targetRIRMatched: return "Target RIR matched"
        case .failureCountReached: return "Failure count"
        case .technicalQualityReached: return "Technical quality"
        case .workoutCompleted: return "Workout completed"
        case .weekCompleted: return "Week completed"
        case .waveCompleted: return "Wave completed"
        case .blockCompleted: return "Block completed"
        case .cycleCompleted: return "Cycle completed"
        case .scheduledDateReached: return "Scheduled date reached"
        case .manualApproval: return "Manual approval"
        case .successfulAttemptRatioReached: return "Successful attempt ratio"
        }
    }
}

private enum ProgramBuilderActionKind: String, CaseIterable, Identifiable {
    case addLoad
    case reduceLoad
    case addLoadPercentage
    case reduceLoadPercentage
    case addAssistance
    case reduceAssistance
    case addRepetitions
    case reduceRepetitions
    case addSets
    case reduceSets
    case addDuration
    case reduceDuration
    case addDistance
    case reduceDistance
    case addRestDuration
    case reduceRestDuration
    case addCalories
    case reduceCalories
    case updateTrainingMax
    case updateEstimatedOneRepMax
    case updateActualOneRepMax
    case repeatPrescription
    case changeStage
    case advanceExerciseVariation
    case regressExerciseVariation
    case advanceWeek
    case repeatWeek
    case advanceWave
    case advanceBlock
    case restartBlock
    case startDeload
    case resetFailureCount
    case resetProgressionOffsets
    case endExercise
    case endProgram
    case generateRecommendation
    case noChange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addLoad: return "Add load"
        case .reduceLoad: return "Reduce load"
        case .addLoadPercentage: return "Add load percentage"
        case .reduceLoadPercentage: return "Reduce load percentage"
        case .addAssistance: return "Add assistance"
        case .reduceAssistance: return "Reduce assistance"
        case .addRepetitions: return "Add repetitions"
        case .reduceRepetitions: return "Reduce repetitions"
        case .addSets: return "Add sets"
        case .reduceSets: return "Reduce sets"
        case .addDuration: return "Add duration"
        case .reduceDuration: return "Reduce duration"
        case .addDistance: return "Add distance"
        case .reduceDistance: return "Reduce distance"
        case .addRestDuration: return "Add rest duration"
        case .reduceRestDuration: return "Reduce rest duration"
        case .addCalories: return "Add calories"
        case .reduceCalories: return "Reduce calories"
        case .updateTrainingMax: return "Update Training Max"
        case .updateEstimatedOneRepMax: return "Update estimated 1RM"
        case .updateActualOneRepMax: return "Update actual 1RM"
        case .repeatPrescription: return "Repeat prescription"
        case .changeStage: return "Change stage"
        case .advanceExerciseVariation: return "Advance variation"
        case .regressExerciseVariation: return "Regress variation"
        case .advanceWeek: return "Advance week"
        case .repeatWeek: return "Repeat week"
        case .advanceWave: return "Advance wave"
        case .advanceBlock: return "Advance block"
        case .restartBlock: return "Restart block"
        case .startDeload: return "Start deload"
        case .resetFailureCount: return "Reset failure count"
        case .resetProgressionOffsets: return "Reset progression offsets"
        case .endExercise: return "End exercise"
        case .endProgram: return "End program"
        case .generateRecommendation: return "Generate recommendation"
        case .noChange: return "No change"
        }
    }
}

private struct ProgramDefinitionRuleEditor: View {
    @Binding var rule: ProgressionRuleDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Picker("Metric", selection: $rule.metric) {
                ForEach(ProgressionMetric.allCases, id: \.self) { metric in
                    Text(metric.rawValue.localizedCapitalized).tag(metric)
                }
            }
            Picker("Trigger", selection: triggerKindBinding) {
                ForEach(ProgramBuilderTriggerKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if triggerUsesThreshold {
                TextField("Threshold", text: thresholdBinding)
                    .keyboardType(.decimalPad)
            }
            Picker("On success", selection: successActionKindBinding) {
                ForEach(ProgramBuilderActionKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if actionUsesValue {
                TextField("Action value", text: actionValueBinding)
                    .keyboardType(.decimalPad)
            }
            Toggle("Use failure action", isOn: hasFailureActionBinding)
            if rule.failureAction != nil {
                Picker("On failure", selection: failureActionKindBinding) {
                    ForEach(ProgramBuilderActionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if failureActionUsesValue {
                    TextField("Failure action value", text: failureActionValueBinding)
                        .keyboardType(.decimalPad)
                }
            }
            Picker("Formula", selection: formulaKindBinding) {
                ForEach(ProgramBuilderFormulaKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if formulaNeedsExposureKey {
                TextField("Formula exposure key", text: formulaExposureKeyBinding)
            }
            if formulaNeedsConstant {
                TextField("Formula constant", text: formulaConstantBinding)
                    .keyboardType(.decimalPad)
            }
            if rule.formula != nil {
                Menu("Compose formula", systemImage: AppIcon.progression) {
                    Button("Multiply by 0.90") {
                        compose { .multiply($0, .source(.constant(0.90))) }
                    }
                    Button("Add 2.5") {
                        compose { .add($0, .source(.constant(2.5))) }
                    }
                    Button("Clamp 0–100") {
                        compose { .clamp(value: $0, minimum: 0, maximum: 100) }
                    }
                    Button("Round to 2.5") {
                        compose { .round($0, rule: .nearestIncrement(2.5)) }
                    }
                    Button("Reset to source") {
                        if case .some(.source(let source)) = rule.formula {
                            rule.formula = .source(source)
                        }
                    }
                }
                .font(AppFont.caption)
            }
            Picker("Cadence", selection: $rule.cadence) {
                ForEach(ProgressionCadence.allCases, id: \.self) { cadence in
                    Text(cadence.rawValue.localizedCapitalized).tag(cadence)
                }
            }
            Picker("Scope", selection: $rule.scope) {
                ForEach(ProgressionScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue.localizedCapitalized).tag(scope)
                }
            }
            Picker("Apply", selection: $rule.applicationMode) {
                ForEach(ProgressionApplicationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.localizedCapitalized).tag(mode)
                }
            }
            Toggle("Enabled", isOn: $rule.isEnabled)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var triggerKind: ProgramBuilderTriggerKind {
        switch rule.trigger {
        case .allRequiredSetsCompleted: return .allRequiredSetsCompleted
        case .allRequiredRepetitionsCompleted: return .allRequiredRepetitionsCompleted
        case .allSetsReachedUpperRepBound: return .allSetsReachedUpperRepBound
        case .totalRepetitionsReached: return .totalRepetitionsReached
        case .totalCaloriesReached: return .totalCaloriesReached
        case .totalVolumeReached: return .totalVolumeReached
        case .amrapResultReached: return .amrapResultReached
        case .extraRepetitionsCompleted: return .extraRepetitionsCompleted
        case .targetRPEMatched: return .targetRPEMatched
        case .actualRPEBelowTarget: return .actualRPEBelowTarget
        case .actualRPEAboveTarget: return .actualRPEAboveTarget
        case .targetRIRMatched: return .targetRIRMatched
        case .failureCountReached: return .failureCountReached
        case .technicalQualityReached: return .technicalQualityReached
        case .workoutCompleted: return .workoutCompleted
        case .weekCompleted: return .weekCompleted
        case .waveCompleted: return .waveCompleted
        case .blockCompleted: return .blockCompleted
        case .cycleCompleted: return .cycleCompleted
        case .scheduledDateReached: return .scheduledDateReached
        case .manualApproval: return .manualApproval
        case .successfulAttemptRatioReached: return .successfulAttemptRatioReached
        }
    }

    private var triggerKindBinding: Binding<ProgramBuilderTriggerKind> {
        Binding(
            get: { triggerKind },
            set: { kind in
                switch kind {
                case .allRequiredSetsCompleted: rule.trigger = .allRequiredSetsCompleted
                case .allRequiredRepetitionsCompleted: rule.trigger = .allRequiredRepetitionsCompleted
                case .allSetsReachedUpperRepBound: rule.trigger = .allSetsReachedUpperRepBound
                case .totalRepetitionsReached: rule.trigger = .totalRepetitionsReached(25)
                case .totalCaloriesReached: rule.trigger = .totalCaloriesReached(100)
                case .totalVolumeReached: rule.trigger = .totalVolumeReached(1_000)
                case .amrapResultReached: rule.trigger = .amrapResultReached(10)
                case .extraRepetitionsCompleted: rule.trigger = .extraRepetitionsCompleted(2)
                case .targetRPEMatched: rule.trigger = .targetRPEMatched(tolerance: 0.5)
                case .actualRPEBelowTarget: rule.trigger = .actualRPEBelowTarget(tolerance: 1)
                case .actualRPEAboveTarget: rule.trigger = .actualRPEAboveTarget(tolerance: 1)
                case .targetRIRMatched: rule.trigger = .targetRIRMatched(tolerance: 1)
                case .failureCountReached: rule.trigger = .failureCountReached(3)
                case .technicalQualityReached: rule.trigger = .technicalQualityReached
                case .workoutCompleted: rule.trigger = .workoutCompleted
                case .weekCompleted: rule.trigger = .weekCompleted
                case .waveCompleted: rule.trigger = .waveCompleted
                case .blockCompleted: rule.trigger = .blockCompleted
                case .cycleCompleted: rule.trigger = .cycleCompleted
                case .scheduledDateReached: rule.trigger = .scheduledDateReached
                case .manualApproval: rule.trigger = .manualApproval
                case .successfulAttemptRatioReached: rule.trigger = .successfulAttemptRatioReached(0.9)
                }
            }
        )
    }

    private var triggerUsesThreshold: Bool {
        switch rule.trigger {
        case .totalRepetitionsReached, .totalCaloriesReached, .totalVolumeReached,
                .amrapResultReached, .extraRepetitionsCompleted, .targetRPEMatched,
                .actualRPEBelowTarget, .actualRPEAboveTarget, .targetRIRMatched,
                .failureCountReached, .successfulAttemptRatioReached:
            return true
        default:
            return false
        }
    }

    private var thresholdBinding: Binding<String> {
        Binding(
            get: {
                switch rule.trigger {
                case .totalRepetitionsReached(let value), .amrapResultReached(let value),
                        .extraRepetitionsCompleted(let value), .failureCountReached(let value),
                        .targetRIRMatched(let value): return String(value)
                case .totalCaloriesReached(let value), .totalVolumeReached(let value),
                        .targetRPEMatched(let value), .actualRPEBelowTarget(let value),
                        .actualRPEAboveTarget(let value), .successfulAttemptRatioReached(let value): return String(value)
                default: return ""
                }
            },
            set: { value in
                switch rule.trigger {
                case .totalRepetitionsReached: rule.trigger = .totalRepetitionsReached(max(1, Int(value) ?? 1))
                case .totalCaloriesReached: rule.trigger = .totalCaloriesReached(max(0, Double(value) ?? 0))
                case .totalVolumeReached: rule.trigger = .totalVolumeReached(max(0, Double(value) ?? 0))
                case .amrapResultReached: rule.trigger = .amrapResultReached(max(0, Int(value) ?? 0))
                case .extraRepetitionsCompleted: rule.trigger = .extraRepetitionsCompleted(max(0, Int(value) ?? 0))
                case .targetRPEMatched: rule.trigger = .targetRPEMatched(tolerance: max(0, Double(value) ?? 0))
                case .actualRPEBelowTarget: rule.trigger = .actualRPEBelowTarget(tolerance: max(0, Double(value) ?? 0))
                case .actualRPEAboveTarget: rule.trigger = .actualRPEAboveTarget(tolerance: max(0, Double(value) ?? 0))
                case .targetRIRMatched: rule.trigger = .targetRIRMatched(tolerance: max(0, Int(value) ?? 0))
                case .failureCountReached: rule.trigger = .failureCountReached(max(1, Int(value) ?? 1))
                case .successfulAttemptRatioReached: rule.trigger = .successfulAttemptRatioReached(min(1, max(0, Double(value) ?? 0.9)))
                default: break
                }
            }
        )
    }

    private var successActionKind: ProgramBuilderActionKind {
        switch rule.successAction {
        case .addLoad: return .addLoad
        case .reduceLoad: return .reduceLoad
        case .addLoadPercentage: return .addLoadPercentage
        case .reduceLoadPercentage: return .reduceLoadPercentage
        case .addAssistance: return .addAssistance
        case .reduceAssistance: return .reduceAssistance
        case .addRepetitions: return .addRepetitions
        case .reduceRepetitions: return .reduceRepetitions
        case .addSets: return .addSets
        case .reduceSets: return .reduceSets
        case .addDuration: return .addDuration
        case .reduceDuration: return .reduceDuration
        case .addDistance: return .addDistance
        case .reduceDistance: return .reduceDistance
        case .addRestDuration: return .addRestDuration
        case .reduceRestDuration: return .reduceRestDuration
        case .addCalories: return .addCalories
        case .reduceCalories: return .reduceCalories
        case .updateTrainingMax: return .updateTrainingMax
        case .updateEstimatedOneRepMax: return .updateEstimatedOneRepMax
        case .updateActualOneRepMax: return .updateActualOneRepMax
        case .repeatPrescription: return .repeatPrescription
        case .changeStage: return .changeStage
        case .advanceExerciseVariation: return .advanceExerciseVariation
        case .regressExerciseVariation: return .regressExerciseVariation
        case .advanceWeek: return .advanceWeek
        case .repeatWeek: return .repeatWeek
        case .advanceWave: return .advanceWave
        case .advanceBlock: return .advanceBlock
        case .restartBlock: return .restartBlock
        case .startDeload: return .startDeload
        case .resetFailureCount: return .resetFailureCount
        case .resetProgressionOffsets: return .resetProgressionOffsets
        case .endExercise: return .endExercise
        case .endProgram: return .endProgram
        case .generateRecommendation: return .generateRecommendation
        default: return .noChange
        }
    }

    private var successActionKindBinding: Binding<ProgramBuilderActionKind> {
        Binding(
            get: { successActionKind },
            set: { kind in
                switch kind {
                case .addLoad: rule.successAction = .addLoad(2.5)
                case .reduceLoad: rule.successAction = .reduceLoad(2.5)
                case .addLoadPercentage: rule.successAction = .addLoadPercentage(0.025)
                case .reduceLoadPercentage: rule.successAction = .reduceLoadPercentage(0.025)
                case .addAssistance: rule.successAction = .addAssistance(5)
                case .reduceAssistance: rule.successAction = .reduceAssistance(5)
                case .addRepetitions: rule.successAction = .addRepetitions(1)
                case .reduceRepetitions: rule.successAction = .reduceRepetitions(1)
                case .addSets: rule.successAction = .addSets(1)
                case .reduceSets: rule.successAction = .reduceSets(1)
                case .addDuration: rule.successAction = .addDuration(30)
                case .reduceDuration: rule.successAction = .reduceDuration(30)
                case .addDistance: rule.successAction = .addDistance(50)
                case .reduceDistance: rule.successAction = .reduceDistance(50)
                case .addRestDuration: rule.successAction = .addRestDuration(15)
                case .reduceRestDuration: rule.successAction = .reduceRestDuration(15)
                case .addCalories: rule.successAction = .addCalories(10)
                case .reduceCalories: rule.successAction = .reduceCalories(10)
                case .updateTrainingMax: rule.successAction = .updateTrainingMax(.source(.constant(100)))
                case .updateEstimatedOneRepMax: rule.successAction = .updateEstimatedOneRepMax(.source(.constant(100)))
                case .updateActualOneRepMax: rule.successAction = .updateActualOneRepMax(.source(.constant(100)))
                case .repeatPrescription: rule.successAction = .repeatPrescription
                case .changeStage: rule.successAction = .changeStage("next")
                case .advanceExerciseVariation: rule.successAction = .advanceExerciseVariation
                case .regressExerciseVariation: rule.successAction = .regressExerciseVariation
                case .advanceWeek: rule.successAction = .advanceWeek
                case .repeatWeek: rule.successAction = .repeatWeek
                case .advanceWave: rule.successAction = .advanceWave
                case .advanceBlock: rule.successAction = .advanceBlock
                case .restartBlock: rule.successAction = .restartBlock
                case .startDeload: rule.successAction = .startDeload
                case .resetFailureCount: rule.successAction = .resetFailureCount
                case .resetProgressionOffsets: rule.successAction = .resetProgressionOffsets
                case .endExercise: rule.successAction = .endExercise
                case .endProgram: rule.successAction = .endProgram
                case .generateRecommendation: rule.successAction = .generateRecommendation
                case .noChange: rule.successAction = .noChange
                }
            }
        )
    }

    private var actionUsesValue: Bool {
        switch rule.successAction {
        case .addLoad, .reduceLoad, .addLoadPercentage, .reduceLoadPercentage,
                .addAssistance, .reduceAssistance, .addRepetitions, .reduceRepetitions,
                .addSets, .reduceSets, .addDuration, .reduceDuration, .addDistance,
                .reduceDistance, .addRestDuration, .reduceRestDuration, .addCalories,
                .reduceCalories, .changeStage:
            return true
        default:
            return false
        }
    }

    private var actionValueBinding: Binding<String> {
        Binding(
            get: {
                switch rule.successAction {
                case .addLoad(let value), .reduceLoad(let value), .addLoadPercentage(let value),
                        .reduceLoadPercentage(let value), .addAssistance(let value),
                        .reduceAssistance(let value), .addDuration(let value), .reduceDuration(let value),
                        .addDistance(let value), .reduceDistance(let value), .addCalories(let value),
                        .reduceCalories(let value): return String(value)
                case .addRepetitions(let value), .reduceRepetitions(let value), .addSets(let value),
                        .reduceSets(let value), .addRestDuration(let value), .reduceRestDuration(let value): return String(value)
                case .changeStage(let value): return value
                default: return ""
                }
            },
            set: { value in
                switch rule.successAction {
                case .addLoad: rule.successAction = .addLoad(max(0, Double(value) ?? 0))
                case .reduceLoad: rule.successAction = .reduceLoad(max(0, Double(value) ?? 0))
                case .addLoadPercentage: rule.successAction = .addLoadPercentage(max(0, Double(value) ?? 0))
                case .reduceLoadPercentage: rule.successAction = .reduceLoadPercentage(max(0, Double(value) ?? 0))
                case .addAssistance: rule.successAction = .addAssistance(max(0, Double(value) ?? 0))
                case .reduceAssistance: rule.successAction = .reduceAssistance(max(0, Double(value) ?? 0))
                case .addRepetitions: rule.successAction = .addRepetitions(max(0, Int(value) ?? 0))
                case .reduceRepetitions: rule.successAction = .reduceRepetitions(max(0, Int(value) ?? 0))
                case .addSets: rule.successAction = .addSets(max(0, Int(value) ?? 0))
                case .reduceSets: rule.successAction = .reduceSets(max(0, Int(value) ?? 0))
                case .addDuration: rule.successAction = .addDuration(max(0, Double(value) ?? 0))
                case .reduceDuration: rule.successAction = .reduceDuration(max(0, Double(value) ?? 0))
                case .addDistance: rule.successAction = .addDistance(max(0, Double(value) ?? 0))
                case .reduceDistance: rule.successAction = .reduceDistance(max(0, Double(value) ?? 0))
                case .addRestDuration: rule.successAction = .addRestDuration(max(0, Int(value) ?? 0))
                case .reduceRestDuration: rule.successAction = .reduceRestDuration(max(0, Int(value) ?? 0))
                case .addCalories: rule.successAction = .addCalories(max(0, Double(value) ?? 0))
                case .reduceCalories: rule.successAction = .reduceCalories(max(0, Double(value) ?? 0))
                case .changeStage: rule.successAction = .changeStage(value)
                default: break
                }
            }
        )
    }

    private var hasFailureActionBinding: Binding<Bool> {
        Binding(
            get: { rule.failureAction != nil },
            set: { enabled in
                rule.failureAction = enabled ? .repeatPrescription : nil
            }
        )
    }

    private var failureActionKindBinding: Binding<ProgramBuilderActionKind> {
        Binding(
            get: { rule.failureAction.map(actionKind) ?? .repeatPrescription },
            set: { rule.failureAction = defaultAction(for: $0) }
        )
    }

    private var failureActionUsesValue: Bool {
        guard let failureAction = rule.failureAction else { return false }
        return actionUsesValue(failureAction)
    }

    private var failureActionValueBinding: Binding<String> {
        Binding(
            get: { rule.failureAction.map(actionValue) ?? "" },
            set: { value in
                guard let action = rule.failureAction else { return }
                rule.failureAction = actionSettingValue(action, value: value)
            }
        )
    }

    private func actionKind(_ action: ProgressionAction) -> ProgramBuilderActionKind {
        switch action {
        case .addLoad: return .addLoad
        case .reduceLoad: return .reduceLoad
        case .addLoadPercentage: return .addLoadPercentage
        case .reduceLoadPercentage: return .reduceLoadPercentage
        case .addAssistance: return .addAssistance
        case .reduceAssistance: return .reduceAssistance
        case .addRepetitions: return .addRepetitions
        case .reduceRepetitions: return .reduceRepetitions
        case .addSets: return .addSets
        case .reduceSets: return .reduceSets
        case .addDuration: return .addDuration
        case .reduceDuration: return .reduceDuration
        case .addDistance: return .addDistance
        case .reduceDistance: return .reduceDistance
        case .addRestDuration: return .addRestDuration
        case .reduceRestDuration: return .reduceRestDuration
        case .addCalories: return .addCalories
        case .reduceCalories: return .reduceCalories
        case .updateTrainingMax: return .updateTrainingMax
        case .updateEstimatedOneRepMax: return .updateEstimatedOneRepMax
        case .updateActualOneRepMax: return .updateActualOneRepMax
        case .repeatPrescription: return .repeatPrescription
        case .changeStage: return .changeStage
        case .advanceExerciseVariation: return .advanceExerciseVariation
        case .regressExerciseVariation: return .regressExerciseVariation
        case .advanceWeek: return .advanceWeek
        case .repeatWeek: return .repeatWeek
        case .advanceWave: return .advanceWave
        case .advanceBlock: return .advanceBlock
        case .restartBlock: return .restartBlock
        case .startDeload: return .startDeload
        case .resetFailureCount: return .resetFailureCount
        case .resetProgressionOffsets: return .resetProgressionOffsets
        case .endExercise: return .endExercise
        case .endProgram: return .endProgram
        case .generateRecommendation: return .generateRecommendation
        case .noChange: return .noChange
        }
    }

    private func defaultAction(for kind: ProgramBuilderActionKind) -> ProgressionAction {
        switch kind {
        case .addLoad: return .addLoad(2.5)
        case .reduceLoad: return .reduceLoad(2.5)
        case .addLoadPercentage: return .addLoadPercentage(0.025)
        case .reduceLoadPercentage: return .reduceLoadPercentage(0.025)
        case .addAssistance: return .addAssistance(5)
        case .reduceAssistance: return .reduceAssistance(5)
        case .addRepetitions: return .addRepetitions(1)
        case .reduceRepetitions: return .reduceRepetitions(1)
        case .addSets: return .addSets(1)
        case .reduceSets: return .reduceSets(1)
        case .addDuration: return .addDuration(30)
        case .reduceDuration: return .reduceDuration(30)
        case .addDistance: return .addDistance(50)
        case .reduceDistance: return .reduceDistance(50)
        case .addRestDuration: return .addRestDuration(15)
        case .reduceRestDuration: return .reduceRestDuration(15)
        case .addCalories: return .addCalories(10)
        case .reduceCalories: return .reduceCalories(10)
        case .updateTrainingMax: return .updateTrainingMax(.source(.constant(100)))
        case .updateEstimatedOneRepMax: return .updateEstimatedOneRepMax(.source(.constant(100)))
        case .updateActualOneRepMax: return .updateActualOneRepMax(.source(.constant(100)))
        case .repeatPrescription: return .repeatPrescription
        case .changeStage: return .changeStage("next")
        case .advanceExerciseVariation: return .advanceExerciseVariation
        case .regressExerciseVariation: return .regressExerciseVariation
        case .advanceWeek: return .advanceWeek
        case .repeatWeek: return .repeatWeek
        case .advanceWave: return .advanceWave
        case .advanceBlock: return .advanceBlock
        case .restartBlock: return .restartBlock
        case .startDeload: return .startDeload
        case .resetFailureCount: return .resetFailureCount
        case .resetProgressionOffsets: return .resetProgressionOffsets
        case .endExercise: return .endExercise
        case .endProgram: return .endProgram
        case .generateRecommendation: return .generateRecommendation
        case .noChange: return .noChange
        }
    }

    private func actionUsesValue(_ action: ProgressionAction) -> Bool {
        switch action {
        case .addLoad, .reduceLoad, .addLoadPercentage, .reduceLoadPercentage,
                .addAssistance, .reduceAssistance, .addRepetitions, .reduceRepetitions,
                .addSets, .reduceSets, .addDuration, .reduceDuration, .addDistance,
                .reduceDistance, .addRestDuration, .reduceRestDuration, .addCalories,
                .reduceCalories, .changeStage:
            return true
        default:
            return false
        }
    }

    private func actionValue(_ action: ProgressionAction) -> String {
        switch action {
        case .addLoad(let value), .reduceLoad(let value), .addLoadPercentage(let value),
                .reduceLoadPercentage(let value), .addAssistance(let value), .reduceAssistance(let value),
                .addDuration(let value), .reduceDuration(let value), .addDistance(let value),
                .reduceDistance(let value), .addCalories(let value), .reduceCalories(let value): return String(value)
        case .addRepetitions(let value), .reduceRepetitions(let value), .addSets(let value),
                .reduceSets(let value), .addRestDuration(let value), .reduceRestDuration(let value): return String(value)
        case .changeStage(let value): return value
        default: return ""
        }
    }

    private func actionSettingValue(_ action: ProgressionAction, value: String) -> ProgressionAction {
        switch action {
        case .addLoad: return .addLoad(max(0, Double(value) ?? 0))
        case .reduceLoad: return .reduceLoad(max(0, Double(value) ?? 0))
        case .addLoadPercentage: return .addLoadPercentage(max(0, Double(value) ?? 0))
        case .reduceLoadPercentage: return .reduceLoadPercentage(max(0, Double(value) ?? 0))
        case .addAssistance: return .addAssistance(max(0, Double(value) ?? 0))
        case .reduceAssistance: return .reduceAssistance(max(0, Double(value) ?? 0))
        case .addRepetitions: return .addRepetitions(max(0, Int(value) ?? 0))
        case .reduceRepetitions: return .reduceRepetitions(max(0, Int(value) ?? 0))
        case .addSets: return .addSets(max(0, Int(value) ?? 0))
        case .reduceSets: return .reduceSets(max(0, Int(value) ?? 0))
        case .addDuration: return .addDuration(max(0, Double(value) ?? 0))
        case .reduceDuration: return .reduceDuration(max(0, Double(value) ?? 0))
        case .addDistance: return .addDistance(max(0, Double(value) ?? 0))
        case .reduceDistance: return .reduceDistance(max(0, Double(value) ?? 0))
        case .addRestDuration: return .addRestDuration(max(0, Int(value) ?? 0))
        case .reduceRestDuration: return .reduceRestDuration(max(0, Int(value) ?? 0))
        case .addCalories: return .addCalories(max(0, Double(value) ?? 0))
        case .reduceCalories: return .reduceCalories(max(0, Double(value) ?? 0))
        case .changeStage: return .changeStage(value)
        default: return action
        }
    }

    private var formulaKind: ProgramBuilderFormulaKind {
        guard let formula = rule.formula else { return .none }
        guard case .source(let source) = formula else { return .constant }
        switch source {
        case .constant: return .constant
        case .trainingMax: return .trainingMax
        case .estimatedOneRepMax: return .estimatedOneRepMax
        case .actualOneRepMax: return .actualOneRepMax
        case .previousOccurrence: return .previousOccurrence
        case .previousSuccessfulSet: return .previousSuccessfulSet
        case .completedTopSet: return .completedTopSet
        case .dailyMaximum: return .dailyMaximum
        case .anotherExposure: return .anotherExposure
        case .completedMetric: return .completedMetric
        }
    }

    private var formulaKindBinding: Binding<ProgramBuilderFormulaKind> {
        Binding(
            get: { formulaKind },
            set: { kind in
                switch kind {
                case .none: rule.formula = nil
                case .constant: rule.formula = .source(.constant(1))
                case .trainingMax: rule.formula = .source(.trainingMax(exposureKey: ""))
                case .estimatedOneRepMax: rule.formula = .source(.estimatedOneRepMax(exposureKey: ""))
                case .actualOneRepMax: rule.formula = .source(.actualOneRepMax(exposureKey: ""))
                case .previousOccurrence: rule.formula = .source(.previousOccurrence(exposureKey: ""))
                case .previousSuccessfulSet: rule.formula = .source(.previousSuccessfulSet(exposureKey: ""))
                case .completedTopSet: rule.formula = .source(.completedTopSet(exposureKey: ""))
                case .dailyMaximum: rule.formula = .source(.dailyMaximum(exposureKey: ""))
                case .anotherExposure: rule.formula = .source(.anotherExposure(exposureKey: ""))
                case .completedMetric: rule.formula = .source(.completedMetric(exposureKey: "", metric: .load))
                }
            }
        )
    }

    private var formulaNeedsExposureKey: Bool {
        switch formulaKind {
        case .trainingMax, .estimatedOneRepMax, .actualOneRepMax, .previousOccurrence,
                .previousSuccessfulSet, .completedTopSet, .dailyMaximum, .anotherExposure,
                .completedMetric:
            return true
        default:
            return false
        }
    }

    private var formulaNeedsConstant: Bool {
        formulaKind == .constant
    }

    private var formulaExposureKeyBinding: Binding<String> {
        Binding(
            get: {
                guard case .source(let source)? = rule.formula else { return "" }
                switch source {
                case .trainingMax(let key), .estimatedOneRepMax(let key), .actualOneRepMax(let key),
                        .previousOccurrence(let key), .previousSuccessfulSet(let key), .completedTopSet(let key),
                        .dailyMaximum(let key), .anotherExposure(let key), .completedMetric(let key, _):
                    return key
                case .constant:
                    return ""
                }
            },
            set: { value in
                guard case .source(let source)? = rule.formula else { return }
                switch source {
                case .trainingMax: rule.formula = .source(.trainingMax(exposureKey: value))
                case .estimatedOneRepMax: rule.formula = .source(.estimatedOneRepMax(exposureKey: value))
                case .actualOneRepMax: rule.formula = .source(.actualOneRepMax(exposureKey: value))
                case .previousOccurrence: rule.formula = .source(.previousOccurrence(exposureKey: value))
                case .previousSuccessfulSet: rule.formula = .source(.previousSuccessfulSet(exposureKey: value))
                case .completedTopSet: rule.formula = .source(.completedTopSet(exposureKey: value))
                case .dailyMaximum: rule.formula = .source(.dailyMaximum(exposureKey: value))
                case .anotherExposure: rule.formula = .source(.anotherExposure(exposureKey: value))
                case .completedMetric(_, let metric): rule.formula = .source(.completedMetric(exposureKey: value, metric: metric))
                case .constant: break
                }
            }
        )
    }

    private var formulaConstantBinding: Binding<String> {
        Binding(
            get: {
                guard case .source(.constant(let value))? = rule.formula else { return "" }
                return String(value)
            },
            set: { value in
                rule.formula = .source(.constant(Double(value) ?? 0))
            }
        )
    }

    private func compose(_ transform: (ProgressionFormula) -> ProgressionFormula) {
        guard let formula = rule.formula else { return }
        rule.formula = transform(formula)
    }
}

private enum ProgramBuilderFormulaKind: String, CaseIterable, Identifiable {
    case none
    case constant
    case trainingMax
    case estimatedOneRepMax
    case actualOneRepMax
    case previousOccurrence
    case previousSuccessfulSet
    case completedTopSet
    case dailyMaximum
    case anotherExposure
    case completedMetric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No formula"
        case .constant: return "Constant"
        case .trainingMax: return "Training Max"
        case .estimatedOneRepMax: return "Estimated 1RM"
        case .actualOneRepMax: return "Actual 1RM"
        case .previousOccurrence: return "Previous occurrence"
        case .previousSuccessfulSet: return "Previous successful set"
        case .completedTopSet: return "Completed top set"
        case .dailyMaximum: return "Daily maximum"
        case .anotherExposure: return "Another exposure"
        case .completedMetric: return "Completed metric"
        }
    }
}

private struct ProgramDefinitionSetEditor: View {
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
        components.append(RepComponent(exerciseID: exercises.first?.id ?? fallbackExerciseID, repetitions: 1))
        set.repetitions = .sequence(components)
    }

    private func removeComponent(at index: Int) {
        guard case .sequence(var components) = set.repetitions,
              components.indices.contains(index), components.count > 1 else { return }
        components.remove(at: index)
        set.repetitions = .sequence(components)
    }
}

private struct ProgramDefinitionPayloadPreviewView: View {
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
                                .foregroundStyle(.secondary)
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

private extension ProgramSetRole {
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

private extension LoadReferenceKind {
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
