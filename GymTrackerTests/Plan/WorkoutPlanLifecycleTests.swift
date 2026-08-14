import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutPlanLifecycleTests: XCTestCase {
    func testPlannedWorkoutSaveCompletesRunProgressAndMakesNextWorkoutAvailable() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        let plan = PlanCoordinator.createPlan(
            name: "Integration Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: template),
                .init(dayOffset: 2, template: template)
            ]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let firstPlannedWorkout = try XCTUnwrap(
            PlanCoordinator.plannedWorkout(for: firstProgress, in: run)
        )
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(
            viewModel.startWorkout(
                from: firstPlannedWorkout,
                progress: firstProgress,
                in: run,
                using: context
            )
        )
        XCTAssertEqual(firstProgress.status, .inProgress)

        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeSet = try XCTUnwrap(activeWorkout.orderedExercises.first?.orderedSets.first)
        activeSet.repetitions = 8
        activeSet.weight = 50
        activeSet.done = true

        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(activeWorkout.status, .completed)
        XCTAssertEqual(firstProgress.status, .completed)
        XCTAssertEqual(firstProgress.completedWorkout?.persistentModelID, activeWorkout.persistentModelID)
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(run.status, .active)
        XCTAssertEqual(run.orderedWorkoutProgress[1].status, .available)

        let savedWorkouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(savedWorkouts.filter { $0.status == .completed }.count, 1)
        XCTAssertEqual(activeWorkout.sourcePlanRunID, run.id)
        XCTAssertEqual(activeWorkout.sourcePlannedWorkoutID, firstPlannedWorkout.id)
        XCTAssertEqual(activeWorkout.orderedExercises.map(\.exercise.name), ["Bench Press"])
        XCTAssertFalse(WorkoutViewModel().restoreActiveWorkout(using: context))
    }

    func testPartialPlannedWorkoutSaveKeepsOnlyCompletedSetsAndAdvancesOnce() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 2)
        let plan = PlanCoordinator.createPlan(
            name: "Partial Planned Save",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            dayAssignments: [
                .init(dayOffset: 0, template: template),
                .init(dayOffset: 2, template: template)
            ]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))
        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let firstProgress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: firstProgress, in: run))
        let viewModel = WorkoutViewModel()
        XCTAssertTrue(
            viewModel.startWorkout(
                from: plannedWorkout,
                progress: firstProgress,
                in: run,
                using: context
            )
        )

        let activeWorkout = try XCTUnwrap(viewModel.activeWorkout)
        let activeEntry = try XCTUnwrap(activeWorkout.orderedExercises.first)
        let completedSet = try XCTUnwrap(activeEntry.orderedSets.first)
        completedSet.repetitions = 8
        completedSet.weight = 50
        completedSet.done = true

        XCTAssertTrue(viewModel.saveWorkout(using: context))
        XCTAssertFalse(viewModel.saveWorkout(using: context))
        XCTAssertEqual(firstProgress.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress[1].status, .available)
        XCTAssertEqual(activeWorkout.status, .completed)
        XCTAssertEqual(activeWorkout.orderedExercises.count, 1)
        XCTAssertEqual(activeWorkout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertTrue(activeWorkout.orderedExercises.first?.orderedSets.first?.done == true)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .completed }.count,
            1
        )
    }

    func testDiscardingPlannedWorkoutRestoresRunAvailabilityAndDeletesActiveWorkout() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Recovery Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        let run = try XCTUnwrap(PlanCoordinator.startRun(for: plan))

        context.insert(exercise)
        context.insert(template)
        context.insert(plan)
        context.insert(run)
        try context.save()

        let progress = try XCTUnwrap(run.orderedWorkoutProgress.first)
        let plannedWorkout = try XCTUnwrap(PlanCoordinator.plannedWorkout(for: progress, in: run))
        let viewModel = WorkoutViewModel()

        XCTAssertTrue(
            viewModel.startWorkout(
                from: plannedWorkout,
                progress: progress,
                in: run,
                using: context
            )
        )
        XCTAssertEqual(progress.status, .inProgress)

        viewModel.discardActiveWorkout(using: context)

        XCTAssertEqual(progress.status, .available)
        XCTAssertNil(progress.startedAt)
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Workout>()).filter { $0.status == .active }.isEmpty
        )
    }

    func testSavingWorkoutExcludesIncompleteSetsAndEmptyExercisesFromHistory() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let completedExercise = WorkoutTestFixture.makeExercise()
        let emptyExercise = Exercise(name: "Cable Fly", primaryMuscles: [.upperChest])
        let workout = Workout(name: "Partial")
        let completedEntry = ExerciseEntry(exercise: completedExercise, usedMetric: .metric)
        completedEntry.sets = [
            ExerciseSet(repetitions: 8, weight: 50, done: true, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 50, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let emptyEntry = ExerciseEntry(exercise: emptyExercise, usedMetric: .metric)
        emptyEntry.sets = [ExerciseSet(repetitions: 0, weight: 20, usedMetric: .metric)]
        workout.exercises = [completedEntry, emptyEntry]

        context.insert(completedExercise)
        context.insert(emptyExercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout
        XCTAssertTrue(viewModel.saveWorkout(using: context))

        XCTAssertEqual(workout.status, .completed)
        XCTAssertEqual(workout.orderedExercises.count, 1)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 1)
        XCTAssertTrue(workout.orderedExercises.first?.orderedSets.first?.done == true)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseEntry>()).contains { $0 === completedEntry })
        XCTAssertFalse(try context.fetch(FetchDescriptor<ExerciseEntry>()).contains { $0 === emptyEntry })
    }

    func testInvalidSaveLeavesActiveDraftUntouched() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let entry = ExerciseEntry(exercise: exercise, usedMetric: .metric)
        entry.sets = [
            ExerciseSet(repetitions: 0, weight: 50, done: false, orderIndex: 0, usedMetric: .metric),
            ExerciseSet(repetitions: 0, weight: 55, done: false, orderIndex: 1, usedMetric: .metric)
        ]
        let workout = Workout(name: "Draft")
        workout.exercises = [entry]
        context.insert(exercise)
        context.insert(workout)
        try context.save()

        let viewModel = WorkoutViewModel()
        viewModel.activeWorkout = workout

        XCTAssertFalse(viewModel.saveWorkout(using: context))
        XCTAssertTrue(viewModel.activeWorkout === workout)
        XCTAssertEqual(workout.status, .active)
        XCTAssertEqual(workout.orderedExercises.count, 1)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.count, 2)
        XCTAssertEqual(workout.orderedExercises.first?.orderedSets.map(\.weight), [50, 55])
        XCTAssertTrue(try context.fetch(FetchDescriptor<Workout>()).contains { $0 === workout })
    }

    func testUndoGuidedSourceSwitchRestoresPriorPlanWithoutMovingItsSchedule() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        let fixedPlan = PlanCoordinator.createRepeatedPlan(
            name: "Original Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0, 2]
        )
        let fixedRun = try XCTUnwrap(PlanCoordinator.startRun(for: fixedPlan))
        let originalUpdatedAt = Date(timeIntervalSince1970: 1_000)
        fixedRun.updatedAt = originalUpdatedAt
        let originalDates = fixedRun.orderedWorkoutProgress.map(\.scheduledDate)

        let rotationTemplate = WorkoutTemplate(name: "Rotation Workout", exercises: [])
        let rotation = RepeatingPlan(
            name: "Temporary Rotation",
            slots: [RepeatingPlanSlot(orderIndex: 0, workoutTemplate: rotationTemplate)]
        )

        context.insert(exercise)
        context.insert(template)
        context.insert(fixedPlan)
        context.insert(fixedRun)
        context.insert(rotationTemplate)
        context.insert(rotation)
        try context.save()

        let snapshot = PlanLifecycleService.switchSnapshot(using: context)
        let switchOutcome = PlanLifecycleService.resolveConflictAndActivate(rotation, using: context)
        guard case .succeededSilently = switchOutcome else {
            return XCTFail("Expected the rotation switch to commit")
        }
        XCTAssertEqual(fixedRun.status, .paused)
        XCTAssertEqual(PlanLifecycleService.activeRepeatingRuns(using: context).count, 1)

        let undoOutcome = PlanLifecycleService.undoSwitch(to: snapshot, using: context)
        guard case .succeeded = undoOutcome else {
            return XCTFail("Expected the previous plan to be restored")
        }
        XCTAssertEqual(fixedRun.status, .active)
        XCTAssertEqual(fixedRun.updatedAt, originalUpdatedAt)
        XCTAssertEqual(fixedRun.orderedWorkoutProgress.map(\.scheduledDate), originalDates)
        XCTAssertTrue(PlanLifecycleService.activeRepeatingRuns(using: context).isEmpty)
    }

    func testStartingFixedPlanAfterStagingConflictPauseLeavesOneActiveRun() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let exercise = WorkoutTestFixture.makeExercise()
        let template = WorkoutTestFixture.makeTemplate(exercise: exercise, targetSets: 1)
        let originalPlan = PlanCoordinator.createRepeatedPlan(
            name: "Original",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        context.insert(exercise)
        context.insert(template)
        context.insert(originalPlan)
        XCTAssertNotNil(PlanCoordinator.startRun(for: originalPlan, using: context))

        // Mirrors catalogue activation: compilation inserts a new, unsaved
        // definition graph before the root resolves the existing-run conflict.
        let replacementPlan = PlanCoordinator.createRepeatedPlan(
            name: "Replacement",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        context.insert(replacementPlan)

        PlanLifecycleService.stagePauseFixedRuns(using: context)
        let outcome = PlanLifecycleService.perform(.start(replacementPlan, .now), using: context)

        XCTAssertTrue(outcome.didCommit)
        XCTAssertEqual(PlanLifecycleService.activeFixedRuns(using: context).count, 1)
        XCTAssertEqual(PlanLifecycleService.activeFixedRuns(using: context).first?.plan?.name, "Replacement")
        XCTAssertEqual(
            CurrentPlanSummary.resolve(
                planRuns: try context.fetch(FetchDescriptor<PlanRun>()),
                repeatingPlanRuns: []
            ).title,
            "Replacement"
        )
    }


}
