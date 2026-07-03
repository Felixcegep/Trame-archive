//
//  WorkoutTemplate.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

struct WorkoutTemplate: Codable {
    let name: String
    let exercises: [ExerciceTemplate]
}
