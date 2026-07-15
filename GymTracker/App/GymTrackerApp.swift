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
                Exercise.self,
                WorkoutTemplate.self,
                TemplateExercise.self,
                WorkoutCollection.self,
                WorkoutPlan.self,
                PlanBlock.self,
                PlanWeek.self,
                PlannedWorkout.self,
                PlannedExercise.self,
                PlanRun.self,
                PlanWorkoutProgress.self
            ]
        )
    }
}
