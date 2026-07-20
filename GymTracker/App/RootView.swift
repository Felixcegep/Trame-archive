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
    @State private var isShowingActiveMobility = false
    @State private var activeMobilitySessionID: UUID?
    @State private var shouldDiscardActiveWorkout = false
    @State private var selectedTab: AppTab = .today
    @State private var requestedRescheduleProgressID: UUID?
    @State private var templateToStart: WorkoutTemplate? = nil
    @State private var plannedWorkoutToStart: PendingPlannedWorkout? = nil
    @State private var isShowingActiveWorkoutConflictAlert = false
    @State private var isPreparingApp = true

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                HomeView(
                    workoutVM: workoutVM,
                    isShowingActiveWorkout: $isShowingActiveWorkout,
                    onStartPlannedWorkout: startPlannedWorkout,
                    onStartMobility: startMobility,
                    onResumeMobility: resumeMobility,
                    onOpenNutrition: { selectedTab = .nutrition },
                    onOpenTrainMobility: openTrainMobility,
                    onOpenTrainingCalendar: { todayPath.append(.trainingCalendar) },
                    onOpenSettings: { todayPath.append(.settings) },
                    requestedRescheduleProgressID: $requestedRescheduleProgressID
                )
                .navigationDestination(for: TodayRoute.self) { route in
                    switch route {
                    case .trainingCalendar:
                        TrainingCalendarView(
                            onStartPlannedWorkout: startPlannedWorkout,
                            onOpenNutrition: { selectedTab = .nutrition },
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
                        SettingView()
                    }
                }
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.icon)
                    .accessibilityIdentifier(AppTab.today.accessibilityIdentifier)
            }
            .tag(AppTab.today)

            NavigationStack(path: $trainPath) {
                FolderView(
                    onStartWorkout: startWorkout,
                    onStartPlannedWorkout: startPlannedWorkout,
                    onShowArchivedExercises: {
                        trainPath.append(.archivedExercises)
                    }
                )
                .navigationDestination(for: LibraryRoute.self) { route in
                    switch route {
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
                    case .plan(let planID):
                        if let plan = plan(id: planID) {
                            PlanDetailView(
                                plan: plan,
                                onStartPlannedWorkout: startPlannedWorkout
                            )
                        } else {
                            ContentUnavailableView(
                                "Program unavailable",
                                systemImage: AppIcon.warning,
                                description: Text("This program may have been removed or replaced.")
                            )
                        }
                    case .mobility:
                        MobilityLibraryView(onStart: { routine, context, workoutID in
                            startMobility(routine, context, workoutID)
                        })
                    }
                }
            }
            .tabItem {
                Label(AppTab.train.title, systemImage: AppTab.train.icon)
                    .accessibilityIdentifier(AppTab.train.accessibilityIdentifier)
            }
            .tag(AppTab.train)

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
                Label(AppTab.nutrition.title, systemImage: AppTab.nutrition.icon)
                    .accessibilityIdentifier(AppTab.nutrition.accessibilityIdentifier)
            }
            .tag(AppTab.nutrition)

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
                Label(AppTab.progress.title, systemImage: AppTab.progress.icon)
                    .accessibilityIdentifier(AppTab.progress.accessibilityIdentifier)
            }
            .tag(AppTab.progress)
        }
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
        .fullScreenCover(isPresented: $isShowingActiveWorkout, onDismiss: {
            activeWorkoutPath.removeAll()
            if shouldDiscardActiveWorkout {
                workoutVM.discardActiveWorkout(using: modelContext)
                shouldDiscardActiveWorkout = false
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
                            onDiscardRequested: requestDiscardActiveWorkout
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingActiveMobility, onDismiss: {
            activeMobilitySessionID = nil
        }) {
            NavigationStack {
                if let session = mobilitySession(id: activeMobilitySessionID) {
                    MobilitySessionView(session: session) {
                        isShowingActiveMobility = false
                    }
                } else {
                    ContentUnavailableView(
                        "Mobility session unavailable",
                        systemImage: AppIcon.warning,
                        description: Text("The session may have been removed."))
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
                templateToStart = nil
                plannedWorkoutToStart = nil
            }
            Button("Discard & Start New", role: .destructive) {
                workoutVM.discardActiveWorkout(using: modelContext)
                if let pendingWorkout = plannedWorkoutToStart {
                    _ = workoutVM.startWorkout(
                        from: pendingWorkout.plannedWorkout,
                        progress: pendingWorkout.progress,
                        in: pendingWorkout.planRun,
                        using: modelContext
                    )
                    isShowingActiveWorkout = workoutVM.hasActiveWorkout
                } else if let template = templateToStart {
                    workoutVM.startWorkout(with: template, using: modelContext)
                    isShowingActiveWorkout = true
                }
                templateToStart = nil
                plannedWorkoutToStart = nil
            }
            Button("Cancel", role: .cancel) {
                templateToStart = nil
                plannedWorkoutToStart = nil
            }
        } message: {
            Text("Do you want to continue your active workout, or discard it and start a new one?")
        }
        .task {
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
            seedExerciseTemplatesIfNeeded()
            seedProgramLibraryIfNeeded()
            seedWorkoutTemplatesIfNeeded()
            seedWorkoutCollectionsIfNeeded()
            seedWorkoutPlansIfNeeded()
            MobilitySeedData.seedIfNeeded(using: modelContext)
            NutritionSeedData.seedIfNeeded(using: modelContext)
            normalizePersistedWorkoutData()
            if fixture == nil || fixture?.refreshesPlanRunAvailability == true {
                refreshActivePlanRuns()
            }
            if CommandLine.arguments.contains("-ui-testing-import-valid") {
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
                // A test reset has just deleted every persisted workout. Avoid
                // restoring a stale in-memory result while SwiftData finishes
                // reconciling that deletion with its query cache.
                workoutVM.restoreActiveWorkout(using: modelContext)
            }
            if let session = MobilitySessionService.activeSession(using: modelContext) {
                activeMobilitySessionID = session.id
                isShowingActiveMobility = true
            }
            if CommandLine.arguments.contains("-ui-testing-open-exercise-detail"),
               let benchPress = try? modelContext.fetch(
                   FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Bench Press" })
               ).first {
                selectedTab = .train
                trainPath = [.exercise(benchPress.id)]
            }
            if CommandLine.arguments.contains("-ui-testing-open-plan-reminder-reschedule"),
               let run = try? modelContext.fetch(FetchDescriptor<PlanRun>()).first(where: { $0.status == .active }),
               let progress = run.orderedWorkoutProgress.first(where: {
                   PlanReminderEligibility.isActionableToday($0, in: run)
               }) {
                PlanNotificationRouter.shared.submit(
                    PlanNotificationDestination(
                        planID: run.sourcePlanID,
                        runID: run.id,
                        progressID: progress.id,
                        action: .reschedule
                    )
                )
            }
            consumePendingPlanNotificationDestination()
            isPreparingApp = false
            await PlanNotificationScheduler.shared.reconcile(using: modelContext)
            await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .gymDataRestored)) { _ in
            templateToStart = nil
            plannedWorkoutToStart = nil
            isShowingActiveWorkout = false
            workoutVM.restoreActiveWorkout(using: modelContext)
            Task {
                await PlanNotificationScheduler.shared.reconcile(using: modelContext)
                await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .planScheduleDidChange)) { _ in
            Task { await PlanNotificationScheduler.shared.reconcile(using: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .planNotificationOpened)) { notification in
            guard let destination = notification.object as? PlanNotificationDestination else { return }
            handlePlanNotificationDestination(destination)
            _ = PlanNotificationRouter.shared.consumePendingDestination()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save modelContext on backgrounding: \(error)")
                }
            } else if newPhase == .active {
                workoutVM.reconcileLiveActivity()
                Task {
                    await PlanNotificationScheduler.shared.reconcile(using: modelContext)
                    await CheckInNotificationScheduler.shared.reconcile(using: modelContext)
                }
            }
        }
    }

    private func plan(id: UUID) -> WorkoutPlan? {
        try? modelContext.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.id == id }
    }

    private func consumePendingPlanNotificationDestination() {
        guard let destination = PlanNotificationRouter.shared.consumePendingDestination() else { return }
        handlePlanNotificationDestination(destination)
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

    private func mobilitySession(id: UUID?) -> MobilitySession? {
        guard let id else { return nil }
        return try? modelContext.fetch(FetchDescriptor<MobilitySession>()).first { $0.id == id }
    }

    private func startMobility(_ routine: MobilityRoutine, _ context: MobilitySessionContext, _ workoutID: UUID?) {
        guard let session = MobilitySessionService.start(
            routine: routine,
            context: context,
            workoutID: workoutID,
            using: modelContext
        ) else { return }
        activeMobilitySessionID = session.id
        isShowingActiveMobility = true
    }

    private func resumeMobility(_ session: MobilitySession) {
        activeMobilitySessionID = session.id
        isShowingActiveMobility = true
    }

    private func openTrainMobility() {
        selectedTab = .train
        trainPath = [.mobility]
    }

    private func exercise(id: UUID) -> Exercise? {
        try? modelContext.fetch(FetchDescriptor<Exercise>()).first { $0.id == id }
    }

    private func seedExerciseTemplatesIfNeeded() {
        do {
            let existingExercises = try modelContext.fetch(FetchDescriptor<Exercise>())
            let existingByName = Dictionary(uniqueKeysWithValues: existingExercises.map { ($0.name, $0) })
            var didChangeTemplates = false

            for template in ExerciseSeedData.templates() {
                if let existingTemplate = existingByName[template.name] {
                    if existingTemplate.equipmentType != template.equipmentType {
                        existingTemplate.equipmentType = template.equipmentType
                        didChangeTemplates = true
                    }
                    if existingTemplate.isPlateLoaded != template.isPlateLoaded {
                        existingTemplate.isPlateLoaded = template.isPlateLoaded
                        didChangeTemplates = true
                    }
                } else {
                    modelContext.insert(template)
                    didChangeTemplates = true
                }
            }

            if didChangeTemplates {
                try modelContext.save()
            }
            _ = try ExerciseRelationshipSeedData.seed(in: modelContext)
        } catch {
            print("Failed to seed exercise templates: \(error)")
        }
    }

    private func runDataMaintenance() {
        do {
            _ = try DataMaintenanceService.runOrphanCleanupIfNeeded(using: modelContext)
        } catch {
            print("Failed to clean orphaned workout data: \(error)")
        }
    }

    private func seedProgramLibraryIfNeeded() {
        do {
            _ = try ProgramLibrarySeedData.seedBundledCatalog(in: modelContext)
        } catch {
            assertionFailure("Failed to seed bundled program library: \(error.localizedDescription)")
        }
    }

    private func seedWorkoutTemplatesIfNeeded() {
        do {
            let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
            let existingTemplates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
            let existingNames = Set(existingTemplates.map(\.name))

            for template in WorkoutTemplateSeedData.templates(using: exercises) where !existingNames.contains(template.name) {
                modelContext.insert(template)
            }
            try modelContext.save()
        } catch {
            print("Failed to seed workout templates: \(error)")
        }
    }

    private func seedWorkoutCollectionsIfNeeded() {
        do {
            let existingCollections = try modelContext.fetch(FetchDescriptor<WorkoutCollection>())
            guard existingCollections.isEmpty else { return }

            let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
            let seedNames = Set(WorkoutTemplateSeedData.seededTemplateNames)
            let programTemplates = templates.filter { seedNames.contains($0.name) }
            guard !programTemplates.isEmpty else { return }

            let orderedTemplates = WorkoutTemplateSeedData.seededTemplateNames.compactMap { name in
                programTemplates.first { $0.name == name }
            }
            let collection = WorkoutCollection(name: WorkoutTemplateSeedData.collectionName, workoutTemplates: orderedTemplates)
            modelContext.insert(collection)
            try modelContext.save()
        } catch {
            print("Failed to seed workout collections: \(error)")
        }
    }

    private func seedWorkoutPlansIfNeeded() {
        do {
            let plans = try modelContext.fetch(FetchDescriptor<WorkoutPlan>())
            guard !plans.contains(where: { $0.name == SacroiliacRehabPlanSeedData.planName }) else { return }
            let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
            guard let plan = SacroiliacRehabPlanSeedData.makePlan(using: exercises) else { return }
            modelContext.insert(plan)
            try modelContext.save()
        } catch {
            print("Failed to seed sacroiliac rehabilitation plan: \(error)")
        }
    }

    private func startFreeWorkout() {
        if !workoutVM.hasActiveWorkout {
            workoutVM.startWorkout(using: modelContext)
        }
        isShowingActiveWorkout = workoutVM.hasActiveWorkout
    }

    private func startWorkout(from template: WorkoutTemplate) {
        if workoutVM.hasActiveWorkout {
            templateToStart = template
            isShowingActiveWorkoutConflictAlert = true
        } else {
            workoutVM.startWorkout(with: template, using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private func startPlannedWorkout(_ planRun: PlanRun, _ progress: PlanWorkoutProgress) {
        guard let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: planRun) else { return }

        if workoutVM.hasActiveWorkout {
            plannedWorkoutToStart = PendingPlannedWorkout(
                planRun: planRun,
                progress: progress,
                plannedWorkout: plannedWorkout
            )
            isShowingActiveWorkoutConflictAlert = true
        } else if workoutVM.startWorkout(
            from: plannedWorkout,
            progress: progress,
            in: planRun,
            using: modelContext
        ) {
            isShowingActiveWorkout = true
        }
    }

    private func resetDataForUITesting() {
        isShowingActiveWorkout = false
        shouldDiscardActiveWorkout = false
        activeWorkoutPath.removeAll()
        templateToStart = nil
        plannedWorkoutToStart = nil
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
        } catch {
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

private struct PendingPlannedWorkout {
    let planRun: PlanRun
    let progress: PlanWorkoutProgress
    let plannedWorkout: PlannedWorkout
}
