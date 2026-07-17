import Foundation
import SwiftData

extension ModelContext {
    func clearAllGymData(saveChanges: Bool = true) throws {
        let workouts = try fetch(FetchDescriptor<Workout>())
        for workout in workouts {
            workout.sourceTemplate = nil
        }

        // Delete graph roots, never relationship children by batch request. This
        // lets SwiftData apply the same cascade and nullification rules that the
        // app uses for a real discard or deletion.
        for workout in workouts { delete(workout) }
        for run in try fetch(FetchDescriptor<PlanRun>()) { delete(run) }
        for plan in try fetch(FetchDescriptor<WorkoutPlan>()) { delete(plan) }
        for collection in try fetch(FetchDescriptor<WorkoutCollection>()) { delete(collection) }
        for template in try fetch(FetchDescriptor<WorkoutTemplate>()) { delete(template) }
        for relationship in try fetch(FetchDescriptor<ExerciseRelationship>()) { delete(relationship) }
        for exercise in try fetch(FetchDescriptor<Exercise>()) { delete(exercise) }
        if saveChanges {
            try save()
            processPendingChanges()
            _ = try DataMaintenanceService.cleanupOrphans(using: self)

            // UI-test resets must not proceed while a stale active workout is
            // still visible to the next launch. Fetch after SwiftData has
            // processed the deletion transaction so callers can trust that the
            // store is actually empty.
            if try fetch(FetchDescriptor<Workout>()).isEmpty == false {
                throw GymDataResetError.workoutsRemain
            }
        }
    }
}

enum GymDataResetError: LocalizedError {
    case workoutsRemain

    var errorDescription: String? {
        "GymTracker reset completed without removing every workout."
    }
}
