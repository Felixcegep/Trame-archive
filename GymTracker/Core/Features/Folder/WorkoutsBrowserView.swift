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

    /// The empty state offers creation, so this screen owns the form rather than
    /// asking the tab root to present it on its behalf.
    @State private var isShowingWorkoutForm = false
    /// Every bundled workout template comes from the seeded catalogue, so an
    /// empty list on first launch is not automatically "nobody has built one
    /// yet" — see `SystemCatalogInstallState`.
    @State private var catalogInstallState = SystemCatalogInstallState.shared

    let onStartWorkout: (WorkoutTemplate) -> Void

    var body: some View {
        // Both the empty-state check and the two sections need these ordered
        // collections. Compute them once per query update rather than sorting
        // the same library again for every branch of the view tree.
        let collections = sortedCollections
        let templates = sortedTemplates

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                if collections.isEmpty && templates.isEmpty {
                    if catalogInstallState.failure != nil {
                        SystemCatalogUnavailableView {
                            AppBootstrap.seedSystemCatalog(using: modelContext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 56)
                    } else {
                        emptyState
                    }
                } else {
                    if !collections.isEmpty {
                        foldersSection(collections)
                    }
                    if !templates.isEmpty {
                        workoutsSection(templates)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.l)
            .padding(.bottom, 104)
        }
        .folderScreenStyle()
        .navigationTitle("Workouts")
        .sheet(isPresented: $isShowingWorkoutForm) {
            NavigationStack {
                WorkoutTemplateFormView { name, templateExercises, preWorkout, postWorkout in
                    LibraryService.createWorkoutTemplate(
                        name: name,
                        templateExercises: templateExercises,
                        preWorkoutMobilityRoutine: preWorkout,
                        postWorkoutMobilityRoutine: postWorkout,
                        using: modelContext
                    )
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
                .buttonStyle(.tramePrimaryAction)
                .accessibilityIdentifier("create-workout-empty-state")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
    }

    private func foldersSection(_ collections: [WorkoutCollection]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "Folders", count: collections.count)

            LibraryOpenGroup {
                ForEach(collections) { collection in
                    NavigationLink(value: LibraryRoute.workoutCollection(collection.id)) {
                        LibraryItemRow(
                            title: collection.name,
                            subtitle: workoutCountText(collection.workoutTemplates.count),
                            icon: "rectangle.stack",
                            badge: "Folder"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workout-collection-\(collection.name)")
                }
            }
        }
    }

    private func workoutsSection(_ templates: [WorkoutTemplate]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "Saved", count: templates.count)

            LibraryOpenGroup {
                ForEach(templates) { template in
                    StartableWorkoutRow(
                        accessibilityName: template.name,
                        isStartDisabled: template.exercises.isEmpty,
                        onStart: { onStartWorkout(template) }
                    ) {
                        LibraryItemRow(
                            title: template.name,
                            subtitle: "\(template.exercises.count) exercises",
                            icon: AppIcon.routine,
                            badge: template.isBuiltIn ? "Starter" : nil,
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
        workoutTemplates
            .filter { !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func workoutCountText(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }
}
