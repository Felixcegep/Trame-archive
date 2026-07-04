//
//  HistoryView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-04.
//


import SwiftUI
import Foundation
import SwiftData
struct HistoryView: View {
    @Query var workouts: [Workout]
    let viewModel: WorkoutViewModel

    var body: some View {
        Text("History")
        
        if (workouts.isEmpty){
            Text("aucun entrainement disponible")
        }
        else {
            List(workouts , id: \.self){ workout in
                Text(workout.exercises.count.description + " exercices")
                
            }
        }
    
    }
    
    
    
}
