import SwiftData
import SwiftUI

struct WorkoutsBrowserView: View {
    @Query private var collections: [WorkoutCollection]
    @Query private var templates: [WorkoutTemplate]
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        LibraryBrowserList(title: "Workouts", searchText: $searchText) {
            LibraryListSectionHeader(title: "Folders", count: filteredCollections.count)
            ForEach(filteredCollections) { collection in
                NavigationLink {
                    WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                } label: {
                    LibraryItemRow(
                        title: collection.name,
                        subtitle: workoutCountText(collection.workoutTemplates.count),
                        icon: "rectangle.stack",
                        color: FolderPalette.accent,
                        surface: FolderPalette.accentSurface
                    )
                }
            }

            LibraryListSectionHeader(title: "All workouts", count: filteredTemplates.count)
            ForEach(filteredTemplates, id: \.self) { template in
                NavigationLink {
                    WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                } label: {
                    LibraryItemRow(
                        title: template.name,
                        subtitle: "\(template.exercises.count) exercises",
                        icon: "list.bullet.rectangle",
                        color: FolderPalette.primary,
                        surface: FolderPalette.primarySurface
                    )
                }
            }
        }
    }

    private var filteredCollections: [WorkoutCollection] {
        collections
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filteredTemplates: [WorkoutTemplate] {
        templates
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func workoutCountText(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }
}
