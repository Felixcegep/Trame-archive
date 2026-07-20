import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutDataIntegrityTests: XCTestCase {
    func testDeletingWorkoutCascadesEntriesAndSets() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let workout = makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        context.delete(workout)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 1)
    }

    func testClearAllGymDataRemovesActiveWorkoutGraphInOneTransaction() throws {
        let context = try makeContext()
        let exercise = makeExercise()
        let workout = makeWorkout(with: exercise)
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        try context.clearAllGymData()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
    }

    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }

    private func makeWorkout(
        with exercise: Exercise,
        reps: Float = 8,
        weight: Float = 50
    ) -> Workout {
        let set = ExerciseSet(repetitions: reps, weight: weight, done: true, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let workout = Workout(name: "Test Workout", endTime: .now)
        workout.exercises = [entry]
        return workout
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
