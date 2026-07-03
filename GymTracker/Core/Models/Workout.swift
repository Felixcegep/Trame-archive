//
//  Workout.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-02.
//

import Foundation

struct Workout: Codable {
    var nom: String
    var startTime: Date
    var endTime: Date?
}
