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
                Text("Train")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(Color.trameText)
                    .gymAssembly(index: 0, isActive: isPlayingAssembly)

                searchField
                    .gymAssembly(index: 1, isActive: isPlayingAssembly)

                if searchText.isEmpty {
                    browseSection
                } else if let searchResults {
                    globalResults(searchResults)
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.s)
            .padding(.bottom, 96)
        }
        .onAppear(perform: resolveAssembly)
        .folderScreenStyle()
        // The tab is "Train". This was empty, so the screen had no name, pushed
        // screens' back buttons read "Back" instead of naming the parent, and
        // the first heading in the content said "Library" — three different
        // answers to what this tab is called, left over from a half-finished
        // rename.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreateMenuPresented = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
            TextField("Search", text: $searchText)
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
        .padding(.horizontal, Spacing.m)
        .frame(height: 46)
        .background(Color.trameSurface, in: RoundedRectangle(cornerRadius: Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.field)
                .stroke(Color.trameSeparator, lineWidth: 1)
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
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
            .gymAssembly(index: 2, isActive: isPlayingAssembly)

            studioGrid
                .gymAssembly(index: 3, isActive: isPlayingAssembly)
        }
    }

    private var studioGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            TrameSectionRule(title: "Studio")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.m),
                    GridItem(.flexible(), spacing: Spacing.m)
                ],
                spacing: Spacing.m
            ) {
                NavigationLink(value: LibraryRoute.plans) {
                    StudioCategoryTile(
                        title: "Plans",
                        count: planCount,
                        icon: AppIcon.plan,
                        color: Color.trameCompetition,
                        subtitle: "Programs",
                        accessibilityIdentifier: "plans-browser"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: LibraryRoute.workouts) {
                    StudioCategoryTile(
                        title: "Workouts",
                        count: workoutTemplates.count,
                        icon: AppIcon.routine,
                        color: Color.trameStrength,
                        subtitle: "Routines",
                        accessibilityIdentifier: "workouts-browser"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: LibraryRoute.exercises) {
                    StudioCategoryTile(
                        title: "Exercises",
                        count: exerciseTemplates.count,
                        icon: AppIcon.workout,
                        color: Color.trameStrength,
                        subtitle: "Movements",
                        accessibilityIdentifier: "exercises-browser"
                    )
                }
                .buttonStyle(.plain)

                if featureFlags.isEnabled(.mobility) {
                    NavigationLink(value: LibraryRoute.mobility) {
                        StudioCategoryTile(
                            title: "Mobility",
                            count: mobilityRoutines.count,
                            icon: AppIcon.mobility,
                            color: Color.trameMobility,
                            subtitle: "Flows",
                            accessibilityIdentifier: "train-mobility-library"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if featureFlags.isEnabled(.mobilityProgram) {
                    NavigationLink(value: LibraryRoute.mobilityPlans) {
                        StudioCategoryTile(
                            title: "Mobility Plans",
                            count: mobilityPlanCount,
                            icon: AppIcon.plan,
                            color: Color.trameRecovery,
                            subtitle: "Guided",
                            accessibilityIdentifier: "mobility-plans-browser"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if featureFlags.isEnabled(.mobilityAssessment) {
                    NavigationLink(value: LibraryRoute.mobilityAssessments) {
                        StudioCategoryTile(
                            title: "Assessments",
                            count: nil,
                            icon: AppIcon.mobilityAssessment,
                            color: Color.trameMobility,
                            subtitle: "Screens",
                            accessibilityIdentifier: "mobility-assessments-browser"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                                    color: Color.trameCompetition
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
                                    color: Color.trameCompetition
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
                                    icon: AppIcon.workout,
                                    color: Color.trameStrength
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
        FolderSearchResults(
            collections: workoutCollections.filter { $0.name.localizedCaseInsensitiveContains(searchText) },
            templates: workoutTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) },
            exercises: exerciseTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) },
            plans: workoutPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) },
            repeatingPlans: repeatingPlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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

    var isEmpty: Bool {
        collections.isEmpty && templates.isEmpty && exercises.isEmpty
            && plans.isEmpty && repeatingPlans.isEmpty
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
    case mobilityPlans
    case mobilityAssessments
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
