//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

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
    @State private var isShowingActiveWorkoutConflictAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(
                    workoutVM: workoutVM,
                    navigationPath: $homePath,
                    isShowingActiveWorkout: $isShowingActiveWorkout
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
                    .accessibilityIdentifier("tab-home")
            }
            .tag(AppTab.home)

            NavigationStack {
                FolderView(onStartWorkout: startWorkout)
            }
            .tabItem {
                Label("Library", systemImage: "folder.fill")
                    .accessibilityIdentifier("tab-library")
            }
            .tag(AppTab.library)

            NavigationStack {
                HistoryView(viewModel: workoutVM)
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
            }
            Button("Discard & Start New", role: .destructive) {
                workoutVM.discardActiveWorkout(using: modelContext)
                if let template = templateToStart {
                    workoutVM.startWorkout(with: template, using: modelContext)
                    isShowingActiveWorkout = true
                }
                templateToStart = nil
            }
            Button("Cancel", role: .cancel) {
                templateToStart = nil
            }
        } message: {
            Text("Do you want to continue your active workout, or discard it and start a new one?")
        }
        .task {
            if CommandLine.arguments.contains("-ui-testing-open-history") {
                selectedTab = .history
            }

            if CommandLine.arguments.contains("-reset-data") {
                resetDataForUITesting()
            }
            seedExerciseTemplatesIfNeeded()
            seedWorkoutTemplatesIfNeeded()
            normalizePersistedWorkoutData()
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

    private func startWorkout(from template: WorkoutTemplate) {
        if workoutVM.hasActiveWorkout {
            templateToStart = template
            isShowingActiveWorkoutConflictAlert = true
        } else {
            workoutVM.startWorkout(with: template, using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private func resetDataForUITesting() {
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

            let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
            for template in templates {
                let templateExercises = template.templateExercises
                let hasStableOrder = Set(templateExercises.map(\.orderIndex)).count == templateExercises.count
                guard !hasStableOrder else { continue }

                for (index, exercise) in templateExercises
                    .sorted(by: { $0.order < $1.order })
                    .enumerated() {
                    if exercise.orderIndex != index || exercise.order != index {
                        exercise.orderIndex = index
                        exercise.order = index
                        didChange = true
                    }
                }
            }

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
