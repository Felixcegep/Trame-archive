//
//  ExerciseCategory.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Strength"
    case cardio = "Cardio"
    case mobility = "Mobility"
    case flexibility = "Flexibility"
    case balance = "Balance"
    case sport = "Sport"
    case other = "Other"
}
