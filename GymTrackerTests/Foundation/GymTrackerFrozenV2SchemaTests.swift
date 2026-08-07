import XCTest
import SwiftData
@testable import GymTracker

/// Formal freeze regression test for Schema.Version(2, 0, 0).
///
/// Context: No GymTracker TestFlight build was ever distributed to internal or external
/// testers prior to this freeze. Therefore, Schema.Version(2, 0, 0) is the first
/// distributable V2 shape.
///
/// Any future model additions, property modifications, or relationship shape changes
/// MUST introduce Schema.Version(3, 0, 0) and a corresponding migration stage rather
/// than extending V2 in place.
@MainActor
final class GymTrackerFrozenV2SchemaTests: XCTestCase {

    func testFrozenV2VersionIdentifier() {
        XCTAssertEqual(
            GymTrackerAdvancedMobilityEvidenceSchema.versionIdentifier,
            Schema.Version(2, 0, 0),
            "GymTrackerAdvancedMobilityEvidenceSchema version identifier MUST be 2.0.0"
        )
        XCTAssertEqual(
            GymTrackerCurrentBaselineSchema.versionIdentifier,
            Schema.Version(1, 0, 0),
            "GymTrackerCurrentBaselineSchema version identifier MUST be 1.0.0"
        )
    }

    func testFrozenV2ModelInventoryMatchesExpectedModels() {
        let actualModels = GymTrackerAdvancedMobilityEvidenceSchema.models
        let actualModelNames = Set(actualModels.map { String(describing: $0) })

        let expectedNames: Set<String> = [
            "Workout",
            "WorkoutExecutionBlock",
            "Exercise",
            "ExerciseRelationship",
            "ExerciseEntry",
            "ExerciseSet",
            "ExerciseSetSegment",
            "ComplexComponentResult",
            "WorkoutTemplate",
            "TemplateExercise",
            "TemplateExerciseBlock",
            "WorkoutCollection",
            "WorkoutPlan",
            "PlanBlock",
            "PlanWeek",
            "PlannedWorkout",
            "PlannedExercise",
            "PlannedExerciseBlock",
            "PlannedSet",
            "PlannedExerciseAlternative",
            "PlanRun",
            "PlanWorkoutProgress",
            "PlanExerciseProgressionState",
            "RepeatingPlan",
            "RepeatingPlanSlot",
            "RepeatingPlanRun",
            "RepeatingPlanRunSlot",
            "RepeatingPlanOccurrence",
            "DailyLogEntry",
            "BodyWeightEntry",
            "SupplementOccurrence",
            "MobilityFamily",
            "MobilityDefinition",
            "MobilityRoutine",
            "MobilityRoutineItem",
            "MobilitySession",
            "MobilityEntry",
            "MobilityResult",
            "MobilityAssessmentDefinition",
            "MobilityAssessmentSession",
            "MobilityAssessmentResult",
            "MobilityAssessmentSample",
            "FoodItem",
            "FoodServing",
            "MealTemplate",
            "MealTemplateItem",
            "LoggedMeal",
            "LoggedMealItem",
            "NutritionTarget",
            "MobilityRoutineItemEvidence",
            "MobilityResultEvidence",
            "MobilityRoutineBlock",
            "MobilityEntryEvidence"
        ]

#if !GYMTRACKER_EXTENSION
        let appOnlyNames: Set<String> = [
            "SystemSeedRecord",
            "ProgramDefinitionRecord",
            "PlanProgressionRecommendationRecord",
            "TrainingProfile",
            "MobilityProgramDefinitionRecord",
            "MobilityProgramRun",
            "MobilityProgramSessionProgress",
            "MobilityProgressionState",
            "MobilityProgressionRecommendationRecord"
        ]
        let fullExpectedNames = expectedNames.union(appOnlyNames)
#else
        let fullExpectedNames = expectedNames
#endif

        XCTAssertEqual(
            actualModelNames,
            fullExpectedNames,
            "The persistent model inventory for Schema.Version(2, 0, 0) has changed! V2 is frozen. Any new model or modified persistent shape requires Schema.Version(3, 0, 0)."
        )
    }

