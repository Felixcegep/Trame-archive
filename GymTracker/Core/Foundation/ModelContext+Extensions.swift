import Foundation
import SwiftData

extension ModelContext {
    func clearAllGymData() throws {
        let workouts = try fetch(FetchDescriptor<Workout>())
        for workout in workouts {
            workout.sourceTemplate = nil
        }
        try save()

        // Delete graph roots, never relationship children by batch request. This
        // lets SwiftData apply the same cascade and nullification rules that the
        // app uses for a real discard or deletion.
        for workout in workouts { delete(workout) }
        for run in try fetch(FetchDescriptor<PlanRun>()) { delete(run) }
        for plan in try fetch(FetchDescriptor<WorkoutPlan>()) { delete(plan) }
        for collection in try fetch(FetchDescriptor<WorkoutCollection>()) { delete(collection) }
        for template in try fetch(FetchDescriptor<WorkoutTemplate>()) { delete(template) }
        for exercise in try fetch(FetchDescriptor<ExerciceTemplate>()) { delete(exercise) }
        try save()
        _ = try DataMaintenanceService.cleanupOrphans(using: self)
    }
}
