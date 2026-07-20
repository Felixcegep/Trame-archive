import SwiftData
import SwiftUI

struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query private var workoutPlans: [WorkoutPlan]

    @State private var activeSheet: FolderSheet?
    @State private var searchText = ""

    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onShowArchivedExercises: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Library")
                    .font(AppFont.displayMedium)
                    .foregroundStyle(Color.gymText)

                searchField

                if searchText.isEmpty {
                    browseSection
                } else {
                    globalResults
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, 104)
        }
        .folderScreenStyle()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section {
                        Button("New Workout", systemImage: "list.bullet.rectangle") {
                            activeSheet = .workoutTemplate
                        }
                        .accessibilityIdentifier("new-workout-template")
                        Button("New Exercise", systemImage: "dumbbell.fill") {
                            activeSheet = .exercise
                        }
                        .accessibilityIdentifier("new-exercise")
                    }
                    Section {
                        Button {
                            activeSheet = .plan
                        } label: {
                            Label("New Program", systemImage: AppIcon.planAdd)
                            Text("Schedule multi-week training")
                        }
                        .accessibilityIdentifier("new-plan")
                        Button {
                            activeSheet = .programDefinition
                        } label: {
                            Label("Program Builder", systemImage: AppIcon.progression)
                            Text("Design a reusable program")
                        }
                        .accessibilityIdentifier("new-program-definition")
                    }
                    Section {
                        Button("New Workout Folder", systemImage: "folder.badge.plus") {
                            activeSheet = .workoutCollection
                        }
                    }
                } label: {
                    Label("Create", systemImage: AppIcon.plus)
                        .font(AppFont.subheadlineSemibold)
                }
                .accessibilityLabel("Create library item")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .workoutCollection:
                    WorkoutCollectionFormView(availableTemplates: workoutTemplates) { name, templates in
                        LibraryService.createWorkoutCollection(name: name, templates: templates, using: modelContext)
                    }
                case .workoutTemplate:
                    WorkoutTemplateFormView(availableExercises: exerciseTemplates) { name, exercises in
                        LibraryService.createWorkoutTemplate(name: name, exercises: exercises, using: modelContext)
                    }
                case .plan:
                    PlanFormView(templates: workoutTemplates) { plan in
                        LibraryService.createPlan(plan, using: modelContext)
                    }
                case .programDefinition:
                    ProgramDefinitionBuilderView(exercises: exerciseTemplates) { payload in
                        _ = try ProgramDefinitionRepository.saveAndCompile(payload, in: modelContext)
                    }
                case .exercise:
                    ExerciseFormView { exercise in
                        LibraryService.createCustomExercise(exercise, using: modelContext)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.gymSubduedText)
            TextField("Search your library", text: $searchText)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("library-search")
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gymSubtleText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 46)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            quickActionsCard
            myWorkoutsSection
        }
    }

    private var quickActionsCard: some View {
        LibraryGroupCard {
            Button {
                activeSheet = .workoutTemplate
            } label: {
                LibraryCreateRow(
                    title: "New Workout…",
                    subtitle: "e.g. Upper Body, Leg Day",
                    icon: AppIcon.plus
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library-new-workout")

            LibraryGroupDivider()

            Button {
                activeSheet = .plan
            } label: {
                LibraryCreateRow(
                    title: "New Program…",
                    subtitle: "Schedule multi-week training",
                    icon: AppIcon.planAdd
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library-new-program")

            LibraryGroupDivider()

            NavigationLink {
                ExerciseBrowserView(onShowArchivedExercises: onShowArchivedExercises)
            } label: {
                LibraryItemRow(
                    title: "My Exercises",
                    subtitle: nil,
                    icon: "dumbbell.fill",
                    color: Color.gymSecondary,
                    surface: Color.gymSecondarySurface,
                    count: exerciseTemplates.count,
                    showsCard: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercises-browser")

            LibraryGroupDivider()

            NavigationLink {
                PlansBrowserView(
                    onStartPlannedWorkout: onStartPlannedWorkout,
                    onCreateProgram: { activeSheet = .plan }
                )
            } label: {
                LibraryItemRow(
                    title: "My Programs",
                    subtitle: nil,
                    icon: AppIcon.plan,
                    color: Color.gymAccent,
                    surface: Color.gymAccentSurface,
                    count: workoutPlans.filter { !$0.isArchived }.count,
                    showsCard: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans-browser")

            LibraryGroupDivider()

            NavigationLink {
                ProgramCatalogView()
            } label: {
                LibraryItemRow(
                    title: "Program Catalog",
                    subtitle: nil,
                    icon: AppIcon.progression,
                    color: Color.gymPrimary,
                    surface: Color.gymPrimarySurface,
                    count: 13,
                    showsCard: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("program-catalog-browser")
        }
    }

    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "My Workouts", count: workoutTemplates.count)

            if sortedCollections.isEmpty && sortedTemplates.isEmpty {
                LibraryGroupCard {
                    Text("No workouts yet — tap New Workout… above to build your first.")
                        .font(.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .padding(Spacing.l)
                }
            } else {
                LibraryGroupCard {
                    ForEach(Array(sortedCollections.enumerated()), id: \.offset) { index, collection in
                        if index > 0 {
                            LibraryGroupDivider()
                        }
                        NavigationLink {
                            WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                        } label: {
                            LibraryItemRow(
                                title: collection.name,
                                subtitle: workoutCountText(collection.workoutTemplates.count),
                                icon: "rectangle.stack",
                                color: Color.gymAccent,
                                surface: Color.gymAccentSurface,
                                showsCard: false
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(sortedTemplates.enumerated()), id: \.offset) { index, template in
                        if index > 0 || !sortedCollections.isEmpty {
                            LibraryGroupDivider()
                        }
                        NavigationLink {
                            WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                        } label: {
                            LibraryItemRow(
                                title: template.name,
                                subtitle: "\(template.exercises.count) exercises",
                                icon: "list.bullet.rectangle",
                                color: Color.gymPrimary,
                                surface: Color.gymPrimarySurface,
                                showsCard: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
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

    @ViewBuilder
    private var globalResults: some View {
        if matchingCollections.isEmpty && matchingTemplates.isEmpty && matchingPlans.isEmpty && matchingExercises.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                if !matchingCollections.isEmpty {
                    searchResultsCard(title: "Workout folders") {
                        ForEach(matchingCollections) { collection in
                            NavigationLink {
                                WorkoutCollectionDetailView(collection: collection, onStartWorkout: onStartWorkout)
                            } label: {
                                RecentLibraryRow(
                                    title: collection.name,
                                    type: "FOLDER",
                                    icon: "rectangle.stack",
                                    color: Color.gymAccent,
                                    surface: Color.gymAccentSurface
                                )
                            }
                        }
                    }
                }
                if !matchingTemplates.isEmpty {
                    searchResultsCard(title: "Workouts") {
                        ForEach(matchingTemplates, id: \.self) { template in
                            NavigationLink {
                                WorkoutTemplateDetailView(template: template, onStartWorkout: onStartWorkout)
                            } label: {
                                RecentLibraryRow(
                                    title: template.name,
                                    type: "WORKOUT",
                                    icon: "list.bullet.rectangle",
                                    color: Color.gymPrimary,
                                    surface: Color.gymPrimarySurface
                                )
                            }
                        }
                    }
                }
                if !matchingPlans.isEmpty {
                    searchResultsCard(title: "Programs") {
                        ForEach(matchingPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                            } label: {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PROGRAM",
                                    icon: AppIcon.plan,
                                    color: Color.gymAccent,
                                    surface: Color.gymAccentSurface
                                )
                            }
                        }
                    }
                }
                if !matchingExercises.isEmpty {
                    searchResultsCard(title: "Exercises") {
                        ForEach(matchingExercises, id: \.self) { exercise in
                            NavigationLink {
                                ExerciseView(exercise: exercise)
                            } label: {
                                RecentLibraryRow(
                                    title: exercise.name,
                                    type: "EXERCISE",
                                    icon: "dumbbell.fill",
                                    color: Color.gymSecondary,
                                    surface: Color.gymSecondarySurface
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func searchResultsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle(title)
            content()
        }
    }

    private var matchingCollections: [WorkoutCollection] {
        workoutCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingTemplates: [WorkoutTemplate] {
        workoutTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingExercises: [Exercise] {
        exerciseTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingPlans: [WorkoutPlan] {
        workoutPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

enum FolderSheet: String, Identifiable {
    case workoutCollection
    case workoutTemplate
    case plan
    case programDefinition
    case exercise

    var id: String { rawValue }
}

enum LibraryRoute: Hashable {
    case archivedExercises
    case exercise(UUID)
    case plan(UUID)
}
