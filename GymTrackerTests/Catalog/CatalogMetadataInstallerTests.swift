import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class CatalogMetadataInstallerTests: XCTestCase {
    func testRecoveredMovementSeedStagesAllEntriesAndIsIdempotent() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)

        let catalog = try CatalogResourceDecoder.decodeBundled()
        let first = try CatalogMetadataInstaller.seedDefinitions(catalog, in: context, registry: registry)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 21)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MobilityDefinition>()), 188)
        XCTAssertEqual(first.inserted, 209)
        XCTAssertEqual(first.updated, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SystemSeedRecord>()), 209)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let airBike = try XCTUnwrap(exercises.first { $0.name == "Air Bike" })
        XCTAssertEqual(airBike.trackingType, .durationAndDistance)
        XCTAssertEqual(airBike.equipmentType, .cardioMachine)
        XCTAssertEqual(airBike.resistanceType, .machine)

        let secondRegistry = try SystemSeedRegistry(context: context)
        let second = try CatalogMetadataInstaller.seedDefinitions(catalog, in: context, registry: secondRegistry)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertEqual(second.unchanged, 209)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 21)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MobilityDefinition>()), 188)
    }

    func testRecoveredMovementSeedPreservesCustomAndUserState() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let registry = try SystemSeedRegistry(context: context)
        let catalog = try CatalogResourceDecoder.decode(
            exercises: Data("[{\"name\":\"Custom\",\"seed_key\":\"exercise.custom\",\"primary_muscles\":[\"quadriceps\"]}]".utf8),
            mobility: Data("[{\"name\":\"Move\",\"seed_key\":\"mobility.move\",\"tracking_type\":\"duration\"}]".utf8),
            programs: Data("[]".utf8)
        )
        let custom = Exercise(name: "Custom", primaryMuscles: [.hamstrings], isFavorite: true, isCustom: true)
        context.insert(custom)
        let archived = MobilityDefinition(name: "Move", isFavorite: true, isCustom: false, isArchived: true)
        context.insert(archived)

        _ = try CatalogMetadataInstaller.seedDefinitions(catalog, in: context, registry: registry)

        XCTAssertTrue(custom.isCustom)
        XCTAssertTrue(custom.isFavorite)
        XCTAssertEqual(custom.primaryMuscles, [.hamstrings])
        XCTAssertTrue(archived.isFavorite)
        XCTAssertTrue(archived.isArchived)
    }

    func testInstallerUpsertsByStableIdentityAndIsIdempotentWithoutChangingUserFields() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(
            name: "Stable Exercise",
            primaryMuscles: [.quadriceps],
            isFavorite: true,
            isArchived: true
        )
        exercise.catalogueKey = "exercise.stable"
        let mobility = MobilityDefinition(
            name: "Stable Mobility",
            isFavorite: true,
            isCustom: false,
            isArchived: true
        )
        mobility.catalogueKey = "stretch.stable"
        context.insert(exercise)
        context.insert(mobility)

        let catalog = try makeCatalog()
        let first = try CatalogMetadataInstaller.stage(catalog, in: context)
        try context.save()

        XCTAssertEqual(first.inserted, 3)
        XCTAssertEqual(first.updated, 0)
        XCTAssertEqual(first.unmatchedProgramKeys, ["reference-only"])
        XCTAssertEqual(first.discoveryOnlyProgramKeys, ["reference-only"])
        XCTAssertTrue(exercise.isFavorite)
        XCTAssertTrue(exercise.isArchived)
        XCTAssertTrue(mobility.isFavorite)
        XCTAssertTrue(mobility.isArchived)

        let rows = try context.fetch(FetchDescriptor<CatalogDefinitionMetadata>())
        XCTAssertEqual(rows.count, 2)
        let exerciseMetadata = try XCTUnwrap(rows.first { $0.definitionKind == .exercise })
        XCTAssertEqual(exerciseMetadata.definitionID, exercise.id)
        XCTAssertEqual(exerciseMetadata.descriptionText, "Recovered description")
        XCTAssertEqual(exerciseMetadata.instructionSteps, ["Setup: Brace", "Move"])
        XCTAssertEqual(exerciseMetadata.sourceReferences.first?.sourceID, "liftosaur")
        XCTAssertEqual(exerciseMetadata.sourceReferences.first?.url, "https://example.com/exercise")

        let mobilityMetadata = try XCTUnwrap(rows.first { $0.definitionKind == .mobilityDefinition })
        XCTAssertEqual(mobilityMetadata.definitionID, mobility.id)
        XCTAssertEqual(mobilityMetadata.categoryRaw, "Yoga")
        XCTAssertEqual(mobilityMetadata.difficultyRaw, "All Levels")
        XCTAssertEqual(mobilityMetadata.metValue, 2.5)

        let second = try CatalogMetadataInstaller.stage(catalog, in: context)
        try context.save()
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertEqual(second.unchanged, 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CatalogDefinitionMetadata>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgramDiscoverySeed>()), 1)
    }

    func testInstallerReportsUnmatchedDefinitionsWithoutCreatingRuntimeEntities() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let catalog = try makeCatalog()

        let report = try CatalogMetadataInstaller.stage(catalog, in: context)

        XCTAssertEqual(report.unmatchedExerciseKeys, ["exercise.stable"])
        XCTAssertEqual(report.unmatchedMobilityKeys, ["stretch.stable"])
        XCTAssertEqual(report.unmatchedProgramKeys, ["reference-only"])
        XCTAssertEqual(report.discoveryOnlyProgramKeys, ["reference-only"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MobilityDefinition>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgramDefinitionRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CatalogDefinitionMetadata>()), 0)
        let discovery = try XCTUnwrap(try context.fetch(FetchDescriptor<ProgramDiscoverySeed>()).first)
        XCTAssertFalse(discovery.isRunnable)
        XCTAssertEqual(discovery.availabilityReason, .structuredPrescriptionUnavailable)
        XCTAssertEqual(discovery.compatibilityStatus, .incompleteRecovery)
        XCTAssertFalse(discovery.compatibilityReason.isEmpty)
    }

    func testProgramNameFallbackAttachesRecoveredSlugVariantsWithoutMakingNewDefinitions() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Catalog Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        let planned = ProgramExerciseDefinition(
            exerciseID: exercise.id,
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
        )
        var payload = ProgramDefinitionFixture.make(exercises: [planned])
        payload.programKey = "foundation-barbell-5x5"
        payload.name = "Foundation Barbell 5×5"
        _ = try ProgramDefinitionRepository.save(payload, isBuiltIn: true, in: context)

        let catalog = try CatalogResourceDecoder.decode(
            exercises: Data("[]".utf8),
            mobility: Data("[]".utf8),
            programs: Data("""
            [{"name":"Foundation Barbell 5×5","slug":"foundation-barbell-5-ud7-5","description":"Summary","daysperweek":"3 days/week","durationweeks":"8 weeks","difficulty":"Beginner","category":"Strength","progressionmodel":"Linear","equipment":"Barbell / Rack","tags":["strength"],"sources":["liftosaur"]}]
            """.utf8)
        )

        let report = try CatalogMetadataInstaller.stage(catalog, in: context)
        XCTAssertEqual(report.discoveryOnlyProgramKeys, [])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgramDiscoverySeed>()), 0)
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<ProgramDefinitionRecord>()).first)
        let metadata = try XCTUnwrap(try context.fetch(FetchDescriptor<CatalogDefinitionMetadata>()).first)
        XCTAssertEqual(metadata.definitionID, record.id)
        XCTAssertEqual(metadata.catalogueKey, "foundation-barbell-5-ud7-5")
        XCTAssertEqual(metadata.categoryRaw, "Strength")
        XCTAssertEqual(metadata.difficultyRaw, "Beginner")
        XCTAssertEqual(metadata.equipmentLabels, ["Barbell", "Rack"])
    }

    func testProgramNameFallbackNeverAdoptsAUserAuthoredDefinition() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Catalog Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        let planned = ProgramExerciseDefinition(
            exerciseID: exercise.id,
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
        )
        var payload = ProgramDefinitionFixture.make(exercises: [planned])
        payload.programKey = "user-owned-key"
        payload.name = "Foundation Barbell 5×5"
        let userRecord = try ProgramDefinitionRepository.save(payload, isBuiltIn: false, in: context)

        let catalog = try CatalogResourceDecoder.decode(
            exercises: Data("[]".utf8),
            mobility: Data("[]".utf8),
            programs: Data("""
            [{"name":"Foundation Barbell 5×5","slug":"foundation-barbell-5-ud7-5","description":"Recovered"}]
            """.utf8)
        )

        let report = try CatalogMetadataInstaller.stage(catalog, in: context)

        XCTAssertEqual(report.discoveryOnlyProgramKeys, ["foundation-barbell-5-ud7-5"])
        XCTAssertNil(try userRecord.payload().discoveryMetadata)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CatalogDefinitionMetadata>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgramDiscoverySeed>()), 1)
    }

    func testClearAllGymDataRemovesCatalogScalarRoots() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Target", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        context.insert(CatalogDefinitionMetadata(
            definitionID: exercise.id,
            definitionKind: .exercise,
            catalogueKey: "target"
        ))
        context.insert(ProgramDiscoverySeed(programKey: "reference-only", name: "Reference Only"))
        try context.save()

        try context.clearAllGymData()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CatalogDefinitionMetadata>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProgramDiscoverySeed>()), 0)
    }

    func testBundledProgramBoundaryIsExecutableDefinitionsPlusDiscoveryOnlyListings() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        _ = try SystemSeedCatalogCoordinator.installBundledCatalog(in: context)

        let executable = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        let discovery = try context.fetch(FetchDescriptor<ProgramDiscoverySeed>())
        XCTAssertEqual(executable.count, 21)
        XCTAssertEqual(discovery.count, 7)
        XCTAssertTrue(discovery.allSatisfy { !$0.isRunnable })
        XCTAssertTrue(discovery.allSatisfy { $0.compatibilityStatus == .incompleteRecovery })
        XCTAssertEqual(
            Set(try executable.map { try $0.payload().programKey }),
            Set(["foundation-barbell-5x5", "double-progression-builder", "tiered-stage-ladder", "heavy-light-medium-5x5", "percent-cycle-4-week", "wave-builder-base-peak", "rpe-bridge-block", "undulating-upper-lower", "six-week-block-strength", "bench-specialization-matrix", "bodyweight-ladder-foundations", "accumulation-wave-upper-lower", "velocity-calibrated-strength", "powerlifting-double-exposure-practice", "skierg-1000m-progression", "weightlifting-complex-to-competition", "conjugate-rotation-wave", "strongman-contest-preparation", "fitness-racing-base-to-peak", "multi-erg-interval-rotation", "powerlifting-foundations"])
        )
    }

    func testInstallerRejectsDuplicateMetadataTargets() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = Exercise(name: "Stable Exercise", primaryMuscles: [.quadriceps])
        exercise.catalogueKey = "exercise.stable"
        context.insert(exercise)
        context.insert(CatalogDefinitionMetadata(
            definitionID: exercise.id,
            definitionKind: .exercise,
            catalogueKey: "exercise.stable"
        ))
        context.insert(CatalogDefinitionMetadata(
            definitionID: exercise.id,
            definitionKind: .exercise,
            catalogueKey: "exercise.stable"
        ))
        try context.save()

        XCTAssertThrowsError(try CatalogMetadataInstaller.stage(try makeCatalog(), in: context)) { error in
            XCTAssertEqual(
                error as? CatalogMetadataInstallError,
                .duplicateTarget(kind: .exercise, definitionID: exercise.id)
            )
        }
    }

    private func makeCatalog() throws -> CatalogResourceCatalog {
        let exercises = Data("""
        [{
          "name":"Stable Exercise",
          "seed_key":"exercise.stable",
          "sources":["liftosaur"],
          "muscle_groups":["Legs"],
          "target_muscles_anatomical":["Vastus medialis"],
          "synergist_muscles_anatomical":["Gluteus maximus"],
          "description":"Recovered description",
          "instructions":[
            {"step":1,"title":"Setup","text":"Brace"},
            {"step":2,"title":"","text":"Move"}
          ],
          "liftosaur_url":"https://example.com/exercise"
        }]
        """.utf8)
        let mobility = Data("""
        [{
          "name":"Stable Mobility",
          "seed_key":"stretch.stable",
          "sources":["recovered"],
          "category":"Yoga",
          "difficulty":"All Levels",
          "equipment":"Yoga Mat / Bodyweight",
          "primary_muscles":["hips"],
          "secondary_muscles":["hamstrings"],
          "met":2.5
        }]
        """.utf8)
        let programs = Data("""
        [{
          "name":"Reference Only",
          "slug":"reference-only",
          "routines_summary":"This prose must never become a runnable prescription."
        }]
        """.utf8)
        return try CatalogResourceDecoder.decode(
            exercises: exercises,
            mobility: mobility,
            programs: programs
        )
    }
}
