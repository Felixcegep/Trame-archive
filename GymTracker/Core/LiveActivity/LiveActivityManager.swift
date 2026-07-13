//
//  LiveActivityManager.swift
//  GymTracker
//
//  Created by Felix Lachapelle on 2026-07-05.
//

import ActivityKit
import Foundation
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    
    private var activity: Activity<GymTrackerAttributes>?
    private var currentExerciseName: String?
    private var currentSerie: Int?
    private var totalSeries: Int?

    private init() {}

    func startWorkout(startTime : Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities disabled")
            return
        }

        // A Live Activity survives process relaunch. Reuse it instead of
        // requesting another activity for the same resumed workout.
        if let existingActivity = Activity<GymTrackerAttributes>.activities.first {
            activity = existingActivity
            return
        }

        let attributes = GymTrackerAttributes(startTime: startTime)

        let state = GymTrackerAttributes.ContentState(
            currentExerciseName: currentExerciseName,
            currentSerie: currentSerie,
            totalSeries: totalSeries,
            restTimeActive: false,
            RestTime: nil
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )

            print("Live Activity started")
        } catch {
            print("Failed to start Live Activity:", error)
        }
    }
    func updateExercise(
        name: String,
        currentSet: Int,
        totalSets: Int
    ) async {
        currentExerciseName = name
        currentSerie = currentSet
        totalSeries = totalSets

        let newState = GymTrackerAttributes.ContentState(
            currentExerciseName: name,
            currentSerie: currentSet,
            totalSeries: totalSets,
            restTimeActive: false,
            RestTime: nil
        )

                let newContent = ActivityContent(
                    state: newState,
                    staleDate: nil
                )

        await activity?.update(newContent)

                print("Live Activity updated")
        
        
    }

    func startPause(timerEndDate : Date) async {
        // show the time left of the pause
        let newState = GymTrackerAttributes.ContentState(
            currentExerciseName: currentExerciseName,
            currentSerie: currentSerie,
            totalSeries: totalSeries,
            restTimeActive: true,
            RestTime: timerEndDate
        )

                let newContent = ActivityContent(
                    state: newState,
                    staleDate: nil
                )

        await activity?.update(newContent)

                print("Live Activity updated")
    }

    func pausePause() async {
        let newState = GymTrackerAttributes.ContentState(
            currentExerciseName: currentExerciseName,
            currentSerie: currentSerie,
            totalSeries: totalSeries,
            restTimeActive: false,
            RestTime: nil
        )

        let newContent = ActivityContent(
            state: newState,
            staleDate: nil
        )

        await activity?.update(newContent)
        print("Live Activity paused")
    }
    
    func end() async {
        guard let activity = activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        currentExerciseName = nil
        currentSerie = nil
        totalSeries = nil
        print("Live Activity ended")
    }
}
