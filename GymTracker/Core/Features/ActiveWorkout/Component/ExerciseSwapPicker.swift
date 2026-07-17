import SwiftUI
import SwiftData

/// Presents only explicit substitution relationships. Similar exercises in a
/// variation family are intentionally not offered here unless the user adds a
/// substitution relationship in the exercise library.
struct ExerciseSwapPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var relationships: [ExerciseRelationship]

    let exerciseEntry: ExerciseEntry
    let onSelect: (Exercise) -> Void

    private var substitutions: [Exercise] {
        var seen = Set<PersistentIdentifier>()
        return relationships.compactMap { relationship in
            guard relationship.type == .substitution else { return nil }

            if relationship.sourceExercise?.id == exerciseEntry.exercise.id {
                return relationship.targetExercise
            }
            if relationship.targetExercise?.id == exerciseEntry.exercise.id {
                return relationship.sourceExercise
            }
            return nil
        }
        .filter { !$0.isArchived && seen.insert($0.persistentModelID).inserted }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if substitutions.isEmpty {
                ContentUnavailableView(
                    "No substitutions configured",
                    systemImage: AppIcon.relationship,
                    description: Text("Add a substitution relationship from this exercise’s details before starting the swap.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(substitutions, id: \.persistentModelID) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(exercise.name)
                                    .font(AppFont.bodyMedium)
                                    .foregroundStyle(Color.gymText)
                                Text(exercise.subtitle)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityIdentifier("swap-option-\(exercise.name)")
                    }
                } header: {
                    Text("Substitute \(exerciseEntry.nameSnapshot) with")
                } footer: {
                    Text("The current uncompleted sets will be reset for the replacement exercise. Your prescription stays in place.")
                }
            }
        }
        .navigationTitle("Swap Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}
