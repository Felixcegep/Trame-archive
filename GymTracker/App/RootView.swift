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
    @State private var activeWorkoutPath: [HomeRoute] = []
    @State private var isShowingActiveWorkout = false

    var body: some View {
        TabView {
            NavigationStack(path: $homePath) {
                HomeView(
                    workoutVM: workoutVM,
                    navigationPath: $homePath,
                    isShowingActiveWorkout: $isShowingActiveWorkout
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                FolderView(onStartWorkout: startWorkout)
            }
            .tabItem {
                Label("Library", systemImage: "folder.fill")
            }

            NavigationStack {
                HistoryView(viewModel: workoutVM)
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
        }
        .fullScreenCover(isPresented: $isShowingActiveWorkout, onDismiss: {
            activeWorkoutPath.removeAll()
        }) {
            NavigationStack(path: $activeWorkoutPath) {
                ActiveWorkoutView(
                    workoutVM: workoutVM,
                    navigationPath: $activeWorkoutPath,
                    isPresented: $isShowingActiveWorkout
                )
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .activeWorkout:
                        EmptyView()
                    case .saveWorkout:
                        WorkoutSaveView(
                            workoutVM: workoutVM,
                            navigationPath: $activeWorkoutPath,
                            isPresented: $isShowingActiveWorkout
                        )
                    }
                }
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

    private func startWorkout(from template: WorkoutTemplate) {
        workoutVM.startWorkout(with: template)
        isShowingActiveWorkout = true
    }
}
