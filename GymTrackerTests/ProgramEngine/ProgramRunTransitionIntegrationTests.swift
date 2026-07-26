import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProgramRunTransitionIntegrationTests: XCTestCase {
    func testScopedWeekStateAppliesOnlyToTargetWeekAndExposure() {
        let squat = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let volume = PlannedExercise(exercise: squat, orderIndex: 0, progressionKey: "squat-volume")
        let strength = PlannedExercise(exercise: squat, orderIndex: 1, progressionKey: "squat-strength")
        let firstWeek = PlanWeek(
            weekIndex: 0,
            plannedWorkouts: [PlannedWorkout(name: "Week one", orderIndex: 0, dayOffset: 0, plannedExercises: [volume, strength])]
        )
        let secondWeek = PlanWeek(
            weekIndex: 1,
            plannedWorkouts: [PlannedWorkout(name: "Week two", orderIndex: 0, dayOffset: 0, plannedExercises: [volume, strength])]
        )
        let plan = WorkoutPlan(
            name: "Scoped",
            daysPerWeek: 1,
            durationWeeks: 2,
            blocks: [PlanBlock(name: "Build", phaseType: .strength, orderIndex: 0, weeks: [firstWeek, secondWeek])]
        )
        let run = PlanRun(plan: plan, startDate: .now)
        let volumeBase = PlanExerciseProgressionState(progressionKey: "squat-volume", currentLoad: 100)
        let strengthBase = PlanExerciseProgressionState(progressionKey: "squat-strength", currentLoad: 90)
        let nextWeekVolume = PlanExerciseProgressionState(
            progressionKey: "squat-volume",
            scopeRaw: ProgressionScope.week.rawValue,
            scopeOwnerKey: "week:1",
            currentLoad: 105
        )
        run.progressionStates = [volumeBase, strengthBase, nextWeekVolume]

        run.currentWeekIndex = 0
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: volume, in: run)?.currentLoad ?? 0,
            100,
            accuracy: 0.001
        )

        run.currentWeekIndex = 1
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: volume, in: run)?.currentLoad ?? 0,
            105,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PlanProgressionStateService.effectiveState(for: strength, in: run)?.currentLoad ?? 0,
            90,
            accuracy: 0.001
        )
    }

    func testWeekScopedNextWeekRuleCreatesASeparateTargetState() {
        let squat = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let planned = PlannedExercise(exercise: squat, orderIndex: 0, progressionKey: "squat")
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Scoped", startDate: .now)
        let source = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Week one", weekIndex: 0, workoutIndex: 0)
        run.progressionStates = [PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)]

        let target = PlanProgressionStateService.stateForEvaluation(
            scope: .week,
            plannedExercise: planned,
            sourceProgress: source,
            sourceBlockIndex: 0,
            cadence: .nextWeek,
            in: run
        )

        XCTAssertEqual(target.scopeRaw, ProgressionScope.week.rawValue)
        XCTAssertEqual(target.scopeOwnerKey, "week:1")
        XCTAssertEqual(target.currentLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(run.progressionStates.count, 2)
    }

    func testAcceptingDeferredRecommendationWaitsForCadenceBeforeStateAndTransition() throws {
        let context = try makeContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Recommendation", startDate: .now)
        let sourceWorkout = Workout(name: "Completed", endTime: .now)
        let source = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Week one",
            weekIndex: 0,
            workoutIndex: 0
        )
        source.status = .completed
        source.completedWorkout = sourceWorkout
        let skippedAtBoundary = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Later this week",
            weekIndex: 0,
            workoutIndex: 1
        )
        let nextWeek = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Next week",
            weekIndex: 1,
            workoutIndex: 0
        )
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        run.workoutProgress = [source, skippedAtBoundary, nextWeek]
        run.progressionStates = [state]
        context.insert(run)
        context.insert(sourceWorkout)

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .advanceWeek,
            cadence: .nextWeek,
            scope: .week,
            reason: "All prescribed sets were completed.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 102.5),
            performance: ProgressionPerformance(weekCompleted: true)
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: sourceWorkout.id
        )
        record.progressionKey = "squat"
        context.insert(record)
        try context.save()

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)

        XCTAssertTrue(record.isResolved)
        XCTAssertEqual(state.currentLoad ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(skippedAtBoundary.status, .upcoming)
        let pending = try XCTUnwrap(state.pendingProgressionData.flatMap {
            try? JSONDecoder().decode([PendingProgressionState].self, from: $0)
        })
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.action, .advanceWeek)
        XCTAssertEqual(pending.first?.state.currentLoad ?? 0, 102.5, accuracy: 0.001)

        run.currentWeekIndex = 1
        run.currentWorkoutIndex = 0
        XCTAssertTrue(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: source,
            in: run
        ))
        XCTAssertEqual(skippedAtBoundary.status, .skipped)
        XCTAssertTrue(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertEqual(state.currentLoad ?? 0, 102.5, accuracy: 0.001)
        XCTAssertNil(state.pendingProgressionData)
    }

    func testAcceptingDueStructuralRecommendationAppliesItOnce() throws {
        let context = try makeContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Recommendation", startDate: .now)
        let sourceWorkout = Workout(name: "Completed", endTime: .now)
        let source = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Upper",
            weekIndex: 0,
            workoutIndex: 0
        )
        source.status = .completed
        source.completedWorkout = sourceWorkout
        let state = PlanExerciseProgressionState(progressionKey: "accessory")
        run.workoutProgress = [source]
        run.progressionStates = [state]
        context.insert(run)
        context.insert(sourceWorkout)

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .endExercise,
            cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure,
            reason: "Exercise target reached.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance()
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: run.id,
            workoutID: sourceWorkout.id
        )
        record.progressionKey = "accessory"
        context.insert(record)
        try context.save()

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        XCTAssertTrue(record.isResolved)

        try PlanProgressionRecommendationService.accept(record, in: run, context: context)
        let keys = try XCTUnwrap(run.endedProgressionKeysData.flatMap {
            try? JSONDecoder().decode(Set<String>.self, from: $0)
        })
        XCTAssertEqual(keys, ["accessory"])
    }

    func testResolvingRecommendationsRecordsEachDecisionWithoutChangingPerformedSets() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Receipt Squat", primaryMuscles: [.quadriceps])
        let performedSet = ExerciseSet(repetitions: 5, weight: 100, done: true, orderIndex: 0, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [performedSet], orderIndex: 0, usedMetric: .metric)
        let workout = Workout(name: "Completed", endTime: .now)
        workout.exercises = [entry]
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Receipt", startDate: .now)
        let progress = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Day", weekIndex: 0, workoutIndex: 0)
        progress.status = .completed
        progress.completedWorkout = workout
        let state = PlanExerciseProgressionState(progressionKey: "squat", currentLoad: 100)
        run.workoutProgress = [progress]
        run.progressionStates = [state]
        context.insert(exercise)
        context.insert(workout)
        context.insert(run)

        func makeRecord(proposedLoad: Double) throws -> PlanProgressionRecommendationRecord {
            let recommendation = ProgressionRecommendation(
                id: UUID(),
                ruleID: UUID(),
                action: .addLoad(2.5),
                cadence: .nextExerciseOccurrence,
                scope: .exerciseExposure,
                reason: "Completed all prescribed work.",
                applicationMode: .recommendation,
                proposedState: ProgressionEvaluationState(currentLoad: proposedLoad),
                performance: ProgressionPerformance(completedSets: 1)
            )
            let record = try PlanProgressionRecommendationRecord(
                recommendation: recommendation,
                planRunID: run.id,
                workoutID: workout.id
            )
            record.progressionKey = "squat"
            context.insert(record)
            return record
        }

        let accepted = try makeRecord(proposedLoad: 102.5)
        let modified = try makeRecord(proposedLoad: 105)
        let declined = try makeRecord(proposedLoad: 107.5)
        try context.save()
        let before = performedSetDigest(workout)

        try PlanProgressionRecommendationService.accept(accepted, in: run, context: context)
        XCTAssertTrue(accepted.isResolved)
        XCTAssertEqual(accepted.decisionOutcome, .accepted)
        XCTAssertNil(accepted.appliedLoad)
        XCTAssertEqual(state.currentLoad, 102.5)
        XCTAssertEqual(performedSetDigest(workout), before)

        try PlanProgressionRecommendationService.accept(modified, withLoad: 101.25, in: run, context: context)
        XCTAssertTrue(modified.isResolved)
        XCTAssertEqual(modified.decisionOutcome, .acceptedWithModifiedValue)
        XCTAssertEqual(modified.proposedLoad, 105)
        XCTAssertEqual(modified.appliedLoad, 101.25)
        XCTAssertEqual(state.currentLoad, 101.25)
        XCTAssertEqual(performedSetDigest(workout), before)

        try PlanProgressionRecommendationService.decline(declined, context: context)
        XCTAssertTrue(declined.isResolved)
        XCTAssertEqual(declined.decisionOutcome, .declined)
        XCTAssertNil(declined.appliedLoad)
        XCTAssertEqual(performedSetDigest(workout), before)
    }

    func testAutomaticAdvanceWeekSkipsOnlyUnfinishedProgress() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let skippedByRule = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Later this week", weekIndex: 0, workoutIndex: 1)
        let nextWeek = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Next week", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, skippedByRule, nextWeek]

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .advanceWeek,
            cadence: .nextWeek,
            scope: .week,
            reason: "Week target reached.",
            applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance(weekCompleted: true)
        )
        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(skippedByRule.status, .skipped)
        XCTAssertEqual(skippedByRule.skipReason, "Advanced by program rule")
        XCTAssertEqual(nextWeek.status, .available)
    }

    func testAutomaticEndProgramPreservesCompletedProgress() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endProgram, cadence: .nextCycle,
            scope: .programRun, reason: "Testing complete.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance(cycleCompleted: true)
        )

        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "test", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(future.status, .skipped)
        XCTAssertEqual(run.status, .completed)
        XCTAssertNotNil(run.endDate)
    }

    func testOfferTestDayLeavesTestSessionAvailableAndCanBeActivated() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Test Squat", primaryMuscles: [.quadriceps])
        let plannedExercise = PlannedExercise(exercise: exercise, orderIndex: 0)
        let testWorkout = PlannedWorkout(
            name: "Test Day",
            orderIndex: 1,
            dayOffset: 1,
            isTestDay: true,
            plannedExercises: [plannedExercise]
        )
        let week = PlanWeek(weekIndex: 0, plannedWorkouts: [testWorkout])
        let plan = WorkoutPlan(
            name: "Test-Day Program",
            daysPerWeek: 1,
            durationWeeks: 1,
            blocks: [PlanBlock(name: "Peak", phaseType: .strength, orderIndex: 0, weeks: [week])]
        )
        plan.programCompletionPolicy = .offerTestDay
        let run = PlanRun(plan: plan)
        let completed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Final Training",
            weekIndex: 0,
            workoutIndex: 0
        )
        completed.status = .completed
        let testProgress = PlanWorkoutProgress(plannedWorkout: testWorkout, weekIndex: 0, workoutIndex: 1)
        run.workoutProgress = [completed, testProgress]
        context.insert(plan)
        context.insert(run)
        try context.save()

        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .endProgram,
            cadence: .nextCycle,
            scope: .programRun,
            reason: "Training cycle complete.",
            applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(),
            performance: ProgressionPerformance(cycleCompleted: true)
        )
        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertEqual(run.status, .testDayAvailable)
        XCTAssertEqual(testProgress.status, .available)

        let activated = try XCTUnwrap(ProgramRunLifecycleService.activateTestDay(for: run, using: context))
        XCTAssertEqual(activated.id, testProgress.id)
        XCTAssertEqual(run.status, .active)
        XCTAssertNil(run.endDate)
    }

    func testDeferredStructuralTransitionWaitsForItsCadenceBoundary() throws {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Completed", weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]
        let state = PlanExerciseProgressionState(progressionKey: "accessory")
        state.pendingProgressionData = try JSONEncoder().encode([
            PendingProgressionState(
                ruleID: UUID(),
                sourceWorkoutID: UUID(),
                action: .endExercise,
                cadence: .nextWeek,
                scope: .exerciseExposure,
                state: ProgressionEvaluationState(),
                sourceWeekIndex: 0,
                sourceWorkoutIndex: 0,
                sourceBlockIndex: 0,
                createdAt: .now
            )
        ])
        run.progressionStates = [state]

        XCTAssertFalse(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: completed,
            in: run
        ))
        XCTAssertFalse(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))

        run.currentWeekIndex = 1
        XCTAssertTrue(PlanProgressionTransitionService.applyDuePendingTransitions(
            sourceProgress: completed,
            in: run
        ))
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        XCTAssertNotNil(state.pendingProgressionData)
        XCTAssertTrue(PlanProgressionCadenceService.applyDueStates(in: run))
        XCTAssertNil(state.pendingProgressionData)
    }

    func testTransitionServiceDoesNotApplyUndueAutomaticRecommendation() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let source = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Current", weekIndex: 0, workoutIndex: 0)
        let future = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Future", weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [source, future]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endProgram, cadence: .nextWeek,
            scope: .programRun, reason: "Wait for next week.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance(weekCompleted: false)
        )

        XCTAssertFalse(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "squat", recommendations: [recommendation])],
            sourceProgress: source,
            in: run
        ))
        XCTAssertEqual(run.status, .active)
        XCTAssertEqual(future.status, .upcoming)
    }

    func testAutomaticEndExerciseOmitsOnlyFutureGeneratedEntries() {
        let exercise = Exercise(name: "Accessory", primaryMuscles: [.bicep])
        let plannedExercise = PlannedExercise(exercise: exercise, orderIndex: 0, progressionKey: "accessory")
        let plannedWorkout = PlannedWorkout(name: "Upper", orderIndex: 0, dayOffset: 0, plannedExercises: [plannedExercise])
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Transition", startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkoutID: plannedWorkout.id, plannedWorkoutName: plannedWorkout.name, weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        run.workoutProgress = [completed]
        let recommendation = ProgressionRecommendation(
            id: UUID(), ruleID: UUID(), action: .endExercise, cadence: .nextExerciseOccurrence,
            scope: .exerciseExposure, reason: "Exposure complete.", applicationMode: .automatic,
            proposedState: ProgressionEvaluationState(), performance: ProgressionPerformance()
        )

        XCTAssertTrue(PlanProgressionTransitionService.applyAutomaticTransitions(
            [PlanExerciseProgressionResult(progressionKey: "accessory", recommendations: [recommendation])],
            sourceProgress: completed,
            in: run
        ))
        XCTAssertTrue(PlanProgressionTransitionService.isExerciseEnded("accessory", in: run))
        let future = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        XCTAssertTrue(future.exercises.isEmpty)
        XCTAssertEqual(completed.status, .completed)
    }

    func testRepeatWeekCreatesNewFutureOccurrenceWithoutChangingCompletion() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Repeat", startDate: .now)
        let completed = PlanWorkoutProgress(
            plannedWorkoutID: UUID(), plannedWorkoutName: "Week one", weekIndex: 0, workoutIndex: 0,
            scheduledDate: .now
        )
        completed.status = .completed
        let future = PlanWorkoutProgress(
            plannedWorkoutID: UUID(), plannedWorkoutName: "Week two", weekIndex: 1, workoutIndex: 0,
            scheduledDate: .now
        )
        run.workoutProgress = [completed, future]

        XCTAssertTrue(PlanCoordinator.repeatWeek(containing: completed, in: run))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress.count, 3)
        let repeated = run.orderedWorkoutProgress.first {
            $0.weekIndex == 1 && $0.plannedWorkoutID == completed.plannedWorkoutID
        }
        XCTAssertEqual(repeated?.sourceWeekIndex, 0)
        XCTAssertEqual(repeated?.status, .available)
        XCTAssertEqual(future.weekIndex, 2)
    }

    func testRestartBlockCreatesFutureOccurrencesFromEveryBlockWeek() {
        let firstWorkout = PlannedWorkout(name: "First", orderIndex: 0, dayOffset: 0)
        let secondWorkout = PlannedWorkout(name: "Second", orderIndex: 0, dayOffset: 0)
        let block = PlanBlock(
            name: "Build",
            phaseType: .strength,
            orderIndex: 0,
            weeks: [
                PlanWeek(weekIndex: 0, plannedWorkouts: [firstWorkout]),
                PlanWeek(weekIndex: 1, plannedWorkouts: [secondWorkout])
            ]
        )
        let plan = WorkoutPlan(name: "Block", daysPerWeek: 1, durationWeeks: 2, blocks: [block])
        let run = PlanRun(plan: plan, startDate: .now)
        let completed = PlanWorkoutProgress(plannedWorkout: firstWorkout, weekIndex: 0, workoutIndex: 0)
        completed.status = .completed
        let future = PlanWorkoutProgress(plannedWorkout: secondWorkout, weekIndex: 1, workoutIndex: 0)
        run.workoutProgress = [completed, future]

        XCTAssertTrue(PlanCoordinator.restartBlock(containing: completed, in: run))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(run.orderedWorkoutProgress.count, 4)
        XCTAssertNotNil(run.orderedWorkoutProgress.first { $0.weekIndex == 1 && $0.plannedWorkoutID == firstWorkout.id })
        XCTAssertNotNil(run.orderedWorkoutProgress.first { $0.weekIndex == 2 && $0.plannedWorkoutID == secondWorkout.id })
        XCTAssertEqual(future.weekIndex, 3)
    }


    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }

    private func performedSetDigest(_ workout: Workout) -> [String] {
        workout.orderedExercises.flatMap { entry in
            entry.orderedSets.map { set in
                [
                    entry.nameSnapshot,
                    String(set.orderIndex),
                    String(set.repetitions),
                    String(set.weight),
                    String(set.done),
                    String(describing: set.meanVelocity)
                ].joined(separator: "|")
            }
        }
    }
}
