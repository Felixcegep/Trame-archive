//
//  GymTrackerAttributes.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-04.

import Foundation
import ActivityKit

// to state possible restTime that's a timer and exercise time that the number of rep that user have to do with the exercise
// to change state en need to send when restTime is finished and restTimeActive and RestTime that his the number of rest that the user choose it can be
// chosen in the workout 
struct GymTrackerAttributes: ActivityAttributes {
    let workoutID: UUID
    let startTime : Date
    struct ContentState: Codable, Hashable, Sendable {
        var currentExerciseName: String?
        var currentSerie: Int?
        var totalSeries: Int?
        var restTimeActive: Bool
        var RestTime : Date?
    }
}
