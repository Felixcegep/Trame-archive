//
//  HistoryView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-04.
//


import SwiftUI
import Foundation

struct HistoryView: View {
    let viewModel: WorkoutViewModel
    var body: some View {
        Text("History")
        
        if (viewModel.workoutList.isEmpty){
            Text("aucun entrainement disponible")
        }
        else {
            List(viewModel.workoutList){ workout in
                Text(workout.exercises[0].exercice.name)
                    .font(.title)
                
                
            }
        }
    
    }
    
    
    
}
