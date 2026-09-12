import Foundation

/// Builds a `FixedProgramPathProjection` from the existing run and source-plan
/// evidence. The builder intentionally shares calendar lifecycle semantics
/// with `PlanCalendarBuilder` and selects the same actionable session as
/// `TodayWorkoutSummary` through `PlanCoordinator.nextProgress(in:)`.
enum FixedProgramPathBuilder {
    static func build(
        for run: PlanRun,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> FixedProgramPathProjection {
        let orderedProgress = run.orderedWorkoutProgress
        let runCanHaveCurrentWork = run.status == .active
            || run.status == .paused
            || run.status == .testDayAvailable
        let currentProgress = runCanHaveCurrentWork
            ? PlanCoordinator.nextProgress(in: run)
            : nil
        let sourceWeeks = sourceWeeksByIndex(in: run.plan)
        let sourceBlocks = sourceBlocksByWeekIndex(in: run.plan)

        var warnings: [FixedProgramPathProjection.Warning] = []
        if run.plan == nil {
            warnings.append(.sourcePlanUnavailable)
        }

        let sessionsByRunWeek = Dictionary(grouping: orderedProgress, by: \.weekIndex)
        let weeks = sessionsByRunWeek.keys.sorted().map { runWeekIndex in
            let progress = (sessionsByRunWeek[runWeekIndex] ?? []).sorted { lhs, rhs in
                if lhs.workoutIndex != rhs.workoutIndex {
                    return lhs.workoutIndex < rhs.workoutIndex
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            let sourceWeekIndex = progress.first?.sourceWeekIndex ?? runWeekIndex
            let sourceWeek = sourceWeeks[sourceWeekIndex]
            let sourceBlock = sourceBlocks[sourceWeekIndex]
            let projectedBlock: FixedProgramPathProjection.Block?
            if let sourceBlock {
                projectedBlock = blockProjection(sourceBlock)
            } else {
                projectedBlock = nil
            }

            if run.plan != nil, sourceWeek == nil,
               !warnings.contains(.sourceWeekUnavailable(sourceWeekIndex: sourceWeekIndex)) {
                warnings.append(.sourceWeekUnavailable(sourceWeekIndex: sourceWeekIndex))
            }

            return FixedProgramPathProjection.Week(
                runWeekIndex: runWeekIndex,
                sourceWeekIndex: sourceWeekIndex,
                sourceWeekName: sourceWeek?.name,
                block: projectedBlock,
                sessions: progress.map {
                    sessionProjection(
                        from: $0,
                        in: run,
                        runID: run.id,
                        currentProgressID: currentProgress?.id,
                        today: today,
                        calendar: calendar
                    )
                }
            )
        }

        let currentID = currentProgress?.id
        let currentWeek = weeks.first { $0.sessions.contains { $0.id == currentID } }
            ?? weeks.first { $0.runWeekIndex == run.currentWeekIndex }
        let orderedBlocks = run.plan?.orderedBlocks ?? []
        let position = FixedProgramPathProjection.Position(
            block: currentWeek?.block,
            blockIndex: currentWeek?.block.flatMap { currentBlock in
                orderedBlocks.firstIndex { $0.id == currentBlock.id }
            },
            totalBlockCount: orderedBlocks.count,
            runWeekIndex: currentWeek?.runWeekIndex,
            weekPosition: currentWeek.flatMap { currentWeek in
                weeks.firstIndex { $0.id == currentWeek.id }
            },
            totalWeekCount: weeks.count,
            sessionIndex: currentWeek?.sessions.firstIndex { $0.id == currentID }
                ?? currentWeek?.sessions.firstIndex { $0.workoutIndex == run.currentWorkoutIndex },
            sessionCountInWeek: currentWeek?.sessions.count ?? 0
        )

        if !orderedProgress.isEmpty, currentID == nil, currentWeek == nil {
            warnings.append(.cursorUnavailable)
        }

        let deloads = deloads(in: weeks)
        let currentDeload: FixedProgramPathProjection.Deload? = runCanHaveCurrentWork
            ? currentWeek.flatMap { week in
            guard let block = week.block, block.isDeload else { return nil }
            return deloads.first {
                $0.block.id == block.id && $0.runWeekIndices.contains(week.runWeekIndex)
            }
        } : nil
        let upcomingDeload = runCanHaveCurrentWork ? deloads.first { deload in
            guard currentDeload?.block.id != deload.block.id else { return false }
            guard let currentWeekIndex = position.runWeekIndex else { return true }
            return deload.firstRunWeekIndex > currentWeekIndex
        } : nil

        return FixedProgramPathProjection(
            runID: run.id,
            title: run.sourcePlanName,
            status: run.status,
            position: position,
            progress: .init(
                completedSessionCount: orderedProgress.filter { $0.status == .completed }.count,
                totalSessionCount: orderedProgress.count
            ),
            weeks: weeks,
            currentSessionID: currentID,
            primaryAction: primaryAction(for: currentProgress, runID: run.id),
            currentDeload: currentDeload,
            upcomingDeload: upcomingDeload,
            warnings: warnings
        )
    }

    private static func sourceWeeksByIndex(in plan: WorkoutPlan?) -> [Int: PlanWeek] {
        Dictionary(uniqueKeysWithValues: (plan?.orderedWeeks ?? []).map { ($0.weekIndex, $0) })
    }

    private static func sourceBlocksByWeekIndex(in plan: WorkoutPlan?) -> [Int: PlanBlock] {
        Dictionary(uniqueKeysWithValues: (plan?.orderedBlocks ?? []).flatMap { block in
            block.orderedWeeks.map { ($0.weekIndex, block) }
        })
    }

    private static func blockProjection(_ block: PlanBlock) -> FixedProgramPathProjection.Block {
        .init(
            id: block.id,
            name: block.name,
            phaseType: block.phaseType,
            orderIndex: block.orderIndex,
            deloadVolumeReductionPercent: block.isDeload ? block.effectiveDeloadVolumeReductionPercent : nil,
            deloadIntensityReductionPercent: block.isDeload ? block.effectiveDeloadIntensityReductionPercent : nil
        )
    }

    private static func sessionProjection(
        from progress: PlanWorkoutProgress,
        in run: PlanRun,
        runID: UUID,
        currentProgressID: UUID?,
        today: Date,
        calendar: Calendar
    ) -> FixedProgramPathProjection.Session {
        let originalScheduledDate = progress.originalScheduledDate
        let scheduledDate = progress.scheduledDate.map(calendar.startOfDay(for:))
        let normalizedOriginalDate = originalScheduledDate.map(calendar.startOfDay(for:))
        let isRescheduled = scheduledDate != nil
            && normalizedOriginalDate != nil
            && scheduledDate != normalizedOriginalDate
            && progress.lastRescheduledAt != nil
        let action: ProgramPathAction?
        switch progress.status {
        case .completed:
            action = progress.completedWorkout.map {
                ProgramPathAction.openCompletedWorkout(workoutID: $0.id)
            }
        case .available, .upcoming:
            action = .rescheduleFixedWorkout(runID: runID, progressID: progress.id)
        case .inProgress, .skipped:
            action = nil
        }

        return .init(
            id: progress.id,
            plannedWorkoutID: progress.plannedWorkoutID,
            workoutName: progress.plannedWorkoutName,
            runWeekIndex: progress.weekIndex,
            sourceWeekIndex: progress.sourceWeekIndex ?? progress.weekIndex,
            workoutIndex: progress.workoutIndex,
            scheduledDate: scheduledDate,
            originalScheduledDate: normalizedOriginalDate,
            lastRescheduledAt: progress.lastRescheduledAt,
            displayState: PlanCalendarBuilder.displayState(
                for: progress,
                in: run,
                today: today,
                calendar: calendar
            ),
            isRescheduled: isRescheduled,
            isCurrent: progress.id == currentProgressID,
            completedWorkoutID: progress.completedWorkout?.id,
            action: action
        )
    }

    private static func primaryAction(
        for progress: PlanWorkoutProgress?,
        runID: UUID
    ) -> ProgramPathAction? {
        guard let progress else { return nil }
        switch progress.status {
        case .available, .inProgress:
            return .startFixedWorkout(runID: runID, progressID: progress.id)
        case .upcoming, .completed, .skipped:
            return nil
        }
    }

    private static func deloads(
        in weeks: [FixedProgramPathProjection.Week]
    ) -> [FixedProgramPathProjection.Deload] {
        var segments: [[FixedProgramPathProjection.Week]] = []
        for week in weeks {
            guard let block = week.block, block.isDeload else { continue }
            if let lastSegment = segments.last,
               let lastWeek = lastSegment.last,
               lastWeek.block?.id == block.id,
               lastWeek.runWeekIndex + 1 == week.runWeekIndex {
                segments[segments.count - 1].append(week)
            } else {
                segments.append([week])
            }
        }

        return segments
            .compactMap { segment in
                guard let firstWeek = segment.first, let block = firstWeek.block else {
                    return nil
                }
                return .init(
                    block: block,
                    runWeekIndices: segment.map(\.runWeekIndex),
                    firstRunWeekIndex: firstWeek.runWeekIndex,
                    firstScheduledDate: segment
                        .flatMap(\.sessions)
                        .compactMap(\.scheduledDate)
                        .min()
                )
            }
            .sorted { $0.firstRunWeekIndex < $1.firstRunWeekIndex }
    }
}
