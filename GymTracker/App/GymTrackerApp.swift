//
//  GymTrackerApp.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    
    var body: some Scene {
        WindowGroup {
                RootView()
        }
        .modelContainer(
            for : [
                Workout.self,
                ExerciceTemplate.self,
                WorkoutTemplate.self,
                TemplateExercise.self,
                WorkoutPlan.self
            ]
        )
    }
}
