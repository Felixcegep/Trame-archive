import Foundation
import XCTest
@testable import GymTracker

final class CatalogDefinitionMetadataBackupTests: XCTestCase {

    func testMetadataTopLevelArrayDecodesAbsentForOlderBackups() throws {
        let backup = makeBackup(exercises: [], metadata: [])
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? [String: Any]
        )
        object.removeValue(forKey: "catalogDefinitionMetadata")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)

        XCTAssertTrue(decoded.catalogDefinitionMetadata.isEmpty)
    }

    func testMetadataDTOEncodingRoundTripsEveryFieldAndValidatesTarget() throws {
        let exerciseID = UUID()
        let metadataID = UUID()
        let sourceData = Data("sources".utf8)
        let authoringData = Data("program source".utf8)
        let metadata = CatalogDefinitionMetadataDTO(
            id: metadataID.uuidString,
            definitionID: exerciseID.uuidString,
            definitionKind: CatalogDefinitionKind.exercise.rawValue,
            catalogueKey: "exercise.catalog-metadata",
            sourceReferencesData: sourceData,
            muscleGroups: ["Legs"],
            anatomicalTargetMuscles: ["Vastus medialis"],
            anatomicalSynergistMuscles: ["Gluteus maximus"],
            descriptionText: "Description",
            instructionSteps: ["Set up", "Perform"],
            videoURLString: "https://example.com/video",
            videoEmbedURLString: "https://example.com/embed",
            thumbnailURLString: "https://example.com/thumb",
            imageURLString: "https://example.com/image",
            liftosaurURLString: "https://example.com/liftosaur",
            liftosaurSlug: "catalog-metadata",
            categoryRaw: "Strength",
            difficultyRaw: "Beginner",
            equipmentLabels: ["Barbell"],
            primaryMuscleLabels: ["quadriceps"],
            secondaryMuscleLabels: ["glutes"],
            sanskritName: "",
            metValue: 2.5,
            benefitsText: "Benefits",
            svgURLString: "https://example.com/image.svg",
            authoringLanguage: "trame",
            authoringLanguageVersion: "1",
            authoringSourceData: authoringData,
            authoringSourceHash: "sha256:test",
            authoringCompilerVersion: "compiler-test",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let backup = makeBackup(
            exercises: [makeExercise(id: exerciseID)],
            metadata: [metadata]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupDTO.self, from: encoder.encode(backup))

        XCTAssertEqual(decoded.catalogDefinitionMetadata.count, 1)
        let restored = try XCTUnwrap(decoded.catalogDefinitionMetadata.first)
        XCTAssertEqual(restored.id, metadata.id)
        XCTAssertEqual(restored.definitionID, metadata.definitionID)
        XCTAssertEqual(restored.definitionKind, metadata.definitionKind)
        XCTAssertEqual(restored.catalogueKey, metadata.catalogueKey)
        XCTAssertEqual(restored.sourceReferencesData, sourceData)
        XCTAssertEqual(restored.muscleGroups, metadata.muscleGroups)
        XCTAssertEqual(restored.anatomicalTargetMuscles, metadata.anatomicalTargetMuscles)
        XCTAssertEqual(restored.anatomicalSynergistMuscles, metadata.anatomicalSynergistMuscles)
        XCTAssertEqual(restored.descriptionText, metadata.descriptionText)
        XCTAssertEqual(restored.instructionSteps, metadata.instructionSteps)
        XCTAssertEqual(restored.videoURLString, metadata.videoURLString)
        XCTAssertEqual(restored.videoEmbedURLString, metadata.videoEmbedURLString)
        XCTAssertEqual(restored.thumbnailURLString, metadata.thumbnailURLString)
        XCTAssertEqual(restored.imageURLString, metadata.imageURLString)
        XCTAssertEqual(restored.liftosaurURLString, metadata.liftosaurURLString)
        XCTAssertEqual(restored.liftosaurSlug, metadata.liftosaurSlug)
        XCTAssertEqual(restored.categoryRaw, metadata.categoryRaw)
        XCTAssertEqual(restored.difficultyRaw, metadata.difficultyRaw)
        XCTAssertEqual(restored.equipmentLabels, metadata.equipmentLabels)
        XCTAssertEqual(restored.primaryMuscleLabels, metadata.primaryMuscleLabels)
        XCTAssertEqual(restored.secondaryMuscleLabels, metadata.secondaryMuscleLabels)
        XCTAssertEqual(restored.sanskritName, metadata.sanskritName)
        XCTAssertEqual(restored.metValue, metadata.metValue)
        XCTAssertEqual(restored.benefitsText, metadata.benefitsText)
        XCTAssertEqual(restored.svgURLString, metadata.svgURLString)
        XCTAssertEqual(restored.authoringLanguage, metadata.authoringLanguage)
        XCTAssertEqual(restored.authoringLanguageVersion, metadata.authoringLanguageVersion)
        XCTAssertEqual(restored.authoringSourceData, authoringData)
        XCTAssertEqual(restored.authoringSourceHash, metadata.authoringSourceHash)
        XCTAssertEqual(restored.authoringCompilerVersion, metadata.authoringCompilerVersion)
        XCTAssertEqual(restored.createdAt, metadata.createdAt)
        XCTAssertEqual(restored.updatedAt, metadata.updatedAt)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testMetadataValidationRejectsMissingTarget() throws {
        let metadata = CatalogDefinitionMetadataDTO(
            id: UUID().uuidString,
            definitionID: UUID().uuidString,
            definitionKind: CatalogDefinitionKind.exercise.rawValue,
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

        XCTAssertThrowsError(try makeBackup(exercises: [], metadata: [metadata]).validate()) { error in
            guard case .missingCatalogDefinitionMetadataTarget = error as? BackupValidationError else {
                return XCTFail("Unexpected validation error: \(error)")
            }
        }
    }

    func testDiscoveryOnlyProgramRoundTripsAndCannotBecomeRunnable() throws {
        let seed = ProgramDiscoverySeedDTO(
            id: ProgramDiscoverySeed.stableID(for: "recovered-only").uuidString,
            programKey: "recovered-only",
            name: "Recovered Only",
            summary: "Metadata summary",
            authorOrOrigin: "Recovered source",
            categoryOrDisciplineLabel: "Strength",
            daysPerWeekText: "3 days/week",
            durationWeeksText: "8 weeks",
            difficultyLabel: "Beginner",
            progressionModelLabel: "Linear",
            equipmentText: "Barbell / Rack",
            tags: ["recovered"],
            sourceURLString: "https://example.com/program",
            imageURLString: nil,
            availabilityReason: ProgramDiscoveryAvailabilityReason.structuredPrescriptionUnavailable.rawValue,
            compatibilityStatus: ProgramDiscoveryCompatibilityStatus.incompleteRecovery.rawValue,
            compatibilityReason: "No trustworthy structured day/set/rep prescription.",
            isRunnable: false,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let backup = makeBackup(exercises: [], metadata: [])
        let withSeed = BackupDTO(
            version: backup.version,
            preferences: backup.preferences,
            exercises: backup.exercises,
            templates: backup.templates,
            collections: backup.collections,
            workouts: backup.workouts,
            programDiscoverySeeds: [seed]
        )
        let decoded = try JSONDecoder().decode(
            BackupDTO.self,
            from: JSONEncoder().encode(withSeed)
        )
        XCTAssertEqual(decoded.programDiscoverySeeds.first?.programKey, "recovered-only")
        try decoded.validate()
        XCTAssertFalse(decoded.programDiscoverySeeds.contains(where: { $0.isRunnable }))
    }

    func testBackupRejectsExecutableAndDiscoveryProgramKeyCollision() throws {
        var payload = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "collision-test",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        payload.programKey = "collision-key"
        let definition = ProgramDefinitionDTO(
            id: payload.id.uuidString,
            schemaVersion: payload.schemaVersion,
            templateVersion: payload.templateVersion,
            name: payload.name,
            summary: payload.description,
            goal: payload.goal.rawValue,
            experienceLevel: payload.experienceLevel.rawValue,
            durationWeeks: payload.durationWeeks,
            supportedDaysPerWeek: payload.supportedDaysPerWeek,
            isBuiltIn: true,
            isArchived: false,
            createdAt: .now,
            updatedAt: .now,
            definitionData: try JSONEncoder().encode(payload)
        )
        let seed = ProgramDiscoverySeedDTO(
            id: ProgramDiscoverySeed.stableID(for: payload.programKey).uuidString,
            programKey: payload.programKey,
            name: "Conflicting Discovery Entry",
            summary: nil,
            authorOrOrigin: nil,
            categoryOrDisciplineLabel: nil,
            daysPerWeekText: nil,
            durationWeeksText: nil,
            difficultyLabel: nil,
            progressionModelLabel: nil,
            equipmentText: nil,
            tags: [],
            sourceURLString: nil,
            imageURLString: nil,
            availabilityReason: ProgramDiscoveryAvailabilityReason.structuredPrescriptionUnavailable.rawValue,
            compatibilityStatus: ProgramDiscoveryCompatibilityStatus.incompleteRecovery.rawValue,
            compatibilityReason: "Incomplete source.",
            isRunnable: false,
            createdAt: .now,
            updatedAt: .now
        )
        let base = makeBackup(exercises: [], metadata: [])
        let backup = BackupDTO(
            version: base.version,
            preferences: base.preferences,
            exercises: base.exercises,
            templates: base.templates,
            collections: base.collections,
            workouts: base.workouts,
            programDefinitions: [definition],
            programDiscoverySeeds: [seed]
        )

        let restoredSeed = try XCTUnwrap(backup.programDiscoverySeeds.first)
        XCTAssertFalse(restoredSeed.programKey.isEmpty)
        XCTAssertFalse(restoredSeed.name.isEmpty)
        XCTAssertNotNil(ProgramDiscoveryAvailabilityReason(rawValue: restoredSeed.availabilityReason))
        XCTAssertNotNil(ProgramDiscoveryCompatibilityStatus(rawValue: restoredSeed.compatibilityStatus))
        XCTAssertFalse(restoredSeed.compatibilityReason.isEmpty)
        XCTAssertFalse(restoredSeed.isRunnable)
        XCTAssertEqual(UUID(uuidString: restoredSeed.id), ProgramDiscoverySeed.stableID(for: restoredSeed.programKey))

        XCTAssertThrowsError(try backup.validate()) { error in
            guard case .duplicateIdentifier("executable/discovery program key") = error as? BackupValidationError else {
                return XCTFail("Unexpected validation error: \(error)")
            }
        }
    }

    private func makeBackup(
        exercises: [ExerciseTemplateDTO],
        metadata: [CatalogDefinitionMetadataDTO]
    ) -> BackupDTO {
        BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: exercises,
            templates: [],
            collections: [],
            workouts: [],
            catalogDefinitionMetadata: metadata
        )
    }

    private func makeExercise(id: UUID) -> ExerciseTemplateDTO {
        ExerciseTemplateDTO(
            id: id.uuidString,
            name: "Metadata Exercise",
            primaryMuscles: [Muscle.quadriceps.rawValue],
            secondaryMuscles: nil,
            category: ExerciseCategory.strength.rawValue,
            trackingType: TrackingType.weightAndReps.rawValue,
            equipmentType: EquipmentType.barbell.rawValue,
            resistanceType: ResistanceType.externalWeight.rawValue,
            movementPattern: MovementPattern.squat.rawValue,
            difficulty: Difficulty.beginner.rawValue,
            tags: [],
            isFavorite: false,
            isPlateLoaded: true,
            isCustom: false,
            isArchived: false
        )
    }
}
