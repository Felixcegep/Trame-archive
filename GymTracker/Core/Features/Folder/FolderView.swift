import SwiftData
import SwiftUI

/// The Train tab root: what you are following, and four doors to what you own.
///
/// This screen used to stack a CREATE card (duplicating the `+` button), a
/// five-row BROWSE list that gave "Ready-Made Plans", "My Plans" and "Rotations"
/// equal billing as three separate ways to do one job, and every saved workout
/// inline below. Plans are now one door, saved workouts live behind another, and
/// creation happens in exactly one place.
struct FolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutCollections: [WorkoutCollection]
    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var repeatingPlans: [RepeatingPlan]
    @Query private var programDefinitions: [ProgramDefinitionRecord]

    @State private var activeSheet: FolderSheet?
    @State private var pendingSheet: FolderSheet?
    @State private var isCreateMenuPresented = false
    @State private var searchText = ""
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    let onOpenRoute: (LibraryRoute) -> Void
    let onOpenProgramPath: (ProgramPathRoute) -> Void
    let onResumePlan: (PlanRun) -> Void
    let onPauseRepeatingPlan: (RepeatingPlanRun) -> Void
    let onResumeRepeatingPlan: (RepeatingPlanRun) -> Void
    let onEndRepeatingPlan: (RepeatingPlanRun) -> Void

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
                .accessibilityIdentifier("library-create")
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
                    WorkoutTemplateFormView(availableExercises: exerciseTemplates) { name, templateExercises in
                        LibraryService.createWorkoutTemplate(name: name, templateExercises: templateExercises, using: modelContext)
                    }
                case .plan:
                    PlanFormView(
                        templates: workoutTemplates,
                        onSave: { LibraryService.createPlan($0, using: modelContext) },
                        onSaveRepeating: { LibraryService.createRepeatingPlan($0, using: modelContext) }
                    )
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
            CurrentPlanCard(
                onOpenPlan: { target in
                    onOpenRoute(target.isRepeating ? .repeatingPlan(target.planID) : .plan(target.planID))
                },
                onOpenProgramPath: onOpenProgramPath,
                onChoosePlan: { onOpenRoute(.plans) },
                onResumePlan: onResumePlan,
                onPauseRepeatingPlan: onPauseRepeatingPlan,
                onResumeRepeatingPlan: onResumeRepeatingPlan,
                onEndRepeatingPlan: onEndRepeatingPlan
            )
            librarySection
        }
    }

    /// Four rows, one noun each. Plans covers ready-made, saved and repeating
    /// plans alike, so "which of these three is a plan?" stops being a question
    /// the user has to answer before they can start.
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Library")

            LibraryGroupCard {
                NavigationLink(value: LibraryRoute.plans) {
                    LibraryItemRow(
                        title: "Plans",
                        subtitle: "Ready-made, yours, and what you follow",
                        icon: AppIcon.plan,
                        color: Color.gymAccent,
                        surface: Color.gymAccentSurface,
                        count: planCount,
                        showsCard: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plans-browser")

                LibraryGroupDivider()

                NavigationLink(value: LibraryRoute.workouts) {
                    LibraryItemRow(
                        title: "Workouts",
                        subtitle: "Single sessions you can start any time",
                        icon: AppIcon.routine,
                        color: Color.gymPrimary,
                        surface: Color.gymPrimarySurface,
                        count: workoutTemplates.count,
                        showsCard: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workouts-browser")

                LibraryGroupDivider()

                NavigationLink(value: LibraryRoute.exercises) {
                    LibraryItemRow(
                        title: "Exercises",
                        subtitle: "Every move you can add to a workout",
                        icon: AppIcon.workout,
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

    /// Ready-made definitions plus everything the user saved, matching what the
    /// Plans destination actually lists.
    private var planCount: Int {
        readyMadePlanCount
            + workoutPlans.filter { !$0.isArchived }.count
            + repeatingPlans.filter { !$0.isArchived }.count
    }

    private var readyMadePlanCount: Int {
        guard featureFlags.isEnabled(.programBuilder) else { return 0 }
        return programDefinitions.filter { $0.isBuiltIn && !$0.isArchived }.count
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
                            NavigationLink(value: LibraryRoute.workoutCollection(collection.id)) {
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
                        ForEach(matchingTemplates) { template in
                            NavigationLink(value: LibraryRoute.workoutTemplate(template.id)) {
                                RecentLibraryRow(
                                    title: template.name,
                                    type: "WORKOUT",
                                    icon: AppIcon.routine,
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
                            NavigationLink(value: LibraryRoute.plan(plan.id)) {
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
                if !matchingRepeatingPlans.isEmpty {
                    searchResultsCard(title: "Repeating Plans") {
                        ForEach(matchingRepeatingPlans) { plan in
                            NavigationLink(value: LibraryRoute.repeatingPlan(plan.id)) {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PLAN",
                                    icon: AppIcon.routine,
                                    color: Color.gymAccent,
                                    surface: Color.gymAccentSurface
                                )
                            }
                        }
                    }
                }
                if !matchingExercises.isEmpty {
                    searchResultsCard(title: "Exercises") {
                        ForEach(matchingExercises) { exercise in
                            NavigationLink(value: LibraryRoute.exercise(exercise.id)) {
                                RecentLibraryRow(
                                    title: exercise.name,
                                    type: "EXERCISE",
                                    icon: AppIcon.workout,
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

    private var matchingRepeatingPlans: [RepeatingPlan] {
        repeatingPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                    systemImage: AppIcon.routine,
                    sheet: .workoutTemplate,
                    accessibilityIdentifier: "new-workout-template"
                )
                option(
                    title: "New Exercise",
                    subtitle: "Add a move you do at the gym",
                    systemImage: AppIcon.workout,
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

/// Every Train destination is path-driven so screens deeper in the stack can pop
/// back to the root — activating a ready-made plan, for one, has to land the
/// user somewhere that shows the plan is now running.
enum LibraryRoute: Hashable {
    case plans
    case workouts
    case exercises
    case mobility
    case archivedExercises
    case readyMadePlan(UUID)
    case plan(UUID)
    case repeatingPlan(UUID)
    case workoutTemplate(UUID)
    case workoutCollection(UUID)
    case exercise(UUID)
    case programPath(ProgramPathRoute)
}
