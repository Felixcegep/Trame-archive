import SwiftData
import SwiftUI

struct MobilityLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onStart: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void

    @Query(sort: \MobilityRoutine.updatedAt, order: .reverse) private var routines: [MobilityRoutine]
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var sessions: [MobilitySession]
    @Query private var workouts: [Workout]
    @State private var selectedRoutine: MobilityRoutine?
    @State private var isShowingDefinitions = false
    @State private var sessionContext: MobilitySessionContext = .standalone

    var body: some View {
        List {
            Section {
                Picker("Session context", selection: $sessionContext) {
                    ForEach(MobilitySessionContext.allCases, id: \.self) { context in
                        Text(context.displayName).tag(context)
                    }
                }
                .disabled(sessionContext != .standalone && activeWorkout == nil)

                if availableRoutines.isEmpty {
                    ContentUnavailableView(
                        "No mobility routines",
                        systemImage: AppIcon.mobility,
                        description: Text("Create a short routine to begin mobility work.")
                    )
                } else {
                    ForEach(availableRoutines) { routine in
                        Button {
                            onStart(routine, sessionContext, sessionContext == .standalone ? nil : activeWorkout?.id)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(routine.name)
                                    .font(AppFont.subheadlineSemibold)
                                Text("^[\(routine.items.count) movement](inflect: true)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityIdentifier("start-mobility-routine-\(routine.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                selectedRoutine = routine
                            } label: {
                                Label("Edit", systemImage: AppIcon.edit)
                            }
                            .tint(Color.gymAccent)
                        }
                    }
                }
            } header: {
                Text("Routines")
            } footer: {
                Text("Starting a routine snapshots its movement targets and instructions into a separate mobility session.")
            }

            if recentMovementNames.isEmpty == false {
                Section("Recent movements") {
                    ForEach(recentMovementNames, id: \.self) { name in
                        Text(name)
                    }
                }
            }

            Section {
                Button {
                    selectedRoutine = createRoutine()
                } label: {
                    Label("New routine", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("create-mobility-routine")

                Button {
                    isShowingDefinitions = true
                } label: {
                    Label("Manage movements", systemImage: AppIcon.mobility)
                }
                .accessibilityIdentifier("manage-mobility-definitions")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Mobility")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $selectedRoutine) { routine in
            NavigationStack {
                MobilityRoutineEditorView(routine: routine)
            }
        }
        .sheet(isPresented: $isShowingDefinitions) {
            NavigationStack {
                MobilityDefinitionsView()
            }
        }
    }

    private var availableRoutines: [MobilityRoutine] {
        routines.filter { $0.isArchived == false }
    }

    private var activeWorkout: Workout? {
        workouts.first { $0.status == .active }
    }

    private var recentMovementNames: [String] {
        var seen = Set<String>()
        return sessions
            .flatMap(\.orderedEntries)
            .compactMap { seen.insert($0.definitionNameSnapshot).inserted ? $0.definitionNameSnapshot : nil }
            .prefix(5)
            .map { $0 }
    }

    private func createRoutine() -> MobilityRoutine? {
        let routine = MobilityRoutine(name: "New mobility routine")
        if let definition = definitions.first(where: { $0.isArchived == false }) {
            routine.items = [MobilityRoutineItem(definition: definition, orderIndex: 0)]
        }
        modelContext.insert(routine)
        guard modelContext.saveOrRollback() else { return nil }
        return routine
    }
}

struct MobilityDefinitionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @State private var isShowingNewDefinition = false
    @State private var definitionToEdit: MobilityDefinition?
    @State private var showsArchived = false

    var body: some View {
        List {
            if visibleDefinitions.isEmpty {
                ContentUnavailableView(
                    showsArchived ? "No archived movements" : "No movements",
                    systemImage: AppIcon.mobility,
                    description: Text("Create a movement before adding it to a routine.")
                )
            } else {
                ForEach(visibleDefinitions) { definition in
                    Button {
                        definitionToEdit = definition
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(definition.name)
                                .font(AppFont.subheadlineSemibold)
                            Text(definition.trackingType.displayName)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .foregroundStyle(Color.gymText)
                    .accessibilityIdentifier("edit-mobility-definition-\(definition.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            definition.isFavorite.toggle()
                            definition.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(
                                definition.isFavorite ? "Remove favorite" : "Favorite",
                                systemImage: definition.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(Color.gymAccent)

                        Button(role: definition.isArchived ? nil : .destructive) {
                            definition.isArchived.toggle()
                            definition.updatedAt = .now
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(
                                definition.isArchived ? "Restore" : "Archive",
                                systemImage: definition.isArchived ? "arrow.uturn.backward" : "archivebox"
                            )
                        }
                        .accessibilityIdentifier("archive-mobility-definition-\(definition.id)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Movements")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(showsArchived ? "Current" : "Archived") {
                    showsArchived.toggle()
                }
                .accessibilityIdentifier("toggle-archived-mobility-definitions")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewDefinition = true
                } label: {
                    Label("New movement", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("create-mobility-definition")
            }
        }
        .sheet(isPresented: $isShowingNewDefinition) {
            MobilityDefinitionForm()
        }
        .sheet(item: $definitionToEdit) { definition in
            MobilityDefinitionForm(definition: definition)
        }
    }

    private var visibleDefinitions: [MobilityDefinition] {
        definitions.filter { $0.isArchived == showsArchived }
    }
}

struct MobilityDefinitionForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var instructions = ""
    @State private var trackingType: MobilityTrackingType = .duration
    @State private var duration = 30
    @State private var repetitions = 8
    @State private var error: ValidationIssue?
    let definition: MobilityDefinition?

    init(definition: MobilityDefinition? = nil) {
        self.definition = definition
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    TextField("Name", text: $name)
                    TextField("Instructions", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Tracks", selection: $trackingType) {
                        ForEach(MobilityTrackingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    if trackingType == .duration {
                        Stepper("Default duration: \(duration) sec", value: $duration, in: 5...600, step: 5)
                    } else {
                        Stepper("Default repetitions: \(repetitions)", value: $repetitions, in: 1...100)
                    }
                }
            }
            .navigationTitle(definition == nil ? "New movement" : "Edit movement")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadDefinition)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-mobility-definition")
                }
            }
            .alert("Couldn’t save movement", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error?.message ?? "Please try again.")
            }
        }
    }

    private func loadDefinition() {
        guard let definition else { return }
        name = definition.name
        instructions = definition.instructions ?? ""
        trackingType = definition.trackingType
        duration = definition.defaultDurationSeconds ?? 30
        repetitions = definition.defaultRepetitions ?? 8
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = (try? modelContext.fetch(FetchDescriptor<MobilityDefinition>())) ?? []
        guard existingNames.allSatisfy({
            $0.id == definition?.id || $0.name.localizedCaseInsensitiveCompare(trimmedName) != .orderedSame
        }) else {
            error = ValidationIssue(severity: .error, message: "A movement with that name already exists.")
            return
        }

        let target = definition ?? MobilityDefinition(
            name: trimmedName,
            instructions: nil,
            trackingType: trackingType,
            defaultDurationSeconds: nil,
            defaultRepetitions: nil
        )
        target.name = trimmedName
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        target.instructions = trimmedInstructions.isEmpty ? nil : trimmedInstructions
        target.trackingType = trackingType
        target.defaultDurationSeconds = trackingType == .duration ? duration : nil
        target.defaultRepetitions = trackingType == .repetitions ? repetitions : nil
        target.updatedAt = .now
        if definition == nil { modelContext.insert(target) }

        if modelContext.saveOrRollback() {
            dismiss()
        } else {
            self.error = ValidationIssue(severity: .error, message: "The movement could not be saved. Try again.")
        }
    }
}

struct MobilityRoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let routine: MobilityRoutine
    @Query(sort: \MobilityDefinition.name) private var definitions: [MobilityDefinition]
    @State private var name = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                ForEach(routine.orderedItems) { item in
                    MobilityRoutineItemEditorRow(item: item)
                }
                .onDelete(perform: deleteItems)

                Menu {
                    ForEach(availableDefinitions) { definition in
                        Button(definition.name) { add(definition) }
                    }
                } label: {
                    Label("Add movement", systemImage: AppIcon.plus)
                }
                .disabled(definitions.filter { $0.isArchived == false }.isEmpty)
            } header: {
                Text("Movements")
            } footer: {
                Text("Each row is an independent prescription, so the same movement can appear more than once.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = routine.name
            notes = routine.notes ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.items.isEmpty)
                    .accessibilityIdentifier("save-mobility-routine")
            }
        }
    }

    private func add(_ definition: MobilityDefinition) {
        routine.items.append(MobilityRoutineItem(definition: definition, orderIndex: routine.items.count))
        routine.normalizeItemOrder()
        _ = modelContext.saveOrRollback()
    }

    private var availableDefinitions: [MobilityDefinition] {
        definitions
            .filter { $0.isArchived == false }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func deleteItems(at offsets: IndexSet) {
        let ordered = routine.orderedItems
        for index in offsets {
            modelContext.delete(ordered[index])
        }
        routine.normalizeItemOrder()
        _ = modelContext.saveOrRollback()
    }

    private func save() {
        routine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        routine.updatedAt = .now
        guard modelContext.saveOrRollback() else { return }
        dismiss()
    }
}

