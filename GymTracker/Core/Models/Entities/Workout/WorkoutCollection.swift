//
//  WorkoutCollection.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-07.
//

import Foundation
import SwiftData

@Model
final class WorkoutCollection: Identifiable {
    var id = UUID()
    var name: String
    var workoutTemplates: [WorkoutTemplate]
    var isBuiltIn: Bool = false

    init(name: String, workoutTemplates: [WorkoutTemplate] = [], isBuiltIn: Bool = false) {
        self.name = name
        self.workoutTemplates = workoutTemplates
        self.isBuiltIn = isBuiltIn
    }
}
