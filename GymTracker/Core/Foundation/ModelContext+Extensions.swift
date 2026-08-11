import Foundation
import SwiftData

public enum PersistenceOutcome: Sendable {
    case saved
    case failed(Error)

    public var didSave: Bool {
        if case .saved = self { return true }
        return false
    }

    public var error: Error? {
        if case let .failed(error) = self { return error }
        return nil
    }
}

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

    /// Saves, or rolls back and returns the error rather than discarding it.
    /// Prefer this over `saveOrRollback()` anywhere the failure is visible to
    /// the user or needs to reach diagnostics.
    func saveOrRollbackReportingFailure() -> PersistenceOutcome {
        do {
            try save()
            return .saved
        } catch {
            rollback()
            print("Failed to save SwiftData changes: \(error)")
            return .failed(error)
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
        // HealthKit provenance and export receipts are scalar ownership rows,
        // not children of their workout/body-weight records. Remove them
        // before their referenced roots so a reset cannot leave identifiers
        // that poison the next backup/import fixture.
        for receipt in (try? fetch(FetchDescriptor<HealthKitWorkoutExportReceipt>())) ?? [] { delete(receipt) }
        for provenance in (try? fetch(FetchDescriptor<HealthKitBodyMassProvenance>())) ?? [] { delete(provenance) }
#endif
        for split in (try? fetch(FetchDescriptor<WorkoutExecutionBlockSplit>())) ?? [] { delete(split) }
        for workout in workouts { delete(workout) }
        for session in try fetch(FetchDescriptor<MobilityAssessmentSession>()) { delete(session) }
        for definition in try fetch(FetchDescriptor<MobilityAssessmentDefinition>()) { delete(definition) }
        for session in try fetch(FetchDescriptor<MobilitySession>()) { delete(session) }
        for evidence in (try? fetch(FetchDescriptor<MobilityResultEvidence>())) ?? [] { delete(evidence) }
        for evidence in (try? fetch(FetchDescriptor<MobilityEntryEvidence>())) ?? [] { delete(evidence) }
        for evidence in (try? fetch(FetchDescriptor<MobilityRoutineItemEvidence>())) ?? [] { delete(evidence) }
        for block in (try? fetch(FetchDescriptor<MobilityRoutineBlock>())) ?? [] { delete(block) }
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
        for definition in try fetch(FetchDescriptor<MobilityProgramDefinitionRecord>()) { delete(definition) }
        // Recommendation records have no relationship to a graph root; they
        // are scalar-only receipts keyed by plan/workout UUIDs. Delete them
        // explicitly so a UI-test reset cannot leave dangling identifiers in
        // the next backup fixture.
        for record in try fetch(FetchDescriptor<PlanProgressionRecommendationRecord>()) { delete(record) }
        // The training profile is a single preference record with no
        // relationships. Cleared here so a restore replaces it rather than
        // leaving the previous device's answers alongside the imported ones.
        //
        // Tolerant of a container that does not register the model — some test
        // harnesses enumerate their own schema — because a preference record
        // that cannot be enumerated is not a reason to fail a restore of
        // someone's entire training history.
        for profile in (try? fetch(FetchDescriptor<TrainingProfile>())) ?? [] { delete(profile) }
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
