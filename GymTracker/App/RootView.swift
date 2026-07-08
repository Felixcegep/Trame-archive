//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exerciceTemplates: [ExerciceTemplate]

    @State private var workoutVM = WorkoutViewModel()
    @State private var homePath: [HomeRoute] = []

    var body: some View {
        TabView {
            NavigationStack(path: $homePath) {
                HomeView(workoutVM: workoutVM, navigationPath: $homePath)
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .activeWorkout:
                            ActiveWorkoutView(
                                workoutVM: workoutVM,
                                navigationPath: $homePath
                            )
                        case .saveWorkout:
                            WorkoutSaveView(
                                workoutVM: workoutVM,
                                navigationPath: $homePath
                            )
                        }
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                FolderView()
            }
            .tabItem {
                Label("Folders", systemImage: "folder.fill")
            }

            NavigationStack {
                HistoryView(viewModel: workoutVM)
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
        }
        .task {
            seedExerciseTemplatesIfNeeded()
        }
    }

    private func seedExerciseTemplatesIfNeeded() {
        let existingNames = Set(exerciceTemplates.map(\.name))

        var didInsertTemplate = false
        for template in ExerciseSeedData.templates() {
            guard !existingNames.contains(template.name) else { continue }
            modelContext.insert(template)
            didInsertTemplate = true
        }

        guard didInsertTemplate else { return }

        do {
            try modelContext.save()
        } catch {
            print("Failed to seed exercise templates: \(error)")
        }
    }
}
