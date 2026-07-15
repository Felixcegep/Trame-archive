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
    private enum AppTab: Hashable {
        case home
        case library
        case history
        case settings
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var exerciceTemplates: [ExerciceTemplate]

    @State private var workoutVM = WorkoutViewModel()
    @State private var homePath: [HomeRoute] = []
    @State private var activeWorkoutPath: [HomeRoute] = []
    @State private var isShowingActiveWorkout = false
    @State private var shouldDiscardActiveWorkout = false
    @State private var selectedTab: AppTab = .home
    @State private var templateToStart: WorkoutTemplate? = nil
    @State private var plannedWorkoutToStart: PendingPlannedWorkout? = nil
    @State private var isShowingActiveWorkoutConflictAlert = false
    @State private var isPreparingApp = true

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(
                    workoutVM: workoutVM,
                    navigationPath: $homePath,
                    isShowingActiveWorkout: $isShowingActiveWorkout,
                    onStartPlannedWorkout: startPlannedWorkout
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
                    .accessibilityIdentifier("tab-home")
            }
            .tag(AppTab.home)

            NavigationStack {
                FolderView(
                    onStartWorkout: startWorkout,
                    onStartPlannedWorkout: startPlannedWorkout
                )
            }
            .tabItem {
                Label("Library", systemImage: "folder.fill")
                    .accessibilityIdentifier("tab-library")
            }
            .tag(AppTab.library)

            NavigationStack {
                HistoryView(viewModel: workoutVM, onStartFreeWorkout: startFreeWorkout)
            }
            .tabItem {
                Label("History", systemImage: "clock")
                    .accessibilityIdentifier("tab-history")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingView()
            }
            .tabItem {
                Label("Settings", systemImage: AppIcon.settings)
                    .accessibilityIdentifier("tab-settings")
            }
            .tag(AppTab.settings)
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
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .activeWorkout:
                        EmptyView()
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
                selectedTab = .history
            }

            if CommandLine.arguments.contains("-ui-testing-open-library") {
                selectedTab = .library
            }

            if CommandLine.arguments.contains("-ui-testing-open-settings") {
                selectedTab = .settings
            }

            if isResettingForUITesting {
                resetDataForUITesting()
            }
            runDataMaintenance()
            seedExerciseTemplatesIfNeeded()
            seedWorkoutTemplatesIfNeeded()
            seedWorkoutCollectionsIfNeeded()
            normalizePersistedWorkoutData()
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
            isPreparingApp = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .gymDataRestored)) { _ in
            homePath = []
            templateToStart = nil
            plannedWorkoutToStart = nil
            isShowingActiveWorkout = false
            workoutVM.restoreActiveWorkout(using: modelContext)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save modelContext on backgrounding: \(error)")
                }
            }
        }
    }

    private func seedExerciseTemplatesIfNeeded() {
        do {
            let existingExercises = try modelContext.fetch(FetchDescriptor<ExerciceTemplate>())
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

    private func seedWorkoutTemplatesIfNeeded() {
        do {
            let exercises = try modelContext.fetch(FetchDescriptor<ExerciceTemplate>())
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
        homePath.removeAll()
        activeWorkoutPath.removeAll()
        templateToStart = nil
        plannedWorkoutToStart = nil
        workoutVM.workout = nil
        workoutVM.activeWorkout = nil

        do {
            try modelContext.clearAllGymData()
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
}

private struct PendingPlannedWorkout {
    let planRun: PlanRun
    let progress: PlanWorkoutProgress
    let plannedWorkout: PlannedWorkout
}
