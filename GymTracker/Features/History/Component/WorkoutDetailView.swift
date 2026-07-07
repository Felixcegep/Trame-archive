//
//  HistoryWorkoutView.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import SwiftUI
import SwiftData

struct HistoryWorkoutView: View {
    let workout: Workout
    
    var body: some View {
        List(workout.exercises) { exercise in
            WorkoutDetailView(exercice: exercise)
        }
        .navigationTitle(workout.nom ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutDetailView: View {
    let exercice: ExerciceEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercice.exercice.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(Array(exercice.sets.enumerated()), id: \.element.persistentModelID) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedSet(set))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedSet(_ set: ExerciseSet) -> String {
        if let duration = set.duration, duration > 0 {
            if let distance = set.distance, distance > 0 {
                return String(format: "%ds @ %.2f %@", Int(duration), distance, set.distanceType.rawValue)
            }
            return "\(Int(duration))s"
        }
        
        if set.weight > 0 {
            return "\(Int(set.repetition)) x \(String(format: "%.1f", set.weight)) \(set.weightType.rawValue)"
        } else {
            return "\(Int(set.repetition)) reps"
        }
    }
}
