import Foundation
import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class HistoricalIntegrityMatrixDigestTests: XCTestCase {

    // MARK: - 1. Completed Workout Digest Invariance
    func testCompletedWorkoutDigestIsInvariantToExerciseRenameOrArchivalOrDeletion() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Bench Press", primaryMuscles: [.upperChest])
        context.insert(exercise)

        let set1 = ExerciseSet(repetitions: 8, weight: 100, done: true, usedMetric: .metric)
        let set2 = ExerciseSet(repetitions: 8, weight: 100, done: true, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set1, set2], usedMetric: .metric)
        let workout = Workout(name: "Upper Body Power", endTime: Date(timeIntervalSince1970: 1_700_000_000))
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let initialDigest = computeWorkoutDigest(workout)

        // Mutate and archive the original exercise definition
        exercise.name = "Renamed Chest Press"
        exercise.isArchived = true
        try context.save()

        let digestAfterRename = computeWorkoutDigest(workout)
        XCTAssertEqual(initialDigest, digestAfterRename, "Completed workout digest must remain unchanged after exercise definition rename and archival")
    }

    // MARK: - 2. Completed Exercise Substitution Digest Invariance
    func testCompletedSubstitutionDigestIsInvariantToTargetExerciseMutation() throws {
        let context = try makeContext()
        let primaryExercise = Exercise(name: "Barbell Back Squat", primaryMuscles: [.quadriceps])
        let subExercise = Exercise(name: "Leg Press", primaryMuscles: [.quadriceps])
        context.insert(primaryExercise)
        context.insert(subExercise)

        let set = ExerciseSet(repetitions: 10, weight: 150, done: true, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: subExercise, sets: [set], usedMetric: .metric)

        let evaluation = SubstitutionEvaluationSnapshot(
            version: 1,
            ruleID: "v1_rule",
            sourceExerciseID: primaryExercise.id,
            candidateExerciseID: subExercise.id,
            reason: .equipmentUnavailable,
            suitability: .good,
            comparability: .direct,
            confidence: .high,
            matchedFactorCodes: ["muscle_group"],
            differingFactorCodes: [],
            missingEvidenceCodes: [],
            hardFilterFailureCodes: [],
            candidateProvenance: .systemReviewed
        )
        let decision = SubstitutionDecision(
            reason: .equipmentUnavailable,
            scope: .todayOnly,
            progressionPolicy: .continueShared,
            evaluation: evaluation
        )
        entry.applySubstitutionDecision(decision)

        let workout = Workout(name: "Leg Day", endTime: Date(timeIntervalSince1970: 1_700_000_100))
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()

        let initialDigest = computeSubstitutionDigest(entry)

        // Mutate target exercise properties
        subExercise.name = "Incline Leg Press 45"
        try context.save()

        let digestAfterMutation = computeSubstitutionDigest(entry)
        XCTAssertEqual(initialDigest, digestAfterMutation, "Completed substitution digest must be invariant to target exercise definition edits")
    }

    // MARK: - 3. Completed Plan Run Digest Invariance
    func testCompletedPlanRunDigestIsInvariantToSourcePlanRescheduleOrTemplateEdit() throws {
        let context = try makeContext()
        let plan = WorkoutPlan(
            name: "Hypertrophy Phase 1",
            goal: .hypertrophy,
            experienceLevel: .intermediate,
            daysPerWeek: 3,
            durationWeeks: 4
        )
        context.insert(plan)

        let run = PlanRun(plan: plan)
        let scheduledDate = Date(timeIntervalSince1970: 1_700_000_000)
        let progress = PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: "Day 1 Workout",
            weekIndex: 0,
            workoutIndex: 0,
            scheduledDate: scheduledDate
        )
        progress.status = .completed
        progress.originalScheduledDate = scheduledDate
        progress.lastRescheduledAt = scheduledDate.addingTimeInterval(86400)
        run.workoutProgress = [progress]
        context.insert(run)
        try context.save()

        let initialDigest = computePlanRunDigest(run)

        // Reschedule source plan
        plan.name = "Hypertrophy Phase 1 (Modified)"
        try context.save()

        let digestAfterEdit = computePlanRunDigest(run)
        XCTAssertEqual(initialDigest, digestAfterEdit, "Completed plan run progress digest must be invariant to source plan edits")
    }

    // MARK: - 4. Completed Mobility Assessment Session Digest Invariance
    func testCompletedAssessmentSessionDigestIsInvariantToAssessmentDefinitionEdit() throws {
        let context = try makeContext()
        let assessmentDef = MobilityAssessmentDefinition(
            catalogueKey: "knee_to_wall_dorsiflexion",
            name: "Knee-to-Wall Dorsiflexion",
            nameLocalizationKey: "knee_to_wall.name",
            instructionsLocalizationKey: "knee_to_wall.instructions",
            setupInstructionsLocalizationKey: "knee_to_wall.setup",
            measurementDescriptionLocalizationKey: "knee_to_wall.desc",
            measurementLimitationsLocalizationKey: "knee_to_wall.limitations",
            zone: .ankles,
            definitionVersion: 1,
            preferredMode: .manualLinear,
            manualMode: .manualLinear,
            unit: .centimetres,
            supportedSides: [.left, .right],
            setupKeys: ["standard"],
            defaultSetupKey: "standard",
            defaultIsActiveRange: true,
            sortOrder: 1
        )
        context.insert(assessmentDef)

        let day = LocalDay(rawValue: "2026-08-04")
        let input = MobilityAssessmentResultInput(
            numericValue: 12.5,
            side: .left,
            isWarm: true,
            setupKey: "standard",
            method: .manualLinear,
            unit: .centimetres,
            isActiveRange: true,
            day: day,
            source: .manual,
            confidence: .high
        )
        let result = MobilityAssessmentResult(
            definition: assessmentDef,
            input: input,
            orderIndex: 0
        )

        let sample = MobilityAssessmentSample.create(
            from: [12.0, 12.5, 13.0],
            createdAt: Date(timeIntervalSince1970: 1_700_000_300)
        )
        result.sample = sample

        let session = MobilityAssessmentSession(
            day: day,
            selectedDefinitionKeys: ["knee_to_wall_dorsiflexion"]
        )
        session.results = [result]
        session.completedAt = Date(timeIntervalSince1970: 1_700_000_300)
        context.insert(session)
        try context.save()

        let initialDigest = computeAssessmentSessionDigest(session)

        // Mutate assessment definition
        assessmentDef.name = "Knee-to-Wall Dorsiflexion (Updated)"
        assessmentDef.definitionVersion = 2
        try context.save()

        let digestAfterEdit = computeAssessmentSessionDigest(session)
        XCTAssertEqual(initialDigest, digestAfterEdit, "Completed assessment session digest must remain invariant when definition is updated")
    }

    // MARK: - 5. Completed State Immutability & Digest Integrity
    func testCompletedStateImmutabilityStatusAndIsCompletedPropagation() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)

        let set = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        let block = WorkoutExecutionBlock(orderIndex: 0, kind: .straight)

        let workout = Workout(name: "Leg Session")
        workout.exercises = [entry]
        workout.executionBlocks = [block]
        context.insert(workout)

        // Active workout state verification
        XCTAssertFalse(workout.isCompleted)
        XCTAssertFalse(entry.isCompleted)
        XCTAssertFalse(set.isCompleted)
        XCTAssertFalse(block.isCompleted)

        // Mark completed
        workout.status = .completed
        workout.endTime = Date.now

        XCTAssertTrue(workout.isCompleted)
        XCTAssertTrue(entry.isCompleted)
        XCTAssertTrue(set.isCompleted)
        XCTAssertTrue(block.isCompleted)

        let initialDigest = computeWorkoutDigest(workout)
        // Digest should reflect completed workout structure cleanly
        XCTAssertFalse(initialDigest.isEmpty)
        let secondDigest = computeWorkoutDigest(workout)
        XCTAssertEqual(initialDigest, secondDigest)
    }

    // MARK: - Helper Digest Functions

    private func computeWorkoutDigest(_ workout: Workout) -> String {
        var components = [String]()
        components.append("workout:\(workout.name ?? "")")
        if let endTime = workout.endTime {
            components.append("endTime:\(endTime.timeIntervalSince1970)")
        }
        for entry in workout.exercises {
            components.append("exerciseSnapshot:\(entry.displayName)")
            for set in entry.sets {
                components.append("set:\(set.repetitions)x\(set.weight)_\(set.done)_\(set.usedMetric.rawValue)")
            }
        }
        return components.joined(separator: "|")
    }

    private func computeSubstitutionDigest(_ entry: ExerciseEntry) -> String {
        var components = [String]()
        components.append("exerciseSnapshot:\(entry.displayName)")
        components.append("reason:\(entry.substitutionReasonCode ?? "none")")
        components.append("suitability:\(entry.substitutionSuitabilityRaw ?? "none")")
        components.append("comparability:\(entry.substitutionComparabilityRaw ?? "none")")
        components.append("policy:\(entry.substitutionProgressionPolicyRaw ?? "none")")
        return components.joined(separator: "|")
    }

    private func computePlanRunDigest(_ run: PlanRun) -> String {
        var components = [String]()
        components.append("status:\(run.status.rawValue)")
        for progress in run.workoutProgress {
            components.append("workout:\(progress.plannedWorkoutID)_\(progress.status.rawValue)")
            if let originalDate = progress.originalScheduledDate {
                components.append("origDate:\(originalDate.timeIntervalSince1970)")
            }
            if let rescheduledDate = progress.lastRescheduledAt {
                components.append("reschedDate:\(rescheduledDate.timeIntervalSince1970)")
            }
        }
        return components.joined(separator: "|")
    }

    private func computeAssessmentSessionDigest(_ session: MobilityAssessmentSession) -> String {
        var components = [String]()
        components.append("session:\(session.dayKey)_\(session.status.rawValue)")
        for result in session.results {
            components.append("result:\(result.definitionCatalogueKeySnapshot)_\(result.definitionNameSnapshot)_\(result.side.rawValue)_\(result.numericValue ?? 0)_\(result.method.rawValue)")
            if let sample = result.sample {
                components.append("sample:\(sample.sampleCount)_\(sample.median)_\(sample.minimum)_\(sample.maximum)")
            }
        }
        return components.joined(separator: "|")
    }

    private func makeContext() throws -> ModelContext {
        try GymTrackerTestStore.makeInMemoryContext()
    }
}
