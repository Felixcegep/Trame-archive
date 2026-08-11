import SwiftUI

/// Records the result in the block's declared score unit. The stored number is
/// interpreted only through `scoreKind`; no untyped metric bag is introduced.
struct BlockScoreEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var block: WorkoutExecutionBlock
    let onPersist: () -> Void

    @State private var completedRounds: String
    @State private var additionalRepetitions: String
    @State private var scoreValue: String
    @State private var tiebreakValue: String

    init(block: WorkoutExecutionBlock, onPersist: @escaping () -> Void) {
        self.block = block
        self.onPersist = onPersist
        _completedRounds = State(initialValue: String(block.completedRounds))
        _additionalRepetitions = State(initialValue: String(block.additionalRepetitions))
        _scoreValue = State(initialValue: block.scoreValue.map { String($0) } ?? "")
        _tiebreakValue = State(initialValue: block.scoreTiebreakValue.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text(block.scoreKind.title)
                    .font(AppFont.titleSmall)
                    .foregroundStyle(Color.gymText)

                if block.scoreKind == .roundsAndRepetitions {
                    numericField("Completed rounds", text: $completedRounds)
                    numericField("Additional repetitions", text: $additionalRepetitions)
                } else if block.scoreKind != .none {
                    decimalField("Result", text: $scoreValue)
                    decimalField("Tiebreak (optional)", text: $tiebreakValue)
                } else {
                    Text("This block has no primary score. Choose a score type when creating it to record a result here.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymSubduedText)
                }
                Spacer()
            }
            .padding(Spacing.xl)
            .background(Color.gymBackground)
            .navigationTitle("Record Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func numericField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
    }

    private func decimalField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
    }

    private func save() {
        let result: WorkoutMutationResult
        if block.scoreKind == .roundsAndRepetitions {
            result = WorkoutExecutionBlockService.updateScore(
                block,
                completedRounds: Int(completedRounds) ?? 0,
                additionalRepetitions: Int(additionalRepetitions) ?? 0
            )
        } else if block.scoreKind != .none {
            result = WorkoutExecutionBlockService.updateScore(
                block,
                scoreValue: Double(scoreValue),
                scoreTiebreakValue: Double(tiebreakValue)
            )
        } else {
            result = .applied
        }
        guard result.isApplied else { return }
        onPersist()
        dismiss()
    }
}
