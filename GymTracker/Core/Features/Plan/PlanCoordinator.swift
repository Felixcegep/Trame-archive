import Foundation
import SwiftData

enum PlanCoordinator {
    struct DayAssignment {
        let dayOffset: Int
        let template: WorkoutTemplate
    }

    struct DeloadConfiguration {
        let weekIndex: Int
        let volumeReductionPercent: Int
        let intensityReductionPercent: Int

        init(
            weekIndex: Int,
            volumeReductionPercent: Int = 50,
            intensityReductionPercent: Int = 10
        ) {
            self.weekIndex = weekIndex
            self.volumeReductionPercent = min(90, max(0, volumeReductionPercent))
            self.intensityReductionPercent = min(90, max(0, intensityReductionPercent))
        }
    }

    static func createPlan(
        name: String,
        goal: PlanGoal,
        experienceLevel: PlanExperienceLevel,
        requiredEquipment: [EquipmentType] = [],
        durationWeeks: Int,
        dayAssignments: [DayAssignment],
        deload: DeloadConfiguration? = nil,
        scheduleMode: PlanScheduleMode = .fixedWeekdays,
        scheduleIntervalDays: Int = 1
    ) -> WorkoutPlan {
        let assignments = dayAssignments
            .filter { (0...6).contains($0.dayOffset) && !$0.template.orderedTemplateExercises.isEmpty }
            .reduce(into: [Int: WorkoutTemplate]()) { result, assignment in
                result[assignment.dayOffset] = assignment.template
            }
            .map { DayAssignment(dayOffset: $0.key, template: $0.value) }
            .sorted { $0.dayOffset < $1.dayOffset }

        let plan = WorkoutPlan(
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            requiredEquipment: normalizedEquipment(requiredEquipment),
            daysPerWeek: assignments.count,
            durationWeeks: durationWeeks,
            scheduleMode: scheduleMode,
            scheduleIntervalDays: scheduleIntervalDays
        )

        let weeks = (0..<durationWeeks).map { weekIndex in
            PlanWeek(
                weekIndex: weekIndex,
                plannedWorkouts: assignments.enumerated().map { workoutIndex, assignment in
                    let content = copiedWorkoutContent(from: assignment.template)
                    return PlannedWorkout(
                        name: assignment.template.name,
                        orderIndex: workoutIndex,
                        dayOffset: assignment.dayOffset,
                        sourceTemplate: assignment.template,
                        plannedExercises: content.exercises,
                        executionBlocks: content.executionBlocks
                    )
                }
            )
        }

        plan.blocks = blocks(from: weeks, deload: deload)
        return plan
    }

    static func createRepeatedPlan(
        name: String,
        goal: PlanGoal,
        experienceLevel: PlanExperienceLevel,
        durationWeeks: Int,
        template: WorkoutTemplate,
        dayOffsets: [Int]
    ) -> WorkoutPlan {
        createPlan(
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            requiredEquipment: [],
            durationWeeks: durationWeeks,
            dayAssignments: dayOffsets.map {
                DayAssignment(dayOffset: $0, template: template)
            }
        )
    }

    @discardableResult
    static func startRun(for plan: WorkoutPlan, startDate: Date = .now) -> PlanRun? {
        guard plan.orderedWeeks.contains(where: { !$0.orderedPlannedWorkouts.isEmpty }) else {
            return nil
        }

        let run = PlanRun(plan: plan, startDate: startDate)
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: startDate)

        var sessionIndex = 0
        for week in plan.orderedWeeks {
            for workout in week.orderedPlannedWorkouts {
                let dayOffset: Int
                switch plan.scheduleMode {
                case .fixedWeekdays:
                    dayOffset = (week.weekIndex * 7) + workout.dayOffset
                case .sequential:
                    dayOffset = sessionIndex
                case .everyNDays:
                    dayOffset = sessionIndex * max(1, plan.scheduleIntervalDays)
                }
                let scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
                run.workoutProgress.append(
                    PlanWorkoutProgress(
                        plannedWorkout: workout,
                        weekIndex: week.weekIndex,
                        workoutIndex: workout.orderIndex,
                        scheduledDate: scheduledDate
                    )
                )
                sessionIndex += 1
            }
        }

