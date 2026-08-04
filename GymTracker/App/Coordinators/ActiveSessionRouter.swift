import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ActiveSessionRouter {
    var activeWorkoutPath: [ActiveWorkoutRoute] = []
    var isShowingActiveWorkout = false
    var shouldDiscardActiveWorkout = false
    var isShowingActiveWorkoutConflictAlert = false
    var pendingWorkoutStart: PendingWorkoutStart?
    var workoutPreparationRequest: WorkoutPreparationRequest?
    var activeMobilitySession: MobilitySession?
    var activeAssessmentSession: MobilityAssessmentSession?

    func requestDiscardActiveWorkout() {
        shouldDiscardActiveWorkout = true
        isShowingActiveWorkout = false
    }

    func showActiveWorkout() {
        activeWorkoutPath.removeAll()
        isShowingActiveWorkout = true
    }

    func clearActiveWorkoutPath() {
        activeWorkoutPath.removeAll()
    }

    func reset() {
        isShowingActiveWorkout = false
        shouldDiscardActiveWorkout = false
        isShowingActiveWorkoutConflictAlert = false
        activeWorkoutPath.removeAll()
        pendingWorkoutStart = nil
        workoutPreparationRequest = nil
        activeMobilitySession = nil
        activeAssessmentSession = nil
    }
}
