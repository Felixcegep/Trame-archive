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
                    Button("New Workout Folder", systemImage: "folder.badge.plus") {
                        activeSheet = .workoutCollection
                    }
                    Button("New Workout", systemImage: "square.stack.3d.up.fill") {
                        activeSheet = .workoutTemplate
                    }
                    .accessibilityIdentifier("new-workout-template")
                    Button("New Program", systemImage: AppIcon.planAdd) {
                        activeSheet = .plan
                    }
                    .accessibilityIdentifier("new-plan")
                    Button("Custom Program", systemImage: AppIcon.progression) {
                        activeSheet = .programDefinition
                    }
                    .accessibilityIdentifier("new-program-definition")
                    Button("New Exercise", systemImage: "dumbbell.fill") {
                        activeSheet = .exercise
                    }
                    .accessibilityIdentifier("new-exercise")
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Browse")

            NavigationLink {
                WorkoutsBrowserView(onStartWorkout: onStartWorkout)
            } label: {
                LibraryCategoryRow(
                    title: "Workouts",
                    subtitle: "Saved sessions and workout folders",
                    count: workoutTemplates.count,
                    icon: "list.bullet.rectangle",
                    color: Color.gymPrimary,
                    surface: Color.gymPrimarySurface
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PlansBrowserView(
                    onStartPlannedWorkout: onStartPlannedWorkout,
                    onCreateProgram: { activeSheet = .plan }
                )
            } label: {
                LibraryCategoryRow(
                    title: "Programs",
                    subtitle: "Scheduled multi-week training",
                    count: workoutPlans.filter { !$0.isArchived }.count,
                    icon: AppIcon.plan,
                    color: Color.gymAccent,
                    surface: Color.gymAccentSurface
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans-browser")

            NavigationLink {
                ExerciseBrowserView(onShowArchivedExercises: onShowArchivedExercises)
            } label: {
                LibraryCategoryRow(
                    title: "Exercises",
                    subtitle: "Your complete exercise catalogue",
                    count: exerciseTemplates.count,
                    icon: "dumbbell.fill",
                    color: Color.gymSecondary,
                    surface: Color.gymSecondarySurface
                )
            }
            .buttonStyle(.plain)
        }
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
    case plan(UUID)
}
