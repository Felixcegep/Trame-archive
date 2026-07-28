import XCTest
@testable import GymTracker

final class WeeklyProgramReviewBuilderTests: XCTestCase {
    private var calendar: Calendar!
    private var today: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        today = date(2026, 7, 16)
    }

    func testBuildKeepsProgramWeekOwnershipAndDerivesNeutralSessionStates() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Strength", startDate: today)
        run.currentWeekIndex = 1

        let completed = progress("Completed", week: 1, workout: 0, scheduled: date(2026, 7, 13))
        completed.status = .completed
        completed.completedWorkout = completedWorkout(named: "Completed", prescribedSets: 3, performedSets: 3)

        let skipped = progress("Skipped", week: 1, workout: 1, scheduled: date(2026, 7, 14))
        skipped.status = .skipped

        let missed = progress("Missed", week: 1, workout: 2, scheduled: date(2026, 7, 15))
        missed.status = .upcoming

        let moved = progress("Moved", week: 1, workout: 3, scheduled: date(2026, 7, 18))
        moved.status = .available
        moved.originalScheduledDate = date(2026, 7, 12)
        moved.lastRescheduledAt = date(2026, 7, 15)

        let unscheduled = progress("Unscheduled", week: 1, workout: 4, scheduled: nil)
        unscheduled.status = .upcoming
        run.workoutProgress = [unscheduled, moved, missed, skipped, completed]

        let review = WeeklyProgramReviewBuilder.build(
            for: run,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(review.week.runWeekIndex, 1)
        XCTAssertEqual(review.sessions.map(\.workoutName), [
            "Completed", "Skipped", "Missed", "Moved", "Unscheduled"
        ])
        XCTAssertEqual(review.sessionSummary.plannedCount, 5)
        XCTAssertEqual(review.sessionSummary.completedCount, 1)
        XCTAssertEqual(review.sessionSummary.skippedCount, 1)
        XCTAssertEqual(review.sessionSummary.missedCount, 1)
        XCTAssertEqual(review.sessionSummary.availableCount, 1)
        XCTAssertEqual(review.sessionSummary.upcomingCount, 1)
        XCTAssertEqual(review.sessionSummary.unscheduledCount, 1)
        XCTAssertTrue(review.sessions[3].isRescheduled)
        XCTAssertEqual(
            review.sessions[3].originalScheduledDate,
            calendar.startOfDay(for: date(2026, 7, 12))
        )
    }

    func testBuildUsesCompletedSnapshotForPerformedAndPrescribedSets() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Deleted plan", startDate: today)
        let completed = progress("Snapshot", week: 0, workout: 0, scheduled: today)
        completed.status = .completed
        completed.completedWorkout = completedWorkout(
            named: "Snapshot",
            prescribedSets: 4,
            performedSets: 3
        )
        run.workoutProgress = [completed]

        let review = WeeklyProgramReviewBuilder.build(
            for: run,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(review.setSummary.prescribedCount, 4)
        XCTAssertEqual(review.setSummary.performedCount, 3)
        XCTAssertTrue(review.setSummary.comparisonIsComplete)
        XCTAssertTrue(review.warnings.contains(.sourcePlanUnavailable))
    }

    func testBuildDoesNotFabricateSetTotalWhenPrescriptionEvidenceIsMissing() {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Deleted plan", startDate: today)
        let upcoming = progress("Unknown prescription", week: 0, workout: 0, scheduled: today)
        upcoming.status = .available
        run.workoutProgress = [upcoming]

        let review = WeeklyProgramReviewBuilder.build(
            for: run,
            today: today,
            calendar: calendar
        )

        XCTAssertNil(review.setSummary.prescribedCount)
        XCTAssertEqual(review.setSummary.performedCount, 0)
        XCTAssertFalse(review.setSummary.comparisonIsComplete)
        XCTAssertTrue(review.warnings.contains(.incompleteSetPrescription(progressID: upcoming.id)))
    }

    func testBuildIncludesOnlyReviewedWeekReceiptsAndStructuredSubstitutions() throws {
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Strength", startDate: today)
        let reviewed = progress("Reviewed", week: 0, workout: 0, scheduled: today)
        reviewed.status = .completed
        let workout = completedWorkout(named: "Reviewed", prescribedSets: 3, performedSets: 3)
        let entry = try XCTUnwrap(workout.orderedExercises.first)
        entry.progressionKey = "squat"
        let originalID = UUID()
        entry.originalExerciseIDSnapshot = originalID
        entry.originalExerciseNameSnapshot = "Back Squat"
        entry.selectedSubstituteExerciseIDSnapshot = entry.historicalExerciseID
        entry.substitutionReasonCode = SubstitutionReason.equipmentUnavailable.rawValue
        entry.substitutionScopeRaw = SubstitutionScope.todayOnly.rawValue
        entry.substitutionSuitabilityRaw = SubstitutionSuitability.good.rawValue
        entry.substitutionComparabilityRaw = SubstitutionComparability.notDirect.rawValue
        entry.substitutionProgressionPolicyRaw = ProgressionTransferPolicy.separate.rawValue
        entry.substitutionEvidenceConfidenceRaw = SubstitutionEvidenceConfidence.high.rawValue
        entry.substitutionEvaluationVersion = 1
        reviewed.completedWorkout = workout

        let other = progress("Other week", week: 1, workout: 0, scheduled: date(2026, 7, 23))
        other.status = .completed
        let otherWorkout = completedWorkout(named: "Other", prescribedSets: 2, performedSets: 2)
        other.completedWorkout = otherWorkout
        run.workoutProgress = [reviewed, other]

        let included = try recommendationRecord(runID: run.id, workoutID: workout.id, key: "squat")
        let excluded = try recommendationRecord(runID: run.id, workoutID: otherWorkout.id, key: "squat")

        let review = WeeklyProgramReviewBuilder.build(
            for: run,
            progressionRecords: [excluded, included],
            reviewedWeekIndex: 0,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(review.progressionDecisions.map(\.id), [included.id])
        XCTAssertEqual(review.progressionDecisions.first?.exerciseName, "Reviewed exercise")
        XCTAssertEqual(review.substitutions.count, 1)
        XCTAssertEqual(review.substitutions.first?.originalExerciseName, "Back Squat")
        XCTAssertEqual(review.substitutions.first?.selectedExerciseName, "Reviewed exercise")
        XCTAssertEqual(review.substitutions.first?.reason, .equipmentUnavailable)
        XCTAssertEqual(review.substitutions.first?.scope, .todayOnly)
        XCTAssertEqual(review.substitutions.first?.progressionPolicy, .separate)
        XCTAssertFalse(review.warnings.contains {
            if case .legacySubstitutionEvidence = $0 { return true }
            return false
        })
    }

    func testBuildPreviewsNextOccurrenceWeekAndDeloadWithoutMovingCurrentSessions() {
        let currentWeek = PlanWeek(weekIndex: 0, name: "Build")
        let deloadWeek = PlanWeek(weekIndex: 1, name: "Recovery")
        let buildBlock = PlanBlock(
            name: "Build block",
            phaseType: .strength,
            orderIndex: 0,
            weeks: [currentWeek]
        )
        let deloadBlock = PlanBlock(
            name: "Deload block",
            phaseType: .deload,
            orderIndex: 1,
            deloadVolumeReductionPercent: 45,
            deloadIntensityReductionPercent: 12,
            weeks: [deloadWeek]
        )
        let plan = WorkoutPlan(
            name: "Strength",
            daysPerWeek: 1,
            durationWeeks: 2,
            blocks: [buildBlock, deloadBlock]
        )
        let run = PlanRun(plan: plan, startDate: today)
        let current = progress("Current", week: 0, sourceWeek: 0, workout: 0, scheduled: today)
        let next = progress("Deload lower", week: 1, sourceWeek: 1, workout: 0, scheduled: date(2026, 7, 23))
        run.workoutProgress = [next, current]

        let review = WeeklyProgramReviewBuilder.build(
            for: run,
            reviewedWeekIndex: 0,
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(review.sessions.map(\.workoutName), ["Current"])
        XCTAssertEqual(review.nextWeek?.runWeekIndex, 1)
        XCTAssertEqual(review.nextWeek?.name, "Recovery")
        XCTAssertEqual(review.nextWeek?.blockName, "Deload block")
        XCTAssertTrue(review.nextWeek?.isDeload == true)
        XCTAssertEqual(review.nextWeek?.deloadVolumeReductionPercent, 45)
        XCTAssertEqual(review.nextWeek?.deloadIntensityReductionPercent, 12)
        XCTAssertEqual(review.nextWeek?.sessions.map(\.name), ["Deload lower"])
    }

    @MainActor
    func testRepositoryRefetchesRunWorkoutAndReceiptEvidence() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Persisted review", startDate: today)
        let progress = progress("Persisted session", week: 0, workout: 0, scheduled: today)
        progress.status = .completed
        let workout = completedWorkout(named: "Persisted session", prescribedSets: 3, performedSets: 2)
        workout.sourcePlanRunID = run.id
        progress.completedWorkout = workout
        run.workoutProgress = [progress]
        let record = try recommendationRecord(
            runID: run.id,
            workoutID: workout.id,
            key: "persisted"
        )

        context.insert(run)
        context.insert(workout)
        context.insert(record)
        try context.save()

        let review = try XCTUnwrap(WeeklyProgramReviewRepository.projection(
            for: WeeklyProgramReviewRoute(runID: run.id),
            in: context,
            today: today,
            calendar: calendar
        ))

        XCTAssertEqual(review.planName, "Persisted review")
        XCTAssertEqual(review.sessions.first?.completedWorkoutID, workout.id)
        XCTAssertEqual(review.setSummary.prescribedCount, 3)
        XCTAssertEqual(review.setSummary.performedCount, 2)
        XCTAssertEqual(review.progressionDecisions.map(\.id), [record.id])
    }

    private func progress(
        _ name: String,
        week: Int,
        sourceWeek: Int? = nil,
        workout: Int,
        scheduled: Date?
    ) -> PlanWorkoutProgress {
        PlanWorkoutProgress(
            plannedWorkoutID: UUID(),
            plannedWorkoutName: name,
            weekIndex: week,
            sourceWeekIndex: sourceWeek ?? week,
            workoutIndex: workout,
            scheduledDate: scheduled
        )
    }

    private func completedWorkout(
        named name: String,
        prescribedSets: Int,
        performedSets: Int
    ) -> Workout {
        let workout = Workout(name: name, endTime: today.addingTimeInterval(3_600))
        let exercise = Exercise(name: "\(name) exercise", primaryMuscles: [.quadriceps])
        let sets = (0..<prescribedSets).map { index in
            ExerciseSet(
                repetitions: index < performedSets ? 5 : 0,
                weight: index < performedSets ? 100 : 0,
                done: index < performedSets,
                orderIndex: index,
                usedMetric: .metric
            )
        }
        let entry = ExerciseEntry(exercise: exercise, sets: sets, usedMetric: .metric)
        entry.prescribedSets = prescribedSets
        workout.exercises = [entry]
        return workout
    }

    private func recommendationRecord(
        runID: UUID,
        workoutID: UUID,
        key: String
    ) throws -> PlanProgressionRecommendationRecord {
        let recommendation = ProgressionRecommendation(
            id: UUID(),
            ruleID: UUID(),
            action: .addLoad(2.5),
            cadence: .nextWorkout,
            scope: .exerciseExposure,
            reason: "Stored but not presented directly.",
            applicationMode: .recommendation,
            proposedState: ProgressionEvaluationState(currentLoad: 102.5),
            performance: ProgressionPerformance(requiredSets: 3, completedSets: 3),
            ruleVersion: 2
        )
        let record = try PlanProgressionRecommendationRecord(
            recommendation: recommendation,
            planRunID: runID,
            workoutID: workoutID
        )
        record.progressionKey = key
        return record
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
