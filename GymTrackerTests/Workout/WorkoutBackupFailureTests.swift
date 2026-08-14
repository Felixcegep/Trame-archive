import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutBackupFailureTests: XCTestCase {
    func testInvalidPlanRunBackupDoesNotReplaceExistingData() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
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
            XCTAssertEqual(UUID(uuidString: identifier), UUID(uuidString: missingPlanID))
        }
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == sentinel.name }
        )
    }

    func testMobilityRecommendationCannotReferenceSessionProgressFromAnotherRun() throws {
        let firstRunID = UUID().uuidString
        let secondRunID = UUID().uuidString
        let firstProgressID = UUID().uuidString
        let secondProgressID = UUID().uuidString
        let snapshotData = try JSONEncoder().encode(makeMobilityProgramPayload())
        let recommendation = MobilityProgressionRecommendationDTO(
            id: UUID().uuidString,
            runID: firstRunID,
            sessionProgressID: secondProgressID,
            progressionKey: "progression",
            side: MobilitySide.none.rawValue,
            ruleID: UUID().uuidString,
            actionData: try JSONEncoder().encode(MobilityProgressionAction.addCycle),
            reason: "Test recommendation",
            reasonKey: nil,
            applicationMode: ProgressionApplicationMode.recommendation.rawValue,
            performanceData: nil,
            proposedDurationOffsetSeconds: 0,
            proposedRepetitionOffset: 0,
            proposedCycleOffset: 1,
            proposedLoadOffset: 0,
            proposedAssistanceLevelOffset: 0,
            proposedSupportLevelStepOffset: 0,
            proposedVariationStepOffset: 0,
            createdAt: .now,
            isResolved: false,
            resolvedAt: nil,
            decisionOutcome: nil
        )
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            mobilityProgramRuns: [
                makeMobilityProgramRunDTO(id: firstRunID, progressID: firstProgressID, snapshotData: snapshotData),
                makeMobilityProgramRunDTO(id: secondRunID, progressID: secondProgressID, snapshotData: snapshotData)
            ],
            mobilityProgressionRecommendations: [recommendation]
        )

        XCTAssertThrowsError(try backup.validate()) { error in
            guard case .invalidIdentifier("mobility progression recommendation") = error as? BackupValidationError else {
                return XCTFail("Expected a cross-run mobility recommendation validation error, got \(error)")
            }
        }
    }

    func testBackupInterruptionBeforeCommitPreservesExistingDatabase() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
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
        let storeURL = try WorkoutTestFixture.makeDiskStoreURL()
        let backup = try makePlanRunBackup()

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Replace Me", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()
            try backup.restore(to: context)
        }

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
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
        let storeURL = try WorkoutTestFixture.makeDiskStoreURL()

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
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

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
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
        let storeURL = try WorkoutTestFixture.makeDiskStoreURL()
        let backup = try makePlanRunBackup()

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
            let sentinel = Exercise(name: "Keep Interrupted Import", primaryMuscles: [.upperChest])
            context.insert(sentinel)
            try context.save()

            XCTAssertThrowsError(
                try backup.restore(to: context, beforeCommit: {
                    throw NSError(domain: "BackupRestoreTest", code: 2)
                })
            )
        }

        try WorkoutTestFixture.withDiskContext(at: storeURL) { context in
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


    private func makeMobilityProgramPayload() -> MobilityProgramDefinitionPayload {
        let occurrence = MobilityMovementOccurrenceDefinition(
            occurrenceID: "occurrence-0",
            mobilityDefinitionID: UUID(),
            orderIndex: 0,
            targets: MobilityMetricTargets(durationSeconds: .exact(30))
        )
        let session = MobilityPlannedSessionDefinition(
            sessionKey: "session-0",
            weekIndex: 0,
            dayIndex: 0,
            name: "Session",
            recipe: MobilityRoutineRecipeDefinition(occurrences: [occurrence])
        )
        let week = MobilityProgramWeekDefinition(weekIndex: 0, sessions: [session])
        let block = MobilityProgramBlockDefinition(orderIndex: 0, name: "Block", weeks: [week])
        return MobilityProgramDefinitionPayload(
            name: "Test Mobility Program",
            durationWeeks: 1,
            supportedDaysPerWeek: [1],
            blocks: [block]
        )
    }

    private func makeMobilityProgramRunDTO(
        id: String,
        progressID: String,
        snapshotData: Data
    ) -> MobilityProgramRunDTO {
        MobilityProgramRunDTO(
            id: id,
            sourceProgramID: UUID().uuidString,
            sourceProgramName: "Test Mobility Program",
            startDate: .now,
            endDate: nil,
            status: MobilityProgramRunStatus.active.rawValue,
            currentWeekIndex: 0,
            currentSessionIndex: 0,
            programSnapshotData: snapshotData,
            createdAt: .now,
            updatedAt: .now,
            sessionProgress: [
                MobilityProgramSessionProgressDTO(
                    id: progressID,
                    sessionKey: "session-0",
                    weekIndex: 0,
                    dayIndex: 0,
                    sameDayOrder: 0,
                    isOptional: false,
                    sessionNameSnapshot: "Session",
                    status: MobilityProgramSessionStatus.pending.rawValue,
                    originalScheduledDate: nil,
                    scheduledDate: nil,
                    lastRescheduledAt: nil,
                    startedAt: nil,
                    completedAt: nil,
                    mobilitySessionID: nil
                )
            ],
            progressionStates: []
        )
    }

    private func makePlanRunBackup() throws -> BackupDTO {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
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

    // Each disk-backed test below calls through to this, which mints a fresh
    // FileManager.default.temporaryDirectory subdirectory keyed by a new UUID
    // per call (see WorkoutTestFixture.makeDiskStoreURL). That is what keeps
    // this file's disk-backed tests from colliding when scheduled adjacently
    // in the same run — the flakiness FeaturesList.md:156 documents. Every
    // test also removes its own directory in a `defer`, so nothing leaks
    // between runs either. Verified by running this suite twice in one
    // invocation (see PR notes).
}
