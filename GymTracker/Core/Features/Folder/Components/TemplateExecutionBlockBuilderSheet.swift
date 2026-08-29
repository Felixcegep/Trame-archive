import SwiftUI
import SwiftData

/// Creates or edits a reusable block prescription. Plans receive a fresh
/// plan-local copy, and workouts later receive a snapshot-local copy.
struct TemplateExecutionBlockBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    let blockToEdit: TemplateExerciseBlock?
    let onPersist: () -> Void

    @State private var kind: ExerciseBlockKind = .circuit
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var name = ""
    @State private var targetRounds = ""
    @State private var isSharedLoad = false
    @State private var restSeconds = ""
    @State private var clockMode: BlockClockMode = .none
    @State private var durationMinutes = ""
    @State private var timeCapMinutes = ""
    @State private var intervalSeconds = ""
    @State private var scoreKind: BlockScoreKind = .none
    @State private var repetitionScheme: BlockRepetitionScheme = .fixed
    @State private var repetitionStart = ""
    @State private var repetitionEnd = ""
    @State private var repetitionStep = ""
    @State private var errorMessage: String?

    init(
        template: WorkoutTemplate,
        blockToEdit: TemplateExerciseBlock? = nil,
        onPersist: @escaping () -> Void
    ) {
        self.template = template
        self.blockToEdit = blockToEdit
        self.onPersist = onPersist

        let editingBlockID = blockToEdit?.id
        _kind = State(initialValue: blockToEdit?.kind ?? .circuit)
        // A new block starts empty; only an existing block pre-fills its
        // members. Filtering by a nil id would pre-select every unassigned
        // exercise.
        _selectedIDs = State(initialValue: editingBlockID == nil ? [] : Set(template.orderedTemplateExercises
            .filter { $0.executionBlockID == editingBlockID }
            .map(\.persistentModelID)))
        _name = State(initialValue: blockToEdit?.name ?? "")
        _targetRounds = State(initialValue: blockToEdit?.targetRounds.map(String.init) ?? "")
        _isSharedLoad = State(initialValue: blockToEdit?.isSharedLoad ?? false)
        _restSeconds = State(initialValue: blockToEdit?.restSeconds.map(String.init) ?? "")
        _clockMode = State(initialValue: blockToEdit?.clockMode ?? .none)
        _durationMinutes = State(initialValue: blockToEdit?.prescribedDurationSeconds.map { String($0 / 60) } ?? "")
        _timeCapMinutes = State(initialValue: blockToEdit?.timeCapSeconds.map { String($0 / 60) } ?? "")
        _intervalSeconds = State(initialValue: blockToEdit?.intervalSeconds.map(String.init) ?? "")
        _scoreKind = State(initialValue: blockToEdit?.scoreKind ?? .none)
        _repetitionScheme = State(initialValue: blockToEdit?.repetitionScheme ?? .fixed)
        _repetitionStart = State(initialValue: blockToEdit?.repetitionStart.map(String.init) ?? "")
        _repetitionEnd = State(initialValue: blockToEdit?.repetitionEnd.map(String.init) ?? "")
        _repetitionStep = State(initialValue: blockToEdit?.repetitionStep.map(String.init) ?? "")
    }

    private var candidates: [TemplateExercise] {
        template.orderedTemplateExercises.filter {
            $0.executionBlockID == nil || $0.executionBlockID == blockToEdit?.id
        }
    }

    private var selected: [TemplateExercise] {
        candidates.filter { selectedIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Format", selection: $kind) {
                        ForEach(ExerciseBlockKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField("Name this block (optional)", text: $name)
                    if kind.supportsRounds {
                        TextField("Target rounds (optional)", text: $targetRounds)
                            .keyboardType(.numberPad)
                    }
                    if kind == .ladder {
                        Picker("Repetition pattern", selection: $repetitionScheme) {
                            Text(BlockRepetitionScheme.ascendingLadder.title).tag(BlockRepetitionScheme.ascendingLadder)
                            Text(BlockRepetitionScheme.descendingLadder.title).tag(BlockRepetitionScheme.descendingLadder)
                        }
                        TextField("Starting repetitions", text: $repetitionStart).keyboardType(.numberPad)
                        TextField("Ending repetitions", text: $repetitionEnd).keyboardType(.numberPad)
                        TextField("Step", text: $repetitionStep).keyboardType(.numberPad)
                    }
                    if kind.requiresInterval {
                        TextField("Interval (seconds)", text: $intervalSeconds)
                            .keyboardType(.numberPad)
                    }
                    if kind.isTimed {
                        TextField(kind.requiresTimeCap ? "Time cap (minutes)" : "Time cap (minutes, optional)", text: $timeCapMinutes)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Format")
                } footer: {
                    Text(kind.summary)
                }

                Section("Advanced options") {
                    Toggle("Use one shared load", isOn: $isSharedLoad)
                    TextField("Rest after each round (seconds, optional)", text: $restSeconds)
                        .keyboardType(.numberPad)
                    if !kind.isTimed {
                        Picker("Clock", selection: $clockMode) {
                            ForEach(BlockClockMode.allCases, id: \.self) { clock in
                                Text(clock.title).tag(clock)
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
                        ForEach(BlockScoreKind.allCases, id: \.self) { score in
                            Text(score.title).tag(score)
                        }
                    }
                }

                Section("Exercises") {
                    if candidates.isEmpty {
                        Text("All template exercises already belong to an execution block.")
                            .foregroundStyle(Color.trameSubdued)
                    }
                    ForEach(candidates, id: \.persistentModelID) { exercise in
                        Button {
                            if selectedIDs.contains(exercise.persistentModelID) {
                                selectedIDs.remove(exercise.persistentModelID)
                            } else {
                                selectedIDs.insert(exercise.persistentModelID)
                            }
                        } label: {
                            HStack {
                                Text(exercise.exercise.name)
                                Spacer()
                                Image(systemName: selectedIDs.contains(exercise.persistentModelID) ? AppIcon.checkmarkCircle : AppIcon.circle)
                                    .foregroundStyle(Color.trameStrength)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.trameDestructiveText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .navigationTitle("Execution Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(blockToEdit == nil ? "Add" : "Save", action: save)
                        .disabled(selected.isEmpty)
                }
            }
        }
        .onChange(of: kind) { _, kind in applyDefaults(for: kind) }
    }

    private func applyDefaults(for kind: ExerciseBlockKind) {
        switch kind {
        case .amrap:
            clockMode = .countUp; scoreKind = .roundsAndRepetitions; repetitionScheme = .fixed
        case .emom:
            clockMode = .repeatingInterval; intervalSeconds = intervalSeconds.isEmpty ? "60" : intervalSeconds; scoreKind = .completedWork; repetitionScheme = .fixed
        case .forTime:
            clockMode = .countUp; scoreKind = .duration; repetitionScheme = .fixed
        case .interval:
            clockMode = .repeatingInterval; scoreKind = .completedWork; repetitionScheme = .fixed
        case .ladder:
            repetitionScheme = .ascendingLadder; clockMode = .none; scoreKind = .none
        case .chipper:
            repetitionScheme = .chipper; clockMode = .none; scoreKind = .none
        default: repetitionScheme = .fixed; clockMode = .none; scoreKind = .none
        }
    }

    private func save() {
        do {
            let configuration = TemplateExecutionBlockConfiguration(
                kind: kind,
                name: name,
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
                try TemplateExecutionBlockService.update(
                    blockToEdit,
                    configuration: configuration,
                    exercises: selected,
                    in: template
                )
            } else {
                try TemplateExecutionBlockService.create(
                    configuration: configuration,
                    exercises: selected,
                    in: template
                )
            }
            onPersist()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TemplateExecutionBlockConfiguration {
    let kind: ExerciseBlockKind
    let name: String
    let targetRounds: Int?
    let isSharedLoad: Bool
    let restSeconds: Int?
    let clockMode: BlockClockMode
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: BlockScoreKind
    let repetitionScheme: BlockRepetitionScheme
    let repetitionStart: Int?
    let repetitionEnd: Int?
    let repetitionStep: Int?
}

enum TemplateExecutionBlockService {
    static func create(
        kind: ExerciseBlockKind,
        exercises: [TemplateExercise],
        in template: WorkoutTemplate,
        name: String,
        targetRounds: Int?,
        isSharedLoad: Bool,
        restSeconds: Int?,
        clockMode: BlockClockMode,
        prescribedDurationSeconds: Int?,
        timeCapSeconds: Int?,
        intervalSeconds: Int?,
        scoreKind: BlockScoreKind,
        repetitionScheme: BlockRepetitionScheme,
        repetitionStart: Int?,
        repetitionEnd: Int?,
        repetitionStep: Int?
    ) throws {
        try create(
            configuration: TemplateExecutionBlockConfiguration(
                kind: kind,
                name: name,
                targetRounds: targetRounds,
                isSharedLoad: isSharedLoad,
                restSeconds: restSeconds,
                clockMode: clockMode,
                prescribedDurationSeconds: prescribedDurationSeconds,
                timeCapSeconds: timeCapSeconds,
                intervalSeconds: intervalSeconds,
                scoreKind: scoreKind,
                repetitionScheme: repetitionScheme,
                repetitionStart: repetitionStart,
                repetitionEnd: repetitionEnd,
                repetitionStep: repetitionStep
            ),
            exercises: exercises,
            in: template
        )
    }

    static func create(
        configuration: TemplateExecutionBlockConfiguration,
        exercises: [TemplateExercise],
        in template: WorkoutTemplate
    ) throws {
        try validate(configuration: configuration, exercises: exercises, in: template)
        let block = TemplateExerciseBlock(orderIndex: template.orderedExecutionBlocks.count, kind: configuration.kind)
        apply(configuration: configuration, to: block)
        template.executionBlocks.append(block)
        assign(exercises, to: block)
    }

    static func update(
        _ block: TemplateExerciseBlock,
        configuration: TemplateExecutionBlockConfiguration,
        exercises: [TemplateExercise],
        in template: WorkoutTemplate
    ) throws {
        try validate(configuration: configuration, exercises: exercises, in: template, allowedBlockID: block.id)
        for exercise in template.templateExercises where exercise.executionBlockID == block.id {
            exercise.executionBlockID = nil
            exercise.executionBlockComponentOrder = nil
        }
        apply(configuration: configuration, to: block)
        assign(exercises, to: block)
    }

    private static func apply(configuration: TemplateExecutionBlockConfiguration, to block: TemplateExerciseBlock) {
        block.kind = configuration.kind
        block.name = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : configuration.name
        block.targetRounds = configuration.targetRounds
        block.isSharedLoad = configuration.isSharedLoad
        block.restSeconds = configuration.restSeconds
        block.clockMode = configuration.clockMode
        block.prescribedDurationSeconds = configuration.prescribedDurationSeconds
        block.timeCapSeconds = configuration.timeCapSeconds
        block.intervalSeconds = configuration.intervalSeconds
        block.scoreKind = configuration.scoreKind
        block.repetitionScheme = configuration.repetitionScheme
        block.repetitionStart = configuration.repetitionStart
        block.repetitionEnd = configuration.repetitionEnd
        block.repetitionStep = configuration.repetitionStep
    }

    private static func assign(_ exercises: [TemplateExercise], to block: TemplateExerciseBlock) {
        for (index, exercise) in exercises.enumerated() {
            exercise.executionBlockID = block.id
            exercise.executionBlockComponentOrder = index
        }
    }

    private static func validate(
        configuration: TemplateExecutionBlockConfiguration,
        exercises: [TemplateExercise],
        in template: WorkoutTemplate,
        allowedBlockID: UUID? = nil
    ) throws {
        guard configuration.targetRounds.map({ $0 > 0 }) ?? true,
              configuration.restSeconds.map({ $0 >= 0 }) ?? true else {
            throw WorkoutExecutionBlockError.invalidConfiguration("Rounds and rest must be valid positive values.")
        }
        if let message = ExecutionBlockConfigurationValidator.message(
            kind: configuration.kind,
            clockMode: configuration.clockMode,
            prescribedDurationSeconds: configuration.prescribedDurationSeconds,
            timeCapSeconds: configuration.timeCapSeconds,
            intervalSeconds: configuration.intervalSeconds,
            repetitionScheme: configuration.repetitionScheme,
            repetitionStart: configuration.repetitionStart,
            repetitionEnd: configuration.repetitionEnd,
            repetitionStep: configuration.repetitionStep
        ) {
            throw WorkoutExecutionBlockError.invalidConfiguration(message)
        }
        guard !exercises.isEmpty else { throw WorkoutExecutionBlockError.emptyBlock }
        let templateExerciseObjects = Set(template.templateExercises.map(ObjectIdentifier.init))
        guard exercises.allSatisfy({ templateExerciseObjects.contains(ObjectIdentifier($0)) }) else {
            throw WorkoutExecutionBlockError.entryDoesNotBelongToWorkout
        }
        guard exercises.allSatisfy({ $0.executionBlockID == nil || $0.executionBlockID == allowedBlockID }) else {
            throw WorkoutExecutionBlockError.entryAlreadyBelongsToBlock
        }
        switch configuration.kind {
        case .pairedSet where exercises.count != 2,
             .triset where exercises.count != 3,
             .straight where exercises.count != 1,
             .giantSet where exercises.count < 4:
            throw WorkoutExecutionBlockError.invalidComponentCount(kind: configuration.kind, count: exercises.count)
        default: break
        }
    }

    static func remove(_ block: TemplateExerciseBlock, from template: WorkoutTemplate) {
        for exercise in template.templateExercises where exercise.executionBlockID == block.id {
            exercise.executionBlockID = nil
            exercise.executionBlockComponentOrder = nil
        }
        template.executionBlocks.removeAll { $0 === block }
        for (index, remaining) in template.orderedExecutionBlocks.enumerated() {
            remaining.orderIndex = index
        }
    }
}
