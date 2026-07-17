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
        LibraryBrowserList(title: "Hidden Exercises", searchText: $searchText) {
            Text("Hidden exercises stay out of workout and program pickers. History remains unchanged.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
                .padding(.horizontal, Spacing.xxs)

            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    "No hidden exercises",
                    systemImage: AppIcon.archive,
                    description: Text(searchText.isEmpty ? "Exercises you hide or archive will appear here." : "Try a different search.")
                )
            } else {
                LibraryListSectionHeader(title: "Hidden Exercises", count: filteredExercises.count)
                ForEach(filteredExercises, id: \.self) { exercise in
                    HStack(spacing: Spacing.m) {
                        LibraryItemRow(
                            title: exercise.name,
                            subtitle: exercise.isCustom ? "Custom exercise" : "Built-in exercise",
                            icon: "dumbbell.fill",
                            color: Color.gymSecondary,
                            surface: Color.gymSecondarySurface,
                            showsCard: false,
                            showsChevron: false
                        )
                        Button("Restore") {
                            restore(exercise)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gymPrimary)
                        .foregroundStyle(.white)
                        .controlSize(.small)
                        .accessibilityIdentifier("restore-exercise-\(exercise.name)")
                        .padding(.trailing, Spacing.l - 2)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: Radius.large)
                            .fill(Color.gymCard)
                            .stroke(Color.gymBorder, lineWidth: 1)
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
