import SwiftUI

#if !GYMTRACKER_EXTENSION

/// Edits one data-only Program Engine execution block and its occurrence
/// membership. Membership is stored by stable block key; no runtime UUID is
/// created until the recipe compiles.
struct ProgramDefinitionExecutionBlockEditor: View {
    @Binding var block: ProgramExecutionBlockDefinition
    @Binding var plannedExercises: [ProgramExerciseDefinition]
    let catalog: [Exercise]
    let onDelete: () -> Void

    var body: some View {
        DisclosureGroup {
            TextField("Block key", text: $block.blockKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityHint("A stable key used to preserve this block across program weeks")
            TextField("Name (optional)", text: optionalNameBinding)

            Picker("Format", selection: $block.kind) {
                ForEach(ExerciseBlockKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            Text(block.kind.summary)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            if block.kind.supportsRounds {
                TextField("Target rounds (optional)", text: optionalIntBinding(\.targetRounds))
                    .keyboardType(.numberPad)
            }

            Toggle("Use one shared load", isOn: $block.isSharedLoad)
            TextField("Rest after each round (seconds, optional)", text: optionalIntBinding(\.restSeconds))
                .keyboardType(.numberPad)

            Picker("Clock", selection: $block.clockMode) {
                ForEach(BlockClockMode.allCases, id: \.self) { clock in
                    Text(clock.title).tag(clock)
                }
            }
            if block.clockMode == .countdown {
                TextField("Duration (seconds)", text: optionalIntBinding(\.prescribedDurationSeconds))
                    .keyboardType(.numberPad)
            }
            if block.clockMode != .none {
                TextField("Time cap (seconds, optional)", text: optionalIntBinding(\.timeCapSeconds))
                    .keyboardType(.numberPad)
            }
            if block.clockMode == .repeatingInterval {
                TextField("Interval length (seconds)", text: optionalIntBinding(\.intervalSeconds))
                    .keyboardType(.numberPad)
            }

            Picker("Score", selection: $block.scoreKind) {
                ForEach(BlockScoreKind.allCases, id: \.self) { score in
                    Text(score.title).tag(score)
                }
            }

            if block.kind == .ladder {
                Picker("Repetition pattern", selection: $block.repetitionScheme) {
                    Text(BlockRepetitionScheme.ascendingLadder.title)
                        .tag(BlockRepetitionScheme.ascendingLadder)
                    Text(BlockRepetitionScheme.descendingLadder.title)
                        .tag(BlockRepetitionScheme.descendingLadder)
                }
                TextField("Starting repetitions", text: optionalIntBinding(\.repetitionStart))
                    .keyboardType(.numberPad)
                TextField("Ending repetitions", text: optionalIntBinding(\.repetitionEnd))
                    .keyboardType(.numberPad)
                TextField("Step", text: optionalIntBinding(\.repetitionStep))
                    .keyboardType(.numberPad)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Exercise components")
                    .font(AppFont.captionBold)
                Text(block.kind.exerciseSelectionHint)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)

                ForEach(plannedExercises) { exercise in
                    Toggle(isOn: membershipBinding(for: exercise.id)) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(exerciseName(for: exercise))
                                .font(AppFont.body)
                            Text(exercise.exposureKey)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .disabled(isAssignedElsewhere(exercise))
                }
            }

            Button("Delete execution block", role: .destructive, action: onDelete)
        } label: {
            HStack {
                Label(displayName, systemImage: AppIcon.relationship)
                    .font(AppFont.captionBold)
                Spacer()
                Text("\(memberCount) selected")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .onChange(of: block.blockKey) { oldKey, newKey in
            renameMembership(from: oldKey, to: newKey)
        }
        .onChange(of: block.kind) { _, kind in
            applyDefaults(for: kind)
        }
    }

    private var normalizedBlockKey: String {
        block.blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        let name = block.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? block.kind.title : name
    }

    private var memberCount: Int {
        plannedExercises.filter {
            $0.executionBlockKey?.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedBlockKey
        }.count
    }

    private var optionalNameBinding: Binding<String> {
        Binding(
            get: { block.name ?? "" },
            set: { block.name = $0.isEmpty ? nil : $0 }
        )
    }

    private func optionalIntBinding(
        _ keyPath: WritableKeyPath<ProgramExecutionBlockDefinition, Int?>
    ) -> Binding<String> {
        Binding(
            get: { block[keyPath: keyPath].map(String.init) ?? "" },
            set: { block[keyPath: keyPath] = Int($0) }
        )
    }

    private func exerciseName(for exercise: ProgramExerciseDefinition) -> String {
        catalog.first(where: { $0.id == exercise.exerciseID })?.name ?? exercise.exposureKey
    }

    private func isAssignedElsewhere(_ exercise: ProgramExerciseDefinition) -> Bool {
        guard let authoredKey = exercise.executionBlockKey else {
            return false
        }
        let assignedKey = authoredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return assignedKey != normalizedBlockKey
    }

    private func membershipBinding(for exerciseID: UUID) -> Binding<Bool> {
        Binding(
            get: {
                guard let exercise = plannedExercises.first(where: { $0.id == exerciseID }) else {
                    return false
                }
                return exercise.executionBlockKey?.trimmingCharacters(in: .whitespacesAndNewlines)
                    == normalizedBlockKey
            },
            set: { selected in
                guard let exerciseIndex = plannedExercises.firstIndex(where: { $0.id == exerciseID }) else {
                    return
                }
                if selected {
                    guard !normalizedBlockKey.isEmpty else { return }
                    plannedExercises[exerciseIndex].executionBlockKey = normalizedBlockKey
                    plannedExercises[exerciseIndex].executionBlockComponentOrder = memberCount
                } else {
                    plannedExercises[exerciseIndex].executionBlockKey = nil
                    plannedExercises[exerciseIndex].executionBlockComponentOrder = nil
                }
                normalizeMembershipOrder()
            }
        )
    }

    private func renameMembership(from oldKey: String, to newKey: String) {
        let oldKey = oldKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard oldKey != newKey else { return }
        for index in plannedExercises.indices
        where plannedExercises[index].executionBlockKey?.trimmingCharacters(in: .whitespacesAndNewlines) == oldKey {
            plannedExercises[index].executionBlockKey = newKey
        }
    }

    private func normalizeMembershipOrder() {
        let members = plannedExercises.indices
            .filter {
                plannedExercises[$0].executionBlockKey?.trimmingCharacters(in: .whitespacesAndNewlines)
                    == normalizedBlockKey
            }
            .sorted {
                let lhs = plannedExercises[$0].executionBlockComponentOrder ?? .max
                let rhs = plannedExercises[$1].executionBlockComponentOrder ?? .max
                return lhs == rhs ? $0 < $1 : lhs < rhs
            }
        for (componentOrder, exerciseIndex) in members.enumerated() {
            plannedExercises[exerciseIndex].executionBlockComponentOrder = componentOrder
        }
    }

    private func applyDefaults(for kind: ExerciseBlockKind) {
        switch kind {
        case .amrap:
            block.clockMode = .countUp
            block.scoreKind = .roundsAndRepetitions
            block.repetitionScheme = .fixed
        case .emom:
            block.clockMode = .repeatingInterval
            block.intervalSeconds = block.intervalSeconds ?? 60
            block.scoreKind = .completedWork
            block.repetitionScheme = .fixed
        case .forTime:
            block.clockMode = .countUp
            block.scoreKind = .duration
            block.repetitionScheme = .fixed
        case .interval:
            block.clockMode = .repeatingInterval
            block.intervalSeconds = block.intervalSeconds ?? 60
            block.scoreKind = .completedWork
            block.repetitionScheme = .fixed
        case .ladder:
            block.clockMode = .none
            block.scoreKind = .none
            block.repetitionScheme = .ascendingLadder
        case .chipper:
            block.clockMode = .none
            block.scoreKind = .none
            block.repetitionScheme = .chipper
        default:
            block.clockMode = .none
            block.scoreKind = .none
            block.repetitionScheme = .fixed
        }
        if !kind.supportsRounds { block.targetRounds = nil }
        if block.clockMode != .countdown { block.prescribedDurationSeconds = nil }
        if block.clockMode == .none { block.timeCapSeconds = nil }
        if block.clockMode != .repeatingInterval { block.intervalSeconds = nil }
        if block.repetitionScheme == .fixed || block.repetitionScheme == .chipper {
            block.repetitionStart = nil
            block.repetitionEnd = nil
            block.repetitionStep = nil
        }
    }
}

#endif
