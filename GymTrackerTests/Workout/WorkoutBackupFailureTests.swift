import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutBackupFailureTests: XCTestCase {
    func testInvalidPlanRunBackupDoesNotReplaceExistingData() throws {
        let context = try makeContext()
        let sentinel = Exercise(name: "Do Not Delete", primaryMuscles: [.upperChest])
        context.insert(sentinel)
        try context.save()

        let missingPlanID = UUID().uuidString
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            plans: [],
            planRuns: [
                PlanRunDTO(
                    id: UUID().uuidString,
                    sourcePlanID: missingPlanID,
                    sourcePlanName: "Missing",
                    planID: missingPlanID,
                    startDate: .now,
                    endDate: nil,
                    status: PlanRunStatus.active.rawValue,
                    currentWeekIndex: 0,
                    currentWorkoutIndex: 0,
                    createdAt: .now,
                    updatedAt: .now,
                    workoutProgress: []
                )
            ]
        )

        XCTAssertThrowsError(try backup.restore(to: context)) { error in
            guard case .missingPlan(let identifier) = error as? BackupValidationError else {
                return XCTFail("Expected a missing-plan validation error, got \(error)")
            }
            XCTAssertEqual(identifier, missingPlanID)
        }
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == sentinel.name }
        )
    }

    func testBackupInterruptionBeforeCommitPreservesExistingDatabase() throws {
        let context = try makeContext()
        let sentinel = Exercise(name: "Keep During Import", primaryMuscles: [.upperChest])
        context.insert(sentinel)
        try context.save()

        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            plans: [],
            planRuns: []
        )

        XCTAssertThrowsError(
            try backup.restore(to: context, beforeCommit: {
                throw NSError(domain: "BackupRestoreTest", code: 1)
            })
        )
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == sentinel.name }
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
    }

    func testBackupReplacementSurvivesDiskRelaunchWithPlanRunHistoryLinks() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let backup = try makePlanRunBackup()

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Replace Me", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()
            try backup.restore(to: context)
        }

        try withDiskContext(at: storeURL) { context in
            let exercises = try context.fetch(FetchDescriptor<Exercise>())
            XCTAssertFalse(exercises.contains { $0.name == "Replace Me" })
            XCTAssertTrue(exercises.contains { $0.name == "Bench Press" })

            // Restore also installs the seeded rehabilitation plan, and an
            // unsorted fetch has no defined order — select the backup's own plan
            // by name instead of trusting whichever row comes back first.
            let plan = try XCTUnwrap(
                context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Backup Plan" }
            )
            let run = try XCTUnwrap(
                context.fetch(FetchDescriptor<PlanRun>()).first { $0.plan?.id == plan.id }
            )
            let workout = try XCTUnwrap(context.fetch(FetchDescriptor<Workout>()).first {
                $0.status == .completed
            })
            let completedProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)

            XCTAssertEqual(plan.name, "Backup Plan")
            XCTAssertEqual(run.plan?.id, plan.id)
            XCTAssertEqual(completedProgress.status, .completed)
            XCTAssertEqual(completedProgress.completedWorkout?.id, workout.id)
            XCTAssertEqual(workout.sourcePlanRunID, run.id)
            XCTAssertEqual(workout.sourcePlannedWorkoutID, completedProgress.plannedWorkoutID)
            XCTAssertEqual(run.orderedWorkoutProgress.dropFirst().first?.status, .available)
        }
    }

    func testCorruptDiskBackupLeavesOriginalDatabaseAfterRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Keep Corrupt Import", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()

            XCTAssertThrowsError(
                try JSONDecoder().decode(BackupDTO.self, from: Data("not-json".utf8))
            )

            let invalidPlanID = UUID().uuidString
            let backup = BackupDTO(
                version: BackupDTO.currentVersion,
                preferences: PreferencesDTO(
                    darkMode: true,
                    restTimer: 120,
                    unitSystem: UnitSystem.imperial.rawValue
                ),
                exercises: [],
                templates: [],
                collections: [],
                workouts: [],
                plans: [],
                planRuns: [
                    PlanRunDTO(
                        id: UUID().uuidString,
                        sourcePlanID: invalidPlanID,
                        sourcePlanName: "Missing plan",
                        planID: invalidPlanID,
                        startDate: .now,
                        endDate: nil,
                        status: PlanRunStatus.active.rawValue,
                        currentWeekIndex: 0,
                        currentWorkoutIndex: 0,
                        createdAt: .now,
                        updatedAt: .now,
                        workoutProgress: []
                    )
                ]
            )

            XCTAssertThrowsError(try backup.restore(to: context))
        }

        try withDiskContext(at: storeURL) { context in
            XCTAssertTrue(
                try context.fetch(FetchDescriptor<Exercise>()).contains {
                    $0.name == "Keep Corrupt Import"
                }
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
        }
    }

    func testInterruptedDiskBackupRestoreLeavesOriginalDatabaseAfterRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let backup = try makePlanRunBackup()

        try withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Keep Interrupted Import", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()

            XCTAssertThrowsError(
                try backup.restore(to: context, beforeCommit: {
                    throw NSError(domain: "BackupRestoreTest", code: 2)
                })
            )
        }

        try withDiskContext(at: storeURL) { context in
            XCTAssertTrue(
                try context.fetch(FetchDescriptor<Exercise>()).contains {
                    $0.name == "Keep Interrupted Import"
                }
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutPlan>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<PlanRun>()).isEmpty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
        }
    }


    private func makePlanRunBackup() throws -> BackupDTO {
        let source = try makeContext()
        let exercise = makeExercise()
        let template = makeTemplate(exercise: exercise, targetSets: 1)
        template.name = "Backup Plan Template"
        let plan = PlanCoordinator.createPlan(
            name: "Backup Plan",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: template),
                .init(dayOffset: 2, template: template)
            ]
        )
        let run = try XCTUnwrap(
            PlanCoordinator.startRun(
                for: plan,
                startDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(
            PlanCoordinator.plannedWorkout(for: firstProgress, in: run)
        )
        let completedWorkout = Workout(
            plannedWorkout: firstPlannedWorkout,
            planRun: run,
            unitSystem: .metric
        )
        completedWorkout.status = .completed
        completedWorkout.endTime = Date(timeIntervalSince1970: 1_700_003_600)
        let firstSet = try XCTUnwrap(completedWorkout.orderedExercises.first?.orderedSets.first)
        firstSet.repetitions = 8
        firstSet.weight = 50
        firstSet.done = true
        PlanCoordinator.markCompleted(firstProgress, with: completedWorkout, in: run)

        source.insert(exercise)
        source.insert(template)
        source.insert(plan)
        source.insert(run)
        source.insert(completedWorkout)
        try source.save()

        return try BackupDTO.create(
            from: source,
            restTimer: 120,
            darkMode: true,
            unitSystem: .imperial
        )
    }

    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    private func makeDiskStoreURL() throws -> URL {
        try WorkoutTestFixture.makeDiskStoreURL()
    }

    private func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        try WorkoutTestFixture.withDiskContext(at: url, body)
    }


    private func makeTemplate(exercise: Exercise, targetSets: Int) -> WorkoutTemplate {
        WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: targetSets)
    }
}
