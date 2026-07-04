//
//  HomeView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-04.
//

import Foundation
import SwiftUI
struct HomeView: View {
    let workoutVM: WorkoutViewModel
    @State private var goToWorkout = false

    var body: some View {
        VStack {
            Text("Home")
            if workoutVM.workout != nil {
                        Text("Ajouter exercice")
                    } else {
                        Text("Lancer Workout")
                    }
            
            Button("Lancer Workout") {
                workoutVM.startWorkout()
                goToWorkout = true
            }
        }
        .navigationDestination(isPresented: $goToWorkout) {
            WorkoutView(viewModel: workoutVM)
        }
    }
}
