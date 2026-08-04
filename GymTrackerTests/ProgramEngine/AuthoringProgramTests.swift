import Foundation
import XCTest
@testable import GymTracker

final class AuthoringProgramTests: XCTestCase {
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
        let set = try authoring.expand(
            path: "velocity/s0",
            orderIndex: 0,
            defaultRestSeconds: 120,
            exposureKey: "squat",
            exerciseIDsByName: [:]
        )

        XCTAssertEqual(set.velocity?.targetMinimum, 0.5)
        XCTAssertEqual(set.velocity?.targetMaximum, 0.7)
        XCTAssertEqual(set.velocity?.lossStopPercent, 20)
        XCTAssertEqual(set.velocity?.isProbe, true)
        let decoded = try JSONDecoder().decode(SetPrescriptionDefinition.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(decoded.velocity, set.velocity)
    }

    func testAuthoringComplexResolvesOrderedNamedComponents() throws {
        let authoring = try JSONDecoder().decode(AuthoringDirectSetDefinition.self, from: Data("""
        {
          "reps": 2,
          "complex": [
            {"exercise": "Hang Snatch", "reps": 1},
            {"exercise": "Snatch", "reps": 1}
          ]
        }
        """.utf8))
        let hang = UUID()
        let snatch = UUID()

        let set = try authoring.expand(
            path: "complex/s0",
            orderIndex: 0,
            defaultRestSeconds: nil,
            exposureKey: "three-position-snatch",
            exerciseIDsByName: ["Hang Snatch": hang, "Snatch": snatch]
        )

        XCTAssertEqual(set.repetitions, .sequence([
            RepComponent(exerciseID: hang, repetitions: 1, exerciseNameSnapshot: "Hang Snatch"),
            RepComponent(exerciseID: snatch, repetitions: 1, exerciseNameSnapshot: "Snatch")
        ]))
    }

    func testAuthoringProgramMatchingMetadataExpansionAndValidation() throws {
        let json = """
        {
          "programKey": "matching-metadata-test",
          "name": "Matching Metadata Test",
          "goal": "generalStrength",
          "experienceLevel": "intermediate",
          "durationWeeks": 4,
          "supportedDaysPerWeek": [3],
          "scheduleMode": "fixedWeekdays",
          "supportedDisciplineIDs": ["powerlifting", "generalStrength"],
          "focusAreaIDs": ["lowerBody", "upperBody"],
          "estimatedSessionMinutesMinimum": 60,
          "estimatedSessionMinutesMaximum": 90,
          "competitionDisciplineID": "powerlifting",
          "optionalEquipmentCapabilityIDs": ["bands", "chains"],
          "blocks": [{
            "name": "Base",
            "phaseType": "strength",
            "weeks": [{
              "weekIndex": 0,
              "workouts": [{"name": "Day 1", "dayOffset": 0, "exercises": []}]
            }]
          }]
        }
        """
        let authoring = try JSONDecoder().decode(AuthoringProgramDefinition.self, from: Data(json.utf8))
        XCTAssertEqual(authoring.supportedDisciplineIDs, ["powerlifting", "generalStrength"])
        XCTAssertEqual(authoring.estimatedSessionMinutesMinimum, 60)
        XCTAssertEqual(authoring.estimatedSessionMinutesMaximum, 90)

        let payload = try authoring.expand(exerciseIDsByName: [:])
        XCTAssertEqual(payload.supportedDisciplineIDs, ["powerlifting", "generalStrength"])
        XCTAssertEqual(payload.focusAreaIDs, ["lowerBody", "upperBody"])
        XCTAssertEqual(payload.estimatedSessionMinutesMinimum, 60)
        XCTAssertEqual(payload.estimatedSessionMinutesMaximum, 90)
        XCTAssertEqual(payload.competitionDisciplineID, "powerlifting")
        XCTAssertEqual(payload.optionalEquipmentCapabilityIDs, ["bands", "chains"])

        let issues = ProgramDefinitionValidator.validate(payload)
        XCTAssertTrue(issues.isEmpty, "Validation should pass with valid session minutes")

        // Round trip test
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ProgramDefinitionPayload.self, from: encoded)
        XCTAssertEqual(decoded.supportedDisciplineIDs, payload.supportedDisciplineIDs)
        XCTAssertEqual(decoded.estimatedSessionMinutesMinimum, 60)
        XCTAssertEqual(decoded.estimatedSessionMinutesMaximum, 90)

        // Invalid minute range test
        var invalidPayload = payload
        invalidPayload.estimatedSessionMinutesMinimum = 100
        invalidPayload.estimatedSessionMinutesMaximum = 50
        let invalidIssues = ProgramDefinitionValidator.validate(invalidPayload)
        XCTAssertTrue(invalidIssues.contains { $0.path == "estimatedSessionMinutesMinimum" && $0.code == .invalidPrescriptionValue })
    }
}
