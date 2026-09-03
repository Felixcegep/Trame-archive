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

    // MARK: - 6. Release-Safe Completed Workout Mutation Boundary
    func testCompletedMutationFamiliesRejectAndPreserveHistoricalDigest() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Squat", primaryMuscles: [.quadriceps])
        let replacementExercise = Exercise(name: "Front Squat", primaryMuscles: [.quadriceps])
        context.insert(exercise)
        context.insert(replacementExercise)

        let set = ExerciseSet(repetitions: 5, weight: 100, done: true, usedMetric: .metric)
        set.setMethod = .cluster
        set.prescribedRepetitions = 5
        let entry = ExerciseEntry(exercise: exercise, sets: [set], usedMetric: .metric)
        entry.comment = "Historical comment"
        let block = WorkoutExecutionBlock(
            orderIndex: 0,
            kind: .straight,
            name: "Historical block",
            scoreKind: .roundsAndRepetitions
        )
        block.status = .inProgress

        let workout = Workout(name: "Leg Session")
        workout.notes = "Historical notes"
        workout.exercises = [entry]
        workout.executionBlocks = [block]
        context.insert(workout)
        try context.save()
        workout.status = .completed
        workout.endTime = Date(timeIntervalSince1970: 1_700_001_000)

        XCTAssertTrue(workout.isCompleted)
        XCTAssertTrue(entry.isCompleted)
        XCTAssertTrue(set.isCompleted)
        XCTAssertTrue(block.isCompleted)
        let initialDigest = computeHistoricalMutationDigest(workout)

        // Workout ownership and metadata mutations.
        XCTAssertEqual(
            workout.updateName("Changed"),
            .rejected(.completedWorkoutMutation(.updateWorkoutName))
        )
        XCTAssertEqual(
            workout.updateNotes("Changed"),
            .rejected(.completedWorkoutMutation(.updateWorkoutNotes))
        )
        XCTAssertEqual(
            workout.updateElapsedDuration(90 * 60),
            .rejected(.completedWorkoutMutation(.updateWorkoutStartTime))
        )
        XCTAssertEqual(
            workout.addEntry(ExerciseEntry(exercise: replacementExercise, usedMetric: .metric)),
            .rejected(.completedWorkoutMutation(.addWorkoutEntry))
        )
        XCTAssertEqual(
            workout.removeEntry(entry),
            .rejected(.completedWorkoutMutation(.removeWorkoutEntry))
        )
        XCTAssertEqual(
            workout.normalizeExerciseOrder(),
            .rejected(.completedWorkoutMutation(.normalizeWorkoutOrder))
        )

        // Exercise-entry mutations.
        XCTAssertEqual(
            entry.addEmptySet(),
            .rejected(.completedWorkoutMutation(.addExerciseSet))
        )
        XCTAssertEqual(
            entry.addDefaultSets(count: 2),
            .rejected(.completedWorkoutMutation(.addExerciseSet))
        )
        XCTAssertEqual(
            entry.removeSet(set),
            .rejected(.completedWorkoutMutation(.removeExerciseSet))
        )
        XCTAssertEqual(
            entry.updateComment("Changed"),
            .rejected(.completedWorkoutMutation(.updateExerciseComment))
        )
        XCTAssertEqual(
            entry.updateExerciseSnapshot(from: replacementExercise),
            .rejected(.completedWorkoutMutation(.updateExerciseSnapshot))
        )
        XCTAssertEqual(
            entry.applySubstitutionDecision(completedMutationTestDecision()),
            .rejected(.completedWorkoutMutation(.applySubstitutionDecision))
        )
        XCTAssertEqual(
            entry.copyLastSet(),
            .rejected(.completedWorkoutMutation(.copyLastSet))
        )
        XCTAssertEqual(
            entry.normalizeSetOrder(),
            .rejected(.completedWorkoutMutation(.normalizeExerciseOrder))
        )
        XCTAssertEqual(
            entry.startActiveDuration(at: Date(timeIntervalSince1970: 1_700_001_001)),
            .rejected(.completedWorkoutMutation(.startExerciseDuration))
        )
        XCTAssertEqual(
            entry.stopActiveDuration(at: Date(timeIntervalSince1970: 1_700_001_002)),
            .rejected(.completedWorkoutMutation(.stopExerciseDuration))
        )

        // Exercise-set mutations, including structured evidence families.
        XCTAssertEqual(
            set.applyStrongmanEvidence(
                implementProfile: StrongmanImplementProfile(kind: .yoke),
                eventFamily: .carry
            ),
            .rejected(.completedWorkoutMutation(.applyStrongmanEvidence))
        )
        XCTAssertEqual(
            set.ensureSegmentsForMethod(),
            .rejected(.completedWorkoutMutation(.ensureSetSegments))
        )
        XCTAssertEqual(
            set.synchronizeSegmentCompletion(),
            .rejected(.completedWorkoutMutation(.synchronizeSetSegmentCompletion))
        )
        XCTAssertEqual(
            set.clearPrescription(),
            .rejected(.completedWorkoutMutation(.clearSetPrescription))
        )
        XCTAssertEqual(
            set.normalizeSegmentOrder(),
            .rejected(.completedWorkoutMutation(.normalizeSegmentOrder))
        )
        XCTAssertEqual(
            set.ensureComplexComponents(for: [
                ComplexComponentSnapshot(
                    exerciseID: replacementExercise.id,
                    exerciseNameSnapshot: replacementExercise.name,
                    prescribedRepetitions: 1
                )
            ]),
            .rejected(.completedWorkoutMutation(.ensureComplexComponents))
        )
        XCTAssertEqual(
            set.synchronizeComplexCompletion(),
            .rejected(.completedWorkoutMutation(.synchronizeComplexCompletion))
        )

        // Execution-block model and service mutations.
        XCTAssertEqual(
            block.start(at: Date(timeIntervalSince1970: 1_700_001_003)),
            .rejected(.completedWorkoutMutation(.startExecutionBlock))
        )
        XCTAssertEqual(
            block.pause(at: Date(timeIntervalSince1970: 1_700_001_004)),
            .rejected(.completedWorkoutMutation(.pauseExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.completeRound(in: block),
            .rejected(.completedWorkoutMutation(.completeExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.recordAdditionalRepetitions(2, in: block),
            .rejected(.completedWorkoutMutation(.updateExecutionBlockScore))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.updateScore(block, completedRounds: 2, scoreValue: 99),
            .rejected(.completedWorkoutMutation(.updateExecutionBlockScore))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.assign(entries: [entry], to: block),
            .rejected(.completedWorkoutMutation(.updateExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.remove(block, from: workout),
            .rejected(.completedWorkoutMutation(.removeExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.complete(block),
            .rejected(.completedWorkoutMutation(.completeExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.cap(block),
            .rejected(.completedWorkoutMutation(.capExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.stop(block),
            .rejected(.completedWorkoutMutation(.stopExecutionBlock))
        )
        XCTAssertEqual(
            WorkoutExecutionBlockService.finalizeForWorkoutSave(block),
            .rejected(.completedWorkoutMutation(.completeExecutionBlock))
        )
        XCTAssertThrowsError(
            try WorkoutExecutionBlockService.create(
                kind: .straight,
                entries: [entry],
                in: workout
            )
        ) { error in
            XCTAssertEqual(
                error as? WorkoutExecutionBlockError,
                .completedWorkoutMutation(.updateExecutionBlock)
            )
        }

        XCTAssertEqual(computeHistoricalMutationDigest(workout), initialDigest)
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

    private func computeHistoricalMutationDigest(_ workout: Workout) -> String {
        var components = [
            "workout:\(workout.name ?? "")",
            "notes:\(workout.notes ?? "")",
            "status:\(workout.status.rawValue)",
            "startTime:\(workout.startTime.timeIntervalSince1970)",
            "endTime:\(workout.endTime?.timeIntervalSince1970 ?? 0)"
        ]
        for entry in workout.orderedExercises {
            components.append("entry:\(entry.id)_\(entry.orderIndex)_\(entry.displayName)_\(entry.comment ?? "")")
            for set in entry.orderedSets {
                components.append(
                    "set:\(set.id)_\(set.orderIndex)_\(set.repetitions)_\(set.weight)_\(set.done)_\(set.resolvedSetMethod.rawValue)_\(set.prescribedRepetitions ?? 0)"
                )
                for segment in set.orderedSegments {
                    components.append("segment:\(segment.id)_\(segment.orderIndex)_\(segment.repetitions)_\(segment.done)")
                }
            }
        }
        for block in workout.orderedExecutionBlocks {
            components.append(
                "block:\(block.id)_\(block.orderIndex)_\(block.kind.rawValue)_\(block.name ?? "")_\(block.status.rawValue)_\(block.completedRounds)_\(block.additionalRepetitions)_\(block.scoreValue ?? 0)"
            )
        }
        return components.joined(separator: "|")
    }

    private func completedMutationTestDecision() -> SubstitutionDecision {
        SubstitutionDecision(
            reason: .preference,
            scope: .todayOnly,
            progressionPolicy: .separate,
            evaluation: SubstitutionEvaluationSnapshot(
                version: 1,
                ruleID: "completed_mutation_test",
                sourceExerciseID: UUID(),
                candidateExerciseID: UUID(),
                reason: .preference,
                suitability: .good,
                comparability: .direct,
                confidence: .high,
                matchedFactorCodes: [],
                differingFactorCodes: [],
                missingEvidenceCodes: [],
                hardFilterFailureCodes: [],
                candidateProvenance: .systemReviewed
            )
        )
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
