import Foundation

/// Tells a plan the app shipped apart from one the user built.
///
/// `RepeatingPlan` carries an `isBuiltIn` flag but `WorkoutPlan` does not, so
/// the seed registry is the shared source of truth. Reading the registry rather
/// than adding a model property also classifies installs that seeded before this
/// distinction existed, which a new defaulted property could not.
enum PlanOwnership {
    static func appProvidedIDs(
        _ kind: SystemSeedEntityKind,
        in seedRecords: [SystemSeedRecord]
    ) -> Set<UUID> {
        Set(
            seedRecords
                .filter { $0.isSystemProvided && $0.entityKind == kind }
                .map(\.entityID)
        )
    }

    static func isAppProvided(_ plan: WorkoutPlan, seedRecords: [SystemSeedRecord]) -> Bool {
        appProvidedIDs(.workoutPlan, in: seedRecords).contains(plan.id)
    }

    static func isAppProvided(_ plan: RepeatingPlan, seedRecords: [SystemSeedRecord]) -> Bool {
        plan.isBuiltIn || appProvidedIDs(.repeatingPlan, in: seedRecords).contains(plan.id)
    }
}