        var stateKeys = Set<String>()
        for plannedExercise in plan.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises)
            where stateKeys.insert(plannedExercise.progressionKey).inserted {
            let initialStageID = plannedExercise.progressionStagesData
                .flatMap { try? JSONDecoder().decode(ProgramStageConfiguration.self, from: $0) }
                .map(\.initialStageID)
            run.progressionStates.append(
                PlanExerciseProgressionState(
                    progressionKey: plannedExercise.progressionKey,
                    currentLoad: plannedExercise.suggestedLoad,
                    currentStageID: initialStageID,
                    currentVariationExerciseID: plannedExercise.initialVariationExerciseID ?? plannedExercise.exercise.id,
                    trainingMax: plannedExercise.initialTrainingMax,
                    estimatedOneRepMax: plannedExercise.initialEstimatedOneRepMax,
                    actualOneRepMax: plannedExercise.initialActualOneRepMax,
                    velocityBaseline: plannedExercise.initialVelocityBaseline
                )
            )
        }

        refreshAvailability(for: run)
        return run
    }

    static func refreshAvailability(for run: PlanRun) {
        guard run.status == .active || run.status == .paused else { return }

        let inProgress = run.orderedWorkoutProgress.filter { $0.status == .inProgress }

        let unfinished = run.orderedWorkoutProgress.filter {
            $0.status != .completed && $0.status != .skipped && $0.status != .inProgress
        }

        for progress in unfinished {
            progress.status = .upcoming
        }

        if let activeProgress = inProgress.sorted(by: isOrderedByAvailability).first {
            // An active workout is the current truth. Relaunch and schedule
            // refreshes must not make a second future session available while
            // that workout is still in progress.
            run.currentWeekIndex = activeProgress.weekIndex
            run.currentWorkoutIndex = activeProgress.workoutIndex
        } else if let next = unfinished.sorted(by: isOrderedByAvailability).first {
            next.status = .available
            run.currentWeekIndex = next.weekIndex
            run.currentWorkoutIndex = next.workoutIndex
        } else if run.status == .active {
            run.status = .completed
            run.endDate = .now
        }
        run.updatedAt = .now
    }

    /// Scheduling edits are allowed while a run is active or paused. Terminal
    /// runs remain immutable so their schedule cannot be changed after the run
    /// is completed or archived.
    static func canEditSchedule(_ run: PlanRun) -> Bool {
        run.status == .active || run.status == .paused
    }

    static func canEditSchedule(_ progress: PlanWorkoutProgress, in run: PlanRun) -> Bool {
        canEditSchedule(run)
            && (progress.status == .available || progress.status == .upcoming)
    }

    static func plannedWorkout(for progress: PlanWorkoutProgress, in run: PlanRun) -> PlannedWorkout? {
        run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .first(where: { $0.id == progress.plannedWorkoutID })
    }

    static func nextProgress(in run: PlanRun) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.status == .inProgress }
            ?? run.orderedWorkoutProgress.first { $0.status == .available }
    }

    /// Creates new future occurrences from the selected template week. The
    /// original completed progress stays immutable; later unfinished weeks are
    /// shifted forward to leave a deterministic slot for the repeat.
    @discardableResult
    static func repeatWeek(containing source: PlanWorkoutProgress, in run: PlanRun) -> Bool {
        guard run.status == .active || run.status == .paused else { return false }
        let sourceWeek = source.weekIndex
        let sourceItems = run.orderedWorkoutProgress.filter { $0.weekIndex == sourceWeek }
        guard !sourceItems.isEmpty else { return false }
        let insertionWeek = sourceWeek + 1
        guard !run.orderedWorkoutProgress.contains(where: { $0.weekIndex >= insertionWeek && $0.status == .completed }) else {
            return false
        }
        shiftUnfinishedOccurrences(startingAt: insertionWeek, by: 1, in: run)
        appendRepeatedOccurrences(sourceItems, atWeekIndex: insertionWeek, in: run)
        refreshAvailability(for: run)
        return true
    }

    /// Repeats the template block containing the source occurrence. All of the
    /// block's workouts are appended as new future progress records; completed
    /// workout snapshots are never reassigned or edited.
    @discardableResult
    static func restartBlock(containing source: PlanWorkoutProgress, in run: PlanRun) -> Bool {
        guard run.status == .active || run.status == .paused,
              let block = run.plan?.orderedBlocks.first(where: {
                  $0.orderedWeeks.contains { $0.weekIndex == (source.sourceWeekIndex ?? source.weekIndex) }
              }) else { return false }
        let sourceWeekIndices = Set(block.orderedWeeks.map(\.weekIndex))
        let sourceItems = run.orderedWorkoutProgress.filter {
            sourceWeekIndices.contains($0.sourceWeekIndex ?? $0.weekIndex)
        }
        guard !sourceItems.isEmpty else { return false }
        let insertionWeek = source.weekIndex + 1
        guard !run.orderedWorkoutProgress.contains(where: { $0.weekIndex >= insertionWeek && $0.status == .completed }) else {
            return false
        }
        let distinctWeeks = Set(sourceItems.map(\.weekIndex)).count
        shiftUnfinishedOccurrences(startingAt: insertionWeek, by: distinctWeeks, in: run)
        let grouped = Dictionary(grouping: sourceItems, by: \.weekIndex)
        for (offset, occurrenceWeek) in grouped.keys.sorted().enumerated() {
            appendRepeatedOccurrences(grouped[occurrenceWeek] ?? [], atWeekIndex: insertionWeek + offset, in: run)
        }
        refreshAvailability(for: run)
        return true
    }

    private static func shiftUnfinishedOccurrences(startingAt weekIndex: Int, by amount: Int, in run: PlanRun) {
        let calendar = Calendar.current
        for progress in run.workoutProgress where progress.weekIndex >= weekIndex && progress.status != .completed {
            progress.weekIndex += amount
            if let date = progress.scheduledDate {
                applyAutomaticSchedule(
                    calendar.date(byAdding: .day, value: amount * 7, to: date),
                    to: progress,
                    calendar: calendar
                )
            }
        }
    }

    private static func appendRepeatedOccurrences(
        _ source: [PlanWorkoutProgress],
        atWeekIndex weekIndex: Int,
        in run: PlanRun
    ) {
        let calendar = Calendar.current
        for item in source.sorted(by: { $0.workoutIndex < $1.workoutIndex }) {
            let copy = PlanWorkoutProgress(
                plannedWorkoutID: item.plannedWorkoutID,
                plannedWorkoutName: item.plannedWorkoutName,
                weekIndex: weekIndex,
                sourceWeekIndex: item.sourceWeekIndex ?? item.weekIndex,
                workoutIndex: item.workoutIndex,
                scheduledDate: item.scheduledDate.flatMap { calendar.date(byAdding: .day, value: 7, to: $0) }
            )
            run.workoutProgress.append(copy)
        }
    }

    /// Moves an available or upcoming session to a new scheduled day and
    /// recomputes which session is next. Completed, skipped, and in-progress
    /// sessions are locked because they no longer represent future work.
    @discardableResult
    static func reschedule(_ progress: PlanWorkoutProgress, to date: Date, in run: PlanRun) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        if let scheduledDate = progress.scheduledDate,
           calendar.startOfDay(for: scheduledDate) == targetDay {
            return true
        }
        applyUserScheduleChange(
            targetDay,
            to: progress,
            calendar: calendar,
            at: .now
        )
        refreshAvailability(for: run)
        return true
    }

    /// Applies and persists a schedule edit as one transaction. A failed save
    /// must not leave run progress or availability changes in memory.
    @discardableResult
    static func reschedule(
        _ progress: PlanWorkoutProgress,
        to date: Date,
        in run: PlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard reschedule(progress, to: date, in: run) else { return false }
        return saveAndNotify(using: modelContext)
    }

    /// Removes a future session from the calendar without changing the reusable
    /// plan. It remains available in the run's Unscheduled section.
    @discardableResult
    static func unschedule(
        _ progress: PlanWorkoutProgress,
        in run: PlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        progress.scheduledDate = nil
        refreshAvailability(for: run)
        return saveAndNotify(using: modelContext)
    }

    /// Moves the selected session and every editable session scheduled after it
    /// by the same number of calendar days. Completed truth and active work stay
    /// fixed in place.
    @discardableResult
    static func rescheduleRemaining(
        from progress: PlanWorkoutProgress,
        to date: Date,
        in run: PlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard canEditSchedule(progress, in: run), let originalDate = progress.scheduledDate else {
            return false
        }
        let calendar = Calendar.current
        let originalDay = calendar.startOfDay(for: originalDate)
        let targetDay = calendar.startOfDay(for: date)
        guard let dayDelta = calendar.dateComponents([.day], from: originalDay, to: targetDay).day else {
            return false
        }
        if dayDelta == 0 {
            return true
        }

        let editable = run.orderedWorkoutProgress.filter {
            canEditSchedule($0, in: run)
                && ($0.scheduledDate.map { calendar.startOfDay(for: $0) >= originalDay } ?? false)
        }
        let rescheduledAt = Date.now
        for item in editable {
            guard let scheduledDate = item.scheduledDate,
                  let shifted = calendar.date(byAdding: .day, value: dayDelta, to: scheduledDate)
            else { continue }
            applyUserScheduleChange(
                calendar.startOfDay(for: shifted),
                to: item,
                calendar: calendar,
                at: rescheduledAt
            )
        }
        refreshAvailability(for: run)
        return saveAndNotify(using: modelContext)
    }

    /// Orders sessions by scheduled date first so rescheduling can promote or
    /// demote a session; sessions sharing a date fall back to plan order.
    nonisolated private static func isOrderedByAvailability(_ lhs: PlanWorkoutProgress, _ rhs: PlanWorkoutProgress) -> Bool {
        let calendar = Calendar.current
        let lhsDate = lhs.scheduledDate.map(calendar.startOfDay(for:)) ?? .distantFuture
        let rhsDate = rhs.scheduledDate.map(calendar.startOfDay(for:)) ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        if lhs.weekIndex != rhs.weekIndex {
            return lhs.weekIndex < rhs.weekIndex
        }
        return lhs.workoutIndex < rhs.workoutIndex
    }

    static func markCompleted(_ progress: PlanWorkoutProgress, with workout: Workout, in run: PlanRun) {
        progress.status = .completed
        progress.completedAt = .now
        progress.completedWorkout = workout
        refreshAvailability(for: run)
    }

    static func restoreAvailability(_ progress: PlanWorkoutProgress, in run: PlanRun) {
        progress.status = .upcoming
        progress.startedAt = nil
        refreshAvailability(for: run)
    }

    static func skip(_ progress: PlanWorkoutProgress, in run: PlanRun) {
        guard canEditSchedule(progress, in: run) else { return }
        progress.status = .skipped
        progress.completedAt = .now
        refreshAvailability(for: run)
    }

    /// Applies and persists a skip as one transaction, mirroring the rollback
    /// boundary used by active-workout save and discard.
    @discardableResult
    static func skip(
        _ progress: PlanWorkoutProgress,
        in run: PlanRun,
        using modelContext: ModelContext
    ) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        skip(progress, in: run)
        return saveAndNotify(using: modelContext)
    }

    static func pause(_ run: PlanRun) {
        guard run.status == .active else { return }
        run.status = .paused
        run.updatedAt = .now
    }

    /// Applies and persists a pause as one transaction, mirroring the rollback
    /// boundary used by reschedule and skip.
    @discardableResult
    static func pause(_ run: PlanRun, using modelContext: ModelContext) -> Bool {
        pause(run)
        return saveAndNotify(using: modelContext)
    }

    static func resume(_ run: PlanRun, at date: Date = .now) {
        guard run.status == .paused else { return }
        run.status = .active
        reanchorUnfinishedSchedule(for: run, from: date)
        refreshAvailability(for: run)
    }

    @discardableResult
    static func resume(_ run: PlanRun, at date: Date = .now, using modelContext: ModelContext) -> Bool {
        resume(run, at: date)
        return saveAndNotify(using: modelContext)
    }

    @discardableResult
    static func resume(_ run: PlanRun, using modelContext: ModelContext) -> Bool {
        resume(run, at: .now, using: modelContext)
    }

    private static func reanchorUnfinishedSchedule(for run: PlanRun, from date: Date) {
        guard let plan = run.plan else { return }
        let unfinished = run.orderedWorkoutProgress.filter {
            $0.status != .completed && $0.status != .skipped && $0.status != .inProgress
        }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: date)

        for (sequenceIndex, progress) in unfinished.enumerated() {
            let dayOffset: Int
            switch plan.scheduleMode {
            case .fixedWeekdays:
                dayOffset = (progress.weekIndex * 7) + (plannedWorkout(for: progress, in: run)?.dayOffset ?? 0)
            case .sequential:
                dayOffset = sequenceIndex
            case .everyNDays:
                dayOffset = sequenceIndex * max(1, plan.scheduleIntervalDays)
            }
            applyAutomaticSchedule(
                calendar.date(byAdding: .day, value: dayOffset, to: anchor),
                to: progress,
                calendar: calendar
            )
        }
    }

    /// Records an explicit user schedule change without ever rewriting the
    /// original occurrence date. A legacy record may not yet carry origin
    /// evidence; its current date is the best preserved baseline. An
    /// initially-unscheduled occurrence instead establishes its first date
    /// without being labelled as rescheduled.
    private static func applyUserScheduleChange(
        _ date: Date,
        to progress: PlanWorkoutProgress,
        calendar: Calendar,
        at timestamp: Date
    ) {
        let targetDay = calendar.startOfDay(for: date)
        if progress.originalScheduledDate == nil {
            progress.originalScheduledDate = progress.scheduledDate.map(calendar.startOfDay(for:)) ?? targetDay
        }
        let existingDay = progress.scheduledDate.map(calendar.startOfDay(for:))
        progress.scheduledDate = targetDay
        if let existingDay, existingDay != targetDay {
            progress.lastRescheduledAt = timestamp
        }
    }

    /// Automatic schedule changes retain the first known occurrence date but
    /// do not claim the user explicitly rescheduled the session.
    private static func applyAutomaticSchedule(
        _ date: Date?,
        to progress: PlanWorkoutProgress,
        calendar: Calendar
    ) {
        guard let date else { return }
        let targetDay = calendar.startOfDay(for: date)
        if progress.originalScheduledDate == nil {
            progress.originalScheduledDate = progress.scheduledDate.map(calendar.startOfDay(for:)) ?? targetDay
        }
        progress.scheduledDate = targetDay
    }

    static func archive(_ run: PlanRun) {
        guard run.status != .completed else { return }
        run.status = .archived
        run.endDate = .now
        run.updatedAt = .now
    }

    @discardableResult
    static func archive(_ run: PlanRun, using modelContext: ModelContext) -> Bool {
        archive(run)
        return saveAndNotify(using: modelContext)
    }

    /// Creates and persists a plan run as one transaction, inserting it before
    /// saving so a failed save leaves nothing partially committed.
    @discardableResult
    static func startRun(
        for plan: WorkoutPlan,
        startDate: Date = .now,
        using modelContext: ModelContext
    ) -> PlanRun? {
        // No path may activate a run against an invalid tracking profile, even
        // one that reached persistence through a route other than the plan
        // editor (seeded content, a future importer, direct model mutation).
        guard TrackingProfileValidator.validate(plan: plan).isEmpty else { return nil }
        guard let run = startRun(for: plan, startDate: startDate) else { return nil }
        modelContext.insert(run)
        return saveAndNotify(using: modelContext) ? run : nil
    }

    private static func saveAndNotify(using modelContext: ModelContext) -> Bool {
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    private static func copiedWorkoutContent(
        from template: WorkoutTemplate
    ) -> (exercises: [PlannedExercise], executionBlocks: [PlannedExerciseBlock]) {
        var copiedGroupIDs: [UUID: UUID] = [:]
        var copiedBlockIDs: [UUID: UUID] = [:]
        let executionBlocks = template.orderedExecutionBlocks.map { source in
            let block = PlannedExerciseBlock(
                orderIndex: source.orderIndex,
                kind: source.kind,
                name: source.name,
                targetRounds: source.targetRounds,
                isSharedLoad: source.isSharedLoad,
                restSeconds: source.restSeconds,
                clockMode: source.clockMode,
                prescribedDurationSeconds: source.prescribedDurationSeconds,
                timeCapSeconds: source.timeCapSeconds,
                intervalSeconds: source.intervalSeconds,
                scoreKind: source.scoreKind,
                repetitionScheme: source.repetitionScheme,
                repetitionStart: source.repetitionStart,
                repetitionEnd: source.repetitionEnd,
                repetitionStep: source.repetitionStep,
                sourceTemplateBlockID: source.id
            )
            copiedBlockIDs[source.id] = block.id
            return block
        }
        let exercises = template.orderedTemplateExercises.enumerated().map { index, templateExercise in
            let groupID: UUID?
            if let sourceID = templateExercise.supersetGroupID {
                if let existingID = copiedGroupIDs[sourceID] {
                    groupID = existingID
                } else {
                    let freshID = UUID()
                    copiedGroupIDs[sourceID] = freshID
                    groupID = freshID
                }
            } else {
                groupID = nil
            }
            let exercise = PlannedExercise(
                exercise: templateExercise.exercise,
                orderIndex: index,
                targetSets: templateExercise.targetSets,
                repRangeMinimum: templateExercise.repRangeMinimum,
                repRangeMaximum: templateExercise.repRangeMaximum,
                restSeconds: templateExercise.restSeconds,
                targetRPE: templateExercise.targetRPE,
                targetRIR: templateExercise.targetRIR,
                notes: templateExercise.notes,
                progressionRule: templateExercise.progressionRule,
                supersetGroupID: groupID,
                progressionKey: templateExercise.progressionKey
            )
            if let sourceBlockID = templateExercise.executionBlockID {
                exercise.executionBlockID = copiedBlockIDs[sourceBlockID]
                exercise.executionBlockComponentOrder = templateExercise.executionBlockComponentOrder
            }
            return exercise
        }
        return (exercises, executionBlocks)
    }

    private static func normalizedEquipment(_ equipment: [EquipmentType]) -> [EquipmentType] {
        Array(Set(equipment)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func blocks(
        from weeks: [PlanWeek],
        deload: DeloadConfiguration?
    ) -> [PlanBlock] {
        guard
            let deload,
            weeks.indices.contains(deload.weekIndex)
        else {
            return [
                PlanBlock(
                    name: "Program",
                    phaseType: .accumulation,
                    orderIndex: 0,
                    weeks: weeks
                )
            ]
        }

        let before = weeks.filter { $0.weekIndex < deload.weekIndex }
        let deloadWeek = weeks.filter { $0.weekIndex == deload.weekIndex }
        let after = weeks.filter { $0.weekIndex > deload.weekIndex }
        var blocks: [PlanBlock] = []

        if !before.isEmpty {
            blocks.append(
                PlanBlock(
                    name: "Build",
                    phaseType: .accumulation,
                    orderIndex: blocks.count,
                    weeks: before
                )
            )
        }

        blocks.append(
            PlanBlock(
                name: "Deload",
                phaseType: .deload,
                orderIndex: blocks.count,
                deloadVolumeReductionPercent: deload.volumeReductionPercent,
                deloadIntensityReductionPercent: deload.intensityReductionPercent,
                weeks: deloadWeek
            )
        )

        if !after.isEmpty {
            blocks.append(
                PlanBlock(
                    name: "Build",
                    phaseType: .accumulation,
                    orderIndex: blocks.count,
                    weeks: after
                )
            )
        }

        return blocks
    }
}
