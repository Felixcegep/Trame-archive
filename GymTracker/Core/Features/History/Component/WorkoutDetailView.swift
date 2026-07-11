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
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time: \(formattedDate(workout.startTime))")
                    if let endTime = workout.endTime {
                        Text("End Time: \(formattedDate(endTime))")
                        Text("Duration: \(formattedDuration(start: workout.startTime, end: endTime))")
                    }
                }
            }
            
            Section {
                ForEach(workout.exercises) { exercise in
                    WorkoutDetailView(exercice: exercise)
                }
            }
        }
        .navigationTitle(workout.nom ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formattedDate(_ date: Date) -> String {
        Formatters.workoutDateFormatter.string(from: date)
    }
    
    private func formattedDuration(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct WorkoutDetailView: View {
    let exercice: ExerciceEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercice.exercice.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Equipment: \(NSLocalizedString(exercice.exercice.equipmentType?.rawValue ?? EquipmentType.other.rawValue, comment: ""))")
                Text("Primary Muscles: \(exercice.exercice.PrimaryMuscle.map { $0.displayName }.joined(separator: ", "))")
                if let secondary = exercice.exercice.SecondaryMuscle, !secondary.isEmpty {
                    Text("Secondary Muscles: \(secondary.map { $0.displayName }.joined(separator: ", "))")
                }
                if !exercice.exercice.tags.isEmpty {
                    Text("Tags: \(exercice.exercice.tags.joined(separator: ", "))")
                }
                if let comment = exercice.Comment, !comment.isEmpty {
                    Text("Note: \(comment)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            ForEach(Array(exercice.sets.enumerated()), id: \.element.persistentModelID) { index, set in
                HStack {
                    Text("Set \(index + 1)\(set.setType != .normal ? " (\(NSLocalizedString(set.setType.rawValue, comment: "")))" : "")\(set.rpe != nil ? " @ RPE \(set.rpe!)" : "")\(set.done ? " (\(NSLocalizedString("Done", comment: "")))" : "")")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(set.displayText())
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
