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

    func testSkippingAvailableSessionAdvancesExactlyOnceAndPreservesPlanDefinition() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        context.insert(run)
        try context.save()

        let sessions = run.orderedWorkoutProgress
        let first = try XCTUnwrap(sessions.first)
        let firstWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: first, in: run))
        let originalDayOffset = firstWorkout.dayOffset
        let originalName = firstWorkout.name

        XCTAssertTrue(PlanCoordinator.skip(first, in: run, using: context))
        XCTAssertEqual(first.status, .skipped)
        XCTAssertNotNil(first.completedAt)
        XCTAssertEqual(PlanCoordinator.nextProgress(in: run)?.plannedWorkoutID, sessions[1].plannedWorkoutID)
        XCTAssertEqual(firstWorkout.dayOffset, originalDayOffset)
        XCTAssertEqual(firstWorkout.name, originalName)

        XCTAssertFalse(PlanCoordinator.skip(first, in: run, using: context))
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<PlanWorkoutProgress>()).filter { $0.status == .skipped }.count,
            1
        )
    }

    func testPausedRunsCanEditScheduleButCompletedAndArchivedRunsAreLocked() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        context.insert(run)
        try context.save()

        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let originalDate = try XCTUnwrap(progress.scheduledDate)
        let pausedDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 5, to: originalDate))
        run.status = .paused

        XCTAssertTrue(PlanCoordinator.canEditSchedule(run))
        XCTAssertTrue(PlanCoordinator.reschedule(progress, to: pausedDate, in: run, using: context))
        XCTAssertEqual(progress.scheduledDate, Calendar.current.startOfDay(for: pausedDate))

        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: progress, in: run))
        // The other session remains earlier in the paused run, so availability
        // may move to it after the reschedule. Set this progress to an
        // otherwise-valid available state to isolate the start guard below.
        progress.status = .available
        let viewModel = WorkoutViewModel()
        XCTAssertFalse(
            viewModel.startWorkout(
                from: plannedWorkout,
                progress: progress,
                in: run,
                using: context
            )
        )
        XCTAssertEqual(progress.status, .available)

        for terminalStatus in [PlanRunStatus.completed, .archived] {
            run.status = terminalStatus
            let terminalDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: pausedDate))
            XCTAssertFalse(PlanCoordinator.canEditSchedule(run))
            XCTAssertFalse(PlanCoordinator.reschedule(progress, to: terminalDate, in: run, using: context))
            XCTAssertEqual(progress.scheduledDate, Calendar.current.startOfDay(for: pausedDate))
            XCTAssertFalse(PlanCoordinator.skip(progress, in: run, using: context))
            XCTAssertEqual(progress.status, .available)
        }
    }

    func testRescheduleNormalizesCalendarDayAcrossDSTBoundary() throws {
        let context = try makeContext()
        let plan = try makeScheduledPlan(in: context)
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        context.insert(run)
        try context.save()

        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? calendar.timeZone
        let transitionDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))
        )
        let dayBefore = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: transitionDay))
        let target = try XCTUnwrap(calendar.date(byAdding: .hour, value: 30, to: dayBefore))

        XCTAssertTrue(PlanCoordinator.reschedule(progress, to: target, in: run, using: context))
        XCTAssertEqual(progress.scheduledDate, Calendar.current.startOfDay(for: target))
        XCTAssertEqual(calendar.component(.day, from: target), 8)
    }

    func testRelaunchRefreshPromotesSessionScheduledForToday() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        var runID = UUID()
        var todayWorkoutID = UUID()
        var tomorrowWorkoutID = UUID()

        try withDiskContext(at: storeURL) { context in
            let plan = try self.makeScheduledPlan(in: context)
            let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan, startDate: today))
            context.insert(run)
            try context.save()

            let sessions = run.orderedWorkoutProgress
            let originallyAvailable = sessions[0]
            let originallyUpcoming = sessions[1]
            originallyAvailable.scheduledDate = tomorrow
            originallyAvailable.status = .available
            originallyUpcoming.scheduledDate = today
            originallyUpcoming.status = .upcoming
            try context.save()

            runID = run.id
            todayWorkoutID = originallyUpcoming.plannedWorkoutID
            tomorrowWorkoutID = originallyAvailable.plannedWorkoutID
        }

        try withDiskContext(at: storeURL) { context in
            let run = try XCTUnwrap(
                context.fetch(FetchDescriptor<PlanRun>()).first { $0.id == runID }
            )
            PlanCoordinator.refreshAvailability(for: run)

            let next = try XCTUnwrap(PlanCoordinator.nextProgress(in: run))
            XCTAssertEqual(next.plannedWorkoutID, todayWorkoutID)
            XCTAssertEqual(next.status, .available)
            XCTAssertEqual(
                run.orderedWorkoutProgress.first { $0.plannedWorkoutID == tomorrowWorkoutID }?.status,
                .upcoming
            )
        }
    }

    func testRelaunchRefreshKeepsInProgressSessionAsTheOnlyCurrentSession() throws {
        let storeURL = try makeDiskStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        var runID = UUID()
        var inProgressWorkoutID = UUID()

        try withDiskContext(at: storeURL) { context in
            let plan = try self.makeScheduledPlan(in: context)
            let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
            context.insert(run)

            let first = try XCTUnwrap(run.orderedWorkoutProgress.first)
            first.status = .inProgress
            first.startedAt = .now
            try context.save()

            runID = run.id
            inProgressWorkoutID = first.plannedWorkoutID
        }

        try withDiskContext(at: storeURL) { context in
            let run = try XCTUnwrap(
                context.fetch(FetchDescriptor<PlanRun>()).first { $0.id == runID }
            )

            PlanCoordinator.refreshAvailability(for: run)

            XCTAssertEqual(PlanCoordinator.nextProgress(in: run)?.plannedWorkoutID, inProgressWorkoutID)
            XCTAssertEqual(
                run.orderedWorkoutProgress.filter { $0.status == .inProgress }.count,
                1
            )
            XCTAssertFalse(run.orderedWorkoutProgress.contains { $0.status == .available })
        }
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
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            ProgramDefinitionRecord.self,
            PlanProgressionRecommendationRecord.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseAlternative.self,
            PlannedSet.self,
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
            ExerciseRelationship.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutCollection.self,
            PlanRun.self,
            PlanWorkoutProgress.self,
            PlanExerciseProgressionState.self,
            ProgramDefinitionRecord.self,
            PlanProgressionRecommendationRecord.self,
            WorkoutPlan.self,
            PlanBlock.self,
            PlanWeek.self,
            PlannedWorkout.self,
            PlannedExercise.self,
            PlannedExerciseAlternative.self,
            PlannedSet.self,
            configurations: configuration
        )
        return try body(ModelContext(container))
    }
}