    func testCurrentV2CleanStoreCreateSaveReopenAndWrite() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("frozen_v2_test.store")
        let config = ModelConfiguration(url: storeURL, allowsSave: true)
        let v2Schema = Schema(versionedSchema: GymTrackerAdvancedMobilityEvidenceSchema.self)

        // Phase 1: Create store and write representative domain graph
        do {
            let container = try ModelContainer(
                for: v2Schema,
                migrationPlan: GymTrackerSchemaMigrationPlan.self,
                configurations: config
            )
            let context = ModelContext(container)

            let exercise = Exercise(name: "Frozen Press", primaryMuscles: [.upperChest])
            context.insert(exercise)

            let workout = Workout(name: "Frozen Session")
            let entry = ExerciseEntry(exercise: exercise, orderIndex: 0, usedMetric: .metric)
            let set = ExerciseSet(repetitions: 10, weight: 100.0, setType: .normal, orderIndex: 0, usedMetric: .metric)
            entry.sets.append(set)
            workout.exercises.append(entry)
            context.insert(workout)

            try context.save()
        }

        // Phase 2: Reopen container and verify data integrity
        do {
            let container = try ModelContainer(
                for: v2Schema,
                migrationPlan: GymTrackerSchemaMigrationPlan.self,
                configurations: config
            )
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Workout>()
            let fetchedWorkouts = try context.fetch(descriptor)

            XCTAssertEqual(fetchedWorkouts.count, 1, "Should fetch exactly 1 saved workout")
            XCTAssertEqual(fetchedWorkouts.first?.name, "Frozen Session")
            XCTAssertEqual(fetchedWorkouts.first?.exercises.count, 1)
            XCTAssertEqual(fetchedWorkouts.first?.exercises.first?.exercise.name, "Frozen Press")

            // Phase 3: Write additional record after reopen
            let newWorkout = Workout(name: "Follow-up Session")
            context.insert(newWorkout)
            try context.save()

            let reFetched = try context.fetch(FetchDescriptor<Workout>())
            XCTAssertEqual(reFetched.count, 2, "Should have 2 workouts after follow-up write")
        }
    }

    func testSupportedV1ToV2Migration() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("v1_to_v2_migration.store")
        let config = ModelConfiguration(url: storeURL, allowsSave: true)
        let v1Schema = Schema(versionedSchema: GymTrackerCurrentBaselineSchema.self)
        let v2Schema = Schema(versionedSchema: GymTrackerAdvancedMobilityEvidenceSchema.self)

        // Phase 1: Initialize V1 baseline store
        do {
            let v1Container = try ModelContainer(
                for: v1Schema,
                configurations: config
            )
            let context = ModelContext(v1Container)
            let exercise = Exercise(name: "V1 Squat", primaryMuscles: [.frontDeltoid])
            context.insert(exercise)
            try context.save()
        }

        // Phase 2: Migrate to V2 via migration plan
        do {
            let v2Container = try ModelContainer(
                for: v2Schema,
                migrationPlan: GymTrackerSchemaMigrationPlan.self,
                configurations: config
            )
            let context = ModelContext(v2Container)
            let fetched = try context.fetch(FetchDescriptor<Exercise>())

            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.name, "V1 Squat")

            // Insert a V2-only entity to confirm V2 model capability
            let mobilityEvidence = MobilityRoutineItemEvidence(routineItemID: UUID())
            context.insert(mobilityEvidence)
            try context.save()

            let evidenceFetched = try context.fetch(FetchDescriptor<MobilityRoutineItemEvidence>())
            XCTAssertEqual(evidenceFetched.count, 1)
        }
    }
}
