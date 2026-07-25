import Foundation
import XCTest
@testable import GymTracker

/// Pure encode/decode round-trip coverage for the program-engine backup DTOs
/// (no ModelContext, no SwiftData persistence). Consolidated from three
/// different files — ProgramEngineTypesTests, AdvancedProgramDefinitionTests,
/// and ProgramStageTests — where these DTO-only tests were scattered next to
/// unrelated concerns. Full SwiftData-backed backup/restore integration
/// coverage lives in ProgramCatalogIntegrationTests.
final class ProgramBackupDTORoundTripTests: XCTestCase {

    func testProgramDefinitionBackupDTORoundTripsAndValidates() throws {
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench-strength",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let definitionData = try JSONEncoder().encode(definition)
        let definitionDTO = ProgramDefinitionDTO(
            id: definition.id.uuidString,
            schemaVersion: definition.schemaVersion,
            templateVersion: definition.templateVersion,
            name: definition.name,
            summary: definition.description,
            goal: definition.goal.rawValue,
            experienceLevel: definition.experienceLevel.rawValue,
            durationWeeks: definition.durationWeeks,
            supportedDaysPerWeek: definition.supportedDaysPerWeek,
            isBuiltIn: false,
            isArchived: false,
            createdAt: .now,
            updatedAt: .now,
            definitionData: definitionData
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            programDefinitions: [definitionDTO]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupDTO.self, from: encoder.encode(backup))

        XCTAssertEqual(decoded.programDefinitions.count, 1)
        XCTAssertNoThrow(try decoded.validate())
        XCTAssertEqual(decoded.programDefinitions.first?.definitionData, definitionData)
    }

    func testProgressionRecommendationBackupPreservesExplainableAction() throws {
        let actionData = try JSONEncoder().encode(ProgressionAction.addLoad(2.5))
        let performanceData = try JSONEncoder().encode(
            ProgressionPerformance(completedSets: 3, completedRepetitions: 36, totalVolume: 2_700)
        )
        let dto = ProgressionRecommendationDTO(
            id: UUID().uuidString,
            planRunID: UUID().uuidString,
            workoutID: UUID().uuidString,
            progressionKey: "bench-strength",
            ruleID: UUID().uuidString,
            actionData: actionData,
            cadence: ProgressionCadence.nextExerciseOccurrence.rawValue,
            scope: ProgressionScope.exerciseExposure.rawValue,
            reason: "All required sets reached the upper rep bound.",
            applicationMode: ProgressionApplicationMode.recommendation.rawValue,
            performanceData: performanceData,
            proposedLoad: 82.5,
            proposedStageID: nil,
            proposedVariationExerciseID: nil,
            proposedRepetitionOffset: 0,
            proposedSetCountOffset: 0,
            createdAt: .now,
            isResolved: false,
            resolvedAt: nil
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            progressionRecommendations: [dto]
        )
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(BackupDTO.self, from: data)
        XCTAssertEqual(decoded.progressionRecommendations.first?.actionData, actionData)
        XCTAssertEqual(try JSONDecoder().decode(ProgressionAction.self, from: decoded.progressionRecommendations[0].actionData), .addLoad(2.5))
        let evidence = try XCTUnwrap(decoded.progressionRecommendations.first?.performanceData)
        XCTAssertEqual(try JSONDecoder().decode(ProgressionPerformance.self, from: evidence).completedSets, 3)
        XCTAssertEqual(try JSONDecoder().decode(ProgressionPerformance.self, from: evidence).totalVolume, 2_700)
    }

    func testProgressionStateBackupPreservesConditioningOffsets() throws {
        let pending = try JSONEncoder().encode([
            PendingProgressionState(
                cadence: .nextWeek,
                scope: .exerciseExposure,
                state: ProgressionEvaluationState(currentLoad: 102.5),
                sourceWeekIndex: 0,
                sourceWorkoutIndex: 2,
                sourceBlockIndex: 0,
                createdAt: .now
            )
        ])
        let state = ProgressionStateDTO(
            id: UUID().uuidString,
            progressionKey: "conditioning",
            scope: ProgressionScope.week.rawValue,
            scopeOwnerKey: "week:3",
            currentLoad: nil,
            currentLoadType: nil,
            repetitionOffset: 0,
            setCountOffset: 0,
            durationOffset: 60,
            distanceOffset: 250,
            restDurationOffset: 5,
            caloriesOffset: 120,
            currentStageID: nil,
            currentVariationExerciseID: nil,
            trainingMax: nil,
            estimatedOneRepMax: nil,
            failureCount: 0,
            successCount: 1,
            currentWaveIndex: 0,
            currentBlockIndex: 0,
            previousAMRAPRepetitions: nil,
            previousActualRPE: nil,
            previousActualRIR: nil,
            lastCompletedOccurrence: nil,
            lastSuccessfulLoad: nil,
            isDeloading: false,
            lastAppliedOutcomeID: nil,
            pendingProgressionData: pending
        )
        let decoded = try JSONDecoder().decode(ProgressionStateDTO.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.durationOffset, 60)
        XCTAssertEqual(decoded.distanceOffset, 250)
        XCTAssertEqual(decoded.restDurationOffset, 5)
        XCTAssertEqual(decoded.caloriesOffset, 120)
        XCTAssertEqual(decoded.scope, ProgressionScope.week.rawValue)
        XCTAssertEqual(decoded.scopeOwnerKey, "week:3")
        let restoredPending = try XCTUnwrap(decoded.pendingProgressionData)
        let pendingStates = try JSONDecoder().decode([PendingProgressionState].self, from: restoredPending)
        XCTAssertEqual(pendingStates.first?.state.currentLoad, 102.5)
        XCTAssertEqual(pendingStates.first?.cadence, .nextWeek)
    }

