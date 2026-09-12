import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class BackupExportSelectionTests: XCTestCase {
    func testEverythingSelectionLeavesAFullArchiveUnchanged() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 3)
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
        source.insert(exercise)
        source.insert(template)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let filtered = try backup.applying(.everything)

        XCTAssertEqual(filtered.workouts.count, backup.workouts.count)
        XCTAssertEqual(filtered.templates.count, backup.templates.count)
        XCTAssertEqual(filtered.exercises.count, backup.exercises.count)
        try filtered.validate()
    }

    func testExportDropsOrphanedMobilityCatalogueMetadata() throws {
        let metadata = CatalogDefinitionMetadataDTO(
            id: UUID().uuidString,
            definitionID: UUID().uuidString,
            definitionKind: CatalogDefinitionKind.mobilityDefinition.rawValue,
            catalogueKey: nil,
            sourceReferencesData: nil,
            muscleGroups: [],
            anatomicalTargetMuscles: [],
            anatomicalSynergistMuscles: [],
            descriptionText: nil,
            instructionSteps: [],
            videoURLString: nil,
            videoEmbedURLString: nil,
            thumbnailURLString: nil,
            imageURLString: nil,
            liftosaurURLString: nil,
            liftosaurSlug: nil,
            categoryRaw: nil,
            difficultyRaw: nil,
            equipmentLabels: [],
            primaryMuscleLabels: [],
            secondaryMuscleLabels: [],
            sanskritName: nil,
            metValue: nil,
            benefitsText: nil,
            svgURLString: nil,
            authoringLanguage: nil,
            authoringLanguageVersion: nil,
            authoringSourceData: nil,
            authoringSourceHash: nil,
            authoringCompilerVersion: nil,
            createdAt: .now,
            updatedAt: .now
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            catalogDefinitionMetadata: [metadata]
        )

        XCTAssertThrowsError(try backup.validate())
        let exported = try backup.applying(.everything)
        XCTAssertTrue(exported.catalogDefinitionMetadata.isEmpty)
        try exported.validate()
    }

    func testEmptySelectionIsRejectedBeforeWritingAFile() throws {
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: []
        )

        XCTAssertThrowsError(
            try backup.applying(BackupExportSelection(categories: []))
        ) { error in
            XCTAssertEqual(error as? BackupExportError, .nothingSelected)
        }
    }

    func testHistoryOnlyBackupOmitsTemplatesAndStillValidates() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 3)
        let workout = WorkoutTestFixture.makeWorkout(with: exercise)
        source.insert(exercise)
        source.insert(template)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let filtered = try backup.applying(
            BackupExportSelection(categories: [.workoutHistory])
        )

        XCTAssertEqual(filtered.workouts.count, 1)
        XCTAssertTrue(filtered.templates.isEmpty)
        XCTAssertTrue(filtered.plans.isEmpty)
        XCTAssertTrue(filtered.loggedMeals.isEmpty)
        XCTAssertTrue(filtered.exercises.contains(where: { $0.isCustom }))
        try filtered.validate()
    }

    func testNutritionOnlyBackupClearsTrainingHistory() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)
        source.insert(exercise)
        source.insert(WorkoutTestFixture.makeWorkout(with: exercise))
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: true,
            unitSystem: .imperial
        )
        let filtered = try backup.applying(
            BackupExportSelection(categories: [.nutrition])
        )

        XCTAssertTrue(filtered.workouts.isEmpty)
        XCTAssertTrue(filtered.exercises.isEmpty)
        XCTAssertEqual(filtered.preferences.restTimer, 0)
        XCTAssertNil(filtered.trainingProfile)
        try filtered.validate()
    }

    func testHistoryWithoutRotationsStripsRepeatingPlanSourceLinks() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let push = WorkoutTemplate(name: "Push", exercises: [])
        let plan = RepeatingPlan(
            name: "PPL Continuous",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell],
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: push)]
        )
        let run = RepeatingPlanRun(plan: plan, startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let workout = Workout(name: "Push", endTime: Date(timeIntervalSince1970: 1_700_000_300))
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 0,
            expectedSlotIndex: 0,
            selectedSlotIndex: 0,
            kind: .expected,
            continuationMode: .keepExpected,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 0,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_150),
            startedAt: Date(timeIntervalSince1970: 1_700_000_200),
            completedAt: Date(timeIntervalSince1970: 1_700_000_300),
            completedWorkout: workout
        )
        run.occurrences = [occurrence]
        workout.sourceRepeatingPlanID = plan.id
        workout.sourceRepeatingPlanRunID = run.id
        workout.sourceRepeatingPlanOccurrenceID = occurrence.id
        workout.sourceRepeatingPlanName = plan.name
        source.insert(push)
        source.insert(plan)
        source.insert(run)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let filtered = try backup.applying(
            BackupExportSelection(categories: [.workoutHistory])
        )

        XCTAssertEqual(filtered.workouts.count, 1)
        XCTAssertTrue(filtered.repeatingPlans.isEmpty)
        XCTAssertNil(filtered.workouts[0].sourceRepeatingPlanID)
        XCTAssertNil(filtered.workouts[0].sourceRepeatingPlanName)
        try filtered.validate()
    }

    func testRotationsWithoutHistoryClearCompletedWorkoutLinksAndKeepTemplates() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let push = WorkoutTemplate(name: "Push", exercises: [])
        let plan = RepeatingPlan(
            name: "PPL Continuous",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            requiredEquipment: [.barbell],
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: push)]
        )
        let run = RepeatingPlanRun(plan: plan, startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let workout = Workout(name: "Push", endTime: Date(timeIntervalSince1970: 1_700_000_300))
        let occurrence = RepeatingPlanOccurrence(
            cycleIndex: 0,
            expectedSlotIndex: 0,
            selectedSlotIndex: 0,
            kind: .expected,
            continuationMode: .keepExpected,
            status: .completed,
            cursorBefore: 0,
            cursorAfter: 0,
            cycleBefore: 0,
            cycleAfter: 0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_150),
            startedAt: Date(timeIntervalSince1970: 1_700_000_200),
            completedAt: Date(timeIntervalSince1970: 1_700_000_300),
            completedWorkout: workout
        )
        run.occurrences = [occurrence]
        source.insert(push)
        source.insert(plan)
        source.insert(run)
        source.insert(workout)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let filtered = try backup.applying(
            BackupExportSelection(categories: [.rotations])
        )

        XCTAssertTrue(filtered.workouts.isEmpty)
        XCTAssertEqual(filtered.repeatingPlans.count, 1)
        XCTAssertEqual(filtered.templates.count, 1)
        XCTAssertNil(filtered.repeatingPlanRuns[0].occurrences[0].completedWorkoutID)
        try filtered.validate()
    }

    func testExportServiceAppliesSelectionBeforeWritingTheFile() async throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)
        source.insert(exercise)
        source.insert(WorkoutTestFixture.makeWorkout(with: exercise))
        try source.save()

        let defaults = UserDefaults(suiteName: "BackupExportSelectionTests.\(UUID().uuidString)")!
        let result = try await DataSafetyService.exportData(
            from: source,
            restTimer: 45,
            darkMode: false,
            unitSystem: .metric,
            selection: BackupExportSelection(categories: [.preferences]),
            defaults: defaults
        )

        XCTAssertTrue(result.backup.workouts.isEmpty)
        XCTAssertEqual(result.backup.preferences.restTimer, 45)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
    }
}
