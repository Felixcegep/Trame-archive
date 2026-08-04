//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftData
import SwiftUI
import Combine

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var workoutVM = WorkoutViewModel()
    @State private var activeLoggingMetrics = ActiveLoggingMetricsRecorder()
    @State private var todayPath: [TodayRoute] = []
    @State private var trainPath: [LibraryRoute] = []
    @State private var trainNavigationID = UUID()
    @State private var nutritionPath: [NutritionRoute] = []
    @State private var progressPath: [ProgressRoute] = []
    @State private var activeWorkoutPath: [ActiveWorkoutRoute] = []
    @State private var isShowingActiveWorkout = false
    @State private var activeMobilitySession: MobilitySession?
    /// The assessment flow is presented from the root, like the active workout
    /// and the active mobility session: the presenter owns dismissal, and the
    /// flow only reports that it is finished.
    @State private var activeAssessmentSession: MobilityAssessmentSession?
    @State private var shouldDiscardActiveWorkout = false
    @State private var selectedTab: AppTab = .today
    @State private var requestedRescheduleProgressID: UUID?
    @State private var pendingWorkoutStart: PendingWorkoutStart?
    @State private var workoutPreparationRequest: WorkoutPreparationRequest?
    @State private var warmupWorkoutID: UUID?
    @State private var pendingCooldownAfterWorkoutDismissal: MobilityRoutineLaunchRequest?
    @State private var cooldownRequest: MobilityRoutineLaunchRequest?
    @State private var pendingProgressionReceiptWorkoutID: UUID?
    @State private var progressionReceiptRequest: ProgressionReceiptRequest?
    @State private var mobilityLinkError: String?
    @State private var guidedSourceCoordinator = GuidedSourceConflictCoordinator()
    @State private var isShowingActiveWorkoutConflictAlert = false
    /// Confirmations shown on Today. Owned here because the two events that
    /// raise them do not happen on Today: saving a workout dismisses its own
    /// screen, and a plan action can be taken from Train.
    @State private var todayStatusMessage: GymStatusMessage?
    /// Increments only when a plan or rotation action actually committed.
    @State private var planStateChangeCount = 0
    @AppStorage(DefaultsKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(DefaultsKey.darkMode) private var legacyDarkMode: Bool = false
    @AppStorage(DefaultsKey.hasCompletedWelcome) private var hasCompletedWelcome: Bool = false
    /// Set only by the personalization offer on Today, which re-presents the
    /// same flow after first launch has long since completed.
    @State private var isShowingOnboarding = false
    @State private var isShowingPersonalizedWorkoutBuilder = false
    @State private var personalizedWorkoutLaunchRequest: WorkoutGenerationLaunchRequest?
    @State private var isPreparingApp = true
    @State private var hasFinishedLaunchAnimation = false
    @State private var appIntentRouteStore = AppIntentRouteStore.shared
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var availableExercises: [Exercise]
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    /// The root becomes interactive only after both the persisted state is
    /// trustworthy and the short brand motion has resolved. These normally
    /// overlap, so the animation never extends a launch whose data work takes
    /// longer than the authored 1.05 seconds.
    private var isShowingLaunchExperience: Bool {
        isPreparingApp
            || !hasFinishedLaunchAnimation
            || UITestLaunch.holdsLaunchExperience()
    }

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
            .id(trainNavigationID)
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
                        case .mobilityAssessmentHistory:
                            MobilityAssessmentHistoryView()
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
        .preferredColorScheme(effectiveAppearance.colorScheme)
        .gymFeedback(.planStateChanged, trigger: planStateChangeCount)
        // A Today confirmation belongs to the screen where the user saw the
        // result. Do not resurrect it when returning from another tab.
        .onChange(of: selectedTab) { _, _ in
            todayStatusMessage = nil
        }
        .accessibilityHidden(isShowingLaunchExperience)
        .overlay {
            if isShowingLaunchExperience {
                ZStack {
                    Color.gymBackground.ignoresSafeArea()

                    TrameBuild(onFinish: { hasFinishedLaunchAnimation = true })
                    .accessibilityIdentifier("launch-brand-mark")
                    .accessibilityValue(hasFinishedLaunchAnimation ? "Ready" : "Animating")
                }
                .accessibilityIdentifier("app-preparing")
                .transition(.opacity)
            }
        }
        .animation(AppMotion.compact, value: isShowingLaunchExperience)
        .fullScreenCover(isPresented: shouldShowWelcome) {
            OnboardingFlowView(onFinish: handleOnboardingOutcome)
        }
        .fullScreenCover(isPresented: $isShowingActiveWorkout, onDismiss: {
            activeWorkoutPath.removeAll()
            if shouldDiscardActiveWorkout {
                workoutVM.discardActiveWorkout(using: modelContext)
                shouldDiscardActiveWorkout = false
                pendingCooldownAfterWorkoutDismissal = nil
                pendingProgressionReceiptWorkoutID = nil
            } else {
                if let pendingCooldownAfterWorkoutDismissal {
                    self.pendingCooldownAfterWorkoutDismissal = nil
                    presentAfterDismissal {
                        cooldownRequest = pendingCooldownAfterWorkoutDismissal
                    }
                }
                if let pendingProgressionReceiptWorkoutID,
                   let receipt = ProgressionReceiptPolicy.receipt(
                    forWorkoutID: pendingProgressionReceiptWorkoutID,
                    using: modelContext
                   ) {
                    self.pendingProgressionReceiptWorkoutID = nil
                    presentAfterDismissal { progressionReceiptRequest = receipt }
                }
            }
        }) {
            NavigationStack(path: $activeWorkoutPath) {
                ActiveWorkoutView(
                    workoutVM: workoutVM,
                    navigationPath: $activeWorkoutPath,
                    modelContext: modelContext,
                    activeLoggingMetrics: activeLoggingMetrics,
                    onDiscardRequested: requestDiscardActiveWorkout
                )
                .navigationDestination(for: ActiveWorkoutRoute.self) { route in
                    switch route {
                    case .saveWorkout:
                        WorkoutSaveView(
                            workoutVM: workoutVM,
                            navigationPath: $activeWorkoutPath,
                            isPresented: $isShowingActiveWorkout,
                            activeLoggingMetrics: activeLoggingMetrics,
                            onWorkoutSaved: { workoutID in
                                prepareCooldown(for: workoutID)
                                preparePendingProgressionReceipts(for: workoutID)
                                // Raised here rather than on the save screen,
                                // which is dismissing. It lands on Today, where
                                // the user is being sent, so the session ends
                                // with something other than a screen vanishing.
                                todayStatusMessage = savedWorkoutMessage()
                            },
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
                    // Closes the loop between this session ending and any
                    // `MobilityProgramSessionProgress` it was started for —
                    // cheap and a no-op whenever the session was not
                    // program-linked, or nothing is active.
                    MobilityProgramRunCoordinator.reconcileTerminalSessions(using: modelContext)
                    resumeWorkoutAfterWarmupIfNeeded(session)
                }
            }
        }
        .fullScreenCover(item: $activeAssessmentSession) { session in
            NavigationStack {
                MobilityAssessmentFlowView(session: session) {
                    activeAssessmentSession = nil
                }
            }
        }
        .sheet(item: $progressionReceiptRequest) { request in
            ProgressionReceiptSheet(planRunID: request.planRunID, workoutID: request.workoutID)
        }
        .sheet(isPresented: $isShowingPersonalizedWorkoutBuilder, onDismiss: {
            personalizedWorkoutLaunchRequest = nil
        }) {
            PersonalizedWorkoutBuilderView(
                availableExercises: availableExercises,
                launchRequest: personalizedWorkoutLaunchRequest,
                onStart: startPersonalizedWorkout
            )
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
                activeLoggingMetrics.workoutDiscarded()
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
            guidedSourceSwitchTitle,
            isPresented: Binding(
                get: { guidedSourceCoordinator.guidedSourceConflictRequest != nil },
                set: { if !$0 { guidedSourceCoordinator.guidedSourceConflictRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            guidedSourceConflictActions
        } message: {
            Text(guidedSourceSwitchMessage)
        }
        // A sheet, not a confirmation dialog: an action sheet had nowhere to
        // put the routine's length or size, so it asked for a decision while
        // withholding what the decision was about. See `WorkoutPreparationSheet`.
        .sheet(isPresented: Binding(
            get: { workoutPreparationRequest != nil },
            set: { if !$0 { workoutPreparationRequest = nil } }
        )) {
            if let request = workoutPreparationRequest {
                let activeSession = MobilitySessionService.activeSession(using: modelContext)
                WorkoutPreparationSheet(
                    routine: request.warmupRoutine,
                    hasActiveMobilitySession: activeSession != nil,
                    onStart: {
                        workoutPreparationRequest = nil
                        continueWorkoutStart(request)
                    },
                    onResumeActive: {
                        workoutPreparationRequest = nil
                        activeMobilitySession = activeSession
                    },
                    onSkip: {
                        workoutPreparationRequest = nil
                        // Rebuilt without the warm-up so the start cannot pick
                        // the linked routine back up on its way through.
                        continueWorkoutStart(WorkoutPreparationRequest(start: request.start))
                    },
                    onCancel: { workoutPreparationRequest = nil }
                )
            }
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
            "Plan change failed",
            isPresented: Binding(
                get: { guidedSourceCoordinator.guidedSourceActionError != nil },
                set: { if !$0 { guidedSourceCoordinator.guidedSourceActionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { guidedSourceCoordinator.guidedSourceActionError = nil }
        } message: {
            Text(guidedSourceCoordinator.guidedSourceActionError ?? "Please try again.")
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
            guidedSourceCoordinator.guidedSourceConflictRequest = nil
            isShowingActiveWorkout = false
            // The restore transaction already staged and committed the
            // bundled catalog as part of its single save (see
            // `GymBackupRestore.restore(to:beforeCommit:)`). Reinstalling it
            // here would be a second, non-atomic transaction whose failure
            // could not roll back the already-committed restore.
            workoutVM.restoreActiveWorkout(using: modelContext)
            activeMobilitySession = reconciledActiveMobilitySession()
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
        .safeAreaInset(edge: .bottom) {
            if guidedSourceCoordinator.pendingGuidedSourceUndo != nil {
                guidedSourceUndoBanner
            }
        }
    }

    private var effectiveAppearance: AppAppearance {
        guard UserDefaults.standard.object(forKey: DefaultsKey.appearance) != nil else {
            return legacyDarkMode ? .dark : .system
        }
        return appearance
    }

    /// The coarse product destination currently visible, derived from
    /// existing root-owned navigation state rather than tracked imperatively
    /// at every boundary. Used only for beta feedback diagnostics.
    private var currentAppScreen: AppScreen {
        AppScreen.current(
            selectedTab: selectedTab,
            isSettingsPresented: todayPath.last == .settings || todayPath.last == .settingsData,
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
            guard workoutVM.restoreActiveWorkout(using: modelContext).didSave,
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
                  let session = reconciledActiveMobilitySession(),
                  session.id == sessionID
            else {
                selectedTab = .today
                return
            }
            selectedTab = .train
            activeMobilitySession = session
        case .personalizedWorkout(let launchRequest):
            guard featureFlags.isEnabled(.workoutGeneration) else {
                selectedTab = .today
                return
            }
            selectedTab = .today
            todayPath.removeAll()
            personalizedWorkoutLaunchRequest = launchRequest
            isShowingPersonalizedWorkoutBuilder = true
        }
    }

    private func startPersonalizedWorkout(_ draft: ValidatedWorkoutDraft) -> Bool {
        guard workoutVM.hasActiveWorkout == false else {
            isShowingActiveWorkout = true
            return false
        }
        do {
            _ = try GeneratedWorkoutStartService.start(
                draft,
                using: modelContext,
                unitSystem: UserDefaults.standard.unitSystem
            )
            guard workoutVM.restoreActiveWorkout(using: modelContext).didSave else { return false }
            isShowingPersonalizedWorkoutBuilder = false
            activeWorkoutPath.removeAll()
            isShowingActiveWorkout = true
            return true
        } catch {
            // Keep the review screen open, where the person can revise the
            // draft or choose the normal manual flow. No partial workout is
            // left behind by the transactional start service.
            return false
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
                // Recorded, not just printed: whatever the active workout
                // logged this session may not have reached disk, and a
                // console line nobody reads is indistinguishable from losing
                // it silently. No UI reads this today, deliberately — the app
                // is backgrounding, so there is no safe moment to present
                // anything: an alert now is dismissed before anyone sees it,
                // and surfacing it on next foreground would ambush the person
                // with a stale error about a session they may not even
                // remember. A real treatment needs to decide whether this is
                // even actionable (a full disk clears on its own; a
                // programmer error does not) and whether re-surfacing a
                // background failure at next launch is worth the ambush,
                // before it becomes something the user sees.
                BackgroundSaveFailureState.shared.recordFailure(error)
            }
            WidgetSnapshotService.refresh(using: modelContext)
            // Rest is the interval the phone spends in a pocket. The deadline
            // is already persisted on the workout, so scheduling here — and
            // only here — means the reminder can never arrive while the app is
            // on screen competing with its own haptic and announcement.
            let restEndDate = workoutVM.activeWorkout?.restEndDate
            let nextSet = nextSetNotificationDescription()
            Task {
                await RestNotificationScheduler.shared.schedule(
                    restEndDate: restEndDate,
                    nextSetDescription: nextSet
                )
            }
        } else if newPhase == .active {
            workoutVM.reconcileLiveActivity()
            Task {
                await RestNotificationScheduler.shared.cancel()
                await PlanNotificationScheduler.shared.reconcile(using: modelContext)
                await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
            }
        }
    }

    /// "Next: Lat Pulldown · Set 2" for the rest reminder, derived from the same
    /// selector Active Workout uses, so the notification and the screen name the
    /// same set. `nil` when nothing is left to do.
    private func nextSetNotificationDescription() -> String? {
        guard let workout = workoutVM.activeWorkout,
              let next = WorkoutSetSelector.nextIncompleteSet(in: workout)
        else {
            return nil
        }
        let setNumber = (next.entry.orderedSets.firstIndex {
            $0.persistentModelID == next.set.persistentModelID
        } ?? 0) + 1
        return String(localized: "Next: \(next.entry.exercise.name) · Set \(setNumber)")
    }

    /// Held back until seeding finishes, so "Follow a plan" never lands on an
    /// empty catalogue. UI-test launches skip it outright — every fixture asserts
    /// against a specific screen, not a welcome sheet — including relaunches,
    /// which carry `-ui-testing` but not the reset or fixture arguments. That
    /// suppression is why the first-launch screen has never been captured, so
    /// `-ui-testing-show-welcome` opts a single screenshot scene back in.
    private var shouldShowWelcome: Binding<Bool> {
        Binding(
            get: {
                // Re-entry from the personalization offer. Deliberately the
                // whole flow, welcome question included: a lifter who skipped
                // setup and is now asking for it is choosing how their next
                // workout gets decided, which is the first question.
                if isShowingOnboarding { return true }
                if CommandLine.arguments.contains("-ui-testing-show-welcome") {
                    return !isPreparingApp
                }
                return !hasCompletedWelcome
                    && !isPreparingApp
                    && !CommandLine.arguments.contains("-ui-testing")
            },
            set: {
                if !$0 {
                    hasCompletedWelcome = true
                    isShowingOnboarding = false
                }
            }
        )
    }

    /// Applies whatever onboarding finished with.
    ///
    /// The flow reports an intent and nothing more; every navigation decision
    /// stays here, beside the tab and path state that has to honour it. Marking
    /// the welcome complete is what dismisses the cover — see
    /// `shouldShowWelcome` — so it happens on every branch.
    private func handleOnboardingOutcome(_ outcome: OnboardingOutcome) {
        hasCompletedWelcome = true
        isShowingOnboarding = false
        switch outcome {
        case .startFreeWorkout:
            selectedTab = .today
            todayPath.removeAll()
            // Raised a runloop turn later: the cover dismissing and the active
            // workout presenting in the same turn is the hand-off SwiftUI
            // swallows. See `presentAfterDismissal`.
            presentAfterDismissal(startFreeWorkout)
        case .openToday:
            selectedTab = .today
            todayPath.removeAll()
        case .browseAllPlans:
            selectedTab = .train
            trainPath = [.plans]
        case .reviewActivePlan:
            selectedTab = .train
            trainPath = [activePlanRoute()]
        }
    }

    /// The plan onboarding just activated, or the browser when the store says
    /// nothing is active — never a detail screen for a plan that is not there.
    private func activePlanRoute() -> LibraryRoute {
        if let run = activeFixedPlanRuns().max(by: { $0.createdAt < $1.createdAt }) {
            return .plan(run.sourcePlanID)
        }
        if let run = activeRepeatingPlanRuns().max(by: { $0.startedAt < $1.startedAt }) {
            return .repeatingPlan(run.sourcePlanID)
        }
        return .plans
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
                guidedSourceCoordinator.guidedSourceConflictRequest = .chooseFromToday
            },
            onResumeMobility: resumeMobility,
            onOpenExercises: openTrainExercises,
            onOpenMobility: openTrainMobility,
            onOpenPlan: openPlanFromToday,
            onOpenTrainingCalendar: { todayPath.append(.trainingCalendar) },
            onOpenSettings: { todayPath.append(.settings) },
            onPersonalize: { isShowingOnboarding = true },
            requestedRescheduleProgressID: $requestedRescheduleProgressID,
            statusMessage: $todayStatusMessage
        )
    }

    /// Reports what the save actually wrote, from the counts the save itself
    /// recorded. They cannot be recomputed once `activeWorkout` is cleared.
    private func savedWorkoutMessage() -> GymStatusMessage {
        guard let summary = workoutVM.lastSavedSummary else {
            return GymStatusMessage(String(localized: "Workout saved."))
        }
        return GymStatusMessage(
            String(localized: "Workout saved · \(CountPhrase.sets(summary.savedSetCount))")
        )
    }

    /// Records that a plan or rotation action committed. The state badge on the
    /// affected screen is the visible confirmation; this adds the spoken and
    /// tactile channels, which were both missing. Called only after
    /// `saveOrRollback` has succeeded — never on the error branches, which
    /// already have their own alert.
    private func confirmPlanStateChange(_ text: String) {
        planStateChangeCount += 1
        GymAnnouncement.post(text)
    }

    private var trainRoot: some View {
        FolderView(
            onOpenRoute: { trainPath.append($0) },
            onOpenProgramPath: { trainPath.append(.programPath($0)) },
            onOpenWeeklyReview: { trainPath.append(.weeklyReview($0)) },
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
            SettingView(
                currentScreen: currentAppScreen,
                activeLoggingMetrics: activeLoggingMetrics
            )
        case .settingsData:
            DataSettingsView()
        case .plan(let planID):
            if let plan = plan(id: planID) {
                PlanDetailView(
                    plan: plan,
                    onStartPlannedWorkout: startPlannedWorkout,
                    onStartPlan: startFixedPlan,
                    onResumePlan: resumeFixedPlan,
                    onStartTestDay: startFixedPlanTestDay,
                    onOpenProgramPath: { todayPath.append(.programPath($0)) },
                    onOpenWeeklyReview: { todayPath.append(.weeklyReview($0)) }
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
                    onEndRepeatingPlan: endRepeatingPlan,
                    onOpenProgramPath: { todayPath.append(.programPath($0)) }
                )
            } else {
                ContentUnavailableView(
                    "Rotation unavailable",
                    systemImage: AppIcon.warning,
                    description: Text("This rotation may have been removed or replaced.")
                )
            }
        case .programPath(let route):
            programPathDestination(route, onOpenWeeklyReview: { todayPath.append(.weeklyReview($0)) })
        case .weeklyReview(let route):
            weeklyReviewDestination(route)
        }
    }

    /// Plan Path is reachable from Today and from Train, so it registers as its
    /// own destination type on both stacks instead of duplicating a case in two
    /// route enums. Workout starts stay here, where the guarded conflict-aware
    /// handlers live. `onOpenWeeklyReview` is supplied per call site because,
    /// unlike the root-level workout actions, it pushes onto whichever typed
    /// path array reached this destination.
    private func programPathDestination(
        _ route: ProgramPathRoute,
        onOpenWeeklyReview: @escaping (WeeklyProgramReviewRoute) -> Void
    ) -> some View {
        ProgramPathView(
            route: route,
            onStartPlannedWorkout: startPlannedWorkout,
            onStartRepeatingWorkout: startRepeatingWorkout,
            onResumeActiveWorkout: { isShowingActiveWorkout = true },
            onOpenWeeklyReview: onOpenWeeklyReview
        )
    }

    /// Weekly Review resolves its own projection from `route` and has no
    /// forward navigation into a typed path itself (its one pushed
    /// destination, a completed workout, is reached the same inline way
    /// `PlanCalendarView` and `FixedProgramPathTimeline` already push theirs).
    private func weeklyReviewDestination(_ route: WeeklyProgramReviewRoute) -> some View {
        WeeklyProgramReviewView(route: route)
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
                // card now names the plan they just started. Replacing the stack
                // avoids asking UIKit to pop the detail while its setup sheet is
                // still completing its dismissal transition.
                ProgramCatalogDetailView(record: record) {
                    trainPath.removeAll()
                    trainNavigationID = UUID()
                }
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
                    onStartTestDay: startFixedPlanTestDay,
                    onOpenProgramPath: { trainPath.append(.programPath($0)) },
                    onOpenWeeklyReview: { trainPath.append(.weeklyReview($0)) }
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
                    onEndRepeatingPlan: endRepeatingPlan,
                    onOpenProgramPath: { trainPath.append(.programPath($0)) }
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
            MobilityLibraryView(
                onStart: startMobility,
                onStartAssessment: { activeAssessmentSession = $0 },
                onStartProgramSession: startMobilityProgramSession
            )
        case .mobilityPlans:
            MobilityProgramCatalogView(onStartProgramSession: startMobilityProgramSession)
        case .mobilityAssessments:
            MobilityAssessmentLandingView(onStart: { activeAssessmentSession = $0 })
        case .programPath(let route):
            programPathDestination(route, onOpenWeeklyReview: { trainPath.append(.weeklyReview($0)) })
        case .weeklyReview(let route):
            weeklyReviewDestination(route)
        }
    }

    /// The launch sequence, now a list of steps rather than their bodies. The
    /// store work lives in `AppBootstrap` and the launch-argument routing in
    /// `UITestLaunch`; what stays here is the part that is genuinely the view's:
    /// deciding what is on screen once the data underneath it is trustworthy.
    ///
    /// Order is load-bearing in three places. Tabs are selected before the
    /// store work so a slow seed cannot flash the wrong one. Record-specific
    /// destinations are resolved after it, because they name rows that do not
    /// exist yet. And the notification destination is submitted before it is
    /// consumed.
    private func prepareApp() async {
        let fixture = UITestFixture.launchFixture
        let isRebootVerificationFixture = CommandLine.arguments.contains("-ui-testing-reboot-rest-fixture")
        let isResettingForUITesting = UITestLaunch.isResettingData(fixture: fixture)
            || isRebootVerificationFixture

        apply(UITestLaunch.initialDestination())

        if isResettingForUITesting {
            resetForUITesting()
        }
        AppBootstrap.runDataMaintenance(using: modelContext)
        AppBootstrap.seedSystemCatalog(using: modelContext)
        AppBootstrap.normalizePersistedWorkoutData(using: modelContext)
        if fixture?.refreshesPlanRunAvailability != false {
            AppBootstrap.refreshActivePlanRuns(using: modelContext)
        }
        AppBootstrap.prepareUITestImportPayloadIfNeeded(using: modelContext)

        if isRebootVerificationFixture {
            // A second xcodebuild invocation installs a fresh test app, so
            // the reboot lane cannot carry the SwiftData container across its
            // two XCTest processes. Rehydrate the same persisted shape at the
            // post-reboot launch boundary; ordinary relaunch coverage still
            // proves the actual store persistence.
            let outcome = AppBootstrap.applyFixture(.activeRestRunning, using: modelContext)
            _ = workoutVM.restoreActiveWorkout(using: modelContext)
            isShowingActiveWorkout = false
            isShowingActiveWorkoutConflictAlert = outcome.showsActiveWorkoutConflict
        } else if let fixture {
            let outcome = AppBootstrap.applyFixture(fixture, using: modelContext)
            _ = workoutVM.restoreActiveWorkout(using: modelContext)
            isShowingActiveWorkout = outcome.opensActiveWorkout && workoutVM.hasActiveWorkout
            isShowingActiveWorkoutConflictAlert = outcome.showsActiveWorkoutConflict
            if let receipt = outcome.progressionReceipt {
                presentAfterDismissal {
                    progressionReceiptRequest = ProgressionReceiptRequest(
                        planRunID: receipt.planRunID,
                        workoutID: receipt.workoutID
                    )
                }
            }
        } else if !isResettingForUITesting {
            workoutVM.restoreActiveWorkout(using: modelContext)
        }

        activeMobilitySession = reconciledActiveMobilitySession()
        apply(UITestLaunch.seededDestination(using: modelContext))
        consumePendingPlanNotificationDestination()
        consumePendingAppIntentDestination()
        isPreparingApp = false
        WidgetSnapshotService.refresh(using: modelContext)
        await PlanNotificationScheduler.shared.reconcile(using: modelContext)
        await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
    }

    /// Applies whatever a UI-test launch asked for. Every field is optional so
    /// that an argument the launch did not pass cannot overwrite state another
    /// one already set.
    private func apply(_ destination: UITestLaunch.Destination) {
        if let tab = destination.tab { selectedTab = tab }
        if let path = destination.todayPath { todayPath = path }
        if let path = destination.trainPath { trainPath = path }
        if let path = destination.progressPath { progressPath = path }
        if let message = destination.guidedSourceError { guidedSourceCoordinator.guidedSourceActionError = message }
        if let message = destination.mobilityLinkError { mobilityLinkError = message }
        if let notification = destination.planNotification {
            PlanNotificationRouter.shared.submit(notification)
        }
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
        guard let restored = reconciledActiveMobilitySession(), restored.id == session.id else { return }
        activeMobilitySession = restored
    }

    /// Mirrors `startMobility`: a mobility program session is compiled and
    /// started by `MobilityProgramRunCoordinator` before this is called, so
    /// this only takes ownership of presenting it — the one centralized
    /// `activeMobilitySession` fullScreenCover every mobility session (
    /// standalone or program) presents through.
    private func startMobilityProgramSession(_ session: MobilitySession) {
        activeMobilitySession = session
    }

    private func reconciledActiveMobilitySession() -> MobilitySession? {
        switch MobilitySessionService.restoreActiveSession(using: modelContext) {
        case .restored(let session), .repaired(let session):
            return session
        case .none, .invalid, .persistenceFailure:
            return nil
        }
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

    /// The exercise library, reached from Today's quick access. Replaces the
    /// path rather than appending, so repeated taps cannot stack the browser on
    /// top of itself.
    private func openTrainExercises() {
        selectedTab = .train
        trainPath = [.exercises]
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
            guidedSourceCoordinator.guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    private func resumeFixedPlan(_ run: PlanRun) {
        let action = FixedPlanAction.resume(run)
        let hasOtherFixedRun = activeFixedPlanRuns().contains { $0.id != run.id }
        guard activeRepeatingPlanRuns().isEmpty, !hasOtherFixedRun else {
            guidedSourceCoordinator.guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    private func startFixedPlanTestDay(_ run: PlanRun) {
        let action = FixedPlanAction.startTestDay(run)
        let hasOtherFixedRun = activeFixedPlanRuns().contains { $0.id != run.id }
        guard activeRepeatingPlanRuns().isEmpty, !hasOtherFixedRun else {
            guidedSourceCoordinator.guidedSourceConflictRequest = .fixedPlan(action)
            return
        }
        _ = performFixedPlanAction(action)
    }

    @discardableResult
    private func performFixedPlanAction(_ action: FixedPlanAction) -> Bool {
        let outcome = PlanLifecycleService.perform(action, using: modelContext)
        if let message = outcome.errorMessage {
            guidedSourceCoordinator.guidedSourceActionError = message
            return false
        }
        if let confirmation = outcome.confirmation {
            confirmPlanStateChange(confirmation)
        }
        // A test day activates a planned workout that still has to be started,
        // and starting one is presentation: it can raise a conflict dialog and
        // a warm-up prompt, neither of which belongs behind a data call.
        if let start = outcome.plannedWorkoutToStart {
            requestWorkoutStart(.planned(start))
        }
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
        guard let warmupRoutine = WorkoutMobilityLinkResolver.linkedRoutine(
            for: start,
            phase: .warmup,
            using: modelContext
        ) else {
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
                guidedSourceCoordinator.guidedSourceConflictRequest = .workoutStart(request)
                return
            }
        case .repeating(let target, _):
            let hasOtherRepeatingSource = activeRepeatingPlanRuns().contains { $0.id != target.id }
            guard activeFixedPlanRuns().isEmpty, !hasOtherRepeatingSource else {
                guidedSourceCoordinator.guidedSourceConflictRequest = .workoutStart(request)
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
            guidedSourceCoordinator.guidedSourceActionError = "The workout could not be started. Check the selected plan or rotation and try again."
            return false
        }

        guard let workout = workoutVM.activeWorkout else {
            guidedSourceCoordinator.guidedSourceActionError = "The workout could not be started. Check the selected plan or rotation and try again."
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
            guidedSourceCoordinator.guidedSourceActionError = String(localized: "The linked warm-up could not be started. Your workout is ready to begin.")
            isShowingActiveWorkout = true
            return true
        }
        warmupWorkoutID = workout.id
        activeMobilitySession = session
        return true
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
        guard let warmupWorkoutID,
              WorkoutMobilityContinuationPolicy.shouldResumeWorkout(
                sessionContext: session.context,
                sessionWorkoutID: session.workoutID,
                pendingWarmupWorkoutID: warmupWorkoutID,
                activeWorkoutID: workoutVM.activeWorkout?.id
              )
        else { return }
        self.warmupWorkoutID = nil
        presentAfterDismissal { isShowingActiveWorkout = true }
    }

    /// SwiftUI swallows a presentation raised in the same runloop turn as the
    /// dismissal of the cover it replaces. Every hand-off in the
    /// workout → warm-up → workout → save → cooldown → receipt chain therefore
    /// lands one turn later, and routing them all through here states that
    /// reason once instead of repeating a bare `DispatchQueue.main.async` at
    /// each site with no explanation.
    ///
    /// Removing the deferral outright means collapsing the root's four
    /// independent presentations into a single stage-driven one. That is a
    /// behavioural change to the chain rather than a cleanup, and it needs the
    /// flow exercised on a device before it ships — see T-37 in
    /// `Documentation/UIUXInteractionPlan.md`.
    private func presentAfterDismissal(_ present: @escaping () -> Void) {
        DispatchQueue.main.async(execute: present)
    }

    private func prepareCooldown(for workoutID: UUID) {
        guard let workout = workout(id: workoutID),
              let routine = WorkoutMobilityLinkResolver.linkedRoutine(
                for: workout,
                phase: .cooldown,
                using: modelContext
              )
        else { return }
        pendingCooldownAfterWorkoutDismissal = MobilityRoutineLaunchRequest(
            routine: routine,
            context: .cooldown,
            workoutID: workoutID
        )
    }

    private func workout(id: UUID) -> Workout? {
        ProgressionReceiptPolicy.workout(id: id, using: modelContext)
    }

    /// Flags a just-saved workout for the progression receipt sheet. The sheet
    /// itself cannot be raised here: the save screen is dismissing, so the
    /// request is held until the cover is gone.
    private func preparePendingProgressionReceipts(for workoutID: UUID) {
        guard ProgressionReceiptPolicy.owesReceipt(forWorkoutID: workoutID, using: modelContext) else {
            return
        }
        pendingProgressionReceiptWorkoutID = workoutID
    }

    private func activateRepeatingPlan(_ plan: RepeatingPlan) {
        apply(PlanLifecycleService.activate(plan, using: modelContext))
    }

    private func pauseRepeatingPlan(_ run: RepeatingPlanRun) {
        apply(PlanLifecycleService.pause(run, using: modelContext))
    }

    private func resumeRepeatingPlan(_ run: RepeatingPlanRun) {
        apply(PlanLifecycleService.resume(run, using: modelContext))
    }

    private func skipRepeatingWorkout(_ run: RepeatingPlanRun) {
        apply(PlanLifecycleService.skipNextWorkout(in: run, using: modelContext))
    }

    /// Renders what a plan action did. The service decides and commits; this
    /// decides only what the person is told about it.
    private func apply(_ outcome: PlanActionOutcome) {
        switch outcome {
        case .succeeded(let confirmation):
            confirmPlanStateChange(confirmation)
        case .succeededSilently:
            break
        case .failed(let message):
            guidedSourceCoordinator.guidedSourceActionError = message
        case .needsConflictResolution(let request):
            guidedSourceCoordinator.guidedSourceConflictRequest = request
        }
    }

    private func undoRepeatingPlanAdvancement(_ run: RepeatingPlanRun) {
        guard !workoutVM.hasActiveWorkout, !workoutVM.restoreActiveWorkout(using: modelContext).didSave else {
            guidedSourceCoordinator.guidedSourceActionError = "Finish or discard the active workout before undoing a rotation change."
            return
        }
        guard workoutVM.undoLastRepeatingPlanAdvancement(in: run, using: modelContext) else {
            guidedSourceCoordinator.guidedSourceActionError = "Undo is available only for the most recent completed or skipped rotation change."
            return
        }
    }

    private func restartRepeatingPlan(_ run: RepeatingPlanRun) {
        apply(PlanLifecycleService.restart(run, using: modelContext))
    }

    private func endRepeatingPlan(_ run: RepeatingPlanRun) {
        apply(PlanLifecycleService.end(run, using: modelContext))
    }

    private func activeFixedPlanRuns() -> [PlanRun] {
        PlanLifecycleService.activeFixedRuns(using: modelContext)
    }

    private func activeRepeatingPlanRuns() -> [RepeatingPlanRun] {
        PlanLifecycleService.activeRepeatingRuns(using: modelContext)
    }

    @ViewBuilder
    private var guidedSourceConflictActions: some View {
        if let request = guidedSourceCoordinator.guidedSourceConflictRequest {
            switch request {
            case .chooseFromToday:
                if !activeFixedPlanRuns().isEmpty {
                    Button("Make Training Plan Active") {
                        resolveTodayGuidedSource(preferRepeating: false)
                    }
                    .accessibilityIdentifier("follow-fixed-plan")
                }
                if !activeRepeatingPlanRuns().isEmpty {
                    Button("Make Rotation Active") {
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
                Button("Pause Current Plan & Start Rotation") {
                    resolveGuidedConflictAndActivate(plan)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-activate")
            case .resume(let run):
                Button("Pause Current Plan & Resume Rotation") {
                    resolveGuidedConflictAndResume(run)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-resume")
            case .fixedPlan(let action):
                Button("Pause Current Plan & Continue") {
                    resolveGuidedConflictAndPerformFixedPlanAction(action)
                }
                .accessibilityIdentifier("resolve-guided-conflict-and-continue-plan")
            }
        }
        Button("Cancel", role: .cancel) {
            guidedSourceCoordinator.guidedSourceConflictRequest = nil
        }
    }

    private func guidedConflictContinuationTitle(for start: PendingWorkoutStart) -> String {
        switch start {
        case .planned:
            return "Pause Rotation & Start Workout"
        case .repeating:
            return "Pause Current Plan & Start Rotation"
        case .template:
            return "Continue"
        }
    }

    private var guidedSourceSwitchTitle: String {
        guard let request = guidedSourceCoordinator.guidedSourceConflictRequest else { return String(localized: "Change active plan?") }
        switch request {
        case .chooseFromToday:
            return String(localized: "Choose your active plan")
        case .activate(_), .resume(_):
            return String(localized: "Switch to this rotation?")
        case .workoutStart(let request):
            if case .planned = request.start {
                return String(localized: "Switch to this training plan?")
            }
            return String(localized: "Switch to this rotation?")
        case .fixedPlan(_):
            return String(localized: "Switch to this training plan?")
        }
    }

    private var guidedSourceSwitchMessage: String {
        guard case .chooseFromToday? = guidedSourceCoordinator.guidedSourceConflictRequest else {
            return String(localized: "Your current plan will be paused, not deleted. Its progress and completed workouts stay available, and you can resume it later.")
        }
        return String(localized: "Choose which plan appears in Today. The other plan will be paused, while its progress and completed workouts remain available.")
    }

    private var guidedSourceUndoBanner: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.pause)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)
            Text("Active plan changed")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymText)
                .lineLimit(2)
            Spacer(minLength: Spacing.s)
            Button("Undo") { undoGuidedSourceSwitch() }
                .font(AppFont.subheadlineSemibold)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .accessibilityIdentifier("undo-guided-source-switch")
                .accessibilityHint("Pauses the new plan and restores the previously active plan.")
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.section, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .shadow(color: Color.gymText.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided-source-undo-banner")
    }

    private func resolveGuidedConflictAndStart(_ request: WorkoutPreparationRequest) {
        guidedSourceCoordinator.guidedSourceConflictRequest = nil
        do {
            switch request.start {
            case .planned:
                try PlanLifecycleService.stagePauseRepeatingRuns(using: modelContext)
            case .repeating(let target, _):
                PlanLifecycleService.stagePauseFixedRuns(using: modelContext)
                try PlanLifecycleService.stagePauseRepeatingRuns(except: target.id, using: modelContext)
            case .template:
                break
            }
            let didStart = performWorkoutStart(request)
            if !didStart {
                modelContext.rollback()
            }
        } catch {
            modelContext.rollback()
            guidedSourceCoordinator.guidedSourceActionError = "The other training source could not be paused. Try again."
        }
    }

    private func resolveGuidedConflictAndActivate(_ plan: RepeatingPlan) {
        let snapshot = PlanLifecycleService.switchSnapshot(using: modelContext)
        guidedSourceCoordinator.guidedSourceConflictRequest = nil
        let outcome = PlanLifecycleService.resolveConflictAndActivate(plan, using: modelContext)
        apply(outcome)
        registerGuidedSourceUndo(snapshot, after: outcome)
    }

    private func resolveGuidedConflictAndResume(_ run: RepeatingPlanRun) {
        let snapshot = PlanLifecycleService.switchSnapshot(using: modelContext)
        guidedSourceCoordinator.guidedSourceConflictRequest = nil
        let outcome = PlanLifecycleService.resolveConflictAndResume(run, using: modelContext)
        apply(outcome)
        registerGuidedSourceUndo(snapshot, after: outcome)
    }

    private func resolveGuidedConflictAndPerformFixedPlanAction(_ action: FixedPlanAction) {
        let snapshot = PlanLifecycleService.switchSnapshot(using: modelContext)
        guidedSourceCoordinator.guidedSourceConflictRequest = nil
        do {
            PlanLifecycleService.stagePauseFixedRuns(except: action.retainedRunID, using: modelContext)
            try PlanLifecycleService.stagePauseRepeatingRuns(using: modelContext)
            guard performFixedPlanAction(action) else {
                modelContext.rollback()
                return
            }
            registerGuidedSourceUndo(snapshot)
        } catch {
            modelContext.rollback()
            guidedSourceCoordinator.guidedSourceActionError = "The rotation could not be paused. Try again."
        }
    }

    private func resolveTodayGuidedSource(preferRepeating: Bool) {
        let snapshot = PlanLifecycleService.switchSnapshot(using: modelContext)
        guidedSourceCoordinator.guidedSourceConflictRequest = nil
        let outcome = PlanLifecycleService.resolveTodaySource(preferRepeating: preferRepeating, using: modelContext)
        apply(outcome)
        registerGuidedSourceUndo(snapshot, after: outcome)
    }

    private func registerGuidedSourceUndo(
        _ snapshot: GuidedSourceSwitchSnapshot,
        after outcome: PlanActionOutcome = .succeededSilently
    ) {
        guard !workoutVM.hasActiveWorkout else { return }
        guidedSourceCoordinator.scheduleUndo(for: snapshot, outcome: outcome)
    }

    private func undoGuidedSourceSwitch() {
        guard let snapshot = guidedSourceCoordinator.pendingGuidedSourceUndo else { return }
        guard !workoutVM.hasActiveWorkout else {
            guidedSourceCoordinator.guidedSourceActionError = "Finish or discard the active workout before restoring the previous plan."
            return
        }
        guidedSourceCoordinator.dismissUndo()
        apply(PlanLifecycleService.undoSwitch(to: snapshot, using: modelContext))
    }

    /// The view's half of a UI-test reset. `AppBootstrap` owns the persisted
    /// half; what is left here is presentation state and the view model, which
    /// nothing outside the view can reach.
    private func resetForUITesting() {
        isShowingActiveWorkout = false
        shouldDiscardActiveWorkout = false
        activeWorkoutPath.removeAll()
        pendingWorkoutStart = nil
        guidedSourceCoordinator.reset()
        workoutVM.workout = nil
        workoutVM.activeWorkout = nil
        activeLoggingMetrics.reset()

        AppBootstrap.resetPersistedDataForUITesting(using: modelContext)

        // Cleared again after the store is emptied: the view model would
        // otherwise be left holding models the delete has already removed.
        workoutVM.activeWorkout = nil
        workoutVM.workout = nil
    }

    private func requestDiscardActiveWorkout() {
        activeLoggingMetrics.workoutDiscarded()
        shouldDiscardActiveWorkout = true
        isShowingActiveWorkout = false
    }
}