    func testConditioningSetBackupPreservesCaloriesAndOverrideEvidence() throws {
        let set = ExerciseSetDTO(
            orderIndex: 0,
            weightType: "kg",
            distanceType: "km",
            repetition: 0,
            weight: 0,
            duration: nil,
            distance: nil,
            calories: 420,
            done: true,
            isUserOverridden: true,
            userOverrideReason: "Adjusted for today's interval",
            userOverrideAffectsFuture: false,
            rpe: nil,
            setType: "normal",
            usedMetric: "metric",
            prescribedCalories: 450
        )
        let decoded = try JSONDecoder().decode(ExerciseSetDTO.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(decoded.calories, 420)
        XCTAssertEqual(decoded.prescribedCalories, 450)
        XCTAssertTrue(decoded.isUserOverridden)
        XCTAssertEqual(decoded.userOverrideReason, "Adjusted for today's interval")
    }

    func testLegacySetPrescriptionDefaultsDeferredBackOffFlagToFalse() throws {
        let definition = SetPrescriptionDefinition(
            orderIndex: 0,
            role: .backOff,
            repetitions: .fixed(5),
            generatesAfterSourceCompletion: true
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(definition)) as? [String: Any]
        )
        object.removeValue(forKey: "generatesAfterSourceCompletion")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let restored = try JSONDecoder().decode(SetPrescriptionDefinition.self, from: legacyData)

        XCTAssertFalse(restored.generatesAfterSourceCompletion)
    }

    func testPlannedSetBackupPreservesTempoAndProgressionEligibility() throws {
        let dto = PlannedSetDTO(
            orderIndex: 0,
            setType: "normal",
            repetitions: 8,
            repRangeMinimum: nil,
            repRangeMaximum: nil,
            suggestedLoad: 40,
            suggestedLoadType: "kg",
            restSeconds: 90,
            targetRPE: 8,
            targetRIR: 2,
            tempo: "3-1-1-0",
            progressionEligible: false,
            isOptional: false,
            notes: nil
        )
        let decoded = try JSONDecoder().decode(PlannedSetDTO.self, from: JSONEncoder().encode(dto))
        XCTAssertEqual(decoded.tempo, "3-1-1-0")
        XCTAssertEqual(decoded.progressionEligible, false)
    }

    // MARK: - Moved from AdvancedProgramDefinitionTests

    func testPlanRunBackupRoundTripsEndedExposureKeysAndLegacyData() throws {
        let ended = try JSONEncoder().encode(Set(["accessory"]))
        let dto = PlanRunDTO(
            id: UUID().uuidString,
            sourcePlanID: UUID().uuidString,
            sourcePlanName: "Run",
            planID: nil,
            startDate: .now,
            endDate: nil,
            status: PlanRunStatus.active.rawValue,
            currentWeekIndex: 0,
            currentWorkoutIndex: 0,
            endedProgressionKeysData: ended,
            createdAt: .now,
            updatedAt: .now,
            workoutProgress: []
        )
        XCTAssertEqual(try JSONDecoder().decode(PlanRunDTO.self, from: JSONEncoder().encode(dto)).endedProgressionKeysData, ended)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any])
        legacy.removeValue(forKey: "endedProgressionKeysData")
        XCTAssertNil(try JSONDecoder().decode(PlanRunDTO.self, from: JSONSerialization.data(withJSONObject: legacy)).endedProgressionKeysData)
    }

    // MARK: - Moved from ProgramStageTests

    func testPlannedExerciseBackupPreservesStageConfiguration() throws {
        let configuration = ProgramStageConfiguration(
            stages: [
                ProgramStageDefinition(
                    stageID: "volume",
                    name: "Volume",
                    plannedSets: [.init(orderIndex: 0, repetitions: .fixed(8))]
                )
            ],
            initialStageID: "volume"
        )
        let data = try JSONEncoder().encode(configuration)
        let dto = PlannedExerciseDTO(
            id: UUID().uuidString,
            exerciseName: "Squat",
            orderIndex: 0,
            role: ExerciseRole.main.rawValue,
            isOptional: false,
            targetSets: 1,
            repRangeMinimum: 8,
            repRangeMaximum: 8,
            suggestedLoad: 100,
            suggestedLoadType: WeightType.kg.rawValue,
            restSeconds: 90,
            targetRPE: nil,
            targetRIR: nil,
            notes: nil,
            progressionRule: ProgressionRule.none.rawValue,
            progressionStagesData: data
        )

        let restored = try JSONDecoder().decode(PlannedExerciseDTO.self, from: JSONEncoder().encode(dto))
        let restoredData = try XCTUnwrap(restored.progressionStagesData)
        XCTAssertEqual(try JSONDecoder().decode(ProgramStageConfiguration.self, from: restoredData), configuration)
    }
}
