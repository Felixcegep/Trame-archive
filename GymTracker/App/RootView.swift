//
//  RootView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation
import SwiftUI
struct RootView: View {
    @State private var workoutViewModel = WorkoutViewModel()

    var body: some View {
        
        TabView {
            NavigationStack {
                WorkoutView(viewModel: workoutViewModel)
                    .tabItem {
                        Label("Workout", systemImage: "stopwatch")
                    }
            }
        }
        
    }
}
