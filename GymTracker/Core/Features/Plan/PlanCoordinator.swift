import Foundation
import SwiftData

enum PlanCoordinator {
    struct DayAssignment {
        let dayOffset: Int
        let template: WorkoutTemplate
    }

    static func createPlan(
        name: String,
        goal: PlanGoal,
        experienceLevel: PlanExperienceLevel,
        durationWeeks: Int,
        dayAssignments: [DayAssignment]
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

        plan.blocks = [
            PlanBlock(
                name: "Plan",
                phaseType: .accumulation,
                orderIndex: 0,
                weeks: weeks
            )
        ]
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
        let unfinished = run.orderedWorkoutProgress.filter {
            $0.status != .completed && $0.status != .skipped && $0.status != .inProgress
        }

        for progress in unfinished {
            progress.status = .upcoming
        }

        if let next = unfinished.sorted(by: isOrderedByAvailability).first {
            next.status = .available
            run.currentWeekIndex = next.weekIndex
            run.currentWorkoutIndex = next.workoutIndex
        } else if !run.orderedWorkoutProgress.contains(where: { $0.status == .inProgress }) {
            run.status = .completed
            run.endDate = .now
        }
        run.updatedAt = .now
    }

    static func plannedWorkout(for progress: PlanWorkoutProgress, in run: PlanRun) -> PlannedWorkout? {
        run.plan?.orderedWeeks
            .first(where: { $0.weekIndex == progress.weekIndex })?
            .orderedPlannedWorkouts
            .first(where: { $0.id == progress.plannedWorkoutID })
    }

    static func nextProgress(in run: PlanRun) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.status == .available || $0.status == .inProgress }
    }

    /// Moves an available or upcoming session to a new scheduled day and
    /// recomputes which session is next. Completed, skipped, and in-progress
    /// sessions are locked because they no longer represent future work.
    @discardableResult
    static func reschedule(_ progress: PlanWorkoutProgress, to date: Date, in run: PlanRun) -> Bool {
        guard progress.status == .available || progress.status == .upcoming else { return false }
        progress.scheduledDate = Calendar.current.startOfDay(for: date)
        refreshAvailability(for: run)
        return true
    }

    /// Orders sessions by scheduled date first so rescheduling can promote or
    /// demote a session; sessions sharing a date fall back to plan order.
    private static func isOrderedByAvailability(_ lhs: PlanWorkoutProgress, _ rhs: PlanWorkoutProgress) -> Bool {
        let lhsDate = lhs.scheduledDate ?? .distantFuture
        let rhsDate = rhs.scheduledDate ?? .distantFuture
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
        guard progress.status == .available || progress.status == .upcoming else { return }
        progress.status = .skipped
        progress.completedAt = .now
        refreshAvailability(for: run)
    }

    static func pause(_ run: PlanRun) {
        guard run.status == .active else { return }
        run.status = .paused
        run.updatedAt = .now
    }

    static func resume(_ run: PlanRun) {
        guard run.status == .paused else { return }
        run.status = .active
        refreshAvailability(for: run)
    }

    static func archive(_ run: PlanRun) {
        guard run.status != .completed else { return }
        run.status = .archived
        run.endDate = .now
        run.updatedAt = .now
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
}
