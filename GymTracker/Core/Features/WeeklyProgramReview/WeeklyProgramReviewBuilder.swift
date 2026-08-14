import Foundation

/// Builds the fixed-plan weekly review without persisting a review record.
///
/// Occurrence `weekIndex` owns review membership. `sourceWeekIndex` is used
/// only to recover optional prescription metadata and next-week context.
enum WeeklyProgramReviewBuilder {
    static func build(
        for run: PlanRun,
        progressionRecords: [PlanProgressionRecommendationRecord] = [],
        reviewedWeekIndex: Int? = nil,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyProgramReviewProjection {
        let weekIndex = reviewedWeekIndex ?? run.currentWeekIndex
        let progress = run.orderedWorkoutProgress
            .filter { $0.weekIndex == weekIndex }
            .sorted { progressOrder($0, $1) }
        let sourceWeekIndex = progress.first?.sourceWeekIndex ?? weekIndex
        let sourceWeek = run.plan?.orderedWeeks.first { $0.weekIndex == sourceWeekIndex }
        var warnings: [WeeklyProgramReviewProjection.Warning] = []

        if run.plan == nil {
            warnings.append(.sourcePlanUnavailable)
        } else if sourceWeek == nil {
            warnings.append(.sourceWeekUnavailable(sourceWeekIndex: sourceWeekIndex))
        }
        if progress.isEmpty {
            warnings.append(.reviewedWeekUnavailable)
        }

        let sessions = progress.map {
            session(from: $0, today: today, calendar: calendar)
        }
        let completedWorkouts = completedWorkouts(
            from: progress,
            warnings: &warnings
        )
        let setSummary = setSummary(
            progress: progress,
            sourceWeek: sourceWeek,
            warnings: &warnings
        )

        return WeeklyProgramReviewProjection(
            runID: run.id,
            planName: run.sourcePlanName,
            runStatus: run.status,
            week: .init(
                runWeekIndex: weekIndex,
                sourceWeekIndex: sourceWeekIndex,
                name: sourceWeek?.name,
                blockName: sourceWeek?.block?.name,
                phaseType: sourceWeek?.block?.phaseType,
                scheduledDateRange: scheduledDateRange(for: sessions)
            ),
            sessions: sessions,
            sessionSummary: sessionSummary(for: sessions),
            setSummary: setSummary,
            progressionDecisions: progressionDecisions(
                records: progressionRecords,
                runID: run.id,
                workouts: completedWorkouts
            ),
            substitutions: substitutions(
                workouts: completedWorkouts,
                warnings: &warnings
            ),
            nextWeek: nextWeek(after: weekIndex, in: run, calendar: calendar),
            warnings: warnings
        )
    }

    nonisolated private static func progressOrder(
        _ lhs: PlanWorkoutProgress,
        _ rhs: PlanWorkoutProgress
    ) -> Bool {
        if lhs.workoutIndex != rhs.workoutIndex {
            return lhs.workoutIndex < rhs.workoutIndex
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func session(
        from progress: PlanWorkoutProgress,
        today: Date,
        calendar: Calendar
    ) -> WeeklyProgramReviewProjection.Session {
        return .init(
            id: progress.id,
            plannedWorkoutID: progress.plannedWorkoutID,
            workoutName: progress.plannedWorkoutName,
            workoutIndex: progress.workoutIndex,
            scheduledDate: progress.scheduledDate.map(calendar.startOfDay(for:)),
            originalScheduledDate: progress.originalScheduledDate.map(calendar.startOfDay(for:)),
            lastRescheduledAt: progress.lastRescheduledAt,
            displayState: PlanCalendarBuilder.displayState(
                status: progress.status,
                scheduledDate: progress.scheduledDate,
                today: today,
                calendar: calendar
            ),
            completedWorkoutID: progress.completedWorkout?.id
        )
    }

    private static func sessionSummary(
        for sessions: [WeeklyProgramReviewProjection.Session]
    ) -> WeeklyProgramReviewProjection.SessionSummary {
        var completedCount = 0
        var inProgressCount = 0
        var skippedCount = 0
        var missedCount = 0
        var availableCount = 0
        var upcomingCount = 0
        var unscheduledCount = 0

        for session in sessions {
            switch session.displayState {
            case .completed: completedCount += 1
            case .inProgress: inProgressCount += 1
            case .skipped: skippedCount += 1
            case .missed: missedCount += 1
            case .available: availableCount += 1
            case .upcoming: upcomingCount += 1
            }
            if session.scheduledDate == nil {
                unscheduledCount += 1
            }
        }

        return .init(
            plannedCount: sessions.count,
            completedCount: completedCount,
            inProgressCount: inProgressCount,
            skippedCount: skippedCount,
            missedCount: missedCount,
            availableCount: availableCount,
            upcomingCount: upcomingCount,
            unscheduledCount: unscheduledCount
        )
    }

    private static func scheduledDateRange(
        for sessions: [WeeklyProgramReviewProjection.Session]
    ) -> DateInterval? {
        let dates = sessions.compactMap(\.scheduledDate)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return DateInterval(start: first, end: last)
    }

    private static func completedWorkouts(
        from progress: [PlanWorkoutProgress],
        warnings: inout [WeeklyProgramReviewProjection.Warning]
    ) -> [Workout] {
        progress.compactMap { item in
            if item.status == .completed, item.completedWorkout == nil {
                warnings.append(.completedSessionMissingWorkout(progressID: item.id))
                return nil
            }
            guard let workout = item.completedWorkout else { return nil }
            guard workout.status == .completed else {
                warnings.append(
                    .linkedWorkoutNotCompleted(progressID: item.id, workoutID: workout.id)
                )
                return nil
            }
            return workout
        }
    }

    private static func setSummary(
        progress: [PlanWorkoutProgress],
        sourceWeek: PlanWeek?,
        warnings: inout [WeeklyProgramReviewProjection.Warning]
    ) -> WeeklyProgramReviewProjection.SetSummary {
        var prescribedTotal = 0
        var performedTotal = 0
        var evidenceCount = 0

        for item in progress {
            if let workout = item.completedWorkout, workout.status == .completed {
                let prescribed = workout.orderedExercises.compactMap(\.prescribedSets)
                if prescribed.count == workout.orderedExercises.count {
                    prescribedTotal += prescribed.reduce(0, +)
                    evidenceCount += 1
                } else {
                    warnings.append(.incompleteSetPrescription(progressID: item.id))
                }
                performedTotal += workout.orderedExercises
                    .flatMap(\.orderedSets)
                    .filter(\.done)
                    .count
                continue
            }

            if let plannedWorkout = sourceWeek?.orderedPlannedWorkouts.first(
                where: { $0.id == item.plannedWorkoutID }
            ) {
                prescribedTotal += plannedWorkout.orderedPlannedExercises
                    .reduce(0) { $0 + $1.targetSets }
                evidenceCount += 1
            } else {
                warnings.append(.incompleteSetPrescription(progressID: item.id))
            }
        }

        return .init(
            prescribedCount: evidenceCount == progress.count ? prescribedTotal : nil,
            performedCount: performedTotal,
            sessionsWithPrescriptionEvidence: evidenceCount,
            reviewedSessionCount: progress.count
        )
    }

    private static func progressionDecisions(
        records: [PlanProgressionRecommendationRecord],
        runID: UUID,
        workouts: [Workout]
    ) -> [WeeklyProgramReviewProjection.ProgressionDecision] {
        let workoutsByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        return records
            .filter { $0.planRunID == runID && workoutsByID[$0.workoutID] != nil }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map { record in
                let exerciseName = workoutsByID[record.workoutID]?
                    .orderedExercises
                    .first { $0.progressionKey == record.progressionKey }?
                    .nameSnapshot
                return .init(
                    id: record.id,
                    workoutID: record.workoutID,
                    progressionKey: record.progressionKey,
                    exerciseName: exerciseName,
                    ruleID: record.ruleID,
                    ruleVersion: record.ruleVersion,
                    createdAt: record.createdAt,
                    resolvedAt: record.resolvedAt,
                    isResolved: record.isResolved,
                    outcome: record.decisionOutcome,
                    proposedLoad: record.proposedLoad,
                    appliedLoad: record.appliedLoad
                )
            }
    }

    private static func substitutions(
        workouts: [Workout],
        warnings: inout [WeeklyProgramReviewProjection.Warning]
    ) -> [WeeklyProgramReviewProjection.Substitution] {
        workouts
            .sorted {
                if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
                return $0.id.uuidString < $1.id.uuidString
            }
            .flatMap { workout in
                workout.orderedExercises.compactMap { entry in
                    guard let originalID = entry.originalExerciseIDSnapshot,
                          let selectedID = entry.selectedSubstituteExerciseIDSnapshot,
                          originalID != selectedID
                    else {
                        return nil
                    }
                    if entry.substitutionReasonValue == nil
                        || entry.substitutionScope == nil
                        || entry.substitutionComparability == nil
                        || entry.substitutionProgressionPolicy == nil {
                        warnings.append(
                            .legacySubstitutionEvidence(
                                workoutID: workout.id,
                                exerciseID: selectedID
                            )
                        )
                    }
                    return .init(
                        id: "\(workout.id.uuidString)-\(entry.orderIndex)-\(selectedID.uuidString)",
                        workoutID: workout.id,
                        originalExerciseID: originalID,
                        originalExerciseName: entry.originalExerciseNameSnapshot,
                        selectedExerciseID: selectedID,
                        selectedExerciseName: entry.nameSnapshot,
                        reason: entry.substitutionReasonValue,
                        scope: entry.substitutionScope,
                        suitability: entry.substitutionSuitability,
                        comparability: entry.substitutionComparability,
                        progressionPolicy: entry.substitutionProgressionPolicy,
                        confidence: entry.substitutionEvidenceConfidence,
                        evaluationVersion: entry.substitutionEvaluationVersion
                    )
                }
            }
    }

    private static func nextWeek(
        after reviewedWeekIndex: Int,
        in run: PlanRun,
        calendar: Calendar
    ) -> WeeklyProgramReviewProjection.NextWeek? {
        let nextRunWeekIndex = reviewedWeekIndex + 1
        let progress = run.orderedWorkoutProgress
            .filter { $0.weekIndex == nextRunWeekIndex }
            .sorted { progressOrder($0, $1) }
        guard !progress.isEmpty else { return nil }
        let sourceWeekIndex = progress.first?.sourceWeekIndex ?? nextRunWeekIndex
        let sourceWeek = run.plan?.orderedWeeks.first { $0.weekIndex == sourceWeekIndex }
        let block = sourceWeek?.block

        return .init(
            runWeekIndex: nextRunWeekIndex,
            sourceWeekIndex: sourceWeekIndex,
            name: sourceWeek?.name,
            blockName: block?.name,
            phaseType: block?.phaseType,
            deloadVolumeReductionPercent: block?.isDeload == true
                ? block?.effectiveDeloadVolumeReductionPercent
                : nil,
            deloadIntensityReductionPercent: block?.isDeload == true
                ? block?.effectiveDeloadIntensityReductionPercent
                : nil,
            sessions: progress.map {
                .init(
                    id: $0.id,
                    name: $0.plannedWorkoutName,
                    workoutIndex: $0.workoutIndex,
                    scheduledDate: $0.scheduledDate.map(calendar.startOfDay(for:))
                )
            }
        )
    }
}
