import SwiftUI
import SwiftData

/// Authoring surface for a snapshot-local execution block. It deliberately
/// records typed configuration instead of deriving a workout format from a
/// free-form note, so the result remains comparable in history and analytics.
struct WorkoutExecutionBlockBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    let blockToEdit: WorkoutExecutionBlock?
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
    @State private var validationMessage: String?

    init(
        workout: Workout,
        blockToEdit: WorkoutExecutionBlock? = nil,
        onPersist: @escaping () -> Void
    ) {
        self.workout = workout
        self.blockToEdit = blockToEdit
        self.onPersist = onPersist

        _kind = State(initialValue: blockToEdit?.kind ?? .circuit)
        _selectedEntryIDs = State(initialValue: Set(workout.orderedExercises
            .filter { $0.executionBlockID == blockToEdit?.id }
            .map(\.persistentModelID)))
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
    }

    private var availableEntries: [ExerciseEntry] {
        workout.orderedExercises.filter {
            $0.executionBlockID == nil || $0.executionBlockID == blockToEdit?.id
        }
    }

    private var selectedEntries: [ExerciseEntry] {
        availableEntries.filter { selectedEntryIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    configurationSection
                    exerciseSelectionSection

                    if let validationMessage {
                        Label(validationMessage, systemImage: AppIcon.info)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymDestructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.m)
                            .background(Color.gymDestructive.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                            .accessibilityIdentifier("execution-block-validation")
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.gymBackground)
            .navigationTitle("Execution Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(blockToEdit == nil ? "Add block" : "Save", action: saveBlock)
                        .disabled(selectedEntries.isEmpty)
                        .accessibilityIdentifier("create-execution-block")
                }
            }
        }
        .onChange(of: kind) { _, newKind in
            applyFormatDefaults(for: newKind)
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionTitle("FORMAT", detail: "Defines the shared execution and score")

            Picker("Format", selection: $kind) {
                ForEach(ExerciseBlockKind.allCases, id: \.self) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.menu)

            TextField("Optional block name", text: $name)
                .textFieldStyle(.roundedBorder)

            if supportsRounds {
                numericField("Target rounds (optional)", text: $targetRounds)
            }

            if kind == .ladder {
                Picker("Repetition pattern", selection: $repetitionScheme) {
                    Text(BlockRepetitionScheme.ascendingLadder.title).tag(BlockRepetitionScheme.ascendingLadder)
                    Text(BlockRepetitionScheme.descendingLadder.title).tag(BlockRepetitionScheme.descendingLadder)
                }
                .pickerStyle(.menu)
                numericField("Starting repetitions", text: $repetitionStart)
                numericField("Ending repetitions", text: $repetitionEnd)
                numericField("Step", text: $repetitionStep)
            }

            Toggle("Use a shared load", isOn: $isSharedLoad)
            numericField("Rest after each round (seconds, optional)", text: $restSeconds)

            Picker("Clock", selection: $clockMode) {
                ForEach(BlockClockMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            if clockMode == .countdown {
                numericField("Duration (minutes)", text: $durationMinutes)
            }
            if clockMode != .none {
                numericField("Time cap (minutes, optional)", text: $timeCapMinutes)
            }
            if clockMode == .repeatingInterval {
                numericField("Interval (seconds)", text: $intervalSeconds)
            }

            Picker("Primary score", selection: $scoreKind) {
                ForEach(BlockScoreKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(Spacing.l)
        .background(Color.gymCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var exerciseSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionTitle("EXERCISES", detail: selectionHint)

            if availableEntries.isEmpty {
                Text("All session exercises already belong to a block.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
            } else {
                ForEach(availableEntries, id: \.persistentModelID) { entry in
                    Button {
                        toggle(entry)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: selectedEntryIDs.contains(entry.persistentModelID) ? AppIcon.checkmarkCircle : AppIcon.circle)
                                .foregroundStyle(selectedEntryIDs.contains(entry.persistentModelID) ? Color.gymPrimary : Color.gymSubduedText)
                            Text(entry.nameSnapshot)
                                .font(AppFont.body)
                                .foregroundStyle(Color.gymText)
                            Spacer(minLength: 0)
                        }
                        .padding(Spacing.m)
                        .background(Color.gymCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(selectedEntryIDs.contains(entry.persistentModelID) ? "Remove" : "Add") \(entry.nameSnapshot)")
                }
            }
        }
    }

    private var supportsRounds: Bool {
        switch kind {
        case .pairedSet, .triset, .giantSet, .circuit, .olympicComplex, .ladder, .interval, .medley:
            true
        case .straight, .amrap, .emom, .forTime, .chipper:
            false
        }
    }

    private var selectionHint: String {
        switch kind {
        case .pairedSet: "Choose exactly two exercises"
        case .triset: "Choose exactly three exercises"
        case .giantSet: "Choose four or more exercises"
        case .straight: "Choose one exercise"
        default: "Choose the exercises that belong to this block"
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)
            Text(detail)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func numericField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
    }

    private func toggle(_ entry: ExerciseEntry) {
        if selectedEntryIDs.contains(entry.persistentModelID) {
            selectedEntryIDs.remove(entry.persistentModelID)
        } else {
            selectedEntryIDs.insert(entry.persistentModelID)
        }
    }

    private func applyFormatDefaults(for kind: ExerciseBlockKind) {
        switch kind {
        case .amrap:
            clockMode = .countUp
            scoreKind = .roundsAndRepetitions
        case .emom:
            clockMode = .repeatingInterval
            intervalSeconds = intervalSeconds.isEmpty ? "60" : intervalSeconds
            scoreKind = .completedWork
        case .forTime:
            clockMode = .countUp
            scoreKind = .duration
        case .interval:
            clockMode = .repeatingInterval
            scoreKind = .completedWork
        case .ladder:
            repetitionScheme = .ascendingLadder
        case .chipper:
            repetitionScheme = .chipper
        default:
            repetitionScheme = .fixed
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
