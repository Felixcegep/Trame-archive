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
        deload: DeloadConfiguration? = nil
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
            durationWeeks: durationWeeks
        )

        let weeks = (0..<durationWeeks).map { weekIndex in
            PlanWeek(
                weekIndex: weekIndex,
                plannedWorkouts: assignments.enumerated().map { workoutIndex, assignment in
                    PlannedWorkout(
                        name: assignment.template.name,
                        orderIndex: workoutIndex,
                        dayOffset: assignment.dayOffset,
                        sourceTemplate: assignment.template,
                        plannedExercises: copiedExercises(from: assignment.template)
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

        for week in plan.orderedWeeks {
            for workout in week.orderedPlannedWorkouts {
                let dayOffset = (week.weekIndex * 7) + workout.dayOffset
                let scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
                run.workoutProgress.append(
                    PlanWorkoutProgress(
                        plannedWorkout: workout,
                        weekIndex: week.weekIndex,
                        workoutIndex: workout.orderIndex,
                        scheduledDate: scheduledDate
                    )
                )
            }
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
            .first(where: { $0.weekIndex == progress.weekIndex })?
            .orderedPlannedWorkouts
            .first(where: { $0.id == progress.plannedWorkoutID })
    }

    static func nextProgress(in run: PlanRun) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.status == .inProgress }
            ?? run.orderedWorkoutProgress.first { $0.status == .available }
    }

    /// Moves an available or upcoming session to a new scheduled day and
    /// recomputes which session is next. Completed, skipped, and in-progress
    /// sessions are locked because they no longer represent future work.
    @discardableResult
    static func reschedule(_ progress: PlanWorkoutProgress, to date: Date, in run: PlanRun) -> Bool {
        guard canEditSchedule(progress, in: run) else { return false }
        progress.scheduledDate = Calendar.current.startOfDay(for: date)
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

        let editable = run.orderedWorkoutProgress.filter {
            canEditSchedule($0, in: run)
                && ($0.scheduledDate.map { calendar.startOfDay(for: $0) >= originalDay } ?? false)
        }
        for item in editable {
            guard let scheduledDate = item.scheduledDate,
                  let shifted = calendar.date(byAdding: .day, value: dayDelta, to: scheduledDate)
            else { continue }
            item.scheduledDate = calendar.startOfDay(for: shifted)
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

    static func resume(_ run: PlanRun) {
        guard run.status == .paused else { return }
        run.status = .active
        refreshAvailability(for: run)
    }

    @discardableResult
    static func resume(_ run: PlanRun, using modelContext: ModelContext) -> Bool {
        resume(run)
        return saveAndNotify(using: modelContext)
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

    private static func copiedExercises(from template: WorkoutTemplate) -> [PlannedExercise] {
        template.orderedTemplateExercises.enumerated().map { index, templateExercise in
            PlannedExercise(
                exercise: templateExercise.exercise,
                orderIndex: index,
                targetSets: templateExercise.targetSets,
                repRangeMinimum: templateExercise.repRangeMinimum,
                repRangeMaximum: templateExercise.repRangeMaximum,
                restSeconds: templateExercise.restSeconds,
                targetRPE: templateExercise.targetRPE,
                targetRIR: templateExercise.targetRIR,
                notes: templateExercise.notes,
                progressionRule: templateExercise.progressionRule
            )
        }
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
