import SwiftData
import SwiftUI

struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var programDefinitions: [ProgramDefinitionRecord]

    @State private var activeSheet: FolderSheet?
    @State private var pendingSheet: FolderSheet?
    @State private var isCreateMenuPresented = false
    @State private var searchText = ""
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onShowArchivedExercises: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Train")
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
                Button {
                    isCreateMenuPresented = true
                } label: {
                    Label("Create", systemImage: AppIcon.plus)
                        .font(AppFont.subheadlineSemibold)
                }
                .accessibilityLabel("Create library item")
                .popover(
                    isPresented: $isCreateMenuPresented,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    LibraryCreatePopover { sheet in
                        pendingSheet = sheet
                        isCreateMenuPresented = false
                    }
                    .presentationCompactAdaptation(.popover)
                    .onDisappear(perform: presentPendingSheet)
                }
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
            Image(systemName: AppIcon.search)
                .foregroundStyle(Color.gymSubduedText)
            TextField("Search workouts, plans, exercises", text: $searchText)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("library-search")
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: AppIcon.failureCircle)
                        .foregroundStyle(Color.gymSubtleText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: 46)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            createSection
            browseLibrarySection
            myWorkoutsSection
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Create")

            LibraryGroupCard {
                Button {
                    activeSheet = .workoutTemplate
                } label: {
                    LibraryCreateRow(
                        title: "Build a Workout",
                        subtitle: "One session you can start any time",
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
                        title: "Build a Training Plan",
                        subtitle: "Schedule your workouts across the week",
                        icon: AppIcon.planAdd
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library-new-program")
            }
        }
    }

    private var browseLibrarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Browse")

            LibraryGroupCard {
                if featureFlags.isEnabled(.programBuilder) {
                    NavigationLink {
                        ProgramCatalogView()
                    } label: {
                        LibraryItemRow(
                            title: "Ready-Made Plans",
                            subtitle: "Proven plans — pick one and start",
                            icon: AppIcon.planCatalog,
                            color: Color.gymPrimary,
                            surface: Color.gymPrimarySurface,
                            count: readyMadePlanCount,
                            showsCard: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("program-catalog-browser")

                    LibraryGroupDivider()
                }

                NavigationLink {
                    PlansBrowserView(
                        onStartPlannedWorkout: onStartPlannedWorkout,
                        onCreateProgram: { activeSheet = .plan }
                    )
                } label: {
                    LibraryItemRow(
                        title: "My Plans",
                        subtitle: "Plans you built or started",
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
                    ExerciseBrowserView(onShowArchivedExercises: onShowArchivedExercises)
                } label: {
                    LibraryItemRow(
                        title: "All Exercises",
                        subtitle: "Every move you can add to a workout",
                        icon: "dumbbell.fill",
                        color: Color.gymSecondary,
                        surface: Color.gymSecondarySurface,
                        count: exerciseTemplates.count,
                        showsCard: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exercises-browser")

                if featureFlags.isEnabled(.mobility) {
                    LibraryGroupDivider()

                    NavigationLink(value: LibraryRoute.mobility) {
                        LibraryItemRow(
                            title: "Stretch & Mobility",
                            subtitle: "Warm-ups, cool-downs and recovery",
                            icon: AppIcon.mobility,
                            color: Color.gymSecondary,
                            surface: Color.gymSecondarySurface,
                            showsCard: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("train-mobility-library")
                }
            }
        }
    }

    private var readyMadePlanCount: Int {
        programDefinitions.filter { $0.isBuiltIn && !$0.isArchived }.count
    }

    private var myWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibraryListSectionHeader(title: "My Workouts", count: workoutTemplates.count)

            if sortedCollections.isEmpty && sortedTemplates.isEmpty {
                LibraryGroupCard {
                    Text("No workouts yet — tap Build a Workout above to create your first one.")
                        .font(AppFont.subheadline)
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
                                badge: collection.isBuiltIn ? "Starter" : nil,
                                showsCard: false
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(sortedTemplates.enumerated()), id: \.offset) { index, template in
                        if index > 0 || !sortedCollections.isEmpty {
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
                                icon: "list.bullet.rectangle",
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

    private func presentPendingSheet() {
        guard let pendingSheet else { return }
        self.pendingSheet = nil
        activeSheet = pendingSheet
    }

    @ViewBuilder
    private var globalResults: some View {
        if matchingCollections.isEmpty && matchingTemplates.isEmpty && matchingPlans.isEmpty && matchingExercises.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if !matchingCollections.isEmpty {
                    searchResultsCard(title: "Folders") {
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
                    searchResultsCard(title: "Training Plans") {
                        ForEach(matchingPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                            } label: {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PLAN",
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

private struct LibraryCreatePopover: View {
    let onSelect: (FolderSheet) -> Void

    var body: some View {
        VStack(spacing: 0) {
            group {
                option(
                    title: "New Workout",
                    subtitle: "One session, like Leg Day",
                    systemImage: "list.bullet.rectangle",
                    sheet: .workoutTemplate,
                    accessibilityIdentifier: "new-workout-template"
                )
                option(
                    title: "New Exercise",
                    subtitle: "Add a move you do at the gym",
                    systemImage: "dumbbell.fill",
                    sheet: .exercise,
                    accessibilityIdentifier: "new-exercise"
                )
            }

            Divider()
                .padding(.horizontal, Spacing.l)

            group {
                option(
                    title: "New Training Plan",
                    subtitle: "A weekly schedule of workouts",
                    systemImage: AppIcon.planAdd,
                    sheet: .plan,
                    accessibilityIdentifier: "new-plan"
                )
                option(
                    title: "Plan Builder",
                    subtitle: "Advanced: sets, reps and weight rules",
                    systemImage: AppIcon.progression,
                    sheet: .programDefinition,
                    accessibilityIdentifier: "new-program-definition"
                )
            }

            Divider()
                .padding(.horizontal, Spacing.l)

            option(
                title: "New Folder",
                subtitle: "Group workouts together",
                systemImage: "folder.badge.plus",
                sheet: .workoutCollection
            )
        }
        .padding(.vertical, Spacing.s)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
    }

    private func option(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        sheet: FolderSheet,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        Button {
            onSelect(sheet)
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: systemImage)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Color.gymText)
                    .frame(width: Spacing.xxl)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
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
    case mobility
}
