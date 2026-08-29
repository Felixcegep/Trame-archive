import SwiftUI

/// Draft-only plan authoring for a within-workout execution block. The draft
/// is committed with the rest of the plan, so Cancel never mutates an active
/// prescription.
struct PlanExecutionBlockBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var workout: PlanWorkoutDraft
    let editingBlockID: UUID?

    @State private var kind: ExerciseBlockKind = .circuit
    @State private var selectedExerciseIDs: Set<UUID> = []
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

    init(workout: Binding<PlanWorkoutDraft>, editingBlockID: UUID? = nil) {
        _workout = workout
        self.editingBlockID = editingBlockID
        let block = workout.wrappedValue.executionBlocks.first { $0.id == editingBlockID }

        _kind = State(initialValue: block?.kind ?? .circuit)
        // A new block starts empty; only an existing block pre-fills its
        // members. Filtering by a nil id would pre-select every unassigned
        // exercise.
        _selectedExerciseIDs = State(initialValue: editingBlockID == nil ? [] : Set(workout.wrappedValue.exercises
            .filter { $0.executionBlockID == editingBlockID }
            .map(\.id)))
        _name = State(initialValue: block?.name ?? "")
        _targetRounds = State(initialValue: block?.targetRounds.map(String.init) ?? "")
        _isSharedLoad = State(initialValue: block?.isSharedLoad ?? false)
        _restSeconds = State(initialValue: block?.restSeconds.map(String.init) ?? "")
        _clockMode = State(initialValue: block?.clockMode ?? .none)
        _durationMinutes = State(initialValue: block?.prescribedDurationSeconds.map { String($0 / 60) } ?? "")
        _timeCapMinutes = State(initialValue: block?.timeCapSeconds.map { String($0 / 60) } ?? "")
        _intervalSeconds = State(initialValue: block?.intervalSeconds.map(String.init) ?? "")
        _scoreKind = State(initialValue: block?.scoreKind ?? .none)
        _repetitionScheme = State(initialValue: block?.repetitionScheme ?? .fixed)
        _repetitionStart = State(initialValue: block?.repetitionStart.map(String.init) ?? "")
        _repetitionEnd = State(initialValue: block?.repetitionEnd.map(String.init) ?? "")
        _repetitionStep = State(initialValue: block?.repetitionStep.map(String.init) ?? "")
    }

    private var availableExercises: [PlanExerciseDraft] {
        workout.exercises.filter { $0.executionBlockID == nil || $0.executionBlockID == editingBlockID }
    }

    private var selectedExercises: [PlanExerciseDraft] {
        availableExercises.filter { selectedExerciseIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $kind) {
                        ForEach(ExerciseBlockKind.allCases, id: \.self) { format in
                            Text(format.title).tag(format)
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
                    TrameDomainSectionRule(title: "Format", color: Color.trameCompetition)
                } footer: {
                    Text(kind.summary)
                }

                Section {
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
                } header: {
                    TrameDomainSectionRule(title: "Advanced options", color: Color.trameAttention)
                }

                Section {
                    Text(kind.exerciseSelectionHint)
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                    ForEach(availableExercises) { exercise in
                        Button {
                            if selectedExerciseIDs.contains(exercise.id) {
                                selectedExerciseIDs.remove(exercise.id)
                            } else {
                                selectedExerciseIDs.insert(exercise.id)
                            }
                        } label: {
                            HStack {
                                Text(exercise.displayName)
                                Spacer()
                                Image(systemName: selectedExerciseIDs.contains(exercise.id) ? AppIcon.checkmarkCircle : AppIcon.circle)
                                    .foregroundStyle(Color.trameActionDeep)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    TrameDomainSectionRule(title: "Exercises", color: Color.trameStrength)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Color.trameDestructiveText)
                    } header: {
                        TrameDomainSectionRule(title: "Needs attention", color: Color.trameAttention)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .navigationTitle("Execution Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingBlockID == nil ? "Add" : "Save", action: save)
                        .disabled(selectedExercises.isEmpty)
                }
            }
        }
        .onChange(of: kind) { _, kind in applyDefaults(for: kind) }
    }

    private func applyDefaults(for kind: ExerciseBlockKind) {
        switch kind {
        case .amrap: clockMode = .countUp; scoreKind = .roundsAndRepetitions; repetitionScheme = .fixed
        case .emom: clockMode = .repeatingInterval; intervalSeconds = intervalSeconds.isEmpty ? "60" : intervalSeconds; scoreKind = .completedWork; repetitionScheme = .fixed
        case .forTime: clockMode = .countUp; scoreKind = .duration; repetitionScheme = .fixed
        case .interval: clockMode = .repeatingInterval; scoreKind = .completedWork; repetitionScheme = .fixed
        case .ladder: repetitionScheme = .ascendingLadder; clockMode = .none; scoreKind = .none
        case .chipper: repetitionScheme = .chipper; clockMode = .none; scoreKind = .none
        default: repetitionScheme = .fixed; clockMode = .none; scoreKind = .none
        }
    }

    private func save() {
        guard validComponentCount else {
            errorMessage = kind.exerciseSelectionHint
            return
        }
        if let message = ExecutionBlockConfigurationValidator.message(
            kind: kind,
            clockMode: clockMode,
            prescribedDurationSeconds: Int(durationMinutes).map { $0 * 60 },
            timeCapSeconds: Int(timeCapMinutes).map { $0 * 60 },
            intervalSeconds: Int(intervalSeconds),
            repetitionScheme: repetitionScheme,
            repetitionStart: Int(repetitionStart),
            repetitionEnd: Int(repetitionEnd),
            repetitionStep: Int(repetitionStep)
        ) {
            errorMessage = message
            return
        }
        guard Int(targetRounds).map({ $0 > 0 }) ?? true,
              Int(restSeconds).map({ $0 >= 0 }) ?? true else {
            errorMessage = "Rounds and rest must be valid positive values."
            return
        }

        let block: PlanExecutionBlockDraft
        if let editingBlockID,
           let blockIndex = workout.executionBlocks.firstIndex(where: { $0.id == editingBlockID }) {
            var existing = workout.executionBlocks[blockIndex]
            existing.kind = kind
            existing.name = name
            existing.targetRounds = Int(targetRounds)
            existing.isSharedLoad = isSharedLoad
            existing.restSeconds = Int(restSeconds)
            existing.clockMode = clockMode
            existing.prescribedDurationSeconds = Int(durationMinutes).map { $0 * 60 }
            existing.timeCapSeconds = Int(timeCapMinutes).map { $0 * 60 }
            existing.intervalSeconds = Int(intervalSeconds)
            existing.scoreKind = scoreKind
            existing.repetitionScheme = repetitionScheme
            existing.repetitionStart = Int(repetitionStart)
            existing.repetitionEnd = Int(repetitionEnd)
            existing.repetitionStep = Int(repetitionStep)
            workout.executionBlocks[blockIndex] = existing
            block = existing
        } else {
            let created = PlanExecutionBlockDraft(
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
            workout.executionBlocks.append(created)
            block = created
        }

        for index in workout.exercises.indices where workout.exercises[index].executionBlockID == block.id {
            workout.exercises[index].executionBlockID = nil
            workout.exercises[index].executionBlockComponentOrder = nil
        }
        for (index, exerciseID) in selectedExercises.map(\.id).enumerated() {
            guard let exerciseIndex = workout.exercises.firstIndex(where: { $0.id == exerciseID }) else { continue }
            workout.exercises[exerciseIndex].executionBlockID = block.id
            workout.exercises[exerciseIndex].executionBlockComponentOrder = index
        }
        dismiss()
    }

    private var validComponentCount: Bool {
        switch kind {
        case .pairedSet: selectedExercises.count == 2
        case .triset: selectedExercises.count == 3
        case .giantSet: selectedExercises.count >= 4
        case .straight: selectedExercises.count == 1
        default: !selectedExercises.isEmpty
        }
    }
}
