import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanSchedulingTests: XCTestCase {
    func testReschedulingPromotesTheEarlierScheduledSessionToAvailable() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(
            PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000))
        )
        context.insert(run)
        try context.save()

        let sessions = run.orderedWorkoutProgress
        XCTAssertEqual(sessions[0].status, .available)
        XCTAssertEqual(sessions[1].status, .upcoming)

        let laterDate = try XCTUnwrap(sessions[1].scheduledDate)
        let earlierDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -5, to: laterDate))

        XCTAssertTrue(PlanCoordinator.reschedule(sessions[1], to: earlierDate, in: run))

        XCTAssertEqual(sessions[1].scheduledDate, Calendar.current.startOfDay(for: earlierDate))
        XCTAssertEqual(sessions[1].status, .available)
        XCTAssertEqual(sessions[0].status, .upcoming)
        XCTAssertEqual(PlanCoordinator.nextProgress(in: run)?.plannedWorkoutID, sessions[1].plannedWorkoutID)
    }

    func testDuplicateScheduledDatesFallBackToPlanOrder() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(
            PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000))
        )
        context.insert(run)
        try context.save()

        let sessions = run.orderedWorkoutProgress
        let sharedDate = try XCTUnwrap(sessions[0].scheduledDate)

        XCTAssertTrue(PlanCoordinator.reschedule(sessions[1], to: sharedDate, in: run))

        XCTAssertEqual(sessions[0].scheduledDate, sessions[1].scheduledDate)
        XCTAssertEqual(sessions[0].status, .available)
        XCTAssertEqual(sessions[1].status, .upcoming)
        XCTAssertEqual(PlanCoordinator.nextProgress(in: run)?.plannedWorkoutID, sessions[0].plannedWorkoutID)
    }

    func testCompletedSkippedAndInProgressSessionsCannotBeRescheduled() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(
            PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000))
        )
        context.insert(run)
        try context.save()

        let sessions = run.orderedWorkoutProgress
        let originalDate = sessions[0].scheduledDate
        let newDate = Date(timeIntervalSince1970: 1_800_000_000)

        sessions[0].status = .inProgress
        XCTAssertFalse(PlanCoordinator.reschedule(sessions[0], to: newDate, in: run))
        XCTAssertEqual(sessions[0].scheduledDate, originalDate)

        sessions[0].status = .completed
        XCTAssertFalse(PlanCoordinator.reschedule(sessions[0], to: newDate, in: run))
        XCTAssertEqual(sessions[0].scheduledDate, originalDate)

        sessions[0].status = .skipped
        XCTAssertFalse(PlanCoordinator.reschedule(sessions[0], to: newDate, in: run))
        XCTAssertEqual(sessions[0].scheduledDate, originalDate)
    }

    func testRescheduleSurvivesRelaunch() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        var rescheduledDate = Date.distantPast
        var runID = UUID()
        var promotedWorkoutID = UUID()
        var demotedWorkoutID = UUID()

        try withDiskContext(at: storeURL) { context in
            let plan = try self.makeScheduledPlan(in: context)
            let run = try XCTUnwrap(
                PlanCoordinator.startRun(for: plan, startDate: Date(timeIntervalSince1970: 1_700_000_000))
            )
            context.insert(run)
            try context.save()

            // Move the second session ahead of the first so the relaunch has to
            // restore a schedule that disagrees with plan order.
            let first = try XCTUnwrap(run.orderedWorkoutProgress.first)
            let second = try XCTUnwrap(run.orderedWorkoutProgress.dropFirst().first)
            let firstDate = try XCTUnwrap(first.scheduledDate)
            rescheduledDate = try XCTUnwrap(
                Calendar.current.date(byAdding: .day, value: -5, to: firstDate)
            )

            XCTAssertTrue(PlanCoordinator.reschedule(second, to: rescheduledDate, in: run))
            try context.save()

            runID = run.id
            promotedWorkoutID = second.plannedWorkoutID
            demotedWorkoutID = first.plannedWorkoutID
        }

        try withDiskContext(at: storeURL) { context in
            let run = try XCTUnwrap(
                context.fetch(FetchDescriptor<PlanRun>()).first { $0.id == runID }
            )
            let promoted = try XCTUnwrap(
                run.orderedWorkoutProgress.first { $0.plannedWorkoutID == promotedWorkoutID }
            )
            let demoted = try XCTUnwrap(
                run.orderedWorkoutProgress.first { $0.plannedWorkoutID == demotedWorkoutID }
            )
            XCTAssertEqual(promoted.scheduledDate, rescheduledDate)
            XCTAssertEqual(promoted.status, .available)
            XCTAssertEqual(demoted.status, .upcoming)
            XCTAssertEqual(PlanCoordinator.nextProgress(in: run)?.plannedWorkoutID, promotedWorkoutID)
        }
    }

    @discardableResult
    private func makeScheduledPlan(in context: ModelContext) throws -> WorkoutPlan {
        let exercise = Exercise(name: "Back Squat", primaryMuscles: [.quadriceps])
        let template = WorkoutTemplate(
            name: "Lower",
            exercises: [exercise],
            templateExercises: [TemplateExercise(exercise: exercise, order: 0)]
        )
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Scheduling Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0, 2]
        )
        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        return plan
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeDiskStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GymTrackerPlanSchedulingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("GymTracker.store")
    }

    private func withDiskContext<T>(
        at url: URL,
        _ body: (ModelContext) throws -> T
    ) throws -> T {
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: Workout.self,
            Exercise.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            configurations: configuration
        )
        return try body(ModelContext(container))
    }
}
