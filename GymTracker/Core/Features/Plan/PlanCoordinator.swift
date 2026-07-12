import Foundation
import SwiftData

enum PlanCoordinator {
    static func createRepeatedPlan(
        name: String,
        goal: PlanGoal,
        experienceLevel: PlanExperienceLevel,
        durationWeeks: Int,
        template: WorkoutTemplate,
        dayOffsets: [Int]
    ) -> WorkoutPlan {
        let normalizedDays = Array(Set(dayOffsets.filter { (0...6).contains($0) })).sorted()
        let plan = WorkoutPlan(
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            daysPerWeek: normalizedDays.count,
            durationWeeks: durationWeeks
        )

        let weeks = (0..<durationWeeks).map { weekIndex in
            PlanWeek(
                weekIndex: weekIndex,
                plannedWorkouts: normalizedDays.enumerated().map { workoutIndex, dayOffset in
                    PlannedWorkout(
                        name: template.name,
                        orderIndex: workoutIndex,
                        dayOffset: dayOffset,
                        sourceTemplate: template,
                        plannedExercises: copiedExercises(from: template)
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

        if let next = unfinished.first {
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
                notes: templateExercise.notes
            )
        }
    }
}
