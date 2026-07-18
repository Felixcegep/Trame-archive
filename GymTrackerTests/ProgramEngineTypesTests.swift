import Foundation
import XCTest
@testable import GymTracker

final class ProgramEngineTypesTests: XCTestCase {
    func testAuthoringSetGroupsExpandAllPrescriptionShapesDeterministically() throws {
        let groups = [
            AuthoringSetGroupDefinition(count: 2, reps: 5),
            AuthoringSetGroupDefinition(count: 1, repRange: [8, 12]),
            AuthoringSetGroupDefinition(count: 1, amrap: [3, nil]),
            AuthoringSetGroupDefinition(count: 1, durationSeconds: 45)
        ]
        var expanded: [SetPrescriptionDefinition] = []
        for (index, group) in groups.enumerated() {
            expanded += try group.expand(path: "fixture/e0/g\(index)", startingAt: expanded.count)
        }

        XCTAssertEqual(expanded.count, 5)
        XCTAssertEqual(expanded.map(\.orderIndex), [0, 1, 2, 3, 4])
        XCTAssertEqual(expanded[0].repetitions, .fixed(5))
        XCTAssertEqual(expanded[2].repetitions, .range(minimum: 8, maximum: 12))
        XCTAssertEqual(expanded[3].repetitions, .amrap(minimum: 3, maximum: nil))
        XCTAssertEqual(expanded[3].role, .amrap)
        XCTAssertEqual(expanded[4].repetitions, .duration(seconds: 45))
        XCTAssertEqual(
            expanded.map(\.id),
            try groups.enumerated().flatMap { index, group in
                try group.expand(
                    path: "fixture/e0/g\(index)",
                    startingAt: groups.prefix(index).reduce(0) { $0 + $1.count }
                ).map(\.id)
            }
        )
    }

    func testAuthoringLoadExpandsReferencesOffsetsBoundsAndRounding() {
        let load = AuthoringLoadDefinition(
            reference: .trainingMax,
            of: "squat",
            percent: 0.85,
            offset: 2.5,
            percentOffset: 0.025,
            min: 20,
            max: 200,
            round: 2.5
        ).expand()

        XCTAssertEqual(load.reference, LoadReference(kind: .trainingMax, exposureKey: "squat"))
        XCTAssertEqual(load.percentage, 0.85)
        XCTAssertEqual(load.absoluteOffset, 2.5)
        XCTAssertEqual(load.percentageOffset, 0.025)
        XCTAssertEqual(load.minimum, 20)
        XCTAssertEqual(load.maximum, 200)
        XCTAssertEqual(load.rounding, .nearestIncrement(2.5))
    }

    func testAuthoringSetGroupRejectsAmbiguousRepetitionPrescription() {
        XCTAssertThrowsError(try AuthoringSetGroupDefinition(
            count: 1,
            reps: 5,
            repRange: [5, 8]
        ).expand(path: "fixture/e0/g0", startingAt: 0)) { error in
            XCTAssertEqual(error as? ProgramLibraryImportError, .invalidSetGroup("fixture/e0/g0"))
        }
    }

