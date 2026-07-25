import Foundation
import XCTest
@testable import GymTracker

final class AdvancedProgramDefinitionTests: XCTestCase {
    func testVelocityRulesUpdateBaselineAndReactToTargetZone() throws {
        let baselineRule = ProgressionRuleDefinition(
            metric: .meanVelocity,
            trigger: .workoutCompleted,
            successAction: .updateVelocityBaseline(.add(
                .multiply(.source(.velocityBaseline(exposureKey: "squat")), .source(.constant(0.7))),
                .multiply(
                    .source(.completedMetric(exposureKey: "squat", metric: .meanVelocity)),
                    .source(.constant(0.3))
                )
            )),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let zoneRule = ProgressionRuleDefinition(
            metric: .meanVelocity,
            trigger: .velocityInTargetZone,
            successAction: .addLoad(2.5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        var context = FormulaResolutionContext()
        context.velocityBaselineByExposure["squat"] = 0.6
        context.completedMetricsByExposure["squat"] = [.meanVelocity: 0.7]

        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [baselineRule, zoneRule],
            performance: ProgressionPerformance(
                workoutCompleted: true,
                meanVelocity: 0.7,
                targetVelocityMinimum: 0.5,
                targetVelocityMaximum: 0.75
            ),
            state: ProgressionEvaluationState(currentLoad: 100, velocityBaseline: 0.6),
            formulaContext: context
        )

        XCTAssertEqual(result.state.currentLoad, 102.5)
        XCTAssertEqual(result.state.velocityBaseline ?? 0, 0.63, accuracy: 0.0001)
    }

    func testVelocityTriggersIgnoreMissingDataWhileFallbackRulesStillApply() throws {
        let rules = [
            ProgressionRuleDefinition(
                metric: .meanVelocity,
                trigger: .velocityInTargetZone,
                successAction: .addLoad(2.5),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            ),
            ProgressionRuleDefinition(
                metric: .repetitions,
                trigger: .allRequiredSetsCompleted,
                successAction: .addRepetitions(1),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]

        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: ProgressionEvaluationState(currentLoad: 100)
        )

        XCTAssertEqual(result.state.currentLoad, 100)
        XCTAssertEqual(result.state.repetitionOffset, 1)
        XCTAssertFalse(result.recommendations.contains { $0.action == .addLoad(2.5) })
    }

    func testComposedTriggerSurvivesDefinitionRoundTripAndStillEvaluates() throws {
        let definition = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allOf([
                .atStage("volume"),
                .anyOf([.firstSetReachedUpperRepBound, .manualApproval])
            ]),
            successAction: .addRepetitions(1),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let decoded = try JSONDecoder().decode(
            ProgressionRuleDefinition.self,
            from: JSONEncoder().encode(definition)
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [decoded],
            performance: ProgressionPerformance(firstSetReachedUpperBound: true),
            state: ProgressionEvaluationState(currentStageID: "volume")
        )

        XCTAssertEqual(result.state.repetitionOffset, 1)
        XCTAssertEqual(result.recommendations.count, 1)
    }

    func testStageTemplateExpandsAndResolvesSelfLoadReference() throws {
        let json = """
        {
          "programKey":"stage-data","name":"Stage Data","goal":"generalStrength",
          "experienceLevel":"intermediate","durationWeeks":1,"supportedDaysPerWeek":[1],
          "scheduleMode":"fixedWeekdays",
          "stageTemplates":{"main":[
            {"stageID":"five","name":"Five","carriesLoad":true,"setGroups":[
              {"count":2,"reps":5,"load":{"reference":"previousOccurrence","of":"$self","round":2.5}}
            ]},
            {"stageID":"three","name":"Three","carriesLoad":true,"setGroups":[
              {"count":3,"reps":3}
            ]}
          ]},
          "blocks":[{"name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,"workouts":[
            {"name":"Day","dayOffset":0,"exercises":[
              {"exercise":"Back Squat","exposureKey":"squat","stages":"main","initialStage":"five"}
            ]}
          ]}]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ["Back Squat": UUID()])
        let exercise = try XCTUnwrap(payload.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)

        XCTAssertEqual(exercise.stages.map(\.stageID), ["five", "three"])
        XCTAssertEqual(exercise.initialStageID, "five")
        XCTAssertEqual(exercise.stages[0].plannedSets.count, 2)
        XCTAssertEqual(
            exercise.stages[0].plannedSets[0].load.reference,
            LoadReference(kind: .previousOccurrence, exposureKey: "squat")
        )
        XCTAssertTrue(exercise.plannedSets.isEmpty)
    }

    func testAuthoringVariationLadderResolvesAndCompilerPersistsOrderedIDs() throws {
        let json = """
        {
          "programKey":"ladder-data","name":"Ladder Data","goal":"generalStrength",
          "experienceLevel":"beginner","durationWeeks":1,"supportedDaysPerWeek":[1],
          "scheduleMode":"fixedWeekdays","blocks":[{"name":"Build","phaseType":"strength",
          "weeks":[{"weekIndex":0,"workouts":[{"name":"Day","dayOffset":0,"exercises":[{
            "exercise":"Assisted Pull-Up","exposureKey":"pull",
            "variationLadder":["Assisted Pull-Up","Pull-Up","Weighted Pull-Up"],
            "setGroups":[{"count":3,"repRange":[5,8]}]
          }]}]}]}]
        }
        """
        let ids = [
            "Assisted Pull-Up": UUID(),
            "Pull-Up": UUID(),
            "Weighted Pull-Up": UUID()
        ]
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ids)
        let definition = try XCTUnwrap(payload.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)

        XCTAssertEqual(definition.variationExerciseIDs, [
            ids["Assisted Pull-Up"], ids["Pull-Up"], ids["Weighted Pull-Up"]
        ].compactMap { $0 })
    }

    func testWaveTemplateExpandsAndInfersCapabilities() throws {
        let json = """
        {
          "programKey":"wave-data","name":"Wave Data","goal":"generalStrength",
          "experienceLevel":"intermediate","durationWeeks":3,"supportedDaysPerWeek":[1],
          "scheduleMode":"fixedWeekdays",
          "waveTemplates":{"main":[
            {"name":"Base","setGroups":[{"count":3,"reps":5,"load":{"reference":"trainingMax","of":"$self","percent":0.75}}]},
            {"name":"Peak","setGroups":[{"count":2,"reps":3},{"count":1,"amrap":[3,null]}]}
          ]},
          "blocks":[{"name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,"workouts":[
            {"name":"Day","dayOffset":0,"exercises":[
              {"exercise":"Back Squat","exposureKey":"squat","waves":"main"}
            ]}
          ]}]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ["Back Squat": UUID()])
        let exercise = try XCTUnwrap(payload.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)

        XCTAssertEqual(exercise.waves.map(\.name), ["Base", "Peak"])
        XCTAssertEqual(exercise.waves.map { $0.plannedSets.count }, [3, 3])
        XCTAssertEqual(exercise.waves[0].plannedSets[0].load.reference.exposureKey, "squat")
        XCTAssertEqual(payload.requiredCapabilities, [
            EngineCapabilities.amrapRepetitions,
            EngineCapabilities.waves
        ].sorted())
        XCTAssertTrue(EngineCapabilities.missing(from: payload.requiredCapabilities).isEmpty)
    }
    func testValidatorRejectsEmptyWarmupScheme() {
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(), exposureKey: "squat", orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
                warmupScheme: WarmupSchemeDefinition(steps: [])
            )
        ])
        XCTAssertFalse(ProgramDefinitionValidator.validate(definition).isEmpty)
    }

    func testAutomaticDeloadPolicyRoundTripsInProgramDefinition() throws {
        let policy = AutomaticDeloadDefinition(volumeReductionPercent: 40, intensityReductionPercent: 15)
        let definition = ProgramDefinitionFixture.make(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
                automaticDeload: policy
            )
        ])
        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONEncoder().encode(definition)
        )
        XCTAssertEqual(
            decoded.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.automaticDeload,
            policy
        )
    }

    // testPlanRunBackupRoundTripsEndedExposureKeysAndLegacyData moved to
    // ProgramBackupDTORoundTripTests.swift, alongside the rest of the
    // pure-DTO backup round-trip coverage.

}
