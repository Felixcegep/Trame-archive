import SwiftUI
import SwiftData

/// Authoring surface for a snapshot-local execution block. It deliberately
/// records typed configuration instead of deriving a workout format from a
/// free-form note, so the result remains comparable in history and analytics.
struct WorkoutExecutionBlockBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    let blockToEdit: WorkoutExecutionBlock?
    let availableExercises: [Exercise]
    let onAddExercise: ((Exercise) -> Void)?
    let onPersist: () -> Void

    @State private var kind: ExerciseBlockKind = .circuit
    @State private var selectedEntryIDs: Set<PersistentIdentifier> = []
    @State private var name = ""
    @State private var targetRounds = ""
    @State private var clockMode: BlockClockMode = .none
    @State private var durationMinutes = ""
    @State private var timeCapMinutes = ""
    @State private var intervalSeconds = ""
    @State private var scoreKind: BlockScoreKind = .none
    @State private var repetitionScheme: BlockRepetitionScheme = .fixed
    @State private var repetitionStart = ""
    @State private var repetitionEnd = ""
    @State private var repetitionStep = ""
    @State private var isSharedLoad = false
    @State private var restSeconds = ""
    @State private var advancedExpanded = false
    @State private var validationMessage: String?
    @State private var isShowingExercisePicker = false

    init(
        workout: Workout,
        blockToEdit: WorkoutExecutionBlock? = nil,
        availableExercises: [Exercise] = [],
        onAddExercise: ((Exercise) -> Void)? = nil,
        onPersist: @escaping () -> Void
    ) {
        self.workout = workout
        self.blockToEdit = blockToEdit
        self.availableExercises = availableExercises
        self.onAddExercise = onAddExercise
        self.onPersist = onPersist

        let editingBlockID = blockToEdit?.id
        let initialKind = blockToEdit?.kind ?? .circuit
        _kind = State(initialValue: initialKind)
        let members = workout.orderedExercises.filter {
            $0.executionBlockID == editingBlockID
        }
        let available = workout.orderedExercises.filter {
            $0.executionBlockID == nil || $0.executionBlockID == editingBlockID
        }
        // A brand-new block starts with nothing selected unless there is
        // exactly one eligible exercise and the format accepts it. Filtering
        // by a nil id would otherwise pre-select every unassigned exercise.
        if editingBlockID != nil {
            _selectedEntryIDs = State(initialValue: Set(members.map(\.persistentModelID)))
        } else if ExecutionBlockAuthoring.shouldPreselectSingleAvailableExercise(
            isEditing: false,
            availableCount: available.count,
            kind: initialKind
        ) {
            _selectedEntryIDs = State(initialValue: Set(available.map(\.persistentModelID)))
        } else {
            _selectedEntryIDs = State(initialValue: [])
        }
        _name = State(initialValue: blockToEdit?.name ?? "")
        _targetRounds = State(initialValue: blockToEdit?.targetRounds.map(String.init) ?? "")
        _clockMode = State(initialValue: blockToEdit?.clockMode ?? .none)
        _durationMinutes = State(initialValue: blockToEdit?.prescribedDurationSeconds.map { String($0 / 60) } ?? "")
        _timeCapMinutes = State(initialValue: blockToEdit?.timeCapSeconds.map { String($0 / 60) } ?? "")
        _intervalSeconds = State(initialValue: blockToEdit?.intervalSeconds.map(String.init) ?? "")
        _scoreKind = State(initialValue: blockToEdit?.scoreKind ?? .none)
        _repetitionScheme = State(initialValue: blockToEdit?.repetitionScheme ?? .fixed)
        _repetitionStart = State(initialValue: blockToEdit?.repetitionStart.map(String.init) ?? "")
        _repetitionEnd = State(initialValue: blockToEdit?.repetitionEnd.map(String.init) ?? "")
        _repetitionStep = State(initialValue: blockToEdit?.repetitionStep.map(String.init) ?? "")
        _isSharedLoad = State(initialValue: blockToEdit?.isSharedLoad ?? false)
        _restSeconds = State(initialValue: blockToEdit?.restSeconds.map(String.init) ?? "")
        // Reveal advanced options up front only when an existing block already
        // uses one of them, so the default authoring view stays uncluttered.
        _advancedExpanded = State(initialValue: blockToEdit.map {
            $0.isSharedLoad || $0.restSeconds != nil || ($0.name?.isEmpty == false)
        } ?? false)
    }

    private var availableEntries: [ExerciseEntry] {
        workout.orderedExercises.filter {
            $0.executionBlockID == nil || $0.executionBlockID == blockToEdit?.id
        }
    }

    private var assignedElsewhere: [ExerciseEntry] {
        workout.orderedExercises.filter {
            $0.executionBlockID != nil && $0.executionBlockID != blockToEdit?.id
        }
    }

    private var selectedEntries: [ExerciseEntry] {
        availableEntries.filter { selectedEntryIDs.contains($0.persistentModelID) }
    }

    private var canSave: Bool {
        ExecutionBlockAuthoring.meetsExerciseRequirement(selectedEntries.count, kind: kind)
    }

    private var saveDisabledReason: String? {
        ExecutionBlockAuthoring.saveDisabledReason(
            kind: kind,
            selectedCount: selectedEntries.count,
            availableCount: availableEntries.count,
            sessionExerciseCount: workout.orderedExercises.count
        )
    }

    private var canAddExercise: Bool {
        onAddExercise != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                exerciseSection
                formatSection
                if kind == .ladder {
                    ladderSection
                }
                if kind.isTimed {
                    timedSection
                }
                advancedSection
                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(AppFont.body)
                            .foregroundStyle(Color.trameDestructiveText)
                            .accessibilityIdentifier("execution-block-validation")
                    } header: {
                        TrameDomainSectionRule(title: "Needs attention", color: Color.trameAttention)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .navigationTitle(blockToEdit == nil ? "Group Exercises" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(blockToEdit == nil ? "Add group" : "Save", action: saveBlock)
                        .disabled(!canSave)
                        .accessibilityIdentifier("create-execution-block")
                        .accessibilityHint(saveDisabledReason ?? "")
                }
            }
            .sheet(isPresented: $isShowingExercisePicker) {
                NavigationStack {
                    ExerciseLibraryView(
                        isSelectingExercise: true,
                        availableExercises: availableExercises,
                        addedExerciseIDs: Set(workout.orderedExercises.map(\.exercise.id)),
                        onSelect: addExerciseFromPicker
                    )
                }
            }
        }
        .onChange(of: kind) { _, newKind in
            applyFormatDefaults(for: newKind)
        }
    }

    private var exerciseSection: some View {
        Section {
            if workout.orderedExercises.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("No exercises yet")
                        .font(AppFont.body)
                        .foregroundStyle(Color.trameText)
                    Text("Add exercises to this workout, then select the ones that run together.")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("block-exercises-empty")
            }

            ForEach(availableEntries, id: \.persistentModelID) { entry in
                exerciseToggle(entry)
            }

            ForEach(assignedElsewhere, id: \.persistentModelID) { entry in
                groupedExerciseRow(entry)
            }

            if canAddExercise {
                Button {
                    isShowingExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("block-add-exercise")
            }
        } header: {
            TrameDomainSectionRule(title: "Exercises", color: Color.trameStrength)
        } footer: {
            Text(exerciseFooter)
                .accessibilityIdentifier("block-selected-count")
        }
    }

    private var exerciseFooter: String {
        if workout.orderedExercises.isEmpty {
            return String(localized: "A group needs exercises from this workout.")
        }
        if availableEntries.isEmpty {
            return String(localized: "Each exercise can only belong to one group.")
        }
        return ExecutionBlockAuthoring.selectionStatus(kind: kind, selected: selectedEntries.count)
    }

    private var formatSection: some View {
        Section {
            NavigationLink {
                ExecutionBlockFormatPicker(kind: $kind)
            } label: {
                HStack {
                    Text("Format")
                        .foregroundStyle(Color.trameText)
                    Spacer(minLength: Spacing.m)
                    Text(kind.title)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
            .accessibilityIdentifier("block-format-picker")

            Text(kind.summary)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("block-format-summary")

            if kind.supportsRounds {
                TextField("Rounds (optional)", text: $targetRounds)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("block-target-rounds")
            }
        } header: {
            TrameDomainSectionRule(title: "How they run", color: Color.trameCompetition)
        }
    }

    private var ladderSection: some View {
        Section {
            Picker("Repetition pattern", selection: $repetitionScheme) {
                Text(BlockRepetitionScheme.ascendingLadder.title).tag(BlockRepetitionScheme.ascendingLadder)
                Text(BlockRepetitionScheme.descendingLadder.title).tag(BlockRepetitionScheme.descendingLadder)
            }
            TextField("Starting repetitions", text: $repetitionStart)
                .keyboardType(.numberPad)
            TextField("Ending repetitions", text: $repetitionEnd)
                .keyboardType(.numberPad)
            TextField("Step", text: $repetitionStep)
                .keyboardType(.numberPad)
        } header: {
            TrameDomainSectionRule(title: "Ladder", color: Color.trameAttention)
        }
    }

    private var timedSection: some View {
        Section {
            if kind.requiresInterval {
                TextField("Interval (seconds)", text: $intervalSeconds)
                    .keyboardType(.numberPad)
            }
            TextField(
                kind.requiresTimeCap ? "Time cap (minutes)" : "Time cap (minutes, optional)",
                text: $timeCapMinutes
            )
            .keyboardType(.numberPad)
        } header: {
            TrameDomainSectionRule(title: "Clock", color: Color.trameAttention)
        } footer: {
            if !clockDescription.isEmpty {
                Label(clockDescription, systemImage: AppIcon.timer)
            }
        }
    }

    private var advancedSection: some View {
        Section {
            DisclosureGroup(isExpanded: $advancedExpanded) {
                TextField("Name (optional)", text: $name)
                Toggle("Use a shared load", isOn: $isSharedLoad)
                TextField("Rest after each round (seconds)", text: $restSeconds)
                    .keyboardType(.numberPad)

                if !kind.isTimed {
                    Picker("Clock", selection: $clockMode) {
                        ForEach(BlockClockMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if clockMode == .countdown {
                        TextField("Duration (minutes)", text: $durationMinutes)
                            .keyboardType(.numberPad)
                    }
                    if clockMode != .none {
                        TextField("Time cap (minutes, optional)", text: $timeCapMinutes)
                            .keyboardType(.numberPad)
                    }
                    if clockMode == .repeatingInterval {
                        TextField("Interval (seconds)", text: $intervalSeconds)
                            .keyboardType(.numberPad)
                    }
                }

                Picker("Score", selection: $scoreKind) {
                    ForEach(BlockScoreKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            } label: {
                Text("Advanced options")
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                    .accessibilityIdentifier("block-advanced-options")
            }
            .tint(Color.trameActionDeep)
        }
    }

    private func exerciseToggle(_ entry: ExerciseEntry) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.persistentModelID)
        return Button {
            toggle(entry)
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                    .foregroundStyle(isSelected ? Color.trameActionDeep : Color.trameSubdued)
                    .accessibilityHidden(true)
                Text(entry.occurrenceDisplayName)
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                Spacer(minLength: 0)
            }
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.occurrenceDisplayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(kind.exerciseSelectionHint)
        .accessibilityIdentifier("block-exercise-\(entry.occurrenceDisplayName)")
    }

    private func groupedExerciseRow(_ entry: ExerciseEntry) -> some View {
        let subtitle = groupedSubtitle(for: entry)
        return HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.lock)
                .foregroundStyle(Color.trameSubdued)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.occurrenceDisplayName)
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                Text(subtitle)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.occurrenceDisplayName)
        .accessibilityValue(subtitle)
        .accessibilityIdentifier("block-exercise-grouped-\(entry.occurrenceDisplayName)")
    }

    private func groupedSubtitle(for entry: ExerciseEntry) -> String {
        guard let blockID = entry.executionBlockID,
              let block = workout.orderedExecutionBlocks.first(where: { $0.id == blockID })
        else {
            return String(localized: "Already grouped")
        }
        return ExecutionBlockAuthoring.groupedSubtitle(blockName: block.name, kindTitle: block.kind.title)
    }

    private var clockDescription: String {
        switch kind {
        case .amrap: String(localized: "Counts up until the time cap.")
        case .forTime: String(localized: "Counts up until you finish.")
        case .emom: String(localized: "Repeats every interval until the cap.")
        case .interval: String(localized: "Repeats the interval throughout.")
        default: ""
        }
    }

    private func toggle(_ entry: ExerciseEntry) {
        if selectedEntryIDs.contains(entry.persistentModelID) {
            selectedEntryIDs.remove(entry.persistentModelID)
        } else {
            selectedEntryIDs.insert(entry.persistentModelID)
        }
    }

    private func addExerciseFromPicker(_ exercise: Exercise) {
        let before = Set(workout.orderedExercises.map(\.persistentModelID))
        onAddExercise?(exercise)
        if let added = workout.orderedExercises.first(where: { !before.contains($0.persistentModelID) }) {
            selectedEntryIDs.insert(added.persistentModelID)
        }
    }

    private func applyFormatDefaults(for kind: ExerciseBlockKind) {
        switch kind {
        case .amrap:
            clockMode = .countUp
            scoreKind = .roundsAndRepetitions
            repetitionScheme = .fixed
        case .emom:
            clockMode = .repeatingInterval
            intervalSeconds = intervalSeconds.isEmpty ? "60" : intervalSeconds
            scoreKind = .completedWork
            repetitionScheme = .fixed
        case .forTime:
            clockMode = .countUp
            scoreKind = .duration
            repetitionScheme = .fixed
        case .interval:
            clockMode = .repeatingInterval
            scoreKind = .completedWork
            repetitionScheme = .fixed
        case .ladder:
            repetitionScheme = .ascendingLadder
            clockMode = .none
            scoreKind = .none
        case .chipper:
            repetitionScheme = .chipper
            clockMode = .none
            scoreKind = .none
        default:
            repetitionScheme = .fixed
            clockMode = .none
            scoreKind = .none
        }
    }

    private func saveBlock() {
        do {
            let configuration = WorkoutExecutionBlockConfiguration(
                kind: kind,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                targetRounds: Int(targetRounds),
                isSharedLoad: isSharedLoad,
                restSeconds: Int(restSeconds),
                clockMode: clockMode,
                prescribedDurationSeconds: Int(durationMinutes).map { $0 * 60 },
                timeCapSeconds: Int(timeCapMinutes).map { $0 * 60 },
                intervalSeconds: Int(intervalSeconds),
                scoreKind: scoreKind,
                repetitionScheme: repetitionScheme,
                repetitionStart: Int(repetitionStart),
                repetitionEnd: Int(repetitionEnd),
                repetitionStep: Int(repetitionStep)
            )
            if let blockToEdit {
                try WorkoutExecutionBlockService.update(
                    blockToEdit,
                    configuration: configuration,
                    entries: selectedEntries,
                    in: workout
                )
            } else {
                try WorkoutExecutionBlockService.create(
                    configuration: configuration,
                    entries: selectedEntries,
                    in: workout
                )
            }
            onPersist()
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}

private struct ExecutionBlockFormatPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var kind: ExerciseBlockKind

    var body: some View {
        List {
            ForEach(ExecutionBlockAuthoring.FormatFamily.allCases, id: \.self) { family in
                Section {
                    ForEach(family.kinds, id: \.self) { format in
                        Button {
                            kind = format
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(format.title)
                                        .font(AppFont.body)
                                        .foregroundStyle(Color.trameText)
                                    Text(format.summary)
                                        .font(AppFont.metadata)
                                        .foregroundStyle(Color.trameSubdued)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: Spacing.s)
                                if format == kind {
                                    Image(systemName: AppIcon.checkmark)
                                        .foregroundStyle(Color.trameActionDeep)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: ComponentSize.minimumTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(format == kind ? [.isSelected] : [])
                        .accessibilityIdentifier("block-format-\(format.rawValue)")
                    }
                } header: {
                    formatFamilyHeader(family)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Format")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func formatFamilyHeader(_ family: ExecutionBlockAuthoring.FormatFamily) -> some View {
        switch family {
        case .pairing:
            TrameDomainSectionRule(title: "Pairing", color: Color.trameStrength)
        case .timed:
            TrameDomainSectionRule(title: "Timed", color: Color.trameAttention)
        case .sequence:
            TrameDomainSectionRule(title: "Sequence", color: Color.trameCompetition)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
