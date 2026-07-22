import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SystemSeedRegistryTests: XCTestCase {
    private final class EmptyBundleToken {}

    func testExerciseSeedInstallIsIdempotentAndUsesStableKeys() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        let first = try ExerciseSystemSeedInstaller.install(
            in: context,
            registry: SystemSeedRegistry(context: context)
        )
        try context.save()
        let firstExercises = try context.fetch(FetchDescriptor<Exercise>())
        let firstIDs = Dictionary(uniqueKeysWithValues: firstExercises.map { ($0.name, $0.id) })

        let second = try ExerciseSystemSeedInstaller.install(
            in: context,
            registry: SystemSeedRegistry(context: context)
        )
        try context.save()
        let secondExercises = try context.fetch(FetchDescriptor<Exercise>())
        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())

        XCTAssertGreaterThan(first.inserted, 0)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(secondExercises.count, firstExercises.count)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: secondExercises.map { ($0.name, $0.id) }), firstIDs)
        XCTAssertEqual(records.count, firstExercises.count)
        XCTAssertEqual(
            records.first(where: { $0.entityID == firstIDs["Bench Press"] })?.seedKey,
            "exercise.bench-press"
        )
    }

    func testExerciseSeedUpdatePreservesUserOwnedFields() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try ExerciseSystemSeedInstaller.install(in: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        let bench = try XCTUnwrap(
            context.fetch(FetchDescriptor<Exercise>()).first(where: { $0.name == "Bench Press" })
        )
        bench.isFavorite = true
        bench.isArchived = true
        try context.save()

        _ = try ExerciseSystemSeedInstaller.install(in: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        XCTAssertTrue(bench.isFavorite)
        XCTAssertTrue(bench.isArchived)
    }

    func testCustomDuplicateNameIsNotAdoptedOrOverwritten() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let custom = Exercise(
            name: "Bench Press",
            primaryMuscles: [.bicep],
            isFavorite: true,
            isCustom: true
        )
        context.insert(custom)
        try context.save()

        _ = try ExerciseSystemSeedInstaller.install(in: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        let matches = try context.fetch(FetchDescriptor<Exercise>()).filter { $0.name == "Bench Press" }
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(custom.primaryMuscles, [.bicep])
        XCTAssertTrue(custom.isFavorite)
        XCTAssertNil(
            try context.fetch(FetchDescriptor<SystemSeedRecord>())
                .first(where: { $0.entityID == custom.id })
        )
    }

    func testRegistryRejectsDuplicateManifestKeysBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)

        XCTAssertThrowsError(try registry.validateUniqueKeys(["exercise.bench-press", "exercise.bench-press"])) {
            XCTAssertEqual($0 as? SystemSeedError, .duplicateSeedKey("exercise.bench-press"))
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<SystemSeedRecord>()).isEmpty)
    }

    func testStableKeySupportsRenameAndContentVersionUpdate() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let key = "exercise.rename-probe"
        let original = Exercise(name: "Original Name", primaryMuscles: [.quadriceps])
        _ = try ExerciseSystemSeedInstaller.install(
            [.init(seedKey: key, template: original)],
            in: context,
            registry: SystemSeedRegistry(context: context),
            contentVersion: 1
        )
        try context.save()
        let originalID = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first).id
        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first)
        stored.isFavorite = true
        stored.isArchived = true
        let completedWorkout = Workout(name: "Historical truth", endTime: .now)
        let historicalEntry = ExerciseEntry(exercise: stored, usedMetric: .metric)
        completedWorkout.exercises = [historicalEntry]
        context.insert(completedWorkout)
        try context.save()

        let renamed = Exercise(name: "Renamed Definition", primaryMuscles: [.hamstrings])
        _ = try ExerciseSystemSeedInstaller.install(
            [.init(seedKey: key, template: renamed)],
            in: context,
            registry: SystemSeedRegistry(context: context),
            contentVersion: 2
        )
        try context.save()

        let result = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<SystemSeedRecord>()).first)
        XCTAssertEqual(result.id, originalID)
        XCTAssertEqual(result.name, "Renamed Definition")
        XCTAssertEqual(result.primaryMuscles, [.hamstrings])
        XCTAssertTrue(result.isFavorite)
        XCTAssertTrue(result.isArchived)
        XCTAssertEqual(record.contentVersion, 2)
        XCTAssertEqual(historicalEntry.nameSnapshot, "Original Name")
        XCTAssertEqual(historicalEntry.trackingTypeSnapshot, .weightAndReps)
    }

    func testDeprecationRequiresAValidReplacement() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        try registry.register(
            key: "exercise.old",
            kind: .exercise,
            entityID: UUID(),
            seedVersion: 1,
            contentVersion: 1,
            sourceKind: .bundled
        )
        XCTAssertThrowsError(try registry.deprecate(key: "exercise.old", replacementSeedKey: "exercise.new"))
        try registry.register(
            key: "exercise.new",
            kind: .exercise,
            entityID: UUID(),
            seedVersion: 1,
            contentVersion: 1,
            sourceKind: .bundled
        )
        try registry.deprecate(key: "exercise.old", replacementSeedKey: "exercise.new")
        try context.save()

        let old = try XCTUnwrap(
            context.fetch(FetchDescriptor<SystemSeedRecord>()).first(where: { $0.seedKey == "exercise.old" })
        )
        XCTAssertTrue(old.isDeprecated)
        XCTAssertEqual(old.replacementSeedKey, "exercise.new")
    }

    func testBundledCoordinatorIsIdempotentAcrossAllCurrentDomains() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let firstCounts = try catalogueCounts(in: context)
        let firstManifest = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let firstIDs = Dictionary(uniqueKeysWithValues: firstManifest.map { ($0.seedKey, $0.entityID) })

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let secondCounts = try catalogueCounts(in: context)
        let secondManifest = try context.fetch(FetchDescriptor<SystemSeedRecord>())

        XCTAssertEqual(secondCounts, firstCounts)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: secondManifest.map { ($0.seedKey, $0.entityID) }), firstIDs)
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("exercise.") })
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("program.") })
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("mobility-definition.") })
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("food.") })
        XCTAssertFalse(try context.fetch(FetchDescriptor<FoodItem>()).contains(where: \.isFavorite))
    }

    func testCoordinatorRollsBackEveryStagedDomainWhenBundledProgramDataIsMissing() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let bundle = Bundle(for: EmptyBundleToken.self)

        XCTAssertThrowsError(try SystemSeedCatalogCoordinator.installBundledCatalog(in: context, bundle: bundle))
        XCTAssertTrue(try context.fetch(FetchDescriptor<SystemSeedRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MobilityDefinition>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    func testSystemManifestIsInstallationStateAndIsNotExportedInBackupV13() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try ExerciseSystemSeedInstaller.install(in: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let encoded = try JSONEncoder().encode(backup)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertFalse(json.contains("seedKey"))
        XCTAssertFalse(json.contains("SystemSeedRecord"))
    }

    func testBackupRestoreRebuildsManifestTransactionallyAndPreservesCustomDuplicate() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: source)
        let custom = Exercise(
            name: "Bench Press",
            primaryMuscles: [.bicep],
            isFavorite: true,
            isCustom: true
        )
        source.insert(custom)
        try source.save()

        let backup = try BackupDTO.create(
            from: source,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let manifest = try restored.fetch(FetchDescriptor<SystemSeedRecord>())
        let matchingExercises = try restored.fetch(FetchDescriptor<Exercise>())
            .filter { $0.name == "Bench Press" }
        let restoredCustom = try XCTUnwrap(matchingExercises.first(where: \.isCustom))
        let restoredSystem = try XCTUnwrap(matchingExercises.first(where: { !$0.isCustom }))

        XCTAssertFalse(manifest.isEmpty)
        XCTAssertTrue(manifest.contains { $0.seedKey == "exercise.bench-press" && $0.entityID == restoredSystem.id })
        XCTAssertEqual(matchingExercises.count, 2)
        XCTAssertEqual(restoredCustom.primaryMuscles, [.bicep])
        XCTAssertTrue(restoredCustom.isFavorite)
    }

    func testInterruptedBackupRestoreRollsBackStagedManifest() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sentinel = Exercise(name: "Keep During Restore", primaryMuscles: [.upperChest])
        context.insert(sentinel)
        try context.save()

        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: []
        )

        XCTAssertThrowsError(
            try backup.restore(to: context, beforeCommit: {
                throw NSError(domain: "SystemSeedRegistryTests", code: 1)
            })
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<SystemSeedRecord>()).isEmpty)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.id == sentinel.id }
        )
    }

    private func catalogueCounts(in context: ModelContext) throws -> [String: Int] {
        [
            "exercise": try context.fetchCount(FetchDescriptor<Exercise>()),
            "relationship": try context.fetchCount(FetchDescriptor<ExerciseRelationship>()),
            "template": try context.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            "collection": try context.fetchCount(FetchDescriptor<WorkoutCollection>()),
            "program": try context.fetchCount(FetchDescriptor<ProgramDefinitionRecord>()),
            "mobility": try context.fetchCount(FetchDescriptor<MobilityDefinition>()),
            "routine": try context.fetchCount(FetchDescriptor<MobilityRoutine>()),
            "food": try context.fetchCount(FetchDescriptor<FoodItem>()),
            "mealTemplate": try context.fetchCount(FetchDescriptor<MealTemplate>())
        ]
    }
}
