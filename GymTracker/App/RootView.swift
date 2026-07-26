//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftData
import SwiftUI
import Combine

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var workoutVM = WorkoutViewModel()
    @State private var todayPath: [TodayRoute] = []
    @State private var trainPath: [LibraryRoute] = []
    @State private var nutritionPath: [NutritionRoute] = []
    @State private var progressPath: [ProgressRoute] = []
    @State private var activeWorkoutPath: [ActiveWorkoutRoute] = []
    @State private var isShowingActiveWorkout = false
    @State private var activeMobilitySession: MobilitySession?
    @State private var shouldDiscardActiveWorkout = false
    @State private var selectedTab: AppTab = .today
    @State private var requestedRescheduleProgressID: UUID?
    @State private var pendingWorkoutStart: PendingWorkoutStart?
    @State private var workoutPreparationRequest: WorkoutPreparationRequest?
    @State private var warmupWorkoutID: UUID?
    @State private var pendingCooldownAfterWorkoutDismissal: MobilityRoutineLaunchRequest?
    @State private var cooldownRequest: MobilityRoutineLaunchRequest?
    @State private var mobilityLinkError: String?
    @State private var guidedSourceConflictRequest: GuidedSourceConflictRequest?
    @State private var guidedSourceActionError: String?
    @State private var isShowingActiveWorkoutConflictAlert = false
    @AppStorage(DefaultsKey.darkMode) private var darkMode: Bool = false
    @AppStorage(DefaultsKey.hasCompletedWelcome) private var hasCompletedWelcome: Bool = false
    @State private var isPreparingApp = true
    @State private var appIntentRouteStore = AppIntentRouteStore.shared
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                todayRoot
                .navigationDestination(for: TodayRoute.self, destination: todayDestination)
            }
            .tabItem {
                tabLabel(for: .today)
            }
            .tag(AppTab.today)

            NavigationStack(path: $trainPath) {
                trainRoot
                .navigationDestination(for: LibraryRoute.self, destination: libraryDestination)
            }
            .tabItem {
                tabLabel(for: .train)
            }
            .tag(AppTab.train)

            if featureFlags.isEnabled(.nutrition) {
                NavigationStack(path: $nutritionPath) {
                    NutritionCenterView()
                        .navigationDestination(for: NutritionRoute.self) { route in
                            switch route {
                            case .foodLibrary:
                                FoodLibraryView()
                            case .mealTemplates:
                                MealTemplateLibraryView()
                            case .targets:
                                NutritionTargetsView()
                            }
                        }
                }
                .tabItem {
                    tabLabel(for: .nutrition)
                }
                .tag(AppTab.nutrition)
            }

            NavigationStack(path: $progressPath) {
                ProgressHubView()
                    .navigationDestination(for: ProgressRoute.self) { route in
                        switch route {
                        case .workoutHistory:
                            HistoryView(viewModel: workoutVM, onStartFreeWorkout: startFreeWorkout)
                        case .records:
                            HistoryView(viewModel: workoutVM, onStartFreeWorkout: startFreeWorkout, initialTab: .records)
                        case .trainingTrends:
                            HistoryView(viewModel: workoutVM, onStartFreeWorkout: startFreeWorkout, initialTab: .progress)
                        case .muscleGroupVolume:
                            HistoryMuscleBalanceDestination()
                        case .mobilityHistory:
                            MobilityHistoryView()
                        case .nutritionHistory:
                            NutritionHistoryView()
                        case .journalHistory:
                            JournalHistoryView()
                        }
                    }
            }
            .tabItem {
                tabLabel(for: .progress)
            }
            .tag(AppTab.progress)
        }
        .preferredColorScheme(darkMode ? .dark : nil)
        .accessibilityHidden(isPreparingApp)
        .overlay {
            if isPreparingApp {
                ZStack {
                    Color.gymBackground.ignoresSafeArea()
                    ProgressView("Preparing GymTracker…")
                        .tint(Color.gymPrimary)
                }
                .accessibilityIdentifier("app-preparing")
            }
        }
        .fullScreenCover(isPresented: shouldShowWelcome) {
            WelcomeView(
                onChoosePlan: {
                    hasCompletedWelcome = true
                    selectedTab = .train
                    trainPath = [.plans]
                },
                onSkip: {
                    hasCompletedWelcome = true
                    selectedTab = .today
                }
            )
        }
        .fullScreenCover(isPresented: $isShowingActiveWorkout, onDismiss: {
            activeWorkoutPath.removeAll()
            if shouldDiscardActiveWorkout {
                workoutVM.discardActiveWorkout(using: modelContext)
                shouldDiscardActiveWorkout = false
                pendingCooldownAfterWorkoutDismissal = nil
            } else if let pendingCooldownAfterWorkoutDismissal {
                self.pendingCooldownAfterWorkoutDismissal = nil
                DispatchQueue.main.async {
                    cooldownRequest = pendingCooldownAfterWorkoutDismissal
                }
            }
        }) {
            NavigationStack(path: $activeWorkoutPath) {
                ActiveWorkoutView(
                    workoutVM: workoutVM,
                    navigationPath: $activeWorkoutPath,
                    modelContext: modelContext,
                    onDiscardRequested: requestDiscardActiveWorkout
                )
                .navigationDestination(for: ActiveWorkoutRoute.self) { route in
                    switch route {
                    case .saveWorkout:
                        WorkoutSaveView(
                            workoutVM: workoutVM,
                            navigationPath: $activeWorkoutPath,
                            isPresented: $isShowingActiveWorkout,
                            onWorkoutSaved: prepareCooldown(for:),
                            onDiscardRequested: requestDiscardActiveWorkout
                        )
                    }
                }
            }
        }
        .fullScreenCover(item: $activeMobilitySession) { session in
            NavigationStack {
                MobilitySessionView(session: session) {
                    activeMobilitySession = nil
                    resumeWorkoutAfterWarmupIfNeeded(session)
                }
            }
        }
        .confirmationDialog(
            "An active workout is already in progress",
            isPresented: $isShowingActiveWorkoutConflictAlert,
            titleVisibility: .visible
        ) {
            Button("Resume Active Workout") {
                isShowingActiveWorkout = true
                pendingWorkoutStart = nil
            }
            Button("Discard & Start New", role: .destructive) {
                let pendingStart = pendingWorkoutStart
                pendingWorkoutStart = nil
                workoutVM.discardActiveWorkout(using: modelContext)
                if workoutVM.hasActiveWorkout {
                    isShowingActiveWorkout = true
                } else if let pendingStart {
                    requestWorkoutPreparation(for: pendingStart)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingWorkoutStart = nil
            }
        } message: {
            Text("Do you want to continue your active workout, or discard it and start a new one?")
        }
        .confirmationDialog(
            "Choose one guided training source",
            isPresented: Binding(
                get: { guidedSourceConflictRequest != nil },
                set: { if !$0 { guidedSourceConflictRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            guidedSourceConflictActions
        } message: {
            Text("Today can follow one training plan or rotation at a time. Your completed workout history will not change.")
        }
        .confirmationDialog(
            "Optional preparation",
            isPresented: Binding(
                get: { workoutPreparationRequest != nil },
                set: { if !$0 { workoutPreparationRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            workoutPreparationActions
        } message: {
            Text(workoutPreparationMessage)
        }
        .confirmationDialog(
            "Add a cooldown?",
            isPresented: Binding(
                get: { cooldownRequest != nil },
                set: { if !$0 { cooldownRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            cooldownActions
        } message: {
            Text(cooldownMessage)
        }
        .alert(
            "Couldn’t update training source",
            isPresented: Binding(
                get: { guidedSourceActionError != nil },
                set: { if !$0 { guidedSourceActionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { guidedSourceActionError = nil }
        } message: {
            Text(guidedSourceActionError ?? "Please try again.")
        }
        .alert(
            "Couldn’t start mobility",
            isPresented: Binding(
                get: { mobilityLinkError != nil },
                set: { if !$0 { mobilityLinkError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { mobilityLinkError = nil }
        } message: {
            Text(mobilityLinkError ?? "Please try again.")
        }
        .task { await prepareApp() }
        .onReceive(NotificationCenter.default.publisher(for: .gymDataRestored)) { _ in
            pendingWorkoutStart = nil
            guidedSourceConflictRequest = nil
            isShowingActiveWorkout = false
            // The restore transaction already staged and committed the
            // bundled catalog as part of its single save (see
            // `GymBackupRestore.restore(to:beforeCommit:)`). Reinstalling it
            // here would be a second, non-atomic transaction whose failure
            // could not roll back the already-committed restore.
            workoutVM.restoreActiveWorkout(using: modelContext)
            Task {
                await PlanNotificationScheduler.shared.reconcile(using: modelContext)
                await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .planScheduleDidChange)) { _ in
            Task { await PlanNotificationScheduler.shared.reconcile(using: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeWorkoutMutated)) { notification in
            // The sole subscriber to App Intent / Live Activity mutations, so
            // the open Active Workout UI reflects an externally-committed
            // change without relaunching or duplicating the mutation itself.
            guard let workoutID = notification.object as? UUID else { return }
            workoutVM.handleExternalWorkoutChange(workoutID: workoutID, using: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .planNotificationOpened)) { notification in
            guard let destination = notification.object as? PlanNotificationDestination else { return }
            handlePlanNotificationDestination(destination)
            _ = PlanNotificationRouter.shared.consumePendingDestination()
        }
        .onChange(of: appIntentRouteStore.pendingDestination) { _, _ in
            consumePendingAppIntentDestination()
        }
        .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
    }

    /// The coarse product destination currently visible, derived from
    /// existing root-owned navigation state rather than tracked imperatively
    /// at every boundary. Used only for beta feedback diagnostics.
    private var currentAppScreen: AppScreen {
        AppScreen.current(
            selectedTab: selectedTab,
            isSettingsPresented: todayPath.last == .settings,
            isShowingActiveWorkout: isShowingActiveWorkout,
            isShowingWorkoutSave: activeWorkoutPath.last == .saveWorkout,
            isShowingActiveMobility: activeMobilitySession != nil
        )
    }

    private func plan(id: UUID) -> WorkoutPlan? {
        try? modelContext.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.id == id }
    }

    private func repeatingPlan(id: UUID) -> RepeatingPlan? {
        try? modelContext.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == id }
    }

    private func programDefinitionRecord(id: UUID) -> ProgramDefinitionRecord? {
        try? modelContext.fetch(FetchDescriptor<ProgramDefinitionRecord>()).first { $0.id == id }
    }

    private func workoutTemplate(id: UUID) -> WorkoutTemplate? {
        try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.id == id }
    }

    private func workoutCollection(id: UUID) -> WorkoutCollection? {
        try? modelContext.fetch(FetchDescriptor<WorkoutCollection>()).first { $0.id == id }
    }

    /// Today's header chip carries only a plan id, so the route is resolved
    /// here: a fixed-length plan and a repeating one land on different detail
    /// screens, and an id matching neither is ignored rather than pushing a
    /// dead screen.
    private func openPlanFromToday(_ planID: UUID) {
        if plan(id: planID) != nil {
            todayPath.append(.plan(planID))
        } else if repeatingPlan(id: planID) != nil {
            todayPath.append(.repeatingPlan(planID))
        }
    }

    private func consumePendingAppIntentDestination() {
        guard let destination = appIntentRouteStore.consume() else { return }
        switch destination {
        case .today:
            selectedTab = .today
            todayPath.removeAll()
        case .activeWorkout(let workoutID):
            guard workoutVM.restoreActiveWorkout(using: modelContext),
                  workoutVM.activeWorkout?.id == workoutID
            else {
                selectedTab = .today
                return
            }
            selectedTab = .today
            activeWorkoutPath.removeAll()
            isShowingActiveWorkout = true
        case .activeMobility(let sessionID):
            guard featureFlags.isEnabled(.mobility),
                  let session = (try? modelContext.fetch(FetchDescriptor<MobilitySession>()))?
                    .first(where: { $0.id == sessionID && $0.status == .active })
            else {
                selectedTab = .today
                return
            }
            selectedTab = .train
            activeMobilitySession = session
        }
    }

    private func consumePendingPlanNotificationDestination() {
        guard let destination = PlanNotificationRouter.shared.consumePendingDestination() else { return }
        handlePlanNotificationDestination(destination)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                print("Failed to save modelContext on backgrounding: \(error)")
            }
            WidgetSnapshotService.refresh(using: modelContext)
        } else if newPhase == .active {
            workoutVM.reconcileLiveActivity()
            Task {
                await PlanNotificationScheduler.shared.reconcile(using: modelContext)
                await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
            }
        }
    }

    /// Held back until seeding finishes, so "Follow a plan" never lands on an
    /// empty catalogue. UI-test launches skip it outright — every fixture asserts
    /// against a specific screen, not a welcome sheet — including relaunches,
    /// which carry `-ui-testing` but not the reset or fixture arguments.
    private var shouldShowWelcome: Binding<Bool> {
        Binding(
            get: {
                !hasCompletedWelcome
                    && !isPreparingApp
                    && !CommandLine.arguments.contains("-ui-testing")
            },
            set: { if !$0 { hasCompletedWelcome = true } }
        )
    }

    private func tabLabel(for tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.icon)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var todayRoot: some View {
        HomeView(
            workoutVM: workoutVM,
            isShowingActiveWorkout: $isShowingActiveWorkout,
            onStartWorkout: startWorkout,
            onStartPlannedWorkout: startPlannedWorkout,
            onStartRepeatingWorkout: startRepeatingWorkout,
            onResolveGuidedSourceConflict: {
                guidedSourceConflictRequest = .chooseFromToday
            },
            onStartMobility: startMobility,
            onResumeMobility: resumeMobility,
            onOpenNutrition: openNutrition,
            onOpenPlan: openPlanFromToday,
            onOpenTrainingCalendar: { todayPath.append(.trainingCalendar) },
            onOpenSettings: { todayPath.append(.settings) },
            requestedRescheduleProgressID: $requestedRescheduleProgressID
        )
    }

    private var trainRoot: some View {
        FolderView(
            onOpenRoute: { trainPath.append($0) },
            onResumePlan: resumeFixedPlan,
            onPauseRepeatingPlan: pauseRepeatingPlan,
            onResumeRepeatingPlan: resumeRepeatingPlan,
            onEndRepeatingPlan: endRepeatingPlan
        )
    }

    @ViewBuilder
    private func todayDestination(_ route: TodayRoute) -> some View {
        switch route {
        case .trainingCalendar:
            TrainingCalendarView(
                onStartPlannedWorkout: startPlannedWorkout,
                onOpenNutrition: openNutrition,
                onOpenMobilityHistory: {
                    selectedTab = .progress
                    progressPath = [.mobilityHistory]
                },
                onOpenJournalHistory: {
                    selectedTab = .progress
                    progressPath = [.journalHistory]
                }
            )
        case .settings:
            SettingView(currentScreen: currentAppScreen)
        case .plan(let planID):
            if let plan = plan(id: planID) {
                PlanDetailView(
                    plan: plan,
                    onStartPlannedWorkout: startPlannedWorkout,
                    onStartPlan: startFixedPlan,
                    onResumePlan: resumeFixedPlan,
                    onStartTestDay: startFixedPlanTestDay
                )
            } else {
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This plan may have been removed or replaced.")
                )
            }
        case .repeatingPlan(let planID):
            if let plan = repeatingPlan(id: planID) {
                RepeatingPlanDetailView(
                    plan: plan,
                    onStartRepeatingWorkout: startRepeatingWorkout,
                    onActivateRepeatingPlan: activateRepeatingPlan,
                    onPauseRepeatingPlan: pauseRepeatingPlan,
                    onResumeRepeatingPlan: resumeRepeatingPlan,
                    onStartAlternateRepeatingWorkout: startAlternateRepeatingWorkout,
                    onRepeatRepeatingWorkout: repeatRepeatingWorkout,
                    onSkipRepeatingWorkout: skipRepeatingWorkout,
                    onUndoRepeatingPlanAdvancement: undoRepeatingPlanAdvancement,
                    onRestartRepeatingPlan: restartRepeatingPlan,
                    onEndRepeatingPlan: endRepeatingPlan
                )
            } else {
                ContentUnavailableView(
                    "Rotation unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This rotation may have been removed or replaced.")
                )
            }
        }
    }

    @ViewBuilder
    private func libraryDestination(_ route: LibraryRoute) -> some View {
        switch route {
        case .plans:
            PlansBrowserView()
        case .workouts:
            WorkoutsBrowserView(onStartWorkout: startWorkout)
        case .exercises:
            ExerciseBrowserView(onShowArchivedExercises: { trainPath.append(.archivedExercises) })
        case .archivedExercises:
            ArchivedExercisesView()
        case .exercise(let exerciseID):
            if let exercise = exercise(id: exerciseID) {
                ExerciseView(exercise: exercise)
            } else {
                ContentUnavailableView(
                    "Exercise unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This exercise may have been removed or replaced.")
                )
            }
        case .readyMadePlan(let recordID):
            if let record = programDefinitionRecord(id: recordID) {
                // Activation lands the user back on Train, where the current-plan
                // card now names the plan they just started.
                ProgramCatalogDetailView(record: record) { trainPath.removeAll() }
            } else {
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This plan may have been removed or replaced.")
                )
            }
        case .plan(let planID):
            if let plan = plan(id: planID) {
                PlanDetailView(
                    plan: plan,
                    onStartPlannedWorkout: startPlannedWorkout,
                    onStartPlan: startFixedPlan,
                    onResumePlan: resumeFixedPlan,
                    onStartTestDay: startFixedPlanTestDay
                )
            } else {
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This plan may have been removed or replaced.")
                )
            }
        case .repeatingPlan(let planID):
            if let plan = repeatingPlan(id: planID) {
                RepeatingPlanDetailView(
                    plan: plan,
                    onStartRepeatingWorkout: startRepeatingWorkout,
                    onActivateRepeatingPlan: activateRepeatingPlan,
                    onPauseRepeatingPlan: pauseRepeatingPlan,
                    onResumeRepeatingPlan: resumeRepeatingPlan,
                    onStartAlternateRepeatingWorkout: startAlternateRepeatingWorkout,
                    onRepeatRepeatingWorkout: repeatRepeatingWorkout,
                    onSkipRepeatingWorkout: skipRepeatingWorkout,
                    onUndoRepeatingPlanAdvancement: undoRepeatingPlanAdvancement,
                    onRestartRepeatingPlan: restartRepeatingPlan,
                    onEndRepeatingPlan: endRepeatingPlan
                )
            } else {
                ContentUnavailableView(
                    "Rotation unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This rotation may have been removed or replaced.")
                )
            }
        case .workoutTemplate(let templateID):
            if let template = workoutTemplate(id: templateID) {
                WorkoutTemplateDetailView(template: template, onStartWorkout: startWorkout)
            } else {
                ContentUnavailableView(
                    "Workout unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This workout may have been removed or replaced.")
                )
            }
        case .workoutCollection(let collectionID):
            if let collection = workoutCollection(id: collectionID) {
                WorkoutCollectionDetailView(collection: collection, onStartWorkout: startWorkout)
            } else {
                ContentUnavailableView(
                    "Folder unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This folder may have been removed or replaced.")
                )
            }
        case .mobility:
            MobilityLibraryView(onStart: startMobility)
        }
    }

    private func prepareApp() async {
        let fixture = UITestFixture.launchFixture
        let isResettingForUITesting = CommandLine.arguments.contains("-reset-data") || fixture != nil

        if CommandLine.arguments.contains("-ui-testing-open-history") {
            selectedTab = .progress
            progressPath = [.workoutHistory]
        }
        if CommandLine.arguments.contains("-ui-testing-open-library") {
            selectedTab = .train
        }
        if CommandLine.arguments.contains("-ui-testing-open-settings") {
            selectedTab = .today
            todayPath = [.settings]
        }

        if isResettingForUITesting {
            resetDataForUITesting()
        }
        runDataMaintenance()
        seedSystemCatalog()
        normalizePersistedWorkoutData()
        if fixture?.refreshesPlanRunAvailability != false {
            refreshActivePlanRuns()
        }
        prepareUITestImportPayloadIfNeeded()

        if let fixture {
            do {
                try UITestFixture.apply(fixture, using: modelContext)
                _ = workoutVM.restoreActiveWorkout(using: modelContext)
                isShowingActiveWorkout = fixture.opensActiveWorkout && workoutVM.hasActiveWorkout
                isShowingActiveWorkoutConflictAlert = fixture.showsActiveWorkoutConflict
            } catch {
                print("Failed to prepare UI-test fixture '\(fixture.rawValue)': \(error)")
            }
        } else if !isResettingForUITesting {
            workoutVM.restoreActiveWorkout(using: modelContext)
        }

        activeMobilitySession = MobilitySessionService.activeSession(using: modelContext)
        configureUITestDestinations()
        consumePendingPlanNotificationDestination()
        consumePendingAppIntentDestination()
        isPreparingApp = false
        WidgetSnapshotService.refresh(using: modelContext)
        await PlanNotificationScheduler.shared.reconcile(using: modelContext)
        await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
    }

    private func prepareUITestImportPayloadIfNeeded() {
        guard CommandLine.arguments.contains("-ui-testing-import-valid") else { return }
        do {
            let backup = try BackupDTO.create(
                from: modelContext,
                restTimer: 120,
                darkMode: true,
                unitSystem: .imperial
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            UITestFixture.UITestImportPayload.validData = try encoder.encode(backup)
        } catch {
            print("Failed to prepare valid UI-test import payload: \(error)")
        }
    }

    private func configureUITestDestinations() {
        if CommandLine.arguments.contains("-ui-testing-open-exercise-detail") {
            let descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.name == "Bench Press" }
            )
            if let benchPress = try? modelContext.fetch(descriptor).first {
                selectedTab = .train
                trainPath = [.exercise(benchPress.id)]
            }
        }

        guard CommandLine.arguments.contains("-ui-testing-open-plan-reminder-reschedule") else {
            return
        }
        guard let run = try? modelContext.fetch(FetchDescriptor<PlanRun>())
            .first(where: { $0.status == .active })
        else {
            return
        }
        guard let progress = run.orderedWorkoutProgress.first(where: {
            PlanReminderEligibility.isActionableToday($0, in: run)
        }) else {
            return
        }
        PlanNotificationRouter.shared.submit(
            PlanNotificationDestination(
                planID: run.sourcePlanID,
                runID: run.id,
                progressID: progress.id,
                action: .reschedule
            )
        )
    }

    private func handlePlanNotificationDestination(_ destination: PlanNotificationDestination) {
        switch destination.action {
        case .openPlan:
            selectedTab = .train
            trainPath = [.plan(destination.planID)]
        case .reschedule:
            guard let run = try? modelContext.fetch(FetchDescriptor<PlanRun>()).first(where: { $0.id == destination.runID }),
                  run.sourcePlanID == destination.planID,
                  let progress = run.workoutProgress.first(where: { $0.id == destination.progressID }),
                  PlanReminderEligibility.isActionableToday(progress, in: run)
            else {
                selectedTab = .today
                return
            }
            selectedTab = .today
            todayPath.removeAll()
            requestedRescheduleProgressID = progress.id
        }
    }

    private func startMobility(_ routine: MobilityRoutine, _ context: MobilitySessionContext, _ workoutID: UUID?) {
        guard let session = MobilitySessionService.start(
            routine: routine,
            context: context,
            workoutID: workoutID,
            using: modelContext
        ) else { return }
        activeMobilitySession = session
    }

    private func resumeMobility(_ session: MobilitySession) {
        activeMobilitySession = session
    }

    /// Central gate for every path that can navigate to Mobility. An
    /// already-active session still resumes through `startMobility`/
    /// `resumeMobility` regardless of this flag: disabling a domain must
    /// never strand in-progress work, only hide new entry points.
    private func openTrainMobility() {
        guard featureFlags.isEnabled(.mobility) else { return }
        selectedTab = .train
        trainPath = [.mobility]
    }

    /// Central gate for every path that can navigate to the Nutrition tab.
    /// Disabled destinations simply stay on the current parent screen rather
    /// than navigating into an unavailable tab.
    private func openNutrition() {
        guard featureFlags.isEnabled(.nutrition) else { return }
        selectedTab = .nutrition
    }

    private func exercise(id: UUID) -> Exercise? {
        try? modelContext.fetch(FetchDescriptor<Exercise>()).first { $0.id == id }
    }

    private func seedSystemCatalog() {
        do {
            guard try SystemSeedCatalogCoordinator.needsInstallation(in: modelContext) else { return }
            _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: modelContext)
        } catch {
            print("Failed to install bundled system catalogue: \(error)")
        }
    }

    private func runDataMaintenance() {
        do {
            _ = try DataMaintenanceService.runOrphanCleanupIfNeeded(using: modelContext)
        } catch {
            print("Failed to clean orphaned workout data: \(error)")
        }
    }

    private func startFreeWorkout() {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout(using: modelContext)
        }
        isShowingActiveWorkout = workoutVM.hasActiveWorkout
    }

    private func startWorkout(from template: WorkoutTemplate) {
        requestWorkoutStart(.template(template))
    }

    private func startPlannedWorkout(_ planRun: PlanRun, _ progress: PlanWorkoutProgress) {
        guard let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: planRun) else { return }
        requestWorkoutStart(.planned(PendingPlannedWorkout(
            planRun: planRun,
            progress: progress,
            plannedWorkout: plannedWorkout
        )))
    }

    private func startFixedPlan(_ plan: WorkoutPlan, _ startDate: Date) {
        let action = FixedPlanAction.start(plan, startDate)
        guard activeRepeatingPlanRuns().isEmpty, activeFixedPlanRuns().isEmpty else {
            guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    private func resumeFixedPlan(_ run: PlanRun) {
        let action = FixedPlanAction.resume(run)
        let hasOtherFixedRun = activeFixedPlanRuns().contains { $0.id != run.id }
        guard activeRepeatingPlanRuns().isEmpty, !hasOtherFixedRun else {
            guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    private func startFixedPlanTestDay(_ run: PlanRun) {
        let action = FixedPlanAction.startTestDay(run)
        let hasOtherFixedRun = activeFixedPlanRuns().contains { $0.id != run.id }
        guard activeRepeatingPlanRuns().isEmpty, !hasOtherFixedRun else {
            guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    @discardableResult
    private func performFixedPlanAction(_ action: FixedPlanAction) -> Bool {
        switch action {
        case .start(let plan, let startDate):
            let started: PlanRun?
            if let completedRun = plan.runs
                .filter({ $0.status == .completed || $0.status == .archived })
                .sorted(by: { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) })
                .first,
               case .offerRestart(let carryState) = plan.programCompletionPolicy {
                started = ProgramRunLifecycleService.restartRun(
                    for: plan,
                    from: completedRun,
                    startDate: startDate,
                    carryState: carryState,
                    using: modelContext
                )
            } else {
                started = PlanCoordinator.startRun(for: plan, startDate: startDate, using: modelContext)
            }
            guard started != nil else {
                guidedSourceActionError = "The plan could not be started. Check its workouts and try again."
                return false
            }
        case .resume(let run):
            guard PlanCoordinator.resume(run, using: modelContext) else {
                guidedSourceActionError = "The plan could not be resumed. Try again."
                return false
            }
        case .startTestDay(let run):
            guard let progress = ProgramRunLifecycleService.activateTestDay(for: run, using: modelContext) else {
                guidedSourceActionError = "The test day could not be started. Try again."
                return false
            }
            startPlannedWorkout(run, progress)
        }
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        return true
    }

    private func startRepeatingWorkout(_ run: RepeatingPlanRun) {
        requestWorkoutStart(.repeating(run, .expected))
    }

    private func startAlternateRepeatingWorkout(
        _ run: RepeatingPlanRun,
        _ slotIndex: Int,
        _ continuationMode: RepeatingPlanContinuationMode
    ) {
        requestWorkoutStart(.repeating(
            run,
            .alternate(slotIndex: slotIndex, continuationMode: continuationMode)
        ))
    }

    private func repeatRepeatingWorkout(_ run: RepeatingPlanRun) {
        requestWorkoutStart(.repeating(run, .repeatLast))
    }

    private func requestWorkoutStart(_ start: PendingWorkoutStart) {
        if workoutVM.hasActiveWorkout {
            pendingWorkoutStart = start
            isShowingActiveWorkoutConflictAlert = true
            return
        }
        requestWorkoutPreparation(for: start)
    }

    private func requestWorkoutPreparation(for start: PendingWorkoutStart) {
        guard let warmupRoutine = linkedMobilityRoutine(for: start, phase: .warmup) else {
            continueWorkoutStart(WorkoutPreparationRequest(start: start))
            return
        }
        workoutPreparationRequest = WorkoutPreparationRequest(
            start: start,
            warmupRoutine: warmupRoutine
        )
    }

    private func continueWorkoutStart(_ request: WorkoutPreparationRequest) {
        switch request.start {
        case .planned:
            guard activeRepeatingPlanRuns().isEmpty else {
                guidedSourceConflictRequest = .workoutStart(request)
                return
            }
        case .repeating(let target, _):
            let hasOtherRepeatingSource = activeRepeatingPlanRuns().contains { $0.id != target.id }
            guard activeFixedPlanRuns().isEmpty, !hasOtherRepeatingSource else {
                guidedSourceConflictRequest = .workoutStart(request)
                return
            }
        case .template:
            break
        }
        performWorkoutStart(request)
    }

    @discardableResult
    private func performWorkoutStart(_ request: WorkoutPreparationRequest) -> Bool {
        let didStart: Bool
        switch request.start {
        case .template(let template):
            didStart = workoutVM.startWorkout(with: template, using: modelContext)
        case .planned(let pending):
            didStart = workoutVM.startWorkout(
                from: pending.plannedWorkout,
                progress: pending.progress,
                in: pending.planRun,
                using: modelContext
            )
        case .repeating(let run, let command):
            didStart = workoutVM.startWorkout(
                from: run,
                command: command,
                using: modelContext
            )
        }
        if !didStart {
            guidedSourceActionError = "The workout could not be started. Check the selected plan or rotation and try again."
            return false
        }

        guard let workout = workoutVM.activeWorkout else {
            guidedSourceActionError = "The workout could not be started. Check the selected plan or rotation and try again."
            return false
        }

        guard let warmupRoutine = request.warmupRoutine else {
            isShowingActiveWorkout = true
            return true
        }

        guard let session = MobilitySessionService.start(
            routine: warmupRoutine,
            context: .warmup,
            workoutID: workout.id,
            using: modelContext
        ) else {
            guidedSourceActionError = String(localized: "The linked warm-up could not be started. Your workout is ready to begin.")
            isShowingActiveWorkout = true
            return true
        }
        warmupWorkoutID = workout.id
        activeMobilitySession = session
        return true
    }

    @ViewBuilder
    private var workoutPreparationActions: some View {
        if let request = workoutPreparationRequest {
            if let activeSession = MobilitySessionService.activeSession(using: modelContext) {
                Button("Resume Active Mobility") {
                    workoutPreparationRequest = nil
                    activeMobilitySession = activeSession
                }
                .accessibilityIdentifier("resume-active-mobility-before-workout")
            } else {
                Button("Start Warmup") {
                    workoutPreparationRequest = nil
                    continueWorkoutStart(request)
                }
                .accessibilityIdentifier("start-linked-warmup")
                .accessibilityHint(String(localized: "Starts the linked warm-up before this workout. The workout begins after you leave mobility."))
            }

            Button("Skip and Start Workout") {
                workoutPreparationRequest = nil
                continueWorkoutStart(WorkoutPreparationRequest(start: request.start))
            }
            .accessibilityIdentifier("skip-linked-warmup")
            .accessibilityHint(String(localized: "Starts the workout without the optional warm-up."))
        }
        Button("Cancel", role: .cancel) {
            workoutPreparationRequest = nil
        }
    }

    private var workoutPreparationMessage: String {
        if MobilitySessionService.activeSession(using: modelContext) != nil {
            return String(localized: "Finish or stop the active mobility session before starting this linked warm-up, or start the workout without it.")
        }
        guard let routineName = workoutPreparationRequest?.warmupRoutine?.name else {
            return String(localized: "This workout has an optional linked warm-up.")
        }
        return String(localized: "Start \(routineName) before this workout? It is recorded as a separate mobility session.")
    }

    @ViewBuilder
    private var cooldownActions: some View {
        if let request = cooldownRequest {
            if let activeSession = MobilitySessionService.activeSession(using: modelContext) {
                Button("Resume Active Mobility") {
                    cooldownRequest = nil
                    activeMobilitySession = activeSession
                }
                .accessibilityIdentifier("resume-active-mobility-before-cooldown")
            } else {
                Button("Start Cooldown") {
                    cooldownRequest = nil
                    startLinkedMobility(request)
                }
                .accessibilityIdentifier("start-linked-cooldown")
                .accessibilityHint(String(localized: "Starts the linked cooldown as a separate mobility session."))
            }
        }
        Button("Done", role: .cancel) {
            cooldownRequest = nil
        }
    }

    private var cooldownMessage: String {
        if MobilitySessionService.activeSession(using: modelContext) != nil {
            return String(localized: "Finish or stop the active mobility session before starting this linked cooldown.")
        }
        guard let routineName = cooldownRequest?.routine.name else {
            return String(localized: "This workout has an optional linked cooldown.")
        }
        return String(localized: "Start \(routineName) after this workout? It is recorded as a separate mobility session.")
    }

    private func startLinkedMobility(_ request: MobilityRoutineLaunchRequest) {
        guard let session = MobilitySessionService.start(
            routine: request.routine,
            context: request.context,
            workoutID: request.workoutID,
            using: modelContext
        ) else {
            mobilityLinkError = String(localized: "The linked mobility routine could not be started. Try again.")
            return
        }
        activeMobilitySession = session
    }

    private func resumeWorkoutAfterWarmupIfNeeded(_ session: MobilitySession) {
        guard session.workoutID == warmupWorkoutID,
              workoutVM.activeWorkout?.id == warmupWorkoutID
        else { return }
        warmupWorkoutID = nil
        DispatchQueue.main.async {
            isShowingActiveWorkout = true
        }
    }

    private func prepareCooldown(for workoutID: UUID) {
        guard let workout = workout(id: workoutID),
              let routine = linkedMobilityRoutine(for: workout, phase: .cooldown)
        else { return }
        pendingCooldownAfterWorkoutDismissal = MobilityRoutineLaunchRequest(
            routine: routine,
            context: .cooldown,
            workoutID: workoutID
        )
    }

    private func workout(id: UUID) -> Workout? {
        (try? modelContext.fetch(FetchDescriptor<Workout>()))?.first { $0.id == id }
    }

    private func linkedMobilityRoutine(
        for start: PendingWorkoutStart,
        phase: WorkoutMobilityLinkPhase
    ) -> MobilityRoutine? {
        switch start {
        case .template(let template):
            return resolvedMobilityRoutine(
                liveRoutine: phase.liveRoutine(in: template),
                snapshotID: nil
            )
        case .planned(let pending):
            return resolvedMobilityRoutine(
                liveRoutine: pending.plannedWorkout.sourceTemplate.flatMap { phase.liveRoutine(in: $0) },
                snapshotID: nil
            )
        case .repeating(let run, let command):
            guard let slot = WorkoutMobilityLinkResolver.slot(in: run, for: command) else { return nil }
            return resolvedMobilityRoutine(
                liveRoutine: phase.liveRoutine(in: slot),
                snapshotID: phase.snapshotID(in: slot)
            )
        }
    }

    private func linkedMobilityRoutine(
        for workout: Workout,
        phase: WorkoutMobilityLinkPhase
    ) -> MobilityRoutine? {
        if let runID = workout.sourceRepeatingPlanRunID,
              let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
              let run = (try? modelContext.fetch(FetchDescriptor<RepeatingPlanRun>()))?.first(where: { $0.id == runID }),
              let occurrence = run.occurrences.first(where: { $0.id == occurrenceID }),
              let slot = WorkoutMobilityLinkResolver.slot(in: run, for: occurrence)
        {
            return resolvedMobilityRoutine(
                liveRoutine: phase.liveRoutine(in: slot),
                snapshotID: phase.snapshotID(in: slot)
            )
        }
        guard let template = workout.sourceTemplate else { return nil }
        return resolvedMobilityRoutine(
            liveRoutine: phase.liveRoutine(in: template),
            snapshotID: nil
        )
    }

    private func resolvedMobilityRoutine(
        liveRoutine: MobilityRoutine?,
        snapshotID: UUID?
    ) -> MobilityRoutine? {
        if let liveRoutine, isRunnableMobilityRoutine(liveRoutine) {
            return liveRoutine
        }
        guard let snapshotID else { return nil }
        return (try? modelContext.fetch(FetchDescriptor<MobilityRoutine>()))?
            .first { $0.id == snapshotID && isRunnableMobilityRoutine($0) }
    }

    private func isRunnableMobilityRoutine(_ routine: MobilityRoutine) -> Bool {
        !routine.isArchived && !routine.orderedItems.isEmpty
    }

    private func activateRepeatingPlan(_ plan: RepeatingPlan) {
        do {
            let run = try RepeatingPlanCoordinator.activate(
                plan,
                fixedPlanRuns: activeFixedPlanRuns(),
                repeatingPlanRuns: activeRepeatingPlanRuns()
            )
            modelContext.insert(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be activated. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch RepeatingPlanCoordinatorError.activationConflict {
            guidedSourceConflictRequest = .activate(plan)
        } catch {
            guidedSourceActionError = "The rotation is unavailable. Check its workouts and try again."
        }
    }

    private func pauseRepeatingPlan(_ run: RepeatingPlanRun) {
        do {
            try RepeatingPlanCoordinator.pause(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be paused. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            guidedSourceActionError = "Only an active rotation can be paused."
        }
    }

    private func resumeRepeatingPlan(_ run: RepeatingPlanRun) {
        let conflicts = RepeatingPlanCoordinator.guidedSourceConflicts(
            fixedPlanRuns: activeFixedPlanRuns(),
            repeatingPlanRuns: activeRepeatingPlanRuns().filter { $0.id != run.id }
        )
        guard conflicts.isEmpty else {
            guidedSourceConflictRequest = .resume(run)
            return
        }
        do {
            try RepeatingPlanCoordinator.resume(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be resumed. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "Only a paused rotation can be resumed."
        }
    }

    private func skipRepeatingWorkout(_ run: RepeatingPlanRun) {
        do {
            let occurrence = try RepeatingPlanCoordinator.skip(in: run)
            modelContext.insert(occurrence)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The workout could not be skipped. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            modelContext.rollback()
            guidedSourceActionError = "Finish or discard the active rotation workout before skipping the next one."
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The workout could not be skipped. Check the rotation and try again."
        }
    }

    private func undoRepeatingPlanAdvancement(_ run: RepeatingPlanRun) {
        guard !workoutVM.hasActiveWorkout, !workoutVM.restoreActiveWorkout(using: modelContext) else {
            guidedSourceActionError = "Finish or discard the active workout before undoing a rotation change."
            return
        }
        guard workoutVM.undoLastRepeatingPlanAdvancement(in: run, using: modelContext) else {
            guidedSourceActionError = "Undo is available only for the most recent completed or skipped rotation change."
            return
        }
    }

    private func restartRepeatingPlan(_ run: RepeatingPlanRun) {
        do {
            try RepeatingPlanCoordinator.restart(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be restarted. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            modelContext.rollback()
            guidedSourceActionError = "Finish or discard the active rotation workout before restarting the rotation."
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The rotation could not be restarted. Check its workouts and try again."
        }
    }

    private func endRepeatingPlan(_ run: RepeatingPlanRun) {
        do {
            try RepeatingPlanCoordinator.end(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be ended. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch RepeatingPlanCoordinatorError.runHasActiveOccurrence {
            modelContext.rollback()
            guidedSourceActionError = "Finish or discard the active rotation workout before ending the rotation."
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The rotation could not be ended. Try again."
        }
    }

    private func activeFixedPlanRuns() -> [PlanRun] {
        ((try? modelContext.fetch(FetchDescriptor<PlanRun>())) ?? [])
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    private func activeRepeatingPlanRuns() -> [RepeatingPlanRun] {
        ((try? modelContext.fetch(FetchDescriptor<RepeatingPlanRun>())) ?? [])
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    @ViewBuilder
    private var guidedSourceConflictActions: some View {
        if let request = guidedSourceConflictRequest {
            switch request {
            case .chooseFromToday:
                if !activeFixedPlanRuns().isEmpty {
                    Button("Follow Training Plan") {
                        resolveTodayGuidedSource(preferRepeating: false)
                    }
                    .accessibilityIdentifier("follow-fixed-plan")
                }
                if !activeRepeatingPlanRuns().isEmpty {
                    Button("Follow Rotation") {
                        resolveTodayGuidedSource(preferRepeating: true)
                    }
                    .accessibilityIdentifier("follow-repeating-plan")
                }
            case .workoutStart(let request):
                Button(guidedConflictContinuationTitle(for: request.start)) {
                    resolveGuidedConflictAndStart(request)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-start")
            case .activate(let plan):
                Button("Pause Current Source & Activate Rotation") {
                    resolveGuidedConflictAndActivate(plan)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-activate")
            case .resume(let run):
                Button("Pause Current Source & Resume Rotation") {
                    resolveGuidedConflictAndResume(run)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-resume")
            case .fixedPlan(let action):
                Button("Pause Current Source & Continue Plan") {
                    resolveGuidedConflictAndPerformFixedPlanAction(action)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-continue-plan")
            }
        }
        Button("Cancel", role: .cancel) {
            guidedSourceConflictRequest = nil
        }
    }

    private func guidedConflictContinuationTitle(for start: PendingWorkoutStart) -> String {
        switch start {
        case .planned:
            return "Pause Rotation & Start Plan Workout"
        case .repeating:
            return "Pause Other Sources & Start Rotation"
        case .template:
            return "Continue"
        }
    }

    private func resolveGuidedConflictAndStart(_ request: WorkoutPreparationRequest) {
        guidedSourceConflictRequest = nil
        do {
            switch request.start {
            case .planned:
                try stagePauseRepeatingRuns()
            case .repeating(let target, _):
                stagePauseFixedRuns()
                try stagePauseRepeatingRuns(except: target.id)
            case .template:
                break
            }
            let didStart = performWorkoutStart(request)
            if !didStart {
                modelContext.rollback()
            }
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The other training source could not be paused. Try again."
        }
    }

    private func resolveGuidedConflictAndActivate(_ plan: RepeatingPlan) {
        guidedSourceConflictRequest = nil
        do {
            stagePauseFixedRuns()
            try stagePauseRepeatingRuns()
            let run = try RepeatingPlanCoordinator.activate(plan)
            modelContext.insert(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be activated. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The rotation could not be activated. Check its workouts and try again."
        }
    }

    private func resolveGuidedConflictAndResume(_ run: RepeatingPlanRun) {
        guidedSourceConflictRequest = nil
        do {
            stagePauseFixedRuns()
            try stagePauseRepeatingRuns(except: run.id)
            try RepeatingPlanCoordinator.resume(run)
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The rotation could not be resumed. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The rotation could not be resumed. Try again."
        }
    }

    private func resolveGuidedConflictAndPerformFixedPlanAction(_ action: FixedPlanAction) {
        guidedSourceConflictRequest = nil
        do {
            stagePauseFixedRuns(except: action.retainedRunID)
            try stagePauseRepeatingRuns()
            guard performFixedPlanAction(action) else {
                modelContext.rollback()
                return
            }
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The rotation could not be paused. Try again."
        }
    }

    private func resolveTodayGuidedSource(preferRepeating: Bool) {
        guidedSourceConflictRequest = nil
        do {
            if preferRepeating {
                let repeatingRuns = activeRepeatingPlanRuns()
                guard repeatingRuns.count == 1, let retained = repeatingRuns.first else {
                    throw GuidedSourceResolutionError.missingSource
                }
                stagePauseFixedRuns()
                try stagePauseRepeatingRuns(except: retained.id)
            } else {
                let fixedRuns = activeFixedPlanRuns()
                guard fixedRuns.count == 1, let retained = fixedRuns.first else {
                    throw GuidedSourceResolutionError.missingSource
                }
                stagePauseFixedRuns(except: retained.id)
                try stagePauseRepeatingRuns()
            }
            guard modelContext.saveOrRollback() else {
                guidedSourceActionError = "The training source could not be changed. Try again."
                return
            }
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
        } catch {
            modelContext.rollback()
            guidedSourceActionError = "The training source could not be changed. Try again."
        }
    }

    private func stagePauseFixedRuns(except retainedRunID: UUID? = nil) {
        for run in activeFixedPlanRuns() where run.id != retainedRunID {
            PlanCoordinator.pause(run)
        }
    }

    private func stagePauseRepeatingRuns(except retainedRunID: UUID? = nil) throws {
        for run in activeRepeatingPlanRuns() where run.id != retainedRunID {
            try RepeatingPlanCoordinator.pause(run)
        }
    }

    private func resetDataForUITesting() {
        isShowingActiveWorkout = false
        shouldDiscardActiveWorkout = false
        activeWorkoutPath.removeAll()
        pendingWorkoutStart = nil
        guidedSourceConflictRequest = nil
        workoutVM.workout = nil
        workoutVM.activeWorkout = nil

        do {
            try modelContext.clearAllGymData()
            workoutVM.activeWorkout = nil
            workoutVM.workout = nil
        } catch {
            print("Failed to reset UI test data: \(error)")
        }
    }

    private func requestDiscardActiveWorkout() {
        shouldDiscardActiveWorkout = true
        isShowingActiveWorkout = false
    }

    private func normalizePersistedWorkoutData() {
        let normalizationVersion = 1
        guard UserDefaults.standard.integer(forKey: DefaultsKey.workoutNormalizationVersion) < normalizationVersion else {
            return
        }
        do {
            var didChange = false

            let workouts = try modelContext.fetch(FetchDescriptor<Workout>())
            for workout in workouts {
                let expectedStatus: WorkoutStatus = workout.endTime == nil ? .active : .completed
                if workout.status != expectedStatus {
                    workout.status = expectedStatus
                    didChange = true
                }

                let workoutExercises = workout.exercises
                let hasStableExerciseOrder = Set(workoutExercises.map(\.orderIndex)).count == workoutExercises.count
                let orderedExercises = hasStableExerciseOrder ? workout.orderedExercises : workoutExercises
                for (exerciseIndex, exercise) in orderedExercises.enumerated() {
                    if exercise.orderIndex != exerciseIndex {
                        exercise.orderIndex = exerciseIndex
                        didChange = true
                    }
                    // Rows persisted before `exerciseIDSnapshot` existed derive
                    // it once from their still-live relationship. Later renames
                    // or archival must never overwrite it again.
                    if exercise.exerciseIDSnapshot == nil {
                        exercise.exerciseIDSnapshot = exercise.exercise.id
                        didChange = true
                    }
                    let exerciseSets = exercise.sets
                    let hasStableSetOrder = Set(exerciseSets.map(\.orderIndex)).count == exerciseSets.count
                    let orderedSets = hasStableSetOrder ? exercise.orderedSets : exerciseSets
                    for (setIndex, set) in orderedSets.enumerated() where set.orderIndex != setIndex {
                        set.orderIndex = setIndex
                        didChange = true
                    }
                }
            }

            if didChange {
                try modelContext.save()
            }
            UserDefaults.standard.set(normalizationVersion, forKey: DefaultsKey.workoutNormalizationVersion)
        } catch {
            modelContext.rollback()
            print("Failed to normalize persisted workout data: \(error)")
        }
    }

    /// Re-evaluates active run availability after a cold launch. A session can
    /// be rescheduled while the app is not running, so persisted `.available`
    /// flags must not outrank a newly due session after relaunch.
    private func refreshActivePlanRuns() {
        do {
            let runs = try modelContext.fetch(FetchDescriptor<PlanRun>())
                .filter { $0.status == .active }
            runs.forEach { PlanCoordinator.refreshAvailability(for: $0) }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            print("Failed to refresh plan-run availability: \(error)")
        }
    }
}

private enum PendingWorkoutStart {
    case template(WorkoutTemplate)
    case planned(PendingPlannedWorkout)
    case repeating(RepeatingPlanRun, RepeatingPlanWorkoutStartCommand)
}

private struct WorkoutPreparationRequest {
    let start: PendingWorkoutStart
    let warmupRoutine: MobilityRoutine?

    init(start: PendingWorkoutStart, warmupRoutine: MobilityRoutine? = nil) {
        self.start = start
        self.warmupRoutine = warmupRoutine
    }
}

private struct MobilityRoutineLaunchRequest {
    let routine: MobilityRoutine
    let context: MobilitySessionContext
    let workoutID: UUID
}

private enum WorkoutMobilityLinkPhase {
    case warmup
    case cooldown

    func liveRoutine(in template: WorkoutTemplate) -> MobilityRoutine? {
        switch self {
        case .warmup: template.preWorkoutMobilityRoutine
        case .cooldown: template.postWorkoutMobilityRoutine
        }
    }

    func liveRoutine(in slot: RepeatingPlanRunSlot) -> MobilityRoutine? {
        switch self {
        case .warmup: slot.preWorkoutMobilityRoutine
        case .cooldown: slot.postWorkoutMobilityRoutine
        }
    }

    func snapshotID(in slot: RepeatingPlanRunSlot) -> UUID? {
        switch self {
        case .warmup: slot.preWorkoutMobilityRoutineIDSnapshot
        case .cooldown: slot.postWorkoutMobilityRoutineIDSnapshot
        }
    }
}

enum WorkoutMobilityLinkResolver {
    static func slot(
        in run: RepeatingPlanRun,
        for command: RepeatingPlanWorkoutStartCommand
    ) -> RepeatingPlanRunSlot? {
        let slots = run.orderedSlots
        switch command {
        case .expected:
            guard slots.indices.contains(run.currentSlotIndex) else { return nil }
            return slots[run.currentSlotIndex]
        case .alternate(let slotIndex, _):
            guard slots.indices.contains(slotIndex) else { return nil }
            return slots[slotIndex]
        case .repeatLast:
            guard let occurrence = run.orderedOccurrences.reversed().first(where: {
                $0.status == .completed && $0.kind != .skip && $0.kind != .restart
            }) else { return nil }
            return slot(in: run, for: occurrence)
        }
    }

    static func slot(
        in run: RepeatingPlanRun,
        for occurrence: RepeatingPlanOccurrence
    ) -> RepeatingPlanRunSlot? {
        let slotIndex = occurrence.selectedSlotIndex ?? occurrence.expectedSlotIndex
        let slots = run.orderedSlots
        guard slots.indices.contains(slotIndex) else { return nil }
        return slots[slotIndex]
    }
}

private enum GuidedSourceConflictRequest {
    case chooseFromToday
    case workoutStart(WorkoutPreparationRequest)
    case activate(RepeatingPlan)
    case resume(RepeatingPlanRun)
    case fixedPlan(FixedPlanAction)
}

private enum FixedPlanAction {
    case start(WorkoutPlan, Date)
    case resume(PlanRun)
    case startTestDay(PlanRun)

    var retainedRunID: UUID? {
        switch self {
        case .start:
            nil
        case .resume(let run), .startTestDay(let run):
            run.id
        }
    }
}

private enum GuidedSourceResolutionError: Error {
    case missingSource
}

private struct PendingPlannedWorkout {
    let planRun: PlanRun
    let progress: PlanWorkoutProgress
    let plannedWorkout: PlannedWorkout
}
