import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseHistoricalIdentityTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    private func makeCompletedWorkout(entryName: String, exercise: Exercise, in context: ModelContext) -> Workout {
        let workout = Workout(name: "Session", endTime: .now)
        workout.status = .completed
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [ExerciseSet(repetitions: 8, weight: 60, done: true, orderIndex: 0, usedMetric: .metric)]
        workout.exercises = [entry]
        context.insert(workout)
        return workout
    }

    func testRenamingAnExerciseDoesNotChangeAnAlreadyCapturedSnapshot() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Original Name", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(exercise)
        let workout = makeCompletedWorkout(entryName: "Original Name", exercise: exercise, in: context)
        try context.save()

        let entry = try XCTUnwrap(workout.exercises.first)
        let originalID = entry.historicalExerciseID
        XCTAssertEqual(entry.nameSnapshot, "Original Name")

        exercise.name = "Renamed Later"
        try context.save()

        XCTAssertEqual(entry.nameSnapshot, "Original Name", "Renaming the live exercise must never rewrite an already-captured snapshot.")
        XCTAssertEqual(entry.displayName, "Original Name")
        XCTAssertEqual(entry.historicalExerciseID, originalID)
    }

    func testBackupV15RoundTripPreservesNameSnapshotAcrossARenameBetweenExportAndImport() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Original Name", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(exercise)
        let workout = makeCompletedWorkout(entryName: "Original Name", exercise: exercise, in: context)
        try context.save()

        let originalEntryID = try XCTUnwrap(workout.exercises.first).historicalExerciseID

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        XCTAssertGreaterThanOrEqual(backup.version, BackupDTO.historicalIdentitySnapshotVersion)

        // Simulate the source exercise being renamed after the backup was
        // taken but before it is restored elsewhere.
        exercise.name = "Renamed After Export"
        try context.save()

        let restoredContext = try makeContext()
        try backup.restore(to: restoredContext)

        let restoredWorkout = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<Workout>()).first)
        let restoredEntry = try XCTUnwrap(restoredWorkout.exercises.first)
        XCTAssertEqual(restoredEntry.nameSnapshot, "Original Name", "Restore must use the entry's own historical snapshot, not the current live name.")
        XCTAssertEqual(restoredEntry.historicalExerciseID, originalEntryID)
    }

    func testLegacyV14BackupWithoutSnapshotFieldsRestoresUsingTheLinkedExercise() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Legacy Exercise", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(exercise)
        let workout = makeCompletedWorkout(entryName: "Legacy Exercise", exercise: exercise, in: context)
        try context.save()

        let originalBackup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalBackup)

        // `BackupDTO` and `ExerciseEntryDTO` are all `let` fields, so a v14
        // fixture (no historical-identity keys at all) is produced by
        // stripping those keys from the encoded JSON rather than by
        // constructing a partially-populated DTO in Swift.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = BackupDTO.templateStimulusVersion
        var workoutDicts = try XCTUnwrap(json["workouts"] as? [[String: Any]])
        for workoutIndex in workoutDicts.indices {
            var entryDicts = try XCTUnwrap(workoutDicts[workoutIndex]["exercises"] as? [[String: Any]])
            for entryIndex in entryDicts.indices {
                for key in ["nameSnapshot", "exerciseIDSnapshot", "trackingTypeSnapshot", "lateralitySnapshot", "repCountingStyleSnapshot", "weightEntryStyleSnapshot", "loadUnitCountSnapshot"] {
                    entryDicts[entryIndex].removeValue(forKey: key)
                }
            }
            workoutDicts[workoutIndex]["exercises"] = entryDicts
        }
        json["workouts"] = workoutDicts

        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupDTO.self, from: legacyData)

        let restoredContext = try makeContext()
        try backup.restore(to: restoredContext)

        let restoredWorkout = try XCTUnwrap(try restoredContext.fetch(FetchDescriptor<Workout>()).first)
        let restoredEntry = try XCTUnwrap(restoredWorkout.exercises.first)
        XCTAssertEqual(restoredEntry.nameSnapshot, "Legacy Exercise", "A v14 backup carries no snapshot fields, so restore must fall back to the newly linked exercise as it always has.")
        XCTAssertEqual(restoredEntry.historicalExerciseID, restoredEntry.exercise.id)
    }

    func testDuplicateNameExercisesRemainDistinctBySnapshotUUID() throws {
        let context = try makeContext()
        let system = Exercise(name: "Bench Press", primaryMuscles: [.middleChest], isCustom: false)
        let custom = Exercise(name: "Bench Press", primaryMuscles: [.upperChest], isCustom: true)
        context.insert(system)
        context.insert(custom)
        let systemWorkout = makeCompletedWorkout(entryName: "Bench Press", exercise: system, in: context)
        let customWorkout = makeCompletedWorkout(entryName: "Bench Press", exercise: custom, in: context)
        try context.save()

        let systemEntryID = try XCTUnwrap(systemWorkout.exercises.first).historicalExerciseID
        let customEntryID = try XCTUnwrap(customWorkout.exercises.first).historicalExerciseID
        XCTAssertNotEqual(systemEntryID, customEntryID)

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let restoredContext = try makeContext()
        try backup.restore(to: restoredContext)

        let restoredWorkouts = try restoredContext.fetch(FetchDescriptor<Workout>())
        let restoredEntries = restoredWorkouts.compactMap(\.exercises.first)
        XCTAssertEqual(restoredEntries.count, 2)
        let restoredIDs = Set(restoredEntries.map(\.historicalExerciseID))
        XCTAssertEqual(restoredIDs, [systemEntryID, customEntryID], "Both duplicate-named entries must round-trip with their own distinct historical identity.")
    }
}
