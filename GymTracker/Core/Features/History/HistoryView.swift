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
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.startTime, order: .reverse) var workouts: [Workout]
    let viewModel: WorkoutViewModel
    
    var body: some View {
        VStack {
            if completedWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workout History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed workouts will appear here.")
                )
            } else {
                List(completedWorkouts, id: \.self) { workout in
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
                            Text("\(workout.exercises.count) exercises")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.gymCard)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeWorkout(using: modelContext, workout: workout)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.gymBackground)
            }
        }
        .background(Color.gymBackground)
        .navigationTitle("History")
    }

    private var completedWorkouts: [Workout] {
        workouts.filter { workout in
            workout.endTime != nil && workout.exercises.contains { exercise in
                exercise.sets.contains(where: \.done)
            }
        }
    }
}
