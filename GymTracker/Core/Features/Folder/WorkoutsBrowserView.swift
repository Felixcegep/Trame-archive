import SwiftData
import SwiftUI

/// Saved workouts and the folders that group them.
///
/// These used to sit inline on the Train root as one flat list, where a folder
/// named "Push / Pull / Legs Split – 3 Days" was indistinguishable from a single
/// workout named "Day 1 – Lower Body" and read like a training plan. Folders are
/// separated out and labelled here so the three concepts stay distinct.
struct WorkoutsBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]

    /// The empty state offers creation, so this screen owns the form rather than
    /// asking the tab root to present it on its behalf.
    @State private var isShowingWorkoutForm = false

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                if sortedCollections.isEmpty && sortedTemplates.isEmpty {
                    emptyState
                } else {
                    if !sortedCollections.isEmpty {
                        foldersSection
                    }
                    if !sortedTemplates.isEmpty {
                        workoutsSection
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
            .padding(.bottom, 104)
        }
        .folderScreenStyle()
        .navigationTitle("Workouts")
        .sheet(isPresented: $isShowingWorkoutForm) {
            NavigationStack {
                WorkoutTemplateFormView(availableExercises: exerciseTemplates) { name, templateExercises in
                    LibraryService.createWorkoutTemplate(name: name, templateExercises: templateExercises, using: modelContext)
                }
            }
        }
    }

    private func createWorkout() {
        isShowingWorkoutForm = true
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No workouts yet", systemImage: AppIcon.routine)
        } description: {
            Text("A workout is one session you can start any time, on its own or as part of a plan.")
        } actions: {
            Button("Build a workout", action: createWorkout)
                .buttonStyle(.borderedProminent)
                .tint(Color.gymPrimary)
                .accessibilityIdentifier("create-workout-empty-state")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "Folders", count: sortedCollections.count)

            LibraryGroupCard {
                ForEach(Array(sortedCollections.enumerated()), id: \.offset) { index, collection in
                    if index > 0 {
                        LibraryGroupDivider()
                    }
                    NavigationLink(value: LibraryRoute.workoutCollection(collection.id)) {
                        LibraryItemRow(
                            title: collection.name,
                            subtitle: workoutCountText(collection.workoutTemplates.count),
                            icon: "rectangle.stack",
                            color: Color.gymAccent,
                            surface: Color.gymAccentSurface,
                            badge: "Folder",
                            showsCard: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workout-collection-\(collection.name)")
                }
            }
        }
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "Workouts", count: sortedTemplates.count)

            LibraryGroupCard {
                ForEach(Array(sortedTemplates.enumerated()), id: \.offset) { index, template in
                    if index > 0 {
                        LibraryGroupDivider()
                    }
                    StartableWorkoutRow(
                        accessibilityName: template.name,
                        isStartDisabled: template.exercises.isEmpty,
                        onStart: { onStartWorkout(template) }
                    ) {
                        LibraryItemRow(
                            title: template.name,
                            subtitle: "\(template.exercises.count) exercises",
                            icon: AppIcon.routine,
                            color: Color.gymPrimary,
                            surface: Color.gymPrimarySurface,
                            badge: template.isBuiltIn ? "Starter" : nil,
                            showsCard: false,
                            showsChevron: false
                        )
                    } editor: {
                        WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                    }
                    .padding(.trailing, Spacing.l - 2)
                }
            }
        }
    }

    private var sortedCollections: [WorkoutCollection] {
        workoutCollections.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var sortedTemplates: [WorkoutTemplate] {
        workoutTemplates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func workoutCountText(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }
}
