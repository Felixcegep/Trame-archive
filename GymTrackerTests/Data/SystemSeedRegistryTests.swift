import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SystemSeedRegistryTests: XCTestCase {
    func testCatalogInstallationIsSkippedWhenCurrentManifestExists() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        XCTAssertTrue(try SystemSeedCatalogCoordinator.needsInstallation(in: context))

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        XCTAssertFalse(try SystemSeedCatalogCoordinator.needsInstallation(in: context))
    }

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
        XCTAssertTrue(secondManifest.contains { $0.seedKey == RepeatingPlanSeedData.pplContinuous.seedKey })
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("mobility-definition.") })
        XCTAssertTrue(secondManifest.contains { $0.seedKey.hasPrefix("food.") })
        XCTAssertFalse(try context.fetch(FetchDescriptor<FoodItem>()).contains(where: \.isFavorite))
    }

    func testPPLContinuousUsesManifestTemplateIDsAndNeverAutoActivates() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let definition = RepeatingPlanSeedData.pplContinuous
        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let planRecord = try XCTUnwrap(records.first { $0.seedKey == definition.seedKey })
        XCTAssertEqual(planRecord.entityKind, .repeatingPlan)
        let plan = try XCTUnwrap(
            context.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == planRecord.entityID }
        )

        XCTAssertTrue(plan.isBuiltIn)
        XCTAssertFalse(plan.isArchived)
        XCTAssertTrue(plan.runs.isEmpty)
        XCTAssertEqual(plan.orderedSlots.map(\.orderIndex), [0, 1, 2])
        XCTAssertEqual(plan.orderedSlots.map(\.templateNameSnapshot), [
            "PPL – Push Day (Chest, Shoulders, Triceps)",
            "PPL – Pull Day (Back, Rear Delts, Biceps)",
            "PPL – Leg Day (Quads, Hamstrings, Calves)"
        ])
        let expectedTemplateIDs = try definition.templateSeedKeys.map { key in
            try XCTUnwrap(records.first { $0.seedKey == key }).entityID
        }
        XCTAssertEqual(plan.orderedSlots.map(\.templateIDSnapshot), expectedTemplateIDs)

        let firstPlanID = plan.id
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)
        let persistedPlans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        XCTAssertEqual(persistedPlans.count, RepeatingPlanSeedData.definitions.count)
        XCTAssertEqual(
            persistedPlans.first { $0.id == firstPlanID }?.id,
            firstPlanID
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlanRun>()).isEmpty)
    }

    func testWaveSixRotationsHaveStableOrderAndNeverCreateRuns() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let plans = try context.fetch(FetchDescriptor<RepeatingPlan>())
        XCTAssertEqual(plans.filter(\.isBuiltIn).count, RepeatingPlanSeedData.definitions.count)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlanRun>()).isEmpty)

        for definition in RepeatingPlanSeedData.definitions {
            let record = try XCTUnwrap(records.first { $0.seedKey == definition.seedKey })
            let plan = try XCTUnwrap(plans.first { $0.id == record.entityID })
            XCTAssertEqual(plan.orderedSlots.map(\.orderIndex), Array(definition.templateSeedKeys.indices))
            XCTAssertEqual(
                plan.orderedSlots.map(\.templateIDSnapshot),
                try definition.templateSeedKeys.map { key in
                    try XCTUnwrap(records.first { $0.seedKey == key }).entityID
                }
            )
            XCTAssertTrue(plan.runs.isEmpty)
        }

        let upperLower = try XCTUnwrap(plans.first { $0.name == "Upper/Lower Continuous" })
        XCTAssertEqual(upperLower.orderedSlots.map(\.templateNameSnapshot), [
            "Day 1 – Lower Body (Squat Focus)",
            "Day 2 – Upper Body (Push/Pull)",
            "Day 3 – Lower Body (Posterior Chain)",
            "Day 4 – Upper Body (Vertical Push/Pull)"
        ])
    }

    func testWaveSixRotationSeedPreservesCustomDuplicateName() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let custom = RepeatingPlan(name: "Home/Dumbbell", notes: "My compact routine")
        context.insert(custom)
        try context.save()

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let matches = try context.fetch(FetchDescriptor<RepeatingPlan>())
            .filter { $0.name == "Home/Dumbbell" }
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches.first { $0.id == custom.id }?.notes, "My compact routine")
        XCTAssertFalse(matches.first { $0.id == custom.id }?.isBuiltIn ?? true)
        XCTAssertTrue(matches.contains { $0.isBuiltIn && $0.id != custom.id })
    }

    func testWaveSixBuiltInRotationIsAdoptedByExactSnapshotIdentity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let definition = RepeatingPlanSeedData.homeDumbbell
        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let oldRecord = try XCTUnwrap(records.first { $0.seedKey == definition.seedKey })
        let planID = oldRecord.entityID
        context.delete(oldRecord)
        try context.save()

        let report = try RepeatingPlanSystemSeedInstaller.install(
            [definition],
            in: context,
            registry: SystemSeedRegistry(context: context),
            seedVersion: SystemSeedCatalogCoordinator.seedVersion,
            contentVersion: SystemSeedCatalogCoordinator.contentVersion
        )
        try context.save()

        let restoredRecords = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        XCTAssertEqual(report.adopted, 1)
        XCTAssertEqual(restoredRecords.first { $0.seedKey == definition.seedKey }?.entityID, planID)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<RepeatingPlan>()).filter { $0.name == definition.name }.count,
            1
        )
    }

    func testSeededTemplateMobilityLinksRefreshDefinitionSlotsWithoutChangingRunSnapshots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let pushTemplateRecord = try XCTUnwrap(records.first {
            $0.seedKey == "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29"
        })
        let template = try XCTUnwrap(
            context.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.id == pushTemplateRecord.entityID }
        )
        let planRecord = try XCTUnwrap(records.first { $0.seedKey == RepeatingPlanSeedData.pplContinuous.seedKey })
        let plan = try XCTUnwrap(
            context.fetch(FetchDescriptor<RepeatingPlan>()).first { $0.id == planRecord.entityID }
        )
        let run = RepeatingPlanRun(plan: plan)
        context.insert(run)
        try context.save()

        let runSlot = try XCTUnwrap(run.orderedSlots.first)
        let runPreSnapshotID = runSlot.preWorkoutMobilityRoutineIDSnapshot
        let runPreSnapshotName = runSlot.preWorkoutMobilityRoutineNameSnapshot
        template.preWorkoutMobilityRoutine = nil
        plan.orderedSlots.first?.preWorkoutMobilityRoutine = nil
        plan.orderedSlots.first?.preWorkoutMobilityRoutineIDSnapshot = nil
        plan.orderedSlots.first?.preWorkoutMobilityRoutineNameSnapshot = nil
        try context.save()

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        XCTAssertEqual(template.preWorkoutMobilityRoutine?.name, "Upper Body Bench Warmup")
        XCTAssertEqual(plan.orderedSlots.first?.preWorkoutMobilityRoutine?.name, "Upper Body Bench Warmup")
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineIDSnapshot, runPreSnapshotID)
        XCTAssertEqual(runSlot.preWorkoutMobilityRoutineNameSnapshot, runPreSnapshotName)
    }

    func testTemplateMobilityLinkerPreflightsRoutineDependenciesBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        let pushTemplateRecord = try XCTUnwrap(records.first {
            $0.seedKey == "workout-template.ppl--u2013--push-day--u28-chest-u2c--shoulders-u2c--triceps-u29"
        })
        let template = try XCTUnwrap(
            context.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.id == pushTemplateRecord.entityID }
        )
        let dailyRoutineRecord = try XCTUnwrap(records.first {
            $0.seedKey == "mobility-routine.daily-mobility-reset"
        })
        let dailyRoutine = try XCTUnwrap(
            context.fetch(FetchDescriptor<MobilityRoutine>()).first { $0.id == dailyRoutineRecord.entityID }
        )
        template.preWorkoutMobilityRoutine = dailyRoutine

        let missingRoutineRecord = try XCTUnwrap(records.first {
            $0.seedKey == "mobility-routine.upper-body-bench-warmup"
        })
        context.delete(missingRoutineRecord)
        try context.save()

        XCTAssertThrowsError(
            try WorkoutTemplateMobilitySeedLinker.apply(
                in: context,
                registry: SystemSeedRegistry(context: context)
            )
        ) {
            XCTAssertEqual(
                $0 as? SystemSeedError,
                .unresolvedDependency(
                    key: "workout-template.day-2--u2013--upper-body--u28-push-slash-pull-u29",
                    dependency: "mobility-routine.upper-body-bench-warmup"
                )
            )
        }
        XCTAssertEqual(template.preWorkoutMobilityRoutine?.id, dailyRoutine.id)
    }

    func testRepeatingPlanSeedPreflightsEveryDependencyBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        let template = WorkoutTemplate(name: "Preflight template", exercises: [])
        context.insert(template)
        try registry.register(
            key: "workout-template.preflight-template",
            kind: .workoutTemplate,
            entityID: template.id,
            seedVersion: 1,
            contentVersion: 1,
            sourceKind: .bundled
        )
        try context.save()

        let valid = RepeatingPlanSeedDefinition(
            seedKey: "repeating-plan.valid-preflight-probe",
            name: "Valid Preflight Probe",
            goal: .generalStrength,
            experienceLevel: .beginner,
            requiredEquipment: [],
            notes: nil,
            templateSeedKeys: ["workout-template.preflight-template"]
        )
        let missing = RepeatingPlanSeedDefinition(
            seedKey: "repeating-plan.missing-preflight-probe",
            name: "Missing Preflight Probe",
            goal: .generalStrength,
            experienceLevel: .beginner,
            requiredEquipment: [],
            notes: nil,
            templateSeedKeys: ["workout-template.missing-preflight-template"]
        )

        XCTAssertThrowsError(
            try RepeatingPlanSystemSeedInstaller.install(
                [valid, missing],
                in: context,
                registry: registry,
                seedVersion: 1,
                contentVersion: 1
            )
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlan>()).isEmpty)
        XCTAssertFalse(
            try context.fetch(FetchDescriptor<SystemSeedRecord>()).contains {
                $0.seedKey.hasPrefix("repeating-plan.")
            }
        )
    }

    func testExplicitWorkoutTemplateAndCollectionKeysPreserveLegacyIdentity() {
        let templates = WorkoutTemplateSeedData.seededTemplates(using: ExerciseSeedData.templates())
        XCTAssertEqual(
            Set(templates.map(\.seedKey)),
            Set(templates.map { SystemSeedKey.make(namespace: "workout-template", legacyName: $0.template.name) })
        )

        for collection in WorkoutTemplateSeedData.collections {
            let expectedKey = collection.name == WorkoutTemplateSeedData.collectionName
                ? "workout-collection.upper-lower-four-day"
                : SystemSeedKey.make(namespace: "workout-collection", legacyName: collection.name)
            XCTAssertEqual(collection.seedKey, expectedKey)
        }
    }

    func testPPLSeedPreservesCustomDuplicateName() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let custom = RepeatingPlan(name: "PPL Continuous", notes: "My custom rotation")
        context.insert(custom)
        try context.save()

        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let matching = try context.fetch(FetchDescriptor<RepeatingPlan>())
            .filter { $0.name == "PPL Continuous" }
        XCTAssertEqual(matching.count, 2)
        let restoredCustom = try XCTUnwrap(matching.first { $0.id == custom.id })
        XCTAssertFalse(restoredCustom.isBuiltIn)
        XCTAssertEqual(restoredCustom.notes, "My custom rotation")
        XCTAssertTrue(matching.contains { $0.isBuiltIn && $0.id != custom.id })
    }

    func testRepeatingPlanSeedRejectsMissingTemplateDependencyBeforeMutation() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        let missingDependency = RepeatingPlanSeedDefinition(
            seedKey: "repeating-plan.missing-template-probe",
            name: "Missing Template Probe",
            goal: .generalStrength,
            experienceLevel: .beginner,
            requiredEquipment: [],
            notes: nil,
            templateSeedKeys: ["workout-template.missing-template-probe"]
        )

        XCTAssertThrowsError(
            try RepeatingPlanSystemSeedInstaller.install(
                [missingDependency],
                in: context,
                registry: registry,
                seedVersion: 1,
                contentVersion: 1
            )
        ) {
            XCTAssertEqual(
                $0 as? SystemSeedError,
                .unresolvedDependency(
                    key: "repeating-plan.missing-template-probe",
                    dependency: "workout-template.missing-template-probe"
                )
            )
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<RepeatingPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SystemSeedRecord>()).isEmpty)
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

    func testExerciseAndFoodBackupV13PreservesSearchAliasesAndFrenchName() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(
            name: "Bench Press",
            primaryMuscles: [.middleChest],
            equipmentType: .barbell
        )
        exercise.frenchName = "Développé couché"
        exercise.searchAliases = ["bench", "chest press"]
        context.insert(exercise)

        let food = FoodItem(
            name: "Chicken breast",
            calories: 165,
            proteinGrams: 31
        )
        food.frenchName = "Poitrine de poulet"
        food.categoryName = "Poultry"
        food.searchAliases = ["poulet", "chix"]
        context.insert(food)
        try context.save()

        let backup = try BackupDTO.create(
            from: context,
            restTimer: 90,
            darkMode: false,
            unitSystem: .metric
        )

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)

        let restoredExercises = try restored.fetch(FetchDescriptor<Exercise>())
        let restoredBench = try XCTUnwrap(restoredExercises.first { $0.name == "Bench Press" })
        XCTAssertEqual(restoredBench.frenchName, "Développé couché")
        XCTAssertEqual(restoredBench.searchAliases, ["bench", "chest press"])

        let restoredFoods = try restored.fetch(FetchDescriptor<FoodItem>())
        let restoredChicken = try XCTUnwrap(restoredFoods.first { $0.name == "Chicken breast" })
        XCTAssertEqual(restoredChicken.frenchName, "Poitrine de poulet")
        XCTAssertEqual(restoredChicken.categoryName, "Poultry")
        XCTAssertEqual(restoredChicken.searchAliases, ["poulet", "chix"])
    }

    private func catalogueCounts(in context: ModelContext) throws -> [String: Int] {
        [
            "exercise": try context.fetchCount(FetchDescriptor<Exercise>()),
            "relationship": try context.fetchCount(FetchDescriptor<ExerciseRelationship>()),
            "template": try context.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            "collection": try context.fetchCount(FetchDescriptor<WorkoutCollection>()),
            "repeatingPlan": try context.fetchCount(FetchDescriptor<RepeatingPlan>()),
            "program": try context.fetchCount(FetchDescriptor<ProgramDefinitionRecord>()),
            "mobility": try context.fetchCount(FetchDescriptor<MobilityDefinition>()),
            "routine": try context.fetchCount(FetchDescriptor<MobilityRoutine>()),
            "food": try context.fetchCount(FetchDescriptor<FoodItem>()),
            "mealTemplate": try context.fetchCount(FetchDescriptor<MealTemplate>())
        ]
    }
}
