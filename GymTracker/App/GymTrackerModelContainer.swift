import Foundation
import SwiftData

/// Diagnostic-only label for the shape of the persisted SwiftData schema
/// below. This is distinct from `BackupDTO.currentVersion` (the portable
/// backup/export format) and from the Program Engine's own schema version —
/// none of the three should be conflated. Bump this whenever a persisted
/// model's stored shape changes, so a beta feedback report can distinguish
/// testers running different schema generations.
enum GymTrackerAppSchema {
    static let diagnosticVersion = "16"

    /// What the shipped build actually does with iCloud. This is deliberately
    /// a literal, not derived from CloudSyncEnvironment: the point is that a
    /// beta feedback report states the truth even if a future configuration
    /// change is made without updating the user-facing copy.
    static let cloudSyncState = "disabled"
}

/// Additive metadata for a reusable definition without changing the frozen
/// V1-V3 entity shapes. `definitionID` points at an Exercise,
/// MobilityDefinition, ProgramDefinitionRecord, or
/// MobilityProgramDefinitionRecord according to `definitionKindRaw`.
/// Completed evidence never references this live descriptive record.
@Model
final class CatalogDefinitionMetadata {
    var id: UUID
    var definitionID: UUID
    var definitionKindRaw: String
    var catalogueKey: String?
    var sourceReferencesData: Data?

    // Exercise metadata.
    var muscleGroups: [String]
    var anatomicalTargetMuscles: [String]
    var anatomicalSynergistMuscles: [String]
    var descriptionText: String?
    var instructionSteps: [String]
    var videoURLString: String?
    var videoEmbedURLString: String?
    var thumbnailURLString: String?
    var imageURLString: String?
    var liftosaurURLString: String?
    var liftosaurSlug: String?

    // Mobility metadata.
    var categoryRaw: String?
    var difficultyRaw: String?
    var equipmentLabels: [String]
    var primaryMuscleLabels: [String]
    var secondaryMuscleLabels: [String]
    var sanskritName: String?
    var metValue: Double?
    var benefitsText: String?
    var svgURLString: String?

    // Reserved source-authoring metadata. The future DSL may populate these,
    // but no parser or second runtime exists in this schema slice.
    var authoringLanguage: String?
    var authoringLanguageVersion: String?
    var authoringSourceData: Data?
    var authoringSourceHash: String?
    var authoringCompilerVersion: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        definitionID: UUID,
        definitionKind: CatalogDefinitionKind,
        catalogueKey: String? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.definitionID = definitionID
        self.definitionKindRaw = definitionKind.rawValue
        self.catalogueKey = catalogueKey
        self.sourceReferencesData = nil
        self.muscleGroups = []
        self.anatomicalTargetMuscles = []
        self.anatomicalSynergistMuscles = []
        self.descriptionText = nil
        self.instructionSteps = []
        self.videoURLString = nil
        self.videoEmbedURLString = nil
        self.thumbnailURLString = nil
        self.imageURLString = nil
        self.liftosaurURLString = nil
        self.liftosaurSlug = nil
        self.categoryRaw = nil
        self.difficultyRaw = nil
        self.equipmentLabels = []
        self.primaryMuscleLabels = []
        self.secondaryMuscleLabels = []
        self.sanskritName = nil
        self.metValue = nil
        self.benefitsText = nil
        self.svgURLString = nil
        self.authoringLanguage = nil
        self.authoringLanguageVersion = nil
        self.authoringSourceData = nil
        self.authoringSourceHash = nil
        self.authoringCompilerVersion = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var definitionKind: CatalogDefinitionKind {
        get { CatalogDefinitionKind(rawValue: definitionKindRaw) ?? .exercise }
        set { definitionKindRaw = newValue.rawValue }
    }

    var sourceReferences: [CatalogSourceReference] {
        get {
            guard let sourceReferencesData else { return [] }
            return (try? JSONDecoder().decode([CatalogSourceReference].self, from: sourceReferencesData)) ?? []
        }
        set {
            sourceReferencesData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }
}

enum CatalogDefinitionKind: String, Codable, CaseIterable, Sendable {
    case exercise
    case mobilityDefinition
    case workoutProgram
    case mobilityProgram
}

/// Additive catalogue metadata for exercise and mobility definitions plus
/// queryable/source-authoring metadata for program definitions. Historical
/// performed evidence remains on the frozen execution snapshots; these live
/// catalogue fields may be refreshed without reinterpreting completed work.
enum GymTrackerCatalogMetadataSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        var types = GymTrackerExecutionSplitSchema.models + [
            CatalogDefinitionMetadata.self
        ]
#if !GYMTRACKER_EXTENSION
        types.append(ProgramDiscoverySeed.self)
#endif
        return types
    }
}

/// Additive execution evidence. The frozen block model is not reshaped;
/// cursor state is derived from ordered split records keyed by block UUID.
enum GymTrackerExecutionSplitSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        var types = GymTrackerAdvancedMobilityEvidenceSchema.models + [
            WorkoutExecutionBlockSplit.self
        ]
#if !GYMTRACKER_EXTENSION
        types.append(HealthKitBodyMassProvenance.self)
        types.append(HealthKitWorkoutExportReceipt.self)
