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

        let state = GymTrackerAttributes.ContentState(restTimeActive: false)

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
                    currentExerciseName: exercice,
                    restTimeActive: false,
                    RestTime : nil,
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
                    restTimeActive: true ,
                    RestTime : timerEndDate
                )

                let newContent = ActivityContent(
                    state: newState,
                    staleDate: nil
                )

        await activity?.update(newContent)

                print("Live Activity updated")
        
        
    }
    
    func end() async {
        guard let activity = activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        print("Live Activity ended")
    }
}
