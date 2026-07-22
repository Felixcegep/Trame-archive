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
}
