//
//  WorkoutSaveView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-06.
//


import SwiftUI
import SwiftData


struct WorkoutSaveView: View {
    @Environment(\.modelContext) private var modelContext

    let workoutVM: WorkoutViewModel
    @Binding var navigationPath: [HomeRoute]

    var body: some View {
        VStack {
            if let workout = workoutVM.activeWorkout {
                @Bindable var workout = workout

                TextField(
                    "Workout name",
                    text: Binding(
                        get: { workout.nom ?? "" },
                        set: { workout.nom = $0.isEmpty ? nil : $0 }
                    )
                )

                Button("Save") {
                    workoutVM.saveWorkout(using: modelContext)
                    navigationPath.removeAll()
                }
            } else {
                Text("Aucun workout en cours")

                Button("Back Home") {
                    navigationPath.removeAll()
                }
            }
        }
    }
}
