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

    private init() {}

    func startWorkout(startTime : Date) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("Live Activities disabled")
                return
            }

        let attributes = GymTrackerAttributes(startTime: startTime)

            let state = GymTrackerAttributes.ContentState()

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
    
    func update(){
        // idk
    }
    func updateExerciceAfterSet(
        exercice : String,
        rep: String,
        numberSet : String
    ) async  {
        let newState = GymTrackerAttributes.ContentState(
                    currentExerciseName: exercice
                )

                let newContent = ActivityContent(
                    state: newState,
                    staleDate: nil
                )

        await activity?.update(newContent)

                print("Live Activity updated")
        
        
    }
    func startPause(){
        // show the time left of the pause
    }
    func endPause(){
        // show the info of the exercice with number of rep
    }
    func end(){
        
    }
}
