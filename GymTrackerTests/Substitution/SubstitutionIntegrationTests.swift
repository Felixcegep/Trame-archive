import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SubstitutionIntegrationTests: XCTestCase {
    func testTodayOnlyDecisionPreservesOriginalAndPerformedIdentities() throws {
        let context = try makeContext()
        let source = exercise("Bench Press")
        let replacement = exercise("Chest Press")
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        try SubstitutionDecisionService.apply(
            decision: decision(source: source, replacement: replacement, scope: .todayOnly),
            replacement: replacement,
            to: entry.persistentModelID,
            in: workout,
            modelContext: context
        )

        XCTAssertEqual(entry.originalExerciseIDSnapshot, source.id)
        XCTAssertEqual(entry.originalExerciseNameSnapshot, "Bench Press")
        XCTAssertEqual(entry.selectedSubstituteExerciseIDSnapshot, replacement.id)
        XCTAssertEqual(entry.exerciseIDSnapshot, replacement.id)
        XCTAssertEqual(entry.exercise.id, replacement.id)
        XCTAssertEqual(entry.substitutionScope, .todayOnly)
        XCTAssertEqual(entry.orderedSets.count, 3)
        XCTAssertTrue(entry.orderedSets.allSatisfy { !$0.done })
    }

    func testUnknownComparabilityRemainsSeparateThroughMutationPath() throws {
        let context = try makeContext()
        let source = exercise("Source")
        let replacement = exercise("Replacement")
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        let unknown = SubstitutionDecision(
            reason: .notSure,
            scope: .todayOnly,
            progressionPolicy: .continueShared,
            evaluation: snapshot(source: source, replacement: replacement, comparability: .unknown)
        )
        try SubstitutionDecisionService.apply(
            decision: unknown,
            replacement: replacement,
            to: entry.persistentModelID,
            in: workout,
            modelContext: context
        )

        XCTAssertEqual(entry.substitutionProgressionPolicy, .separate)
        XCTAssertFalse(entry.substitutionSharesProgressionState)
    }

    func testSubstitutionGuardsRejectStartedAndSameExerciseEntries() throws {
        let context = try makeContext()
        let source = exercise("Source")
        let replacement = exercise("Replacement")
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(workout)
        try context.save()

        XCTAssertThrowsError(try SubstitutionDecisionService.apply(
            decision: decision(source: source, replacement: source), replacement: source,
            to: entry.persistentModelID, in: workout, modelContext: context
        )) { XCTAssertEqual($0 as? SubstitutionDecisionService.Failure, .sameExercise) }

        entry.orderedSets[0].done = true
        XCTAssertThrowsError(try SubstitutionDecisionService.apply(
            decision: decision(source: source, replacement: replacement), replacement: replacement,
            to: entry.persistentModelID, in: workout, modelContext: context
        )) { XCTAssertEqual($0 as? SubstitutionDecisionService.Failure, .alreadyStarted) }
        XCTAssertEqual(entry.exercise.id, source.id)
    }

    func testTodayOnlyMutationDoesNotTouchPlanAndFutureScopeUsesPreviewService() throws {
        let context = try makeContext()
        let source = exercise("Source")
        let replacement = exercise("Replacement")
        let planned = PlannedExercise(exercise: source, orderIndex: 0, progressionKey: "bench")
        let plannedWorkout = PlannedWorkout(name: "Day", orderIndex: 0, dayOffset: 0, plannedExercises: [planned])
        let week = PlanWeek(weekIndex: 0, plannedWorkouts: [plannedWorkout])
        let block = PlanBlock(name: "Block", phaseType: .strength, orderIndex: 0, weeks: [week])
        let plan = WorkoutPlan(name: "Plan", daysPerWeek: 1, durationWeeks: 1, blocks: [block])
        let run = PlanRun(plan: plan)
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        entry.sourcePlannedExerciseID = planned.id
        let workout = Workout(name: "Active")
        workout.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(plan)
        context.insert(run)
        context.insert(workout)
        try context.save()

        try SubstitutionDecisionService.apply(
            decision: decision(source: source, replacement: replacement, scope: .todayOnly),
            replacement: replacement, to: entry.persistentModelID, in: workout, modelContext: context
        )
        XCTAssertEqual(planned.exercise.id, source.id)
        XCTAssertEqual(planned.progressionKey, "bench")

        let preview = try PlanSubstitutionPreviewService.preview(
            plannedExerciseID: planned.id, replacement: replacement, run: run, modelContext: context
        )
        XCTAssertEqual(preview.originalExerciseName, "Source")
        XCTAssertEqual(preview.replacementExerciseName, "Replacement")
        XCTAssertEqual(try PlanSubstitutionPreviewService.apply(
            plannedExerciseID: planned.id, replacement: replacement, run: run, modelContext: context
        ), 1)
        XCTAssertEqual(planned.exercise.id, replacement.id)
        XCTAssertEqual(planned.progressionKey, "bench")

        run.status = PlanRunStatus.completed
        XCTAssertThrowsError(try PlanSubstitutionPreviewService.apply(
            plannedExerciseID: planned.id, replacement: source, run: run, modelContext: context
        )) { XCTAssertEqual($0 as? PlanSubstitutionPreviewService.Failure, .runNotEditable) }
    }

    func testHistoryLookupAfterSwapUsesReplacementIdentityOnly() throws {
        let context = try makeContext()
        let source = exercise("Source")
        let replacement = exercise("Replacement")
        let sourceHistory = completedWorkout(exercise: source, weight: 100, at: .distantPast)
        let replacementHistory = completedWorkout(exercise: replacement, weight: 55, at: Date(timeIntervalSince1970: 1))
        let entry = ExerciseEntry(from: source, usedMetric: .metric)
        let active = Workout(name: "Active")
        active.startTime = Date(timeIntervalSince1970: 10)
        active.exercises = [entry]
        context.insert(source)
        context.insert(replacement)
        context.insert(sourceHistory)
        context.insert(replacementHistory)
        context.insert(active)
        try context.save()

        try SubstitutionDecisionService.apply(
            decision: decision(source: source, replacement: replacement), replacement: replacement,
            to: entry.persistentModelID, in: active, modelContext: context
        )
        let previous = try XCTUnwrap(ExerciseHistoryService(modelContext: context)
            .mostRecentPerformance(for: entry.exercise, before: active.startTime))
        XCTAssertEqual(previous.sets.first?.weight, 55)
    }

    private func exercise(_ name: String) -> Exercise {
        Exercise(name: name, primaryMuscles: [.upperChest])
    }

    private func snapshot(source: Exercise, replacement: Exercise, comparability: SubstitutionComparability = .direct) -> SubstitutionEvaluationSnapshot {
        SubstitutionEvaluationSnapshot(
            version: SubstitutionEvaluationService.ruleVersion,
            ruleID: SubstitutionEvaluationService.ruleID,
            sourceExerciseID: source.id,
            candidateExerciseID: replacement.id,
            reason: .preference,
            suitability: .good,
            comparability: comparability,
            confidence: .moderate,
            matchedFactorCodes: [], differingFactorCodes: [], missingEvidenceCodes: [], hardFilterFailureCodes: [],
            candidateProvenance: .systemReviewed
        )
    }

    private func decision(source: Exercise, replacement: Exercise, scope: SubstitutionScope = .todayOnly) -> SubstitutionDecision {
        SubstitutionDecision(reason: .preference, scope: scope, progressionPolicy: .separate, evaluation: snapshot(source: source, replacement: replacement))
    }

    private func completedWorkout(exercise: Exercise, weight: Float, at date: Date) -> Workout {
        let entry = ExerciseEntry(exercise: exercise, sets: [ExerciseSet(repetitions: 8, weight: weight, done: true, orderIndex: 0, usedMetric: .metric)], usedMetric: .metric)
        let workout = Workout(name: "History", endTime: date)
        workout.startTime = date
        workout.status = WorkoutStatus.completed
        workout.exercises = [entry]
        return workout
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
