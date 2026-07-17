//
//  GymTrackerAttributes.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-04.

import ActivityKit
import Foundation

enum LiveActivityRestPhase: String, Codable, Hashable, Sendable {
    case inactive
    case running
    case paused
}

/// A Codable display projection of persisted `Workout` truth. It deliberately
/// contains no independently mutable workout state.
struct LiveActivityProjection: Hashable, Sendable {
    let workoutID: UUID
    let startTime: Date
    let currentExerciseName: String?
    let currentSet: Int?
    let totalSets: Int?
    let currentExerciseOrderIndex: Int?
    let currentSetOrderIndex: Int?
    let restPhase: LiveActivityRestPhase
    let restEndDate: Date?
    let pausedRemainingTime: TimeInterval?

    @MainActor
    init(workout: Workout, now: Date = .now) {
        let next = workout.orderedExercises.lazy.compactMap { exercise -> (ExerciseEntry, ExerciseSet)? in
            guard let set = exercise.orderedSets.first(where: { !$0.done }) else { return nil }
            return (exercise, set)
        }.first

        self.workoutID = workout.id
        self.startTime = workout.startTime
        self.currentExerciseName = next?.0.nameSnapshot
        self.currentSet = next.map { $0.1.orderIndex + 1 }
        self.totalSets = next?.0.orderedSets.count
        self.currentExerciseOrderIndex = next?.0.orderIndex
        self.currentSetOrderIndex = next?.1.orderIndex

        if let deadline = workout.restEndDate, deadline > now {
            self.restPhase = .running
            self.restEndDate = deadline
            self.pausedRemainingTime = nil
        } else if let remaining = workout.pausedRemainingTime, remaining > 0 {
            self.restPhase = .paused
            self.restEndDate = nil
            self.pausedRemainingTime = remaining
        } else {
            self.restPhase = .inactive
            self.restEndDate = nil
            self.pausedRemainingTime = nil
        }
    }
}

struct GymTrackerAttributes: ActivityAttributes {
    let workoutID: UUID
    let startTime: Date

    struct ContentState: Codable, Hashable, Sendable {
        var currentExerciseName: String?
        var currentSet: Int?
        var totalSeries: Int?
        var currentExerciseOrderIndex: Int?
        var currentSetOrderIndex: Int?
        var restPhase: LiveActivityRestPhase
        var restEndDate: Date?
        var pausedRemainingTime: TimeInterval?
    }
}
