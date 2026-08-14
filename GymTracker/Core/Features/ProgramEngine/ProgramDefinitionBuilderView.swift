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
    @State private var isLoadingImport = false
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
            Section("Plan") {
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
        .navigationTitle("Plan Builder")
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
                    .disabled(isLoadingImport)
                    Button("Export JSON", systemImage: AppIcon.export) {
                        exportDocument = try? ProgramDefinitionDocument(definition: definition)
                        isExporting = exportDocument != nil
                    }
                } label: {
                    if isLoadingImport {
                        ProgressView()
                    } else {
                        Image(systemName: AppIcon.ellipsis)
                    }
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
                                isOptional: workout.isOptional,
                                executionBlocks: workout.executionBlocks.map { block in
                                    var copy = block
                                    copy.id = UUID()
                                    return copy
                                },
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
            guard url.startAccessingSecurityScopedResource() else {
                validationMessages = ["Cannot access the selected file."]
                return
            }
            isLoadingImport = true
            Task {
                defer { isLoadingImport = false }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try await Task.detached(priority: .utility) {
                        try Data(contentsOf: url)
                    }.value
                    let importedDefinition = try ProgramDefinitionCodec.decode(data)
                    guard !Task.isCancelled else { return }
                    definition = importedDefinition
                    validationMessages = []
                } catch {
                    guard !Task.isCancelled else { return }
                    validationMessages = [error.localizedDescription]
                }
            }
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

#endif
