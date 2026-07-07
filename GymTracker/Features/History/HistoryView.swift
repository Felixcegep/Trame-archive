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
        VStack {
            if workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("aucun entrainement disponible")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List(workouts, id: \.self) { workout in
                    NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.nom ?? "Workout")
                                    .font(.headline)
                                Text(workout.startTime, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(workout.exercises.count) exercices")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}