    func testAuthoringProgramExpandsRepeatsNamesWarmupsAndStableStructure() throws {
        let json = """
        {
          "programKey": "json-structure",
          "name": "JSON Structure",
          "goal": "generalStrength",
          "experienceLevel": "beginner",
          "durationWeeks": 4,
          "supportedDaysPerWeek": [1],
          "scheduleMode": "fixedWeekdays",
          "blocks": [{
            "name": "Build",
            "phaseType": "strength",
            "repeat": 2,
            "weeks": [{
              "weekIndex": 0,
              "repeat": 2,
              "workouts": [{
                "name": "Day One",
                "dayOffset": 0,
                "exercises": [{
                  "exercise": "Back Squat",
                  "exposureKey": "squat",
                  "restSeconds": 180,
                  "warmupScheme": [{"percent": 0.5, "reps": 5}],
                  "setGroups": [{
                    "count": 3,
                    "reps": 5,
                    "load": {"reference": "trainingMax", "of": "squat", "percent": 0.8, "round": 2.5}
                  }]
                }]
              }]
            }]
          }]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let squatID = UUID()
        let first = try authoring.expand(exerciseIDsByName: ["Back Squat": squatID])
        let second = try authoring.expand(exerciseIDsByName: ["Back Squat": squatID])

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.id, ProgramLibraryDeterministicID.uuid(for: "json-structure"))
        XCTAssertEqual(first.blocks.count, 2)
        XCTAssertEqual(first.blocks.flatMap(\.weeks).map(\.weekIndex), [0, 1, 2, 3])
        let exercise = try XCTUnwrap(first.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first)
        XCTAssertEqual(exercise.exerciseID, squatID)
        XCTAssertEqual(exercise.plannedSets.count, 3)
        XCTAssertEqual(exercise.plannedSets.map(\.restSeconds), [180, 180, 180])
        XCTAssertEqual(exercise.warmupScheme?.steps.first?.percentage, 0.5)
        XCTAssertEqual(exercise.plannedSets.first?.load.reference.kind, .trainingMax)
    }

    func testAuthoringProgramFailsLoudlyForUnknownExerciseName() throws {
        let json = """
        {
          "programKey": "missing-exercise",
          "name": "Missing Exercise",
          "goal": "generalStrength",
          "experienceLevel": "beginner",
          "durationWeeks": 1,
          "supportedDaysPerWeek": [1],
          "scheduleMode": "fixedWeekdays",
          "blocks": [{"name": "Build", "phaseType": "strength", "weeks": [{
            "weekIndex": 0,
            "workouts": [{"name": "Day", "dayOffset": 0, "exercises": [{
              "exercise": "Unknown Lift", "exposureKey": "unknown", "setGroups": [{"count": 1, "reps": 5}]
            }]}]
          }]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))

        XCTAssertThrowsError(try authoring.expand(exerciseIDsByName: [:])) { error in
            XCTAssertEqual(error as? ProgramLibraryImportError, .missingExercise("Unknown Lift"))
        }
    }

    func testAuthoringVelocityPrescriptionExpandsWithoutDataLoss() throws {
        let json = """
        {
          "reps": 3,
          "velocity": {"zone": [0.5, 0.7], "lossStopPercent": 20, "probe": true}
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringDirectSetDefinition.self, from: Data(json.utf8))
        let set = try authoring.expand(path: "velocity/s0", orderIndex: 0, defaultRestSeconds: 120, exposureKey: "squat")

        XCTAssertEqual(set.velocity?.targetMinimum, 0.5)
        XCTAssertEqual(set.velocity?.targetMaximum, 0.7)
        XCTAssertEqual(set.velocity?.lossStopPercent, 20)
        XCTAssertEqual(set.velocity?.isProbe, true)
        let decoded = try JSONDecoder().decode(SetPrescriptionDefinition.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(decoded.velocity, set.velocity)
    }

    func testNamedRuleLibraryExpandsCompositeTriggerAndActions() throws {
        let json = """
        {
          "programKey": "rules-only-data",
          "name": "Rules Only Data",
          "goal": "generalStrength",
          "experienceLevel": "beginner",
          "durationWeeks": 1,
          "supportedDaysPerWeek": [1],
          "scheduleMode": "fixedWeekdays",
          "rulesLibrary": {
            "linear": [{
              "metric": "load",
              "trigger": {"type": "allOf", "triggers": [
                {"type": "allRequiredSetsCompleted"},
                {"type": "targetRPEMatched", "tolerance": 0.5}
              ]},
              "success": {"type": "addLoad", "value": 2.5},
              "failure": {"type": "repeatPrescription"},
              "cadence": "nextExerciseOccurrence",
              "scope": "exerciseExposure",
              "mode": "automatic",
              "priority": 2
            }]
          },
          "blocks": [{"name": "Build", "phaseType": "strength", "weeks": [{
            "weekIndex": 0,
            "workouts": [{"name": "Day", "dayOffset": 0, "exercises": [{
              "exercise": "Back Squat",
              "exposureKey": "squat",
              "rules": "linear",
              "setGroups": [{"count": 1, "reps": 5}]
            }]}]
          }]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ["Back Squat": UUID()])
        let rule = try XCTUnwrap(payload.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.progressionRules.first)

        XCTAssertEqual(rule.trigger, .allOf([
            .allRequiredSetsCompleted,
            .targetRPEMatched(tolerance: 0.5)
        ]))
        XCTAssertEqual(rule.successAction, .addLoad(2.5))
        XCTAssertEqual(rule.failureAction, .repeatPrescription)
        XCTAssertEqual(rule.applicationMode, .automatic)
        XCTAssertEqual(rule.priority, 2)
    }

    func testDerivedRuleAliasOverridesGenericAddLoadWithoutProgramBranch() throws {
        let json = """
        {
          "programKey":"rule-alias","name":"Rule Alias","goal":"generalStrength",
          "experienceLevel":"beginner","durationWeeks":1,"supportedDaysPerWeek":[1],
          "scheduleMode":"fixedWeekdays",
          "rulesLibrary":{
            "upper":[{"metric":"load","trigger":{"type":"allRequiredSetsCompleted"},
              "success":{"type":"addLoad","value":2.5},"cadence":"nextExerciseOccurrence",
              "scope":"exerciseExposure","mode":"automatic"}],
            "lower":"upper with addLoad 5"
          },
          "blocks":[{"name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,
            "workouts":[{"name":"Day","dayOffset":0,"exercises":[{
              "exercise":"Back Squat","exposureKey":"squat","rules":"lower",
              "setGroups":[{"count":1,"reps":5}]
            }]}]
          }]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ["Back Squat": UUID()])
        let action = payload.blocks[0].weeks[0].workouts[0].plannedExercises[0].progressionRules[0].successAction

        XCTAssertEqual(action, .addLoad(5))
    }

    func testCatalogDecoderReportsOneProgramFailureWithoutDiscardingValidPrograms() throws {
        let validProgram: [String: Any] = [
            "programKey": "valid",
            "name": "Valid",
            "goal": "generalStrength",
            "experienceLevel": "beginner",
            "durationWeeks": 1,
            "supportedDaysPerWeek": [1],
            "scheduleMode": "fixedWeekdays",
            "blocks": [[
                "name": "Build", "phaseType": "strength",
                "weeks": [["weekIndex": 0, "workouts": []]]
            ]]
        ]
        let invalidProgram: [String: Any] = [
            "programKey": "placeholder",
            "name": "Placeholder",
            "blocks": [["name": "Build", "phaseType": "strength", "weeks": [[
                "weekIndex": 0, "workouts": "same as last week"
            ]]]]
        ]
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "programDefinitions": [validProgram, invalidProgram]
        ])

        let result = try AuthoringProgramCatalogDecoder.decode(data)

        XCTAssertEqual(result.definitions.map(\.programKey), ["valid"])
        XCTAssertEqual(result.failures.map(\.programKey), ["placeholder"])
    }

    func testDirectSetsDeferredBackoffExtraGroupsAndStageRulesExpand() throws {
        let json = """
        {
          "programKey":"direct-sets","name":"Direct Sets","goal":"generalStrength",
          "experienceLevel":"intermediate","durationWeeks":1,"supportedDaysPerWeek":[1],
          "scheduleMode":"fixedWeekdays",
          "rulesLibrary":{"stage":[{
            "metric":"load","trigger":{"type":"atStage","stageID":"base"},
            "success":{"type":"changeStage","next":"peak"},
            "cadence":"nextExerciseOccurrence","scope":"exerciseExposure","mode":"automatic"
          }]},
          "blocks":[{"name":"Build","phaseType":"strength","weeks":[{"weekIndex":0,"workouts":[{
            "name":"Day","dayOffset":0,"exercises":[{
              "exercise":"Bench Press","exposureKey":"bench","rules":"stage","restSeconds":180,
              "sets":[
                {"reps":3,"role":"topSet","targetRPE":8},
                {"reps":5,"role":"backOff","deferred":true,"load":{"reference":"topSet","of":"$self","percent":0.9}}
              ],
              "extraSetGroups":[{"count":2,"repRange":[8,12],"optional":true}]
            }]
          }]}]}]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        let payload = try authoring.expand(exerciseIDsByName: ["Bench Press": UUID()])
        let exercise = payload.blocks[0].weeks[0].workouts[0].plannedExercises[0]

        XCTAssertEqual(exercise.plannedSets.count, 4)
        XCTAssertEqual(exercise.plannedSets[0].role, .topSet)
        XCTAssertTrue(exercise.plannedSets[1].generatesAfterSourceCompletion)
        XCTAssertEqual(exercise.plannedSets[1].load.reference, LoadReference(kind: .topSet, exposureKey: "bench"))
        XCTAssertEqual(exercise.plannedSets.map(\.restSeconds), [180, 180, 180, 180])
        XCTAssertEqual(exercise.progressionRules[0].trigger, .atStage("base"))
        XCTAssertEqual(exercise.progressionRules[0].successAction, .changeStage("peak"))
    }

    func testNamedRuleLibraryRejectsMissingAndUnsupportedRules() throws {
        let trigger = AuthoringTriggerDefinition(type: "futureTrigger")
        XCTAssertThrowsError(try trigger.expand()) { error in
            XCTAssertEqual(
                error as? ProgramLibraryImportError,
                .unsupportedRuleConstruct("trigger.futureTrigger")
            )
        }

        let action = AuthoringActionDefinition(type: "futureAction")
        XCTAssertThrowsError(try action.expand()) { error in
            XCTAssertEqual(
                error as? ProgramLibraryImportError,
                .unsupportedRuleConstruct("action.futureAction")
            )
        }
    }

    func testAuthoringFormulaResolvesSelfAndComposesOperations() throws {
        let json = """
        {
          "op": "multiply",
          "args": [
            {"metric": "load", "of": "$self"},
            {"op": "add", "args": [
              {"const": 1},
              {"op": "divide", "args": [
                {"metric": "repetitions", "of": "$self"},
                {"const": 30}
              ]}
            ]}
          ]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringFormulaDefinition.self, from: Data(json.utf8))

        XCTAssertEqual(
            try authoring.expand(exposureKey: "bench"),
            .multiply(
                .source(.completedMetric(exposureKey: "bench", metric: .load)),
                .add(
                    .source(.constant(1)),
                    .divide(
                        .source(.completedMetric(exposureKey: "bench", metric: .repetitions)),
                        .source(.constant(30))
                    )
                )
            )
        )
    }

    func testFormulaBackedTrainingMaxActionExpands() throws {
        let json = """
        {"type":"updateTrainingMax","formula":{"op":"add","args":[
          {"source":"trainingMax","of":"$self"},{"const":2.5}
        ]}}
        """
        let action = try JSONDecoder().decode(AuthoringActionDefinition.self, from: Data(json.utf8))

        XCTAssertEqual(
            try action.expand(exposureKey: "deadlift"),
            .updateTrainingMax(.add(
                .source(.trainingMax(exposureKey: "deadlift")),
                .source(.constant(2.5))
            ))
        )
    }

    func testAuthoringFormulaExpandsBoundedRelativeDelta() throws {
        let json = """
        {"op":"add","args":[
          {"source":"trainingMax","of":"$self"},
          {"op":"clamp","min":-5,"max":5,"args":[
            {"op":"multiply","args":[
              {"op":"subtract","args":[{"metric":"amrapRepetitions","of":"$self"},{"const":6}]},
              {"const":1.25}
            ]}
          ]}
        ]}
        """
        let formula = try JSONDecoder().decode(AuthoringFormulaDefinition.self, from: Data(json.utf8))

        XCTAssertEqual(
            try formula.expand(exposureKey: "squat"),
            .add(
                .source(.trainingMax(exposureKey: "squat")),
                .clamp(
                    value: .multiply(
                        .subtract(
                            .source(.completedMetric(exposureKey: "squat", metric: .amrapRepetitions)),
                            .source(.constant(6))
                        ),
                        .source(.constant(1.25))
                    ),
                    minimum: -5,
                    maximum: 5
                )
            )
        )
    }

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
        let definition = makeDefinition(exercises: [
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
        let definition = makeDefinition(exercises: [
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

    func testEveryActionCanBeStoredAsAFailurePolicy() throws {
        let formula = ProgressionFormula.source(.constant(100))
        let actions: [ProgressionAction] = [
            .addLoad(2.5), .reduceLoad(2.5), .addLoadPercentage(0.025), .reduceLoadPercentage(0.025),
            .addAssistance(5), .reduceAssistance(5), .addRepetitions(1), .reduceRepetitions(1),
            .addSets(1), .reduceSets(1), .addDuration(30), .reduceDuration(30), .addDistance(50),
            .reduceDistance(50), .addRestDuration(15), .reduceRestDuration(15), .addCalories(10),
            .reduceCalories(10), .updateTrainingMax(formula), .updateEstimatedOneRepMax(formula),
            .updateActualOneRepMax(formula), .repeatPrescription, .changeStage("second"),
            .advanceExerciseVariation, .regressExerciseVariation, .advanceWeek, .repeatWeek,
            .advanceWave, .advanceBlock, .restartBlock, .startDeload, .resetFailureCount,
            .resetProgressionOffsets, .endExercise, .endProgram, .generateRecommendation, .noChange
        ]
        let rules = actions.enumerated().map { index, action in
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .repeatPrescription,
                failureAction: action,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                priority: index
            )
        }
        let data = try JSONEncoder().encode(rules)
        XCTAssertEqual(try JSONDecoder().decode([ProgressionRuleDefinition].self, from: data), rules)
    }

    func testProgramDefinitionRoundTripsComposedFormulaAndRules() throws {
        let exerciseID = UUID()
        let formula = ProgressionFormula.round(
            .multiply(
                .source(.trainingMax(exposureKey: "squat-strength")),
                .source(.constant(0.85))
            ),
            rule: .nearestIncrement(2.5)
        )
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .allRequiredSetsCompleted,
            successAction: .addLoad(2.5),
            failureAction: .repeatPrescription,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            formula: formula,
            applicationMode: .automatic
        )
        let definition = makeDefinition(
            exercises: [
                ProgramExerciseDefinition(
                    exerciseID: exerciseID,
                    exposureKey: "squat-strength",
                    orderIndex: 0,
                    plannedSets: [
                        SetPrescriptionDefinition(
                            orderIndex: 0,
                            repetitions: .range(minimum: 3, maximum: 5),
                            load: LoadPrescription(
                                reference: LoadReference(kind: .trainingMax, exposureKey: "squat-strength"),
                                percentage: 0.85,
                                rounding: .nearestIncrement(2.5)
                            )
                        )
                    ],
                    progressionRules: [rule]
                )
            ]
        )

        let data = try JSONEncoder().encode(definition)
        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: data)

        XCTAssertEqual(decoded, definition)
        XCTAssertTrue(ProgramDefinitionValidator.validate(decoded).isEmpty)
    }

    func testProgramDefinitionDecodesLegacyPayloadWithoutScheduleFields() throws {
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "legacy-squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let encoded = try JSONEncoder().encode(definition)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "scheduleMode")
        object.removeValue(forKey: "scheduleIntervalDays")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: legacyData)
        XCTAssertEqual(decoded.scheduleMode, .fixedWeekdays)
        XCTAssertEqual(decoded.scheduleIntervalDays, 1)
    }

    func testProgramDefinitionDecodesLegacyPayloadWithoutExtensibilityMetadata() throws {
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "legacy-squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(definition)) as? [String: Any])
        [
            "programKey", "prerequisites", "warnings", "isExperimental", "intakeInputs",
            "missedWorkoutPolicy", "completionPolicy", "requiredCapabilities"
        ].forEach { object.removeValue(forKey: $0) }
        var blocks = try XCTUnwrap(object["blocks"] as? [[String: Any]])
        var weeks = try XCTUnwrap(blocks[0]["weeks"] as? [[String: Any]])
        var workouts = try XCTUnwrap(weeks[0]["workouts"] as? [[String: Any]])
        workouts[0].removeValue(forKey: "isOptional")
        weeks[0]["workouts"] = workouts
        blocks[0]["weeks"] = weeks
        object["blocks"] = blocks

        let decoded = try JSONDecoder().decode(
            ProgramDefinitionPayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.programKey, "")
        XCTAssertEqual(decoded.prerequisites, [])
        XCTAssertEqual(decoded.warnings, [])
        XCTAssertFalse(decoded.isExperimental)
        XCTAssertEqual(decoded.intakeInputs, [])
        XCTAssertEqual(decoded.missedWorkoutPolicy, .shiftSequence)
        XCTAssertEqual(decoded.completionPolicy, .end)
        XCTAssertEqual(decoded.requiredCapabilities, [])
        XCTAssertFalse(try XCTUnwrap(decoded.blocks.first?.weeks.first?.workouts.first).isOptional)
    }

    func testProgramMetadataAndPoliciesRoundTrip() throws {
        var definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        definition.programKey = "strength-cycle"
        definition.prerequisites = ["Know your one-rep max"]
        definition.warnings = ["Advanced loading"]
        definition.isExperimental = true
        definition.intakeInputs = [.init(exposureKey: "squat", kind: .trainingMax, defaultPercentOfMax: 0.9)]
        definition.missedWorkoutPolicy = .skipAndContinue
        definition.completionPolicy = .offerRestart(carryState: true)
        definition.requiredCapabilities = ["stages", "velocity"]
        definition.blocks[0].weeks[0].workouts[0].isOptional = true

        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: JSONEncoder().encode(definition))

        XCTAssertEqual(decoded, definition)
        XCTAssertEqual(EngineCapabilities.missing(from: decoded.requiredCapabilities), ["velocity"])
    }

    func testBuiltInValidationRequiresProgramKeyAndValidIntakeExposure() {
        var definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        definition.intakeInputs = [.init(exposureKey: "missing", kind: .startingLoad)]

        XCTAssertFalse(ProgramDefinitionValidator.validate(definition).contains { $0.code == .emptyProgramKey })
        let invalidIssues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertTrue(invalidIssues.contains { $0.code == .emptyProgramKey })
        XCTAssertTrue(invalidIssues.contains { $0.code == .invalidIntakeExposure })

        definition.programKey = "squat-cycle"
        definition.intakeInputs = [.init(exposureKey: "squat", kind: .startingLoad)]
        XCTAssertTrue(ProgramDefinitionValidator.validate(definition, isBuiltIn: true).isEmpty)
    }

    func testCompositeTriggersSupportNestingAndStageState() throws {
        let rule = ProgressionRuleDefinition(
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
        let matching = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(firstSetReachedUpperBound: true),
            state: ProgressionEvaluationState(currentStageID: "volume")
        )
        XCTAssertEqual(matching.state.repetitionOffset, 1)
        XCTAssertTrue(matching.recommendations.first?.reason.contains("first set") == true)

        let wrongStage = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(firstSetReachedUpperBound: true),
            state: ProgressionEvaluationState(currentStageID: "strength")
        )
        XCTAssertEqual(wrongStage.state.repetitionOffset, 0)
        XCTAssertTrue(wrongStage.recommendations.isEmpty)
    }

    func testAnyOfMatchesOnlyOneBranchAndReportsTheMatchedReason() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .anyOf([.manualApproval, .workoutCompleted]),
            successAction: .addRepetitions(1),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(workoutCompleted: true),
            state: ProgressionEvaluationState()
        )

        XCTAssertEqual(result.state.repetitionOffset, 1)
        XCTAssertEqual(result.recommendations.first?.reason, "The workout was completed.")
    }

    func testValidatorRejectsEmptyAndMalformedCompositeTriggers() {
        var definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
                progressionRules: [
                    ProgressionRuleDefinition(
                        metric: .repetitions,
                        trigger: .allOf([.anyOf([]), .atStage(" ")]),
                        successAction: .addRepetitions(1),
                        cadence: .nextExerciseOccurrence,
                        scope: .exerciseExposure
                    )
                ]
            )
        ])
        definition.programKey = "invalid-composite"

        let issues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertEqual(issues.filter { $0.code == .invalidPrescriptionValue }.count, 2)
    }

    func testStageDefinitionCompilesAndSeedsInitialRunState() throws {
        let squat = Exercise(name: "Stage Squat", primaryMuscles: [.quadriceps])
        let definition = stageDefinition(exerciseID: squat.id)

        XCTAssertTrue(ProgramDefinitionValidator.validate(definition, isBuiltIn: true).isEmpty)
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let plannedExercise = try XCTUnwrap(
            plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first
        )
        let configuration = try JSONDecoder().decode(
            ProgramStageConfiguration.self,
            from: try XCTUnwrap(plannedExercise.progressionStagesData)
        )
        XCTAssertEqual(configuration.initialStageID, "volume")
        XCTAssertEqual(plannedExercise.orderedPlannedSets.count, 2)

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.first?.currentStageID, "volume")
    }

    func testAMRAPMetricFeedsTrainingMaxFormula() throws {
        var context = FormulaResolutionContext()
        context.completedMetricsByExposure["squat"] = [.amrapRepetitions: 8]
        let formula = ProgressionFormula.clamp(
            value: .add(
                .source(.trainingMax(exposureKey: "squat")),
                .multiply(
                    .source(.completedMetric(exposureKey: "squat", metric: .amrapRepetitions)),
                    .source(.constant(2.5))
                )
            ),
            minimum: 0,
            maximum: 120
        )
        context.trainingMaxByExposure["squat"] = 100

        XCTAssertEqual(try ProgramFormulaResolver.resolve(formula, context: context), 120)
        context.completedMetricsByExposure["squat"] = nil
        XCTAssertThrowsError(try ProgramFormulaResolver.resolve(formula, context: context))
    }

    func testSnapshotPersistsPrescriptionReferenceValueInKilograms() throws {
        let squat = Exercise(
            name: "Reference Squat",
            primaryMuscles: [.quadriceps],
            equipmentType: .barbell
        )
        let exercise = ProgramExerciseDefinition(
            exerciseID: squat.id,
            exposureKey: "reference-squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(
                        reference: .init(kind: .trainingMax, exposureKey: "reference-squat"),
                        percentage: 0.8
                    )
                )
            ],
            initialTrainingMax: 200
        )
        let plan = try ProgramDefinitionCompiler.compile(
            makeDefinition(exercises: [exercise]),
            exercisesByID: [squat.id: squat]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .imperial)
        let set = try XCTUnwrap(workout.orderedExercises.first?.orderedSets.first)

        XCTAssertEqual(set.prescribedReferenceValue ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(set.prescribedSuggestedLoadType, .lbs)
    }

    func testStageTransitionClearsLoadOnlyWhenDestinationDoesNotCarryIt() throws {
        let stages = [
            ProgramStageDefinition(stageID: "volume", plannedSets: [.init(orderIndex: 0, repetitions: .fixed(8))]),
            ProgramStageDefinition(stageID: "reset", plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))], carriesLoad: false)
        ]
        let rule = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .changeStage("reset"),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(manualApproval: true),
            state: ProgressionEvaluationState(currentLoad: 100, currentStageID: "volume"),
            stageDefinitions: stages
        )

        XCTAssertEqual(result.state.currentStageID, "reset")
        XCTAssertNil(result.state.currentLoad)
    }

    func testStageSnapshotGrowsAndPreservesCompletedSetsWhenShrinking() throws {
        let squat = Exercise(name: "Snapshot Stage Squat", primaryMuscles: [.quadriceps])
        let plan = try ProgramDefinitionCompiler.compile(
            stageDefinition(exerciseID: squat.id),
            exercisesByID: [squat.id: squat]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        let plannedWorkout = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first)
        let plannedExercise = try XCTUnwrap(plannedWorkout.orderedPlannedExercises.first)
        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        XCTAssertEqual(entry.orderedSets.count, 2)

        let state = try XCTUnwrap(run.orderedProgressionStates.first)
        state.currentStageID = "strength"
        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric
        )
        XCTAssertEqual(entry.orderedSets.count, 4)

        let completed = entry.orderedSets[3]
        completed.done = true
        state.currentStageID = "volume"
        ProgramPrescriptionSnapshotService.apply(
            to: entry,
            plannedExercise: plannedExercise,
            run: run,
            unitSystem: .metric,
            preservingCompletedSets: true
        )
        XCTAssertEqual(entry.orderedSets.count, 3)
        XCTAssertTrue(entry.orderedSets.contains { $0.id == completed.id && $0.done })
    }

    func testValidatorRejectsStageWaveMixAndUnknownStageTargets() {
        let exerciseID = UUID()
        var definition = stageDefinition(exerciseID: exerciseID)
        definition.blocks[0].weeks[0].workouts[0].plannedExercises[0].waves = [
            ProgramWaveDefinition(orderIndex: 0, plannedSets: [.init(orderIndex: 0, repetitions: .fixed(5))])
        ]
        definition.blocks[0].weeks[0].workouts[0].plannedExercises[0].progressionRules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .manualApproval,
                successAction: .changeStage("missing"),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure
            )
        ]

        let issues = ProgramDefinitionValidator.validate(definition, isBuiltIn: true)
        XCTAssertTrue(issues.contains { $0.code == .invalidStage && $0.message.contains("cannot be used") })
        XCTAssertTrue(issues.contains { $0.code == .invalidStage && $0.message.contains("missing stage") })
    }

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

    func testProgramDefinitionCodecRejectsInvalidImportedRecipes() throws {
        let valid = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "squat",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
            )
        ])
        let data = try ProgramDefinitionCodec.encode(valid)
        XCTAssertEqual(try ProgramDefinitionCodec.decode(data), valid)

        var invalid = valid
        invalid.name = ""
        XCTAssertThrowsError(try ProgramDefinitionCodec.encode(invalid)) { error in
            guard let codecError = error as? ProgramDefinitionCodecError,
                  case .validation(let issues) = codecError else {
                return XCTFail("Expected validation error")
            }
            XCTAssertTrue(issues.contains { $0.code == .emptyName })
        }
        XCTAssertThrowsError(try ProgramDefinitionCodec.decode(Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? ProgramDefinitionCodecError, .malformed)
        }
    }

    func testProgramDefinitionBuilderCreatesAndReordersAValidRecipe() throws {
        var builder = ProgramDefinitionBuilder(name: "Builder Test", durationWeeks: 1)
        let block = builder.addBlock(name: "Strength", phaseType: .strength)
        let week = try builder.addWeek(toBlock: block, name: "Week 1")
        let workout = try builder.addWorkout(toBlock: block, week: week, name: "Day 1", dayOffset: 0)
        let first = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "squat")
        _ = try builder.addExercise(toBlock: block, week: week, workout: workout, exerciseID: UUID(), exposureKey: "bench")
        try builder.addSet(toBlock: block, week: week, workout: workout, exercise: first, prescription: SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5)))
        try builder.moveExercise(fromBlock: block, week: week, workout: workout, from: 0, to: 2)

        let definition = try builder.build()
        let exercises = try XCTUnwrap(definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises)
        XCTAssertEqual(exercises.map(\.exposureKey), ["bench", "squat"])
        XCTAssertEqual(exercises.map(\.orderIndex), [0, 1])
        XCTAssertEqual(exercises.last?.plannedSets.count, 1)
    }

    func testProgramDefinitionBuilderRetainsADeferredSourceBasedBackOff() throws {
        var builder = ProgramDefinitionBuilder(name: "Top set builder", durationWeeks: 1)
        let block = builder.addBlock(name: "Strength", phaseType: .strength)
        let week = try builder.addWeek(toBlock: block)
        let workout = try builder.addWorkout(toBlock: block, week: week, name: "Press", dayOffset: 0)
        let bench = try builder.addExercise(
            toBlock: block,
            week: week,
            workout: workout,
            exerciseID: UUID(),
            exposureKey: "bench"
        )
        try builder.addSet(
            toBlock: block,
            week: week,
            workout: workout,
            exercise: bench,
            prescription: SetPrescriptionDefinition(
                orderIndex: 0,
                role: .topSet,
                repetitions: .fixed(5)
            )
        )
        try builder.addSet(
            toBlock: block,
            week: week,
            workout: workout,
            exercise: bench,
            prescription: SetPrescriptionDefinition(
                orderIndex: 1,
                role: .backOff,
                repetitions: .fixed(5),
                load: LoadPrescription(
                    reference: .init(kind: .topSet, exposureKey: "bench"),
                    percentage: 0.9
                ),
                generatesAfterSourceCompletion: true
            )
        )

        let definition = try builder.build()
        let sets = try XCTUnwrap(
            definition.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.plannedSets
        )
        XCTAssertEqual(sets.count, 2)
        XCTAssertTrue(sets[1].generatesAfterSourceCompletion)
    }

    func testPolicyPresetsProduceValidatedDataOnlyRules() {
        for preset in ProgramPolicyPreset.allCases {
            let rules = preset.rules()
            XCTAssertFalse(rules.isEmpty, preset.rawValue)
            XCTAssertTrue(rules.allSatisfy { $0.version > 0 }, preset.rawValue)
        }
    }

    func testWaveAndAlternativeExposureDataRoundTripsAndValidates() throws {
        let mainID = UUID()
        let alternativeID = UUID()
        let waveSets = [
            SetPrescriptionDefinition(
                orderIndex: 0,
                repetitions: .fixed(2),
                load: LoadPrescription(reference: LoadReference(kind: .fixedLoad), fixedValue: 80)
            ),
            SetPrescriptionDefinition(
                orderIndex: 1,
                repetitions: .fixed(1),
                load: LoadPrescription(reference: LoadReference(kind: .fixedLoad), fixedValue: 85)
            )
        ]
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: mainID,
                exposureKey: "clean-wave",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(3))],
                waves: [
                    ProgramWaveDefinition(orderIndex: 0, name: "Wave 1", plannedSets: waveSets),
                    ProgramWaveDefinition(orderIndex: 1, name: "Wave 2", plannedSets: waveSets.map { set in
                        var copy = set
                        copy.id = UUID()
                        copy.orderIndex += 2
                        return copy
                    })
                ],
                alternativeExerciseIDs: [alternativeID]
            )
        ])

        let data = try JSONEncoder().encode(definition)
        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: data)
        XCTAssertEqual(decoded, definition)
        XCTAssertTrue(ProgramDefinitionValidator.validate(decoded).isEmpty)
        XCTAssertEqual(decoded.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.waves.count, 2)
        XCTAssertEqual(decoded.blocks.first?.weeks.first?.workouts.first?.plannedExercises.first?.alternativeExerciseIDs, [alternativeID])
    }

    func testProgramDefinitionPreviewFlattensEveryPlannedExposure() throws {
        let definition = ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: [
            "squat": UUID(), "bench": UUID(), "row": UUID(), "plank": UUID(), "complex": UUID(), "clean": UUID(), "jerk": UUID()
        ])
        let rows = try ProgramDefinitionPreview.rows(for: definition)
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.contains { $0.roles.contains(.topSet) && $0.loadReferences.contains(.topSet) })
        XCTAssertTrue(rows.contains { $0.sets.contains { $0.generatesAfterSourceCompletion } })
        XCTAssertTrue(rows.contains { $0.repPrescriptions.contains { if case .sequence = $0 { return true }; return false } })
        XCTAssertTrue(rows.contains { !$0.transitions.isEmpty })
    }

    func testDeferredBackOffValidationRequiresABackOffWithASourceSetReference() {
        let invalidRole = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(reference: .init(kind: .topSet, exposureKey: "bench")),
                        generatesAfterSourceCompletion: true
                    )
                ]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(invalidRole).contains {
            $0.code == .invalidPrescriptionValue
        })

        let invalidReference = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "bench",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .backOff,
                        repetitions: .fixed(5),
                        load: LoadPrescription(reference: .init(kind: .previousOccurrence, exposureKey: "bench")),
                        generatesAfterSourceCompletion: true
                    )
                ]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(invalidReference).contains {
            $0.code == .invalidLoadReference
        })
    }

    func testProgramDefinitionPreviewResolvesInitialLoadsAndDeloadMetadata() throws {
        let squatID = UUID()
        let definition = ProgramDefinitionPayload(
            name: "Preview Cycle",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Deload",
                    phaseType: .deload,
                    deloadVolumeReductionPercent: 40,
                    deloadIntensityReductionPercent: 15,
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            name: "Recovery Week",
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Recovery",
                                    dayOffset: 2,
                                    role: "recovery",
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: squatID,
                                            exposureKey: "squat",
                                            orderIndex: 0,
                                            plannedSets: [
                                                SetPrescriptionDefinition(
                                                    orderIndex: 0,
                                                    role: .working,
                                                    repetitions: .fixed(5),
                                                    load: LoadPrescription(
                                                        reference: .init(kind: .trainingMax, exposureKey: "squat"),
                                                        percentage: 0.8,
                                                        rounding: .nearestIncrement(2.5)
                                                    ),
                                                    restSeconds: 120
                                                )
                                            ],
                                            initialTrainingMax: 200
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let row = try XCTUnwrap(ProgramDefinitionPreview.rows(for: definition).first)
        XCTAssertEqual(row.phaseType, .deload)
        XCTAssertEqual(row.weekName, "Recovery Week")
        XCTAssertEqual(row.workoutRole, "recovery")
        XCTAssertEqual(row.dayOffset, 2)
        XCTAssertEqual(row.deloadVolumeReductionPercent, 40)
        XCTAssertEqual(row.deloadIntensityReductionPercent, 15)
        XCTAssertEqual(row.sets.first?.unroundedLoad ?? .nan, 160, accuracy: 0.001)
        XCTAssertEqual(row.sets.first?.prescribedLoad ?? .nan, 160, accuracy: 0.001)
        XCTAssertEqual(row.sets.first?.restSeconds, 120)
    }

    func testValidatorRejectsDeloadReductionsOutsideDeloadPhases() {
        let definition = ProgramDefinitionPayload(
            name: "Invalid Deload",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [
                ProgramBlockDefinition(
                    orderIndex: 0,
                    name: "Strength",
                    deloadVolumeReductionPercent: 95,
                    weeks: [
                        ProgramWeekDefinition(
                            weekIndex: 0,
                            workouts: [
                                ProgramWorkoutDefinition(
                                    orderIndex: 0,
                                    name: "Day",
                                    dayOffset: 0,
                                    plannedExercises: [
                                        ProgramExerciseDefinition(
                                            exerciseID: UUID(),
                                            exposureKey: "squat",
                                            orderIndex: 0,
                                            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let issues = ProgramDefinitionValidator.validate(definition)
        XCTAssertTrue(issues.contains { $0.path == "blocks[0].deloadVolumeReductionPercent" })
    }

    func testWaveLoadingFixturePreservesStructuredWavesInPreview() throws {
        let rows = try ProgramDefinitionPreview.rows(for: ProgramFixtureCatalog.waveLoading(exerciseIDs: ["squat": UUID()]))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.waveCount, 2)
        XCTAssertEqual(rows.first?.setCount, 2)
    }

    func testValidatorReportsInvalidPrescriptionAndDuplicateExposure() {
        let first = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "bench",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .range(minimum: 12, maximum: 8),
                    load: LoadPrescription(percentage: 3.5),
                    targetRPE: 11,
                    restSeconds: -1
                )
            ]
        )
        let second = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "bench",
            orderIndex: 1,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [first, second]))

        XCTAssertTrue(issues.contains { $0.code == .invalidRepRange })
        XCTAssertTrue(issues.contains { $0.code == .invalidPercentage })
        XCTAssertTrue(issues.contains { $0.code == .invalidRest })
        XCTAssertTrue(issues.contains { $0.code == .invalidRPE })
        XCTAssertTrue(issues.contains { $0.code == .duplicateExposureKey })
    }

    func testValidatorRejectsCrossExerciseLoadReferenceCycles() {
        let first = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "volume",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(reference: .init(kind: .anotherPlannedExercise, exposureKey: "intensity"), percentage: 0.8)
                )
            ]
        )
        let second = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "intensity",
            orderIndex: 1,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(reference: .init(kind: .anotherPlannedExercise, exposureKey: "volume"), percentage: 0.8)
                )
            ]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [first, second]))
        XCTAssertTrue(issues.contains { $0.code == .referenceCycle })
    }

    func testValidatorRejectsInvalidConditioningValuesAndReferences() {
        let exercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "conditioning",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .duration(seconds: -1),
                    load: LoadPrescription(reference: .init(kind: .trainingMax))
                )
            ]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [exercise]))
        XCTAssertTrue(issues.contains { $0.code == .invalidPrescriptionValue })
        XCTAssertTrue(issues.contains { $0.code == .invalidLoadReference })
    }

    func testValidatorRejectsUnknownExposureReferencesBeforeActivation() {
        let loadExercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(
                    orderIndex: 0,
                    repetitions: .fixed(5),
                    load: LoadPrescription(
                        reference: .init(kind: .anotherPlannedExercise, exposureKey: "missing-bench"),
                        percentage: 0.8
                    )
                )
            ]
        )
        let formulaExercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "press",
            orderIndex: 1,
            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))],
            progressionRules: [
                ProgressionRuleDefinition(
                    metric: .trainingMax,
                    trigger: .cycleCompleted,
                    successAction: .updateTrainingMax(.add(
                        .source(.anotherExposure(exposureKey: "missing-squat")),
                        .source(.completedMetric(exposureKey: "missing-volume", metric: .totalVolume))
                    )),
                    cadence: .nextCycle,
                    scope: .cycle
                )
            ]
        )

        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [loadExercise, formulaExercise]))

        XCTAssertTrue(issues.contains { $0.code == .invalidLoadReference && $0.message.contains("missing-bench") })
        XCTAssertTrue(issues.contains { $0.code == .invalidFormula && $0.message.contains("missing-squat") })
        XCTAssertTrue(issues.contains { $0.code == .invalidFormula && $0.message.contains("missing-volume") })
    }

    func testValidatorRejectsDuplicateSetOrder() {
        let exercise = ProgramExerciseDefinition(
            exerciseID: UUID(),
            exposureKey: "squat",
            orderIndex: 0,
            plannedSets: [
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5)),
                SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5))
            ]
        )
        let issues = ProgramDefinitionValidator.validate(makeDefinition(exercises: [exercise]))
        XCTAssertTrue(issues.contains { $0.code == .invalidSetOrder })
    }

    func testValidatorRejectsCrossExposureFormulaCycles() {
        let ruleA = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .noChange,
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            formula: .source(.anotherExposure(exposureKey: "b"))
        )
        let ruleB = ProgressionRuleDefinition(
            metric: .load,
            trigger: .manualApproval,
            successAction: .noChange,
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            formula: .source(.anotherExposure(exposureKey: "a"))
        )
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "a",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleA]
            ),
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "b",
                orderIndex: 1,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleB]
            )
        ])

        XCTAssertTrue(ProgramDefinitionValidator.validate(definition).contains { $0.code == .formulaCycle })
    }

    func testValidatorChecksFormulaReferencesInsideTrainingMaxActions() {
        let ruleA = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(.source(.anotherExposure(exposureKey: "b"))),
            cadence: .nextCycle,
            scope: .cycle
        )
        let ruleB = ProgressionRuleDefinition(
            metric: .trainingMax,
            trigger: .cycleCompleted,
            successAction: .updateTrainingMax(.source(.anotherExposure(exposureKey: "a"))),
            cadence: .nextCycle,
            scope: .cycle
        )
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(), exposureKey: "a", orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleA]
            ),
            ProgramExerciseDefinition(
                exerciseID: UUID(), exposureKey: "b", orderIndex: 1,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(1))],
                progressionRules: [ruleB]
            )
        ])
        XCTAssertTrue(ProgramDefinitionValidator.validate(definition).contains { $0.code == .formulaCycle })
    }

    func testCompilerCreatesNormalPlanAndRunStatePerExposure() throws {
        let squat = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: squat.id,
                exposureKey: "squat-strength",
                orderIndex: 0,
                plannedSets: [
                    SetPrescriptionDefinition(
                        orderIndex: 0,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(
                            reference: LoadReference(kind: .fixedLoad),
                            fixedValue: 100,
                            rounding: .nearestIncrement(2.5)
                        )
                    ),
                    SetPrescriptionDefinition(
                        orderIndex: 1,
                        role: .working,
                        repetitions: .fixed(5),
                        load: LoadPrescription(
                            reference: LoadReference(kind: .fixedLoad),
                            fixedValue: 100,
                            rounding: .nearestIncrement(2.5)
                        )
                    )
                ]
            )
        ])

        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let plannedExercise = try XCTUnwrap(plan.orderedWeeks.first?.orderedPlannedWorkouts.first?.orderedPlannedExercises.first)
        XCTAssertEqual(plan.sourceProgramDefinitionID, definition.id)
        XCTAssertEqual(plan.sourceProgramDefinitionVersion, definition.templateVersion)
        XCTAssertEqual(plannedExercise.progressionKey, "squat-strength")
        XCTAssertEqual(plannedExercise.orderedPlannedSets.count, 2)
        XCTAssertEqual(plannedExercise.orderedPlannedSets.first?.suggestedLoad, 100)
        XCTAssertNotNil(plannedExercise.orderedPlannedSets.first?.definitionData)

        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.map(\.progressionKey), ["squat-strength"])
        XCTAssertEqual(run.orderedProgressionStates.first?.currentVariationExerciseID, squat.id)
    }

    func testDefinitionRecordStoresVersionedPayloadMetadata() throws {
        var definition = makeDefinition(exercises: [
            ProgramExerciseDefinition(
                exerciseID: UUID(),
                exposureKey: "row",
                orderIndex: 0,
                plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(10))]
            )
        ])
        definition.programKey = "row-program"
        let record = try ProgramDefinitionRecord(payload: definition, isBuiltIn: true)

        XCTAssertEqual(record.id, definition.id)
        XCTAssertEqual(record.templateVersion, definition.templateVersion)
        XCTAssertTrue(record.isBuiltIn)
        XCTAssertEqual(try record.payload(), definition)
    }

    func testProgramDefinitionBackupDTORoundTripsAndValidates() throws {
        let definition = makeDefinition(exercises: [
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

    func testLoadResolverExplainsTrainingMaxAndRoundsForEquipment() throws {
        var context = LoadResolutionContext()
        context.trainingMaxByExposure["squat"] = 108
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .trainingMax, exposureKey: "squat"),
                percentage: 0.85,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )

        XCTAssertEqual(result.referenceValue, 108)
        XCTAssertEqual(result.unroundedLoad ?? 0, 91.8, accuracy: 0.0001)
        XCTAssertEqual(result.prescribedLoad ?? 0, 92.5, accuracy: 0.0001)
        XCTAssertTrue(result.explanation.contains("85%"))
        XCTAssertTrue(result.explanation.contains("92.5"))
    }

    func testEquipmentDefaultsRoundInTheWorkoutUnitAndPreserveBodyweight() {
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                91.8,
                equipment: .barbell,
                resistance: .externalWeight,
                isPlateLoaded: true,
                unit: .kg
            )?.prescribedLoad ?? 0,
            92.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                31.1,
                equipment: .dumbbell,
                resistance: .externalWeight,
                isPlateLoaded: false,
                unit: .kg
            )?.prescribedLoad ?? 0,
            32,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                83.2,
                equipment: .cable,
                resistance: .machine,
                isPlateLoaded: false,
                unit: .lbs
            )?.prescribedLoad ?? 0,
            85,
            accuracy: 0.001
        )
        XCTAssertEqual(
            EquipmentLoadRounding.round(
                37.4,
                equipment: .bodyweight,
                resistance: .assistedBodyweight,
                isPlateLoaded: false,
                unit: .kg
            )?.prescribedLoad ?? 0,
            37.5,
            accuracy: 0.001
        )
        XCTAssertNil(EquipmentLoadRounding.round(
            37.4,
            equipment: .bodyweight,
            resistance: .bodyweight,
            isPlateLoaded: false,
            unit: .kg
        ))
    }

    func testLoadResolverSupportsTopSetBackOffAndMissingReferences() throws {
        var context = LoadResolutionContext()
        context.completedTopSetByExposure["bench-strength"] = 150
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: LoadReference(kind: .topSet, exposureKey: "bench-strength"),
                percentage: 0.9,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        XCTAssertEqual(result.prescribedLoad ?? 0, 135, accuracy: 0.0001)

        XCTAssertThrowsError(try ProgramLoadResolver.resolve(
            LoadPrescription(reference: LoadReference(kind: .trainingMax, exposureKey: "deadlift"), percentage: 0.8),
            context: context
        )) { error in
            XCTAssertEqual(error as? LoadResolutionError, .missingReference(.trainingMax))
        }
    }

    func testLoadResolverSupportsActualOneRepMaxReference() throws {
        var context = LoadResolutionContext()
        context.actualOneRepMaxByExposure["clean"] = 120
        let result = try ProgramLoadResolver.resolve(
            LoadPrescription(
                reference: .init(kind: .exerciseOneRepMax, exposureKey: "clean"),
                percentage: 1.1,
                rounding: .nearestIncrement(2.5)
            ),
            context: context
        )
        XCTAssertEqual(result.prescribedLoad, 132)
    }

    func testFormulaResolverSupportsCrossExposureAndSafeDivision() throws {
        var context = FormulaResolutionContext()
        context.trainingMaxByExposure["squat"] = 200
        context.valuesByExposure["offset"] = 5
        let formula: ProgressionFormula = .round(
            .add(
                .multiply(.source(.trainingMax(exposureKey: "squat")), .source(.constant(0.85))),
                .source(.anotherExposure(exposureKey: "offset"))
            ),
            rule: .nearestIncrement(2.5)
        )
        XCTAssertEqual(try ProgramFormulaResolver.resolve(formula, context: context), 175)
        XCTAssertThrowsError(try ProgramFormulaResolver.resolve(
            .divide(.source(.constant(10)), .source(.constant(0))),
            context: context
        )) { error in
            XCTAssertEqual(error as? FormulaResolutionError, .divisionByZero)
        }
    }

    func testProgressionEvaluatorAppliesLinearSuccessAndFailureActions() throws {
        let rules = [
            ProgressionRuleDefinition(
                metric: .load,
                trigger: .allRequiredSetsCompleted,
                successAction: .addLoad(2.5),
                failureAction: .repeatPrescription,
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                applicationMode: .automatic
            )
        ]
        let state = ProgressionEvaluationState(currentLoad: 100)
        let success = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            state: state
        )
        XCTAssertEqual(success.state.currentLoad, 102.5)
        XCTAssertEqual(success.recommendations.count, 1)
        XCTAssertEqual(success.recommendations.first?.applicationMode, .automatic)
        XCTAssertEqual(success.recommendations.first?.performance.completedSets, 3)

        let failure = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 2, didFail: true),
            state: state
        )
        XCTAssertEqual(failure.state.currentLoad, 100)
        XCTAssertEqual(failure.recommendations.first?.action, .repeatPrescription)
    }

    func testProgressionEvaluatorSupportsDoubleProgressionRecommendationAndVariationLadder() throws {
        let increaseRule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .allSetsReachedUpperRepBound,
            successAction: .addLoad(5),
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .recommendation
        )
        let variationRule = ProgressionRuleDefinition(
            metric: .exerciseVariation,
            trigger: .technicalQualityReached,
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [increaseRule, variationRule],
            performance: ProgressionPerformance(requiredSets: 3, upperBoundSets: 3, technicalQualityReached: true),
            state: ProgressionEvaluationState(currentLoad: 30, currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentLoad, 30)
        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertEqual(result.recommendations.first?.applicationMode, .recommendation)
        XCTAssertTrue(result.recommendations.contains { $0.action == .addLoad(5) })
    }

    func testProgressionEvaluatorSupportsTechnicalQualityRatio() throws {
        let rule = ProgressionRuleDefinition(
            metric: .technicalQuality,
            trigger: .successfulAttemptRatioReached(0.9),
            successAction: .advanceExerciseVariation,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let firstVariation = UUID()
        let secondVariation = UUID()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(successfulAttemptRatio: 0.9),
            state: ProgressionEvaluationState(currentVariationExerciseID: firstVariation),
            variationLadder: [firstVariation, secondVariation]
        )

        XCTAssertEqual(result.state.currentVariationExerciseID, secondVariation)
        XCTAssertEqual(result.recommendations.first?.action, .advanceExerciseVariation)
    }

    func testProgressionEvaluatorSupportsDurationDistanceAndRestProgression() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .duration, trigger: .allRequiredSetsCompleted, successAction: .addDuration(10), cadence: .nextExerciseOccurrence, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .distance, trigger: .allRequiredSetsCompleted, successAction: .addDistance(100), cadence: .nextExerciseOccurrence, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .restDuration, trigger: .allRequiredSetsCompleted, successAction: .reduceRestDuration(5), cadence: .nextExerciseOccurrence, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .calories, trigger: .allRequiredSetsCompleted, successAction: .addCalories(25), cadence: .nextExerciseOccurrence, scope: .exerciseExposure)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(requiredSets: 1, completedSets: 1),
            state: ProgressionEvaluationState(durationOffset: 30, distanceOffset: 500, restDurationOffset: 10, caloriesOffset: 100)
        )

        XCTAssertEqual(result.state.durationOffset, 40)
        XCTAssertEqual(result.state.distanceOffset, 600)
        XCTAssertEqual(result.state.restDurationOffset, 5)
        XCTAssertEqual(result.state.caloriesOffset, 125)
    }

    func testProgressionEvaluatorSupportsCalorieThresholds() throws {
        let rule = ProgressionRuleDefinition(
            metric: .calories,
            trigger: .totalCaloriesReached(500),
            successAction: .addCalories(50),
            cadence: .nextWorkout,
            scope: .exerciseExposure
        )
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(completedCalories: 525),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(result.state.caloriesOffset, 50)
    }

    func testProgressionEvaluatorResetsFailureAndOffsets() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetFailureCount, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic),
            ProgressionRuleDefinition(metric: .load, trigger: .manualApproval, successAction: .resetProgressionOffsets, cadence: .nextWorkout, scope: .exerciseExposure, applicationMode: .automatic)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(manualApproval: true),
            state: ProgressionEvaluationState(repetitionOffset: 2, setCountOffset: 1, durationOffset: 30, distanceOffset: 100, restDurationOffset: 5, caloriesOffset: 100, failureCount: 3)
        )
        XCTAssertEqual(result.state.failureCount, 0)
        XCTAssertEqual(result.state.repetitionOffset, 0)
        XCTAssertEqual(result.state.distanceOffset, 0)
        XCTAssertEqual(result.state.caloriesOffset, 0)
    }

    func testRequiredProgramFixturesValidateWithoutProgramSpecificLogic() {
        let ids = Dictionary(uniqueKeysWithValues: [
            "squat", "bench", "row", "press", "deadlift", "upper", "assisted", "band", "bodyweight", "weighted",
            "snatch", "pull", "complex", "clean", "jerk", "plank", "carry"
        ].map { ($0, UUID()) })
        let fixtures = [
            ProgramFixtureCatalog.beginnerFiveByFive(exerciseIDs: ids),
            ProgramFixtureCatalog.doubleProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.stageProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.trainingMaxCycle(exerciseIDs: ids),
            ProgramFixtureCatalog.topSetBackOff(exerciseIDs: ids),
            ProgramFixtureCatalog.bodyweightVariation(exerciseIDs: ids),
            ProgramFixtureCatalog.olympicWeightlifting(exerciseIDs: ids),
            ProgramFixtureCatalog.mixedAcceptance(exerciseIDs: ids),
            ProgramFixtureCatalog.weeklyHeavyLightMedium(exerciseIDs: ids),
            ProgramFixtureCatalog.amrapWave(exerciseIDs: ids),
            ProgramFixtureCatalog.blockPeriodized(exerciseIDs: ids),
            ProgramFixtureCatalog.conditioningProgression(exerciseIDs: ids),
            ProgramFixtureCatalog.waveLoading(exerciseIDs: ids)
        ]
        for fixture in fixtures {
            let issues = ProgramDefinitionValidator.validate(fixture)
            XCTAssertTrue(issues.isEmpty, "\(fixture.name): \(issues.map(\.message).joined(separator: " | "))")
        }
    }

    func testProgressionEvaluatorPersistsRepAndSetVolumeOffsets() throws {
        let rule = ProgressionRuleDefinition(
            metric: .repetitions,
            trigger: .weekCompleted,
            successAction: .addRepetitions(2),
            failureAction: .addSets(1),
            cadence: .nextWeek,
            scope: .exerciseExposure,
            applicationMode: .automatic
        )
        let state = ProgressionEvaluationState()
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: [rule],
            performance: ProgressionPerformance(weekCompleted: true),
            state: state
        )
        XCTAssertEqual(result.state.repetitionOffset, 2)
        XCTAssertEqual(result.state.setCountOffset, 0)
    }

    func testProgressionEvaluatorAdvancesWaveAndBlockState() throws {
        let rules = [
            ProgressionRuleDefinition(metric: .load, trigger: .waveCompleted, successAction: .advanceWave, cadence: .nextWave, scope: .exerciseExposure),
            ProgressionRuleDefinition(metric: .load, trigger: .blockCompleted, successAction: .advanceBlock, cadence: .nextBlock, scope: .exerciseExposure)
        ]
        let result = try ProgramProgressionEvaluator.evaluate(
            rules: rules,
            performance: ProgressionPerformance(waveCompleted: true, blockCompleted: true),
            state: ProgressionEvaluationState()
        )
        XCTAssertEqual(result.state.currentWaveIndex, 1)
        XCTAssertEqual(result.state.currentBlockIndex, 1)
    }

    func testCompiledExposureSeedsItsFirstRunValues() throws {
        let squat = Exercise(name: "Seeded Squat", primaryMuscles: [.quadriceps])
        let definition = ProgramDefinitionPayload(
            name: "Seeded Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [ProgramBlockDefinition(
                orderIndex: 0,
                name: "Main",
                weeks: [ProgramWeekDefinition(
                    weekIndex: 0,
                    workouts: [ProgramWorkoutDefinition(
                        orderIndex: 0,
                        name: "Day",
                        dayOffset: 0,
                        plannedExercises: [ProgramExerciseDefinition(
                            exerciseID: squat.id,
                            exposureKey: "seeded-squat",
                            orderIndex: 0,
                            plannedSets: [SetPrescriptionDefinition(orderIndex: 0, repetitions: .fixed(5), load: LoadPrescription(reference: .init(kind: .trainingMax, exposureKey: "seeded-squat"), percentage: 0.8))],
                            initialTrainingMax: 200,
                            initialActualOneRepMax: 220
                        )]
                    )]
                )]
            )]
        )
        let plan = try ProgramDefinitionCompiler.compile(definition, exercisesByID: [squat.id: squat])
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        XCTAssertEqual(run.orderedProgressionStates.first?.trainingMax, 200)
        XCTAssertEqual(run.orderedProgressionStates.first?.actualOneRepMax, 220)
        XCTAssertNil(run.orderedProgressionStates.first?.currentLoad, "No fixed current load should be invented from a percentage prescription")
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

    private func stageDefinition(exerciseID: UUID) -> ProgramDefinitionPayload {
        let volumeSets = (0..<2).map {
            SetPrescriptionDefinition(orderIndex: $0, repetitions: .fixed(8), restSeconds: 90)
        }
        let strengthSets = (0..<4).map {
            SetPrescriptionDefinition(orderIndex: $0, repetitions: .fixed(3), restSeconds: 150)
        }
        let exercise = ProgramExerciseDefinition(
            exerciseID: exerciseID,
            exposureKey: "squat-stage",
            orderIndex: 0,
            plannedSets: [],
            stages: [
                ProgramStageDefinition(stageID: "volume", name: "Volume", plannedSets: volumeSets),
                ProgramStageDefinition(stageID: "strength", name: "Strength", plannedSets: strengthSets)
            ],
            initialStageID: "volume",
            progressionRules: [
                ProgressionRuleDefinition(
                    metric: .load,
                    trigger: .allOf([.atStage("volume"), .allRequiredSetsCompleted]),
                    successAction: .changeStage("strength"),
                    cadence: .nextExerciseOccurrence,
                    scope: .exerciseExposure,
                    applicationMode: .automatic
                )
            ],
            initialLoad: 100
        )
        var definition = makeDefinition(exercises: [exercise])
        definition.programKey = "stage-program"
        return definition
    }

    private func makeDefinition(exercises: [ProgramExerciseDefinition]) -> ProgramDefinitionPayload {
        let workout = ProgramWorkoutDefinition(
            orderIndex: 0,
            name: "Training Day",
            dayOffset: 0,
            plannedExercises: exercises
        )
        let week = ProgramWeekDefinition(weekIndex: 0, workouts: [workout])
        let block = ProgramBlockDefinition(orderIndex: 0, name: "Accumulation", weeks: [week])
        return ProgramDefinitionPayload(
            name: "Test Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [block]
        )
    }
}
