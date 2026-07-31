import Foundation
import SwiftData

extension ModelContext {
    /// Keeps a failed persistence operation from leaving deleted or edited
    /// models registered in this context for a later unrelated save. Callers
    /// that need to present an error can use the Boolean result while the
    /// rollback restores the last committed graph immediately.
    @discardableResult
    func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            print("Failed to save SwiftData changes: \(error)")
            return false
        }
    }

    func clearAllGymData(saveChanges: Bool = true) throws {
        let workouts = try fetch(FetchDescriptor<Workout>())
        for workout in workouts {
            workout.sourceTemplate = nil
        }

        // Delete graph roots, never relationship children by batch request. This
        // lets SwiftData apply the same cascade and nullification rules that the
        // app uses for a real discard or deletion.
#if !GYMTRACKER_EXTENSION
        for record in try fetch(FetchDescriptor<SystemSeedRecord>()) { delete(record) }
#endif
        for workout in workouts { delete(workout) }
        for session in try fetch(FetchDescriptor<MobilityAssessmentSession>()) { delete(session) }
        for definition in try fetch(FetchDescriptor<MobilityAssessmentDefinition>()) { delete(definition) }
        for session in try fetch(FetchDescriptor<MobilitySession>()) { delete(session) }
        for routine in try fetch(FetchDescriptor<MobilityRoutine>()) { delete(routine) }
        for definition in try fetch(FetchDescriptor<MobilityDefinition>()) { delete(definition) }
        for family in try fetch(FetchDescriptor<MobilityFamily>()) { delete(family) }
        for meal in try fetch(FetchDescriptor<LoggedMeal>()) { delete(meal) }
        for template in try fetch(FetchDescriptor<MealTemplate>()) { delete(template) }
        for target in try fetch(FetchDescriptor<NutritionTarget>()) { delete(target) }
        for food in try fetch(FetchDescriptor<FoodItem>()) { delete(food) }
        for entry in try fetch(FetchDescriptor<DailyLogEntry>()) { delete(entry) }
        for entry in try fetch(FetchDescriptor<BodyWeightEntry>()) { delete(entry) }
        for occurrence in try fetch(FetchDescriptor<SupplementOccurrence>()) { delete(occurrence) }
#if !GYMTRACKER_EXTENSION
        for definition in try fetch(FetchDescriptor<ProgramDefinitionRecord>()) { delete(definition) }
        // Recommendation records have no relationship to a graph root; they
        // are scalar-only receipts keyed by plan/workout UUIDs. Delete them
        // explicitly so a UI-test reset cannot leave dangling identifiers in
        // the next backup fixture.
        for record in try fetch(FetchDescriptor<PlanProgressionRecommendationRecord>()) { delete(record) }
#endif
        for run in try fetch(FetchDescriptor<RepeatingPlanRun>()) { delete(run) }
        for plan in try fetch(FetchDescriptor<RepeatingPlan>()) { delete(plan) }
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
