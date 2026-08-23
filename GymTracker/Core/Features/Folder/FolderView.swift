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
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }) private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query(filter: #Predicate<WorkoutPlan> { !$0.isArchived }) private var workoutPlans: [WorkoutPlan]
    @Query(filter: #Predicate<RepeatingPlan> { !$0.isArchived }) private var repeatingPlans: [RepeatingPlan]
    @Query(filter: #Predicate<ProgramDefinitionRecord> { $0.isBuiltIn && !$0.isArchived })
    private var programDefinitions: [ProgramDefinitionRecord]
    @Query(filter: #Predicate<MobilityRoutine> { !$0.isArchived })
    private var mobilityRoutines: [MobilityRoutine]
    @Query(filter: #Predicate<MobilityProgramDefinitionRecord> { !$0.isArchived })
    private var mobilityProgramDefinitions: [MobilityProgramDefinitionRecord]

    @Query private var mobilityAssessmentDefinitions: [MobilityAssessmentDefinition]

    @State private var activeSheet: FolderSheet?
    @State private var pendingSheet: FolderSheet?
    @State private var isCreateMenuPresented = false
    @State private var searchText = ""
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    let onOpenRoute: (LibraryRoute) -> Void
    let onOpenProgramPath: (ProgramPathRoute) -> Void
    let onOpenWeeklyReview: (WeeklyProgramReviewRoute) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onStartFreeWorkout: () -> Void
    let onResumePlan: (PlanRun) -> Void
    let onPauseRepeatingPlan: (RepeatingPlanRun) -> Void
    let onResumeRepeatingPlan: (RepeatingPlanRun) -> Void
    let onEndRepeatingPlan: (RepeatingPlanRun) -> Void

    /// Whether Train assembles itself on this appearance. See `resolveAssembly`.
    @State private var isPlayingAssembly = false

    var body: some View {
        let searchResults = searchText.isEmpty ? nil : makeSearchResults()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                CurrentPlanCard(
                    onOpenPlan: { target in
                        onOpenRoute(target.isRepeating ? .repeatingPlan(target.planID) : .plan(target.planID))
                    },
                    onOpenProgramPath: onOpenProgramPath,
                    onOpenWeeklyReview: onOpenWeeklyReview,
                    onChoosePlan: { onOpenRoute(.plans) },
                    onStartPlannedWorkout: onStartPlannedWorkout,
                    onStartRepeatingWorkout: onStartRepeatingWorkout,
                    onResumePlan: onResumePlan,
                    onPauseRepeatingPlan: onPauseRepeatingPlan,
                    onResumeRepeatingPlan: onResumeRepeatingPlan,
                    onEndRepeatingPlan: onEndRepeatingPlan
                )
                .gymAssembly(index: 0, isActive: isPlayingAssembly)

                searchField
                    .gymAssembly(index: 1, isActive: isPlayingAssembly)

                if searchText.isEmpty {
                    strengthSection
                        .gymAssembly(index: 2, isActive: isPlayingAssembly)

                    if featureFlags.isEnabled(.mobility) {
                        mobilitySection
                            .gymAssembly(index: 3, isActive: isPlayingAssembly)
                    }
                } else if let searchResults {
                    globalResults(searchResults)
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xl)
        }
        .onAppear(perform: resolveAssembly)
        .folderScreenStyle()
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onOpenRoute(.trainingCalendar)
                } label: {
                    Image(systemName: AppIcon.plan)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Training Calendar")
                .accessibilityIdentifier("open-training-calendar")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        activeSheet = .workoutTemplate
                    } label: {
                        Label("New Workout", systemImage: AppIcon.routine)
                    }
                    .accessibilityIdentifier("new-workout-template")

                    Button {
                        activeSheet = .exercise
                    } label: {
                        Label("New Exercise", systemImage: AppIcon.exercise)
                    }
                    .accessibilityIdentifier("new-exercise")

                    Divider()

                    Button {
                        activeSheet = .plan
                    } label: {
                        Label("New Plan", systemImage: AppIcon.planAdd)
                    }
                    .accessibilityIdentifier("new-plan")

                    Button {
                        activeSheet = .programDefinition
                    } label: {
                        Label("Plan Builder", systemImage: AppIcon.progression)
                    }
                    .accessibilityIdentifier("new-program-definition")

                    Divider()

                    Button {
                        activeSheet = .workoutCollection
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.trameText)
                        .frame(
                            width: ComponentSize.minimumTouchTarget,
                            height: ComponentSize.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Create library item")
                .accessibilityIdentifier("library-create")
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
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
            TextField("Search Train", text: $searchText)
                .font(AppFont.bodyMedium)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("library-search")
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: AppIcon.failureCircle)
                        .foregroundStyle(Color.trameSubdued)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.xs)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
        }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameDomainSectionRule(title: "STRENGTH", color: Color.trameStrength)

            VStack(spacing: 0) {
                NavigationLink(value: LibraryRoute.plans) {
                    LibraryItemRow(
                        title: "Plans",
                        icon: AppIcon.plan,
                        color: Color.trameStrength,
                        count: planCount
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plans-browser")

                NavigationLink(value: LibraryRoute.workouts) {
                    LibraryItemRow(
                        title: "Workouts",
                        icon: AppIcon.routine,
                        color: Color.trameStrength,
                        count: workoutTemplates.count
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workouts-browser")

                NavigationLink(value: LibraryRoute.exercises) {
                    LibraryItemRow(
                        title: "Exercises",
                        icon: AppIcon.exercise,
                        color: Color.trameStrength,
                        count: exerciseTemplates.count
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exercises-browser")
            }
        }
    }

    private var mobilitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameDomainSectionRule(title: "MOBILITY", color: Color.trameMobility)

            VStack(spacing: 0) {
                NavigationLink(value: LibraryRoute.mobility) {
                    LibraryItemRow(
                        title: "Routines",
                        icon: AppIcon.mobility,
                        color: Color.trameMobility,
                        count: mobilityRoutines.count
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("train-mobility-library")

                if featureFlags.isEnabled(.mobilityProgram) {
                    NavigationLink(value: LibraryRoute.mobilityPlans) {
                        LibraryItemRow(
                            title: "Plans",
                            icon: AppIcon.plan,
                            color: Color.trameMobility,
                            count: mobilityPlanCount
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mobility-plans-browser")
                }

                if featureFlags.isEnabled(.mobilityAssessment) {
                    NavigationLink(value: LibraryRoute.mobilityAssessments) {
                        LibraryItemRow(
                            title: "Assessments",
                            icon: AppIcon.mobilityAssessment,
                            color: Color.trameMobility,
                            count: mobilityAssessmentCount
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mobility-assessments-browser")
                }
            }
        }
    }

    private var mobilityAssessmentCount: Int {
        mobilityAssessmentDefinitions.isEmpty ? 4 : mobilityAssessmentDefinitions.count
    }

    /// Bundled plus user-authored mobility plans, matching what the Mobility
    /// plans destination actually lists.
    private var mobilityPlanCount: Int {
        mobilityProgramDefinitions.count
    }

    /// Ready-made definitions plus everything the user saved, matching what the
    /// Plans destination actually lists.
    private var planCount: Int {
        readyMadePlanCount
            + workoutPlans.count
            + repeatingPlans.count
    }

    /// Not gated on `.programBuilder`. Bundled plans are shipped *content*, and
    /// hiding them behind an authoring capability also hid the destination that
    /// onboarding's recommendations send people to. See `PlansBrowserView`.
    private var readyMadePlanCount: Int {
        programDefinitions.count
    }

    private func presentPendingSheet() {
        guard let pendingSheet else { return }
        self.pendingSheet = nil
        activeSheet = pendingSheet
    }

    @ViewBuilder
    private func globalResults(_ results: FolderSearchResults) -> some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
        } else {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                if !results.collections.isEmpty {
                    searchResultsCard(title: "Folders") {
                        ForEach(results.collections) { collection in
                            NavigationLink(value: LibraryRoute.workoutCollection(collection.id)) {
                                RecentLibraryRow(
                                    title: collection.name,
                                    type: "FOLDER",
                                    icon: "rectangle.stack",
                                    color: Color.trameCompetition
                                )
                            }
                        }
                    }
                }
                if !results.templates.isEmpty {
                    searchResultsCard(title: "Workouts") {
                        ForEach(results.templates) { template in
                            NavigationLink(value: LibraryRoute.workoutTemplate(template.id)) {
                                RecentLibraryRow(
                                    title: template.name,
                                    type: "WORKOUT",
                                    icon: AppIcon.routine,
                                    color: Color.trameStrength
                                )
                            }
                        }
                    }
                }
                if !results.plans.isEmpty {
                    searchResultsCard(title: "Training Plans") {
                        ForEach(results.plans) { plan in
                            NavigationLink(value: LibraryRoute.plan(plan.id)) {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PLAN",
                                    icon: AppIcon.plan,
                                    color: Color.trameStrength
                                )
                            }
                        }
                    }
                }
                if !results.repeatingPlans.isEmpty {
                    searchResultsCard(title: "Repeating Plans") {
                        ForEach(results.repeatingPlans) { plan in
                            NavigationLink(value: LibraryRoute.repeatingPlan(plan.id)) {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PLAN",
                                    icon: AppIcon.routine,
                                    color: Color.trameStrength
                                )
                            }
                        }
                    }
                }
                if !results.exercises.isEmpty {
                    searchResultsCard(title: "Exercises") {
                        ForEach(results.exercises) { exercise in
                            NavigationLink(value: LibraryRoute.exercise(exercise.id)) {
                                RecentLibraryRow(
                                    title: exercise.name,
                                    type: "EXERCISE",
                                    icon: AppIcon.exercise,
                                    color: Color.trameStrength
                                )
                            }
                        }
                    }
                }
                if !results.mobilityRoutines.isEmpty {
                    searchResultsCard(title: "Mobility Routines") {
                        ForEach(results.mobilityRoutines) { routine in
                            NavigationLink(value: LibraryRoute.mobility) {
                                RecentLibraryRow(
                                    title: routine.name,
                                    type: "ROUTINE",
                                    icon: AppIcon.mobility,
                                    color: Color.trameMobility
                                )
                            }
                        }
                    }
                }
                if !results.mobilityPlans.isEmpty {
                    searchResultsCard(title: "Mobility Plans") {
                        ForEach(results.mobilityPlans) { plan in
                            NavigationLink(value: LibraryRoute.mobilityPlans) {
                                RecentLibraryRow(
                                    title: plan.name,
                                    type: "PLAN",
                                    icon: AppIcon.plan,
                                    color: Color.trameMobility
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

    private func makeSearchResults() -> FolderSearchResults {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return FolderSearchResults(
            collections: workoutCollections.filter { $0.name.localizedCaseInsensitiveContains(query) },
            templates: workoutTemplates.filter { $0.name.localizedCaseInsensitiveContains(query) },
            exercises: exerciseTemplates.filter { $0.name.localizedCaseInsensitiveContains(query) },
            plans: workoutPlans.filter { $0.name.localizedCaseInsensitiveContains(query) },
            repeatingPlans: repeatingPlans.filter { $0.name.localizedCaseInsensitiveContains(query) },
            mobilityRoutines: mobilityRoutines.filter { $0.name.localizedCaseInsensitiveContains(query) },
            mobilityPlans: mobilityProgramDefinitions.filter { $0.name.localizedCaseInsensitiveContains(query) }
        )
    }

    /// Train assembles itself the first time a lifter with no history opens it,
    /// and never again that session.
    private func resolveAssembly() {
        guard (try? modelContext.fetchCount(FetchDescriptor<Workout>())) ?? 0 == 0,
              GymAssemblySession.claim("train")
        else {
            return
        }
        isPlayingAssembly = true
    }
}

private struct FolderSearchResults {
    let collections: [WorkoutCollection]
    let templates: [WorkoutTemplate]
    let exercises: [Exercise]
    let plans: [WorkoutPlan]
    let repeatingPlans: [RepeatingPlan]
    let mobilityRoutines: [MobilityRoutine]
    let mobilityPlans: [MobilityProgramDefinitionRecord]

    var isEmpty: Bool {
        collections.isEmpty && templates.isEmpty && exercises.isEmpty
            && plans.isEmpty && repeatingPlans.isEmpty
            && mobilityRoutines.isEmpty && mobilityPlans.isEmpty
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
    case mobilityPlans
    case mobilityAssessments
    case trainingCalendar
    case archivedExercises
    case readyMadePlan(UUID)
    case plan(UUID)
    case repeatingPlan(UUID)
    case workoutTemplate(UUID)
    case workoutCollection(UUID)
    case exercise(UUID)
    case programPath(ProgramPathRoute)
    case weeklyReview(WeeklyProgramReviewRoute)
}
