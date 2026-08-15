import Foundation
import XCTest
@testable import GymTracker

@MainActor
final class ProgramDiscoveryMetadataTests: XCTestCase {
    func testLegacyPayloadDecodesWithoutNewDiscoveryMetadata() throws {
        let definition = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(definition)) as? [String: Any]
        )
        object.removeValue(forKey: "equipmentRequirement")
        object.removeValue(forKey: "focusAreaApplicability")

        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertNil(decoded.equipmentRequirement)
        XCTAssertNil(decoded.focusAreaApplicability)
    }

    func testEquipmentRequirementRoundTrips() throws {
        var definition = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        definition.equipmentRequirement = .init(
            allOf: [.barbell, .dumbbell],
            anyOf: [[.cable, .machine]],
            requiredCapabilityIDs: ["sled"],
            optionalCapabilityIDs: ["skiErg"]
        )

        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONEncoder().encode(definition)
        )

        XCTAssertEqual(decoded.equipmentRequirement, definition.equipmentRequirement)
    }

    func testEquipmentAllOfAnyOfAndCapabilitiesMustAllBeSatisfied() {
        let candidate = makeCandidate(equipmentRequirement: .init(
            allOf: [.barbell, .dumbbell],
            anyOf: [[.cable, .machine]],
            requiredCapabilityIDs: ["sled"]
        ))

        let match = ProgramMatchService.evaluate(candidate, criteria: .init(
            availableEquipment: [.barbell, .dumbbell, .machine],
            availableEquipmentCapabilityIDs: ["sled"]
        ))
        XCTAssertTrue(match.warnings.isEmpty)
        XCTAssertTrue(match.reasons.contains { $0.text.contains("equipment") })

        let missingAlternative = ProgramMatchService.evaluate(candidate, criteria: .init(
            availableEquipment: [.barbell, .dumbbell],
            availableEquipmentCapabilityIDs: ["sled"]
        ))
        XCTAssertEqual(missingAlternative.compatibility, .worksWithChanges)

        let missingCapability = ProgramMatchService.evaluate(candidate, criteria: .init(
            availableEquipment: [.barbell, .dumbbell, .cable]
        ))
        XCTAssertEqual(missingCapability.compatibility, .worksWithChanges)
    }

    func testGoalDoesNotBecomeAnInferredDisciplineMatch() {
        let candidate = makeCandidate(goal: .powerlifting, supportedDisciplineIDs: [])
        let result = ProgramMatchService.evaluate(candidate, criteria: .init(discipline: .powerlifting))

        XCTAssertFalse(result.reasons.contains { $0.text.contains("powerlifting") })
        XCTAssertEqual(result.score, 0)
    }

    func testExplicitDisciplineMatches() {
        let candidate = makeCandidate(
            goal: .generalStrength,
            supportedDisciplineIDs: [TrainingDisciplinePreference.olympicWeightlifting.rawValue]
        )
        let result = ProgramMatchService.evaluate(
            candidate,
            criteria: .init(discipline: .olympicWeightlifting)
        )

        XCTAssertEqual(result.score, 30)
        XCTAssertEqual(result.reasons.count, 1)
    }

    func testNotApplicableFocusNeverScores() {
        let candidate = makeCandidate(
            focusAreaApplicability: .notApplicable,
            focusAreaIDs: [.balanced]
        )
        let result = ProgramMatchService.evaluate(candidate, criteria: .init(focusAreas: [.balanced]))

        XCTAssertEqual(result.score, 0)
        XCTAssertTrue(result.reasons.isEmpty)
    }

    func testFocusApplicabilityValidation() {
        var notApplicable = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        notApplicable.focusAreaApplicability = .notApplicable
        notApplicable.focusAreaIDs = [FocusArea.balanced.rawValue]
        XCTAssertTrue(ProgramDefinitionValidator.validate(notApplicable).contains { $0.code == .invalidFocusAreaID })

        var applicable = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        applicable.focusAreaApplicability = .applicable
        applicable.focusAreaIDs = []
        XCTAssertTrue(ProgramDefinitionValidator.validate(applicable).contains { $0.code == .invalidFocusAreaID })
    }

    func testUnknownAndEmptyEquipmentAlternativesFailValidation() {
        var definition = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        definition.equipmentRequirement = .init(
            anyOf: [[]],
            requiredCapabilityIDs: ["invented-device"]
        )
        let issues = ProgramDefinitionValidator.validate(definition)

        XCTAssertTrue(issues.contains { $0.code == .invalidEquipmentRequirement })
        XCTAssertTrue(issues.contains { $0.code == .invalidEquipmentCapabilityID })
    }

    func testDiscoveryFiltersUseAnySupportedDayAndCombineFacets() {
        let candidate = ProgramMatchCandidate(
            id: UUID(),
            name: "Four or Five Day Plan",
            goal: .generalStrength,
            experienceLevel: .intermediate,
            supportedDaysPerWeek: [4, 5],
            durationWeeks: 10,
            scheduleMode: .fixedWeekdays,
            supportedDisciplineIDs: [TrainingDisciplinePreference.bodybuilding.rawValue]
        )
        var filters = ProgramDiscoveryFilters()
        filters.daysPerWeek = [5]
        filters.goals = [.generalStrength]
        filters.disciplines = [.bodybuilding]

        XCTAssertTrue(filters.matches(candidate))
        filters.durationWeeks = [8]
        XCTAssertFalse(filters.matches(candidate))
    }

    func testEmptyDiscoveryFiltersNeverHideAProgram() {
        XCTAssertTrue(ProgramDiscoveryFilters().matches(makeCandidate()))
    }

    func testDiscoveryMetadataDoesNotChangeCompiledPrescription() throws {
        let exercise = Exercise(name: "Metadata Squat", primaryMuscles: [.quadriceps])
        var base = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: exercise.id,
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let baseline = try ProgramDefinitionCompiler.compile(base, exercisesByID: [exercise.id: exercise])

        base.supportedDisciplineIDs = [TrainingDisciplinePreference.generalStrength.rawValue]
        base.focusAreaApplicability = .applicable
        base.focusAreaIDs = [FocusArea.balanced.rawValue]
        base.estimatedSessionMinutesMinimum = 45
        base.estimatedSessionMinutesMaximum = 60
        base.equipmentRequirement = .init(allOf: [.barbell], requiredCapabilityIDs: ["squatRack"])
        let enriched = try ProgramDefinitionCompiler.compile(base, exercisesByID: [exercise.id: exercise])

        XCTAssertEqual(prescriptionSignature(baseline), prescriptionSignature(enriched))
    }

    func testDiscoveryMetadataDefaultsToAbsentOnNewPayloads() {
        let strength = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        let mobility = MobilityProgramDefinitionPayload(
            name: "Mobility",
            durationWeeks: 1,
            supportedDaysPerWeek: [2],
            blocks: []
        )

        XCTAssertNil(strength.discoveryMetadata)
        XCTAssertNil(mobility.discoveryMetadata)
        XCTAssertEqual(ProgramDiscoveryMetadata().tags, [])
    }

    func testStrengthDiscoveryMetadataRoundTripsAndAuthoringLoweringPreservesIt() throws {
        let metadata = ProgramDiscoveryMetadata(
            authorOrOrigin: "Example Coach",
            categoryOrDisciplineLabel: "Hypertrophy",
            progressionModelLabel: "Double progression",
            tags: ["upper body", "intermediate"],
            sourceProgramURL: "https://example.com/program",
            imageURL: "https://example.com/program.jpg"
        )
        var payload = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        payload.discoveryMetadata = metadata

        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONEncoder().encode(payload)
        )
        XCTAssertEqual(decoded.discoveryMetadata, metadata)

        let authoring = try JSONDecoder().decode(
            AuthoringProgramDefinition.self,
            from: JSONEncoder().encode(makeAuthoringProgram(discoveryMetadata: metadata))
        )
        let lowered = try authoring.expand(exerciseIDsByName: [:])
        XCTAssertEqual(lowered.discoveryMetadata, metadata)
    }

    func testMobilityDiscoveryMetadataRoundTrips() throws {
        let metadata = ProgramDiscoveryMetadata(
            authorOrOrigin: "Mobility Lab",
            categoryOrDisciplineLabel: "Mobility",
            progressionModelLabel: "Range control",
            tags: ["hips"],
            sourceProgramURL: "https://example.com/mobility",
            imageURL: "https://example.com/mobility.jpg"
        )
        let payload = MobilityProgramDefinitionPayload(
            name: "Mobility",
            durationWeeks: 1,
            supportedDaysPerWeek: [2],
            discoveryMetadata: metadata,
            blocks: []
        )

        let decoded = try JSONDecoder().decode(
            MobilityProgramDefinitionPayload.self,
            from: JSONEncoder().encode(payload)
        )
        XCTAssertEqual(decoded.discoveryMetadata, metadata)
    }

    func testLegacyPayloadWithoutDiscoveryMetadataDecodesAsAbsent() throws {
        let strengthData = try removingDiscoveryMetadata(
            from: JSONEncoder().encode(ProgramDefinitionFixture.make(exercises: [exerciseDefinition()]))
        )
        let decodedStrength = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: strengthData)
        XCTAssertNil(decodedStrength.discoveryMetadata)

        let mobility = MobilityProgramDefinitionPayload(
            name: "Mobility",
            durationWeeks: 1,
            supportedDaysPerWeek: [2],
            blocks: []
        )
        let mobilityData = try removingDiscoveryMetadata(
            from: JSONEncoder().encode(mobility)
        )
        let decodedMobility = try JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: mobilityData)
        XCTAssertNil(decodedMobility.discoveryMetadata)
    }

    func testCatalogMetadataReservesProgramKeyAndAuthoringHooksWithoutChangingProgramRecord() throws {
        var payload = ProgramDefinitionFixture.make(exercises: [exerciseDefinition()])
        payload.programKey = "stable-program-key"
        let source = Data("program source".utf8)
        let record = try ProgramDefinitionRecord(payload: payload)
        let metadata = CatalogDefinitionMetadata(
            definitionID: record.id,
            definitionKind: .workoutProgram,
            catalogueKey: payload.programKey
        )
        metadata.authoringLanguage = "trame"
        metadata.authoringLanguageVersion = "1"
        metadata.authoringSourceData = source
        metadata.authoringSourceHash = "sha256:example"
        metadata.authoringCompilerVersion = "compiler-1"

        XCTAssertEqual(metadata.catalogueKey, "stable-program-key")
        XCTAssertEqual(metadata.authoringLanguage, "trame")
        XCTAssertEqual(metadata.authoringLanguageVersion, "1")
        XCTAssertEqual(metadata.authoringSourceData, source)
        XCTAssertEqual(metadata.authoringSourceHash, "sha256:example")
        XCTAssertEqual(metadata.authoringCompilerVersion, "compiler-1")
    }

    private func exerciseDefinition() -> ProgramExerciseDefinition {
        ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))]
        )
    }

    private func makeAuthoringProgram(discoveryMetadata: ProgramDiscoveryMetadata) -> AuthoringProgramDefinition {
        AuthoringProgramDefinition(
            programKey: "authoring-program",
            name: "Authoring Program",
            description: nil,
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            scheduleMode: .fixedWeekdays,
            scheduleIntervalDays: 1,
            requiredEquipment: [],
            prerequisites: [],
            warnings: [],
            isExperimental: false,
            intakeInputs: [],
            missedWorkoutPolicy: .shiftSequence,
            completionPolicy: nil,
            requiredCapabilities: [],
            provenance: nil,
            sourceReferences: nil,
            discoveryMetadata: discoveryMetadata,
            supportedDisciplineIDs: nil,
            focusAreaApplicability: nil,
            focusAreaIDs: nil,
            estimatedSessionMinutesMinimum: nil,
            estimatedSessionMinutesMaximum: nil,
            competitionDisciplineID: nil,
            optionalEquipmentCapabilityIDs: nil,
            equipmentRequirement: nil,
            displayName: nil,
            disclaimer: nil,
            rulesLibrary: nil,
            stageTemplates: nil,
            waveTemplates: nil,
            blocks: []
        )
    }

    private func makeCandidate(
        goal: PlanGoal = .generalStrength,
        equipmentRequirement: ProgramEquipmentRequirement = .init(),
        supportedDisciplineIDs: [String] = [],
        focusAreaApplicability: FocusAreaApplicability? = nil,
        focusAreaIDs: [FocusArea] = []
    ) -> ProgramMatchCandidate {
        ProgramMatchCandidate(
            id: UUID(),
            name: "Metadata Fixture",
            goal: goal,
            experienceLevel: .beginner,
            supportedDaysPerWeek: [3],
            durationWeeks: 6,
            scheduleMode: .fixedWeekdays,
            equipmentRequirement: equipmentRequirement,
            supportedDisciplineIDs: supportedDisciplineIDs,
            focusAreaIDs: focusAreaIDs.map(\.rawValue),
            focusAreaApplicability: focusAreaApplicability
        )
    }

    private func prescriptionSignature(_ plan: WorkoutPlan) -> [String] {
        plan.orderedWeeks.flatMap { week in
            week.orderedPlannedWorkouts.flatMap { workout in
                workout.orderedPlannedExercises.flatMap { exercise in
                    exercise.orderedPlannedSets.map { set in
                        [
                            String(week.weekIndex), String(workout.orderIndex), workout.name,
                            exercise.progressionKey, exercise.exercise.id.uuidString,
                            String(exercise.restSeconds), String(set.orderIndex),
                            canonicalJSON(set.definitionData)
                        ].joined(separator: "|")
                    }
                }
            }
        }
    }

    private func canonicalJSON(_ data: Data?) -> String {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data),
              let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return "" }
        return canonical.base64EncodedString()
    }

    private func removingDiscoveryMetadata(from data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "discoveryMetadata")
        return try JSONSerialization.data(withJSONObject: object)
    }
}
