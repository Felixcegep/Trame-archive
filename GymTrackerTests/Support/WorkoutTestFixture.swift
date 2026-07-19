import Foundation
import SwiftData
@testable import GymTracker

@MainActor
enum WorkoutTestFixture {
    static func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }

    static func makeTemplate(exercise: Exercise, targetSets: Int) -> WorkoutTemplate {
        WorkoutTemplate(
            name: "Bench Template",
            exercises: [exercise],
            templateExercises: [
                TemplateExercise(
                    exercise: exercise,
                    order: 0,
                    targetSets: targetSets,
                    repRangeMinimum: 6,
                    repRangeMaximum: 8,
                    progressionRule: .doubleProgression
                )
            ]
        )
    }

    static func makeWorkout(
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

    static func previousSet(order: Int, reps: Float, weight: Float) -> PreviousSetPerformance {
        PreviousSetPerformance(
            orderIndex: order,
            repetitions: reps,
            weight: weight,
            weightType: .lbs,
            duration: nil,
            distance: nil,
            distanceType: .miles,
            setType: .normal
        )
    }

    static func makeDiskStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTrackerBackupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("GymTracker.store")
    }

    static func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        try GymTrackerTestStore.withDiskContext(at: url, body)
    }
}
