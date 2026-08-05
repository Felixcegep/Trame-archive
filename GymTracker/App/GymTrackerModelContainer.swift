import Foundation
import SwiftData

/// Diagnostic-only label for the shape of the persisted SwiftData schema
/// below. This is distinct from `BackupDTO.currentVersion` (the portable
/// backup/export format) and from the Program Engine's own schema version —
/// none of the three should be conflated. Bump this whenever a persisted
/// model's stored shape changes, so a beta feedback report can distinguish
/// testers running different schema generations.
enum GymTrackerAppSchema {
    static let diagnosticVersion = "14"

    /// What the shipped build actually does with iCloud. This is deliberately
    /// a literal, not derived from CloudSyncEnvironment: the point is that a
    /// beta feedback report states the truth even if a future configuration
    /// change is made without updating the user-facing copy.
    static let cloudSyncState = "disabled"
}

/// First additive schema after the verified baseline. The existing models are
/// intentionally untouched; the transition only introduces mobility-owned
/// prescription and performed-evidence records.
enum GymTrackerAdvancedMobilityEvidenceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        var types = GymTrackerCurrentBaselineSchema.models + [
            MobilityRoutineItemEvidence.self,
            MobilityResultEvidence.self,
            MobilityRoutineBlock.self,
            MobilityEntryEvidence.self
        ]
#if !GYMTRACKER_EXTENSION
        // The mobility program definition graph (Release 8 part 1) extends
        // this same V2 generation in place, exactly like the four models
        // above already did: additive, optional-decode, no new schema
        // version. It is app-only, mirroring `ProgramDefinitionRecord`'s own
        // extension gate on the baseline schema below.
        types.append(MobilityProgramDefinitionRecord.self)
        // The mobility program runtime (Release 8 part 2) extends the same
        // V2 generation in place again: a run, its per-session progress,
        // its per-(progressionKey, side) progression state, and its
        // recommendation receipts. All four are new tables with no existing
        // column changes, so this stays additive under the frozen
        // `Schema.Version(2, 0, 0)` identifier — neither part has shipped.
        types.append(MobilityProgramRun.self)
        types.append(MobilityProgramSessionProgress.self)
        types.append(MobilityProgressionState.self)
        types.append(MobilityProgressionRecommendationRecord.self)
#endif
        return types
    }
}

/// The exact persisted model list used by the current shipping baseline.
///
/// This is intentionally named for what has been verified rather than called
/// `V1`: earlier shipped shapes have not yet been reconstructed as versioned
/// schemas, and this declaration must not imply support that has not been
/// proven. Its `1.0.0` identifier preserves the version SwiftData assigned to
/// the preceding ad-hoc `Schema(types)` construction. The independent product
/// diagnostic label remains `GymTrackerAppSchema.diagnosticVersion`.
enum GymTrackerCurrentBaselineSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        var types: [any PersistentModel.Type] = [
            Workout.self,
            WorkoutExecutionBlock.self,
            Exercise.self,
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            ExerciseSetSegment.self,
            ComplexComponentResult.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateExerciseBlock.self,
            WorkoutCollection.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseBlock.self,
            PlannedSet.self,
            PlannedExerciseAlternative.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            RepeatingPlan.self,
            RepeatingPlanSlot.self,
            RepeatingPlanRun.self,
            RepeatingPlanRunSlot.self,
            RepeatingPlanOccurrence.self,
            DailyLogEntry.self,
            BodyWeightEntry.self,
            SupplementOccurrence.self,
            MobilityFamily.self,
            MobilityDefinition.self,
            MobilityRoutine.self,
            // SwiftData expands the registered relationship graph: the
            // cascade children MobilityPhasePrescription and
            // MobilityPhaseResult are already part of the effective schema
            // through MobilityRoutineItem and MobilityEntry. Keep this frozen
            // explicit list identical to the verified pre-versioning list;
            // redundantly naming relationship-discovered children here would
            // not represent a new persisted model version.
            MobilityRoutineItem.self,
            MobilitySession.self,
            MobilityEntry.self,
            MobilityResult.self,
            MobilityAssessmentDefinition.self,
            MobilityAssessmentSession.self,
            MobilityAssessmentResult.self,
            MobilityAssessmentSample.self,
            FoodItem.self,
            FoodServing.self,
            MealTemplate.self,
            MealTemplateItem.self,
            LoggedMeal.self,
            LoggedMealItem.self,
            NutritionTarget.self
        ]
