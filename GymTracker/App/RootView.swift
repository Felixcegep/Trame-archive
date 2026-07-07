//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
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
        guard exerciceTemplates.isEmpty else { return }

        let templates: [ExerciceTemplate] = [

            ExerciceTemplate(
                name: "Bench Press",
                PrimaryMuscle: [.middleChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead]
            ),

            ExerciceTemplate(
                name: "Incline Bench Press",
                PrimaryMuscle: [.upperChest],
                SecondaryMuscle: [.frontDeltoid, .tricepLateralHead]
            ),

            ExerciceTemplate(
                name: "Deadlift",
                PrimaryMuscle: [.erectorSpinae, .gluteMaximus, .hamstrings],
                SecondaryMuscle: [.trapezius, .forearms]
            ),

            ExerciceTemplate(
                name: "Back Squat",
                PrimaryMuscle: [.quadriceps, .gluteMaximus],
                SecondaryMuscle: [.hamstrings, .erectorSpinae]
            ),

            ExerciceTemplate(
                name: "Overhead Press",
                PrimaryMuscle: [.frontDeltoid, .lateralDeltoid],
                SecondaryMuscle: [.tricepLongHead]
            ),

            ExerciceTemplate(
                name: "Barbell Row",
                PrimaryMuscle: [.latissimusDorsi, .rhomboids],
                SecondaryMuscle: [.rearDeltoid, .bicep, .forearms]
            ),

            ExerciceTemplate(
                name: "Pull Up",
                PrimaryMuscle: [.latissimusDorsi],
                SecondaryMuscle: [.bicep, .rhomboids]
            ),

            ExerciceTemplate(
                name: "Lat Pulldown",
                PrimaryMuscle: [.latissimusDorsi],
                SecondaryMuscle: [.bicep, .teresMajor]
            ),

            ExerciceTemplate(
                name: "Seated Cable Row",
                PrimaryMuscle: [.rhomboids, .latissimusDorsi],
                SecondaryMuscle: [.bicep, .rearDeltoid]
            ),

            ExerciceTemplate(
                name: "Barbell Curl",
                PrimaryMuscle: [.bicep],
                SecondaryMuscle: [.brachialis, .brachioradialis]
            ),

            ExerciceTemplate(
                name: "Hammer Curl",
                PrimaryMuscle: [.brachialis],
                SecondaryMuscle: [.bicep, .brachioradialis]
            ),

            ExerciceTemplate(
                name: "Triceps Pushdown",
                PrimaryMuscle: [.tricepLateralHead, .tricepMedialHead],
                SecondaryMuscle: [.tricepLongHead]
            ),

            ExerciceTemplate(
                name: "Lateral Raise",
                PrimaryMuscle: [.lateralDeltoid]
            ),

            ExerciceTemplate(
                name: "Rear Delt Fly",
                PrimaryMuscle: [.rearDeltoid],
                SecondaryMuscle: [.rhomboids]
            ),

            ExerciceTemplate(
                name: "Leg Press",
                PrimaryMuscle: [.quadriceps],
                SecondaryMuscle: [.gluteMaximus, .hamstrings]
            ),

            ExerciceTemplate(
                name: "Romanian Deadlift",
                PrimaryMuscle: [.hamstrings, .gluteMaximus],
                SecondaryMuscle: [.erectorSpinae]
            ),

            ExerciceTemplate(
                name: "Leg Extension",
                PrimaryMuscle: [.quadriceps]
            ),

            ExerciceTemplate(
                name: "Leg Curl",
                PrimaryMuscle: [.hamstrings]
            ),

            ExerciceTemplate(
                name: "Standing Calf Raise",
                PrimaryMuscle: [.calves]
            ),

            ExerciceTemplate(
                name: "Crunch",
                PrimaryMuscle: [.rectusAbdominis]
            ),

            ExerciceTemplate(
                name: "Plank",
                PrimaryMuscle: [.transverseAbdominis],
                SecondaryMuscle: [.rectusAbdominis, .obliques]
            )
        ]

        for template in templates {
            modelContext.insert(template)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to seed exercise templates: \(error)")
        }
    }
}
