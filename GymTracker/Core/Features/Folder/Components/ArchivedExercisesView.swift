import SwiftData
import SwiftUI

struct ArchivedExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.isArchived }) private var exercises: [Exercise]
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        exercises
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let results = filteredExercises

        LibraryBrowserList(title: "Hidden Exercises", searchText: $searchText) {
            Text("Hidden exercises stay out of workout and plan pickers. History remains unchanged.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.trameSubdued)
                .padding(.horizontal, Spacing.xxs)

            if results.isEmpty {
                ContentUnavailableView(
                    "No hidden exercises",
                    systemImage: AppIcon.archive,
                    description: Text(searchText.isEmpty ? "Exercises you hide or archive will appear here." : "Try a different search.")
                )
            } else {
                LibraryListSectionHeader(title: "Hidden Exercises", count: results.count)
                ForEach(results, id: \.id) { exercise in
                    HStack(spacing: Spacing.m) {
                        LibraryItemRow(
                            title: exercise.name,
                            subtitle: exercise.isCustom ? "Custom exercise" : "Built-in exercise",
                            icon: "dumbbell.fill",
                            color: Color.trameRecovery,
                            showsChevron: false
                        )
                        Button("Restore") {
                            restore(exercise)
                        }
                        .buttonStyle(.plain)
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameStrength)
                        .frame(minHeight: ComponentSize.minimumTouchTarget)
                        .accessibilityIdentifier("restore-exercise-\(exercise.name)")
                        .padding(.trailing, Spacing.xxs)
                    }
                }
            }
        }
    }

    private func restore(_ exercise: Exercise) {
        do {
            try ExerciseArchiveService.restore(exercise, using: modelContext)
        } catch {
            print("Failed to restore exercise: \(error)")
        }
    }
}