#if !GYMTRACKER_EXTENSION
        types.append(SystemSeedRecord.self)
        types.append(ProgramDefinitionRecord.self)
        types.append(PlanProgressionRecommendationRecord.self)
        types.append(TrainingProfile.self)
#endif
        return types
    }
}

/// Migration infrastructure from the verified baseline into the first
/// additive post-baseline schema. Earlier historical shapes still require
/// retained source/store evidence before they can be declared safely.
enum GymTrackerSchemaMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        GymTrackerCurrentBaselineSchema.self,
        GymTrackerAdvancedMobilityEvidenceSchema.self
    ]

    static let stages: [MigrationStage] = [
        .lightweight(
            fromVersion: GymTrackerCurrentBaselineSchema.self,
            toVersion: GymTrackerAdvancedMobilityEvidenceSchema.self
        )
    ]
}

/// The one persistent store used by both the SwiftUI scene and
/// `LiveActivityIntent` executions. A Live Activity intent runs in the app
/// process, so it can safely use this container without an App Group store.
@MainActor
enum GymTrackerModelContainer {
    enum BootstrapState {
        case ready(ModelContainer)
        case unavailable(String)
    }

    /// A failed store open should not terminate the process: the app renders a
    /// recovery state without attaching a context, so it cannot overwrite a
    /// recoverable on-disk store with a fresh empty one.
    ///
    /// **This only holds for failures SwiftData reports as a Swift `Error`.**
    /// Verified the hard way: a malformed migration plan made CoreData raise an
    /// `NSException` from `addPersistentStoreWithDescription:` instead, which
    /// `catch` below cannot intercept, so the process hit `SIGABRT` on launch
    /// and the recovery state was never reached. If store-open failure has to
    /// be survivable for every cause, the open needs an Objective-C shim that
    /// catches `NSException`, or a pre-flight compatibility check against the
    /// store's metadata before the container is built. Neither exists yet.
    static let bootstrapState: BootstrapState = {
        // The recovery state is otherwise reachable only through a real store
        // failure, which no UI test can provoke, so it has never had a
        // screenshot. Capture-only: the argument is never passed by a shipped
        // launch, and the branch attaches no context, exactly like the real
        // failure path.
        if CommandLine.arguments.contains("-ui-testing-storage-unavailable") {
            return .unavailable("Simulated store failure for screenshot capture.")
        }
        let persistence = GymTrackerPersistenceConfiguration()
        // Build the configuration once and reuse it, so the store that gets
        // copied aside is provably the same one that is about to be opened.
        let configuration = persistence.makeModelConfiguration()
        let currentVersion = GymTrackerAdvancedMobilityEvidenceSchema.versionIdentifier

        let backupOutcome = GymTrackerPreMigrationBackup.backUpIfSchemaVersionChanged(
            storeURL: configuration.url,
            currentVersion: currentVersion
        )

        do {
            let container = try persistence.makeContainer(using: configuration)
            // Only a completed open proves the migration succeeded, so the
            // recorded version advances here and nowhere else. A throw leaves
            // the marker on the previous version, which is what stops the next
            // launch from copying a damaged store over a good backup.
            GymTrackerPreMigrationBackup.recordSuccessfulOpen(
                storeURL: configuration.url,
                version: currentVersion
            )
            return .ready(container)
        } catch {
            print("Unable to create GymTracker's persistent model container: \(error)")
            let recovery = backupOutcome.recoveryDescription.map { " \($0)" } ?? ""
            return .unavailable("\(error.localizedDescription)\(recovery)")
        }
    }()

    static var shared: ModelContainer? {
        guard case let .ready(container) = bootstrapState else { return nil }
        return container
    }

    /// Retained for existing callers and test helpers that consume a `Schema`
    /// value directly. The model list now has one owner: the named current
    /// baseline above.
    static let schema = Schema(versionedSchema: GymTrackerAdvancedMobilityEvidenceSchema.self)
}
