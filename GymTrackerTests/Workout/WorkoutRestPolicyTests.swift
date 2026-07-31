import XCTest
@testable import GymTracker

@MainActor
final class WorkoutRestPolicyTests: XCTestCase {
    func testMovementPatternAndLoadTiers() {
        XCTAssertEqual(seconds(pattern: .squat), 150)
        XCTAssertEqual(seconds(pattern: .hinge), 150)
        XCTAssertEqual(seconds(pattern: .squat, equipment: .barbell), 180)
        XCTAssertEqual(seconds(pattern: .horizontalPush), 90)
        XCTAssertEqual(seconds(pattern: .horizontalPush, equipment: .barbell), 120)
        XCTAssertEqual(seconds(pattern: .antiRotation), 60)
        XCTAssertEqual(seconds(pattern: nil), 90)
    }

    func testNonStrengthCategoryAndOverrides() throws {
        let cardio = Exercise(
            name: "Easy Run",
            primaryMuscles: [.quadriceps],
            category: .cardio,
            movementPattern: .locomotion
        )
        XCTAssertEqual(WorkoutRestPolicy.defaultSeconds(for: cardio), 60)

        let exercise = Exercise(
            name: "Bench",
            primaryMuscles: [.middleChest],
            movementPattern: .horizontalPush
        )
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.prescribedRestSeconds = 37
        XCTAssertEqual(WorkoutRestPolicy.defaultSeconds(for: entry), 90)

        let nextSet = ExerciseSet(orderIndex: 1, usedMetric: .metric)
        let completedSet = ExerciseSet(done: true, orderIndex: 0, usedMetric: .metric)
        entry.sets = [completedSet, nextSet]
        let workout = Workout(name: "Rest policy fixture")
        workout.exercises = [entry]
        XCTAssertEqual(
            WorkoutSetSelector.restSeconds(afterCompleting: entry, in: workout, defaultSeconds: WorkoutRestPolicy.defaultSeconds(for: entry)),
            37
        )
    }

    func testDefaultIsNotTheLegacyTwentySeconds() {
        XCTAssertNotEqual(WorkoutRestPolicy.defaultSeconds(for: Exercise(
            name: "Unknown",
            primaryMuscles: [.quadriceps],
            movementPattern: nil
        )), 20)
    }

    private func seconds(
        pattern: MovementPattern?,
        equipment: EquipmentType = .other
    ) -> Int {
        let exercise = Exercise(
            name: "Rest fixture",
            primaryMuscles: [.quadriceps],
            equipmentType: equipment,
            movementPattern: pattern
        )
        return WorkoutRestPolicy.defaultSeconds(for: exercise)
    }
}
