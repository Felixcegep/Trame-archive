//
//  EquipmentType.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-06.
//

enum EquipmentType: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case kettlebell = "Kettlebell"
    case medicineBall = "Medicine Ball"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case cardioMachine = "Cardio Machine"
    case other = "Other"
}