#endif
        return types
    }
}

/// First additive schema after the verified baseline. Schema.Version(2, 0, 0)
/// is formally frozen before first TestFlight distribution. The Mobility Program
/// definition and runtime models listed here form the frozen initial V2 shape.
/// Do not append another persistent model or otherwise change persistent shape under V2.
/// Any future persistent shape change requires a new VersionedSchema generation.
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
        // Part of the frozen initial V2 shape: App-only mobility program definition
        // and runtime models. Appended here prior to V2 schema freeze.
        types.append(MobilityProgramDefinitionRecord.self)
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
        GymTrackerAdvancedMobilityEvidenceSchema.self,
        GymTrackerExecutionSplitSchema.self,
        GymTrackerCatalogMetadataSchema.self
    ]

    static let stages: [MigrationStage] = [
        .lightweight(
            fromVersion: GymTrackerCurrentBaselineSchema.self,
            toVersion: GymTrackerAdvancedMobilityEvidenceSchema.self
        ),
        .lightweight(
            fromVersion: GymTrackerAdvancedMobilityEvidenceSchema.self,
            toVersion: GymTrackerExecutionSplitSchema.self
        ),
        .lightweight(
            fromVersion: GymTrackerExecutionSplitSchema.self,
            toVersion: GymTrackerCatalogMetadataSchema.self
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
        case unavailable(message: String, storeURL: URL)
    }

    /// A failed store open must not terminate the process: the app renders a
    /// recovery state without attaching a context, so it cannot overwrite a
    /// recoverable on-disk store with a fresh empty one. SwiftData normally
    /// throws a Swift `Error`, but Core Data can also raise an Objective-C
    /// `NSException` while adding an incompatible persistent store. The narrow
    /// `GTExceptionBoundary` around only `makeContainer` converts that otherwise
    /// uncatchable launch failure into the same unavailable-store state.
    static let bootstrapState: BootstrapState = {
        // The recovery state is otherwise reachable only through a real store
        // failure, which no UI test can provoke, so it has never had a
        // screenshot. Capture-only: the argument is never passed by a shipped
        // launch, and the branch attaches no context, exactly like the real
        // failure path.
        if AppLaunchArguments.current.contains("-ui-testing-storage-unavailable") {
            let configuration = GymTrackerPersistenceConfiguration().makeModelConfiguration()
            return .unavailable(
                message: "Simulated store failure for screenshot capture.",
                storeURL: configuration.url
            )
        }
        let persistence = GymTrackerPersistenceConfiguration()
        // Build the configuration once and reuse it, so the store that gets
        // copied aside is provably the same one that is about to be opened.
        let configuration = persistence.makeModelConfiguration()
        let currentVersion = GymTrackerCatalogMetadataSchema.versionIdentifier

        let backupOutcome = GymTrackerPreMigrationBackup.backUpIfSchemaVersionChanged(
            storeURL: configuration.url,
            currentVersion: currentVersion
        )

#if GYMTRACKER_EXTENSION
        // The widget extension does not link the app-only Objective-C
        // exception shim. SwiftData failures still surface as a recoverable
        // Swift error here; the app process uses the broader boundary below.
        do {
            let container = try persistence.makeContainer(using: configuration)
            GymTrackerPreMigrationBackup.recordSuccessfulOpen(
                storeURL: configuration.url,
                version: currentVersion
            )
            return .ready(container)
        } catch {
            let recovery = backupOutcome.recoveryDescription.map { " \($0)" } ?? ""
            return .unavailable(
                message: "\(error.localizedDescription)\(recovery)",
                storeURL: configuration.url
            )
        }
#else
        var openedContainer: ModelContainer?
        var openError: Error?
        var caughtException: NSException?

        let operationReturned = GTExceptionBoundary.performOperation({
            do {
                openedContainer = try persistence.makeContainer(using: configuration)
            } catch {
                openError = error
            }
        }, caughtException: &caughtException)

        if operationReturned, let container = openedContainer {
            // Only a completed open proves the migration succeeded, so the
            // recorded version advances here and nowhere else. A throw leaves
            // the marker on the previous version, which is what stops the next
            // launch from copying a damaged store over a good backup.
            GymTrackerPreMigrationBackup.recordSuccessfulOpen(
                storeURL: configuration.url,
                version: currentVersion
            )
            return .ready(container)
        }

        let recovery = backupOutcome.recoveryDescription.map { " \($0)" } ?? ""
        let failureMessage: String
        if let openError {
            failureMessage = openError.localizedDescription
        } else if let caughtException {
            let reason = caughtException.reason ?? "The persistent store could not be opened."
            failureMessage = "\(caughtException.name.rawValue): \(reason)"
        } else {
            failureMessage = "The persistent store could not be opened."
        }
        return .unavailable(
            message: "\(failureMessage)\(recovery)",
            storeURL: configuration.url
        )
#endif
    }()

    static var shared: ModelContainer? {
        guard case let .ready(container) = bootstrapState else { return nil }
        return container
    }

    /// Retained for existing callers and test helpers that consume a `Schema`
    /// value directly. The model list now has one owner: the named current
    /// baseline above.
    static let schema = Schema(versionedSchema: GymTrackerCatalogMetadataSchema.self)
}
