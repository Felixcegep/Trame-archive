import SwiftUI
import SwiftData

/// Maintains deliberate exercise-to-exercise relationships. A relationship is
/// directional for progression/regression; substitution is treated as usable
/// in either direction by the active-workout picker.
struct ExerciseRelationshipEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [ExerciseRelationship]

    let exercise: Exercise

    @State private var isChoosingRelationshipType = false
    @State private var relationshipTypeToAdd: ExerciseRelationshipType?

    private var outgoingRelationships: [ExerciseRelationship] {
        relationships
            .filter { $0.sourceExercise?.id == exercise.id }
            .sorted { lhs, rhs in
                let typeOrder = lhs.type.rawValue.localizedCaseInsensitiveCompare(rhs.type.rawValue)
                if typeOrder != .orderedSame { return typeOrder == .orderedAscending }
                return (lhs.targetExercise?.name ?? "").localizedCaseInsensitiveCompare(rhs.targetExercise?.name ?? "") == .orderedAscending
            }
    }

    var body: some View {
        List {
            if outgoingRelationships.isEmpty {
                ContentUnavailableView(
                    "No relationships yet",
                    systemImage: AppIcon.relationship,
                    description: Text("Add substitutions, progressions, or regressions for \(exercise.name).")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("From \(exercise.name)") {
                    ForEach(outgoingRelationships, id: \.persistentModelID) { relationship in
                        relationshipRow(relationship)
                    }
                    .onDelete(perform: deleteRelationships)
                }
            }
        }
        .navigationTitle("Exercise Relationships")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isChoosingRelationshipType = true
                } label: {
                    Image(systemName: AppIcon.plus)
                }
                .accessibilityLabel("Add exercise relationship")
            }
        }
        .confirmationDialog(
            "Choose relationship type",
            isPresented: $isChoosingRelationshipType,
            titleVisibility: .visible
        ) {
            ForEach(ExerciseRelationshipType.allCases) { type in
                Button(type.actionTitle) {
                    relationshipTypeToAdd = type
                }
            }
        } message: {
            Text("Substitutions can be swapped during an unstarted exercise. Progressions and regressions document the library relationship.")
        }
        .sheet(item: $relationshipTypeToAdd) { type in
            NavigationStack {
                ExerciseRelationshipCandidatePicker(
                    sourceExercise: exercise,
                    relationshipType: type,
                    existingRelationships: outgoingRelationships
                ) { target in
                    modelContext.insert(ExerciseRelationship(
                        sourceExercise: exercise,
                        targetExercise: target,
                        type: type
                    ))
                    saveChanges()
                }
            }
        }
    }

    private func relationshipRow(_ relationship: ExerciseRelationship) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(relationship.targetExercise?.name ?? "Unavailable exercise")
                .font(AppFont.bodyMedium)
                .foregroundStyle(Color.gymText)
            Text(relationship.type.rawValue)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func deleteRelationships(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(outgoingRelationships[index])
        }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save exercise relationship: \(error)")
        }
    }
}

private struct ExerciseRelationshipCandidatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]

    let sourceExercise: Exercise
    let relationshipType: ExerciseRelationshipType
    let existingRelationships: [ExerciseRelationship]
    let onSelect: (Exercise) -> Void

    private var candidates: [Exercise] {
        let existingTargetIDs = Set(
            existingRelationships
                .filter { $0.type == relationshipType }
                .compactMap { $0.targetExercise?.id }
        )
        return exercises
            .filter { $0.id != sourceExercise.id && !existingTargetIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(candidates, id: \.persistentModelID) { candidate in
            Button {
                onSelect(candidate)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(candidate.name)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.gymText)
                    Text(candidate.subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
            .accessibilityIdentifier("relationship-candidate-\(candidate.name)")
        }
        .navigationTitle("Add \(relationshipType.actionTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
