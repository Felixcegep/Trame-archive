import Foundation

/// A read-only projection for Today. It derives from existing workout and plan
/// truth and is deliberately not persisted as a second daily-plan graph.
struct TodayWorkoutSummary {
    enum Kind: Equatable {
        case active
        case planned
        case free
    }

    let kind: Kind
    let title: String
    let subtitle: String

    static func resolve(
        activeWorkout: Workout?,
        activePlanRun: PlanRun?,
        nextPlanProgress: PlanWorkoutProgress?,
        calendar: Calendar = .current
    ) -> TodayWorkoutSummary {
        if let workout = activeWorkout {
            let title = workout.name?.nilIfEmpty.map { "Resume \($0)" } ?? "Resume workout"
            let subtitle: String
            if workout.totalSetCount == 0 {
                subtitle = "No exercises yet · Pick your first exercise"
            } else {
                subtitle = "\(workout.completedSetCount) / \(workout.totalSetCount) sets"
            }
            return .init(kind: .active, title: title, subtitle: subtitle)
        }

        if let activePlanRun, let nextPlanProgress {
            let timing = nextPlanProgress.scheduledDate.map { calendar.isDateInToday($0) ? "Today" : "Start when you are ready" }
                ?? "Start when you are ready"
            return .init(
                kind: .planned,
                title: nextPlanProgress.plannedWorkoutName,
                subtitle: "\(activePlanRun.sourcePlanName) · Week \(nextPlanProgress.weekIndex + 1) · \(timing)"
            )
        }

        return .init(kind: .free, title: "Free Workout", subtitle: "Jump in and add exercises as you go.")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