private struct MobilityRoutineItemEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: MobilityRoutineItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(item.definition.name)
                .font(AppFont.subheadlineSemibold)
            Picker("Side", selection: $item.sideRaw) {
                ForEach(MobilitySide.allCases, id: \.self) { side in
                    Text(side.displayName).tag(side.rawValue)
                }
            }
            if item.definition.trackingType == .duration {
                Stepper("Target: \(item.targetDurationSeconds ?? item.definition.defaultDurationSeconds ?? 30) sec", value: durationBinding, in: 5...600, step: 5)
            } else {
                Stepper("Target: \(item.targetRepetitions ?? item.definition.defaultRepetitions ?? 8) reps", value: repetitionsBinding, in: 1...100)
            }
        }
        .onChange(of: item.sideRaw) { _, _ in save() }
    }

    private var durationBinding: Binding<Int> {
        Binding(get: { item.targetDurationSeconds ?? item.definition.defaultDurationSeconds ?? 30 }, set: { item.targetDurationSeconds = $0; save() })
    }

    private var repetitionsBinding: Binding<Int> {
        Binding(get: { item.targetRepetitions ?? item.definition.defaultRepetitions ?? 8 }, set: { item.targetRepetitions = $0; save() })
    }

    private func save() { _ = modelContext.saveOrRollback() }
}
