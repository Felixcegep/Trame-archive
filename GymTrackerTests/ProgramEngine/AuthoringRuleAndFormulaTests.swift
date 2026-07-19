import Foundation
import XCTest
@testable import GymTracker

final class AuthoringRuleAndFormulaTests: XCTestCase {
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
}
