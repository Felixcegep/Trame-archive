import Foundation

/// A read-only projection for Today. It derives from existing workout and plan
/// truth and is deliberately not persisted as a second daily-plan graph.
struct TodayWorkoutSummary {
    enum Kind: Equatable {
        case active
        case planned
        case repeating
        case guidedConflict
        case unavailable
        case free
    }

    let kind: Kind
    let title: String
    let subtitle: String

    /// Whether the primary card already owns the screen's forward workout
    /// action. The week card uses this instead of duplicating start/resume.
    var offersStartAction: Bool {
        switch kind {
        case .active, .planned, .repeating, .free:
            true
        case .guidedConflict, .unavailable:
            false
        }
    }

    static func resolve(
        activeWorkout: Workout?,
        activePlanRun: PlanRun?,
        nextPlanProgress: PlanWorkoutProgress?,
        calendar: Calendar = .current
    ) -> TodayWorkoutSummary {
        if let workout = activeWorkout {
            return resolve(
                activeWorkout: workout,
                planRuns: activePlanRun.map { [$0] } ?? [],
                repeatingPlanRuns: [],
                calendar: calendar
            )
        }
        if let activePlanRun, let nextPlanProgress {
            let timing = nextPlanProgress.scheduledDate.map {
                calendar.isDateInToday($0) ? "Today" : "Start when you are ready"
            } ?? "Start when you are ready"
            return .init(
                kind: .planned,
                title: nextPlanProgress.plannedWorkoutName,
                subtitle: "\(activePlanRun.sourcePlanName) · Week \(nextPlanProgress.weekIndex + 1) · \(timing)"
            )
        }
        return resolve(
            activeWorkout: nil,
            planRuns: activePlanRun.map { [$0] } ?? [],
            repeatingPlanRuns: [],
            calendar: calendar
        )
    }

    static func resolve(
        activeWorkout: Workout?,
        planRuns: [PlanRun],
        repeatingPlanRuns: [RepeatingPlanRun],
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

        let activeFixedRuns = planRuns
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        let activeRepeatingRuns = repeatingPlanRuns
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        let guidedSourceCount = activeFixedRuns.count + activeRepeatingRuns.count

        guard guidedSourceCount <= 1 else {
            return .init(
                kind: .guidedConflict,
                title: String(localized: "Choose what to follow"),
                subtitle: String(localized: "More than one guided training source is active.")
            )
        }

        if let activePlanRun = activeFixedRuns.first,
           let nextPlanProgress = PlanCoordinator.nextProgress(in: activePlanRun) {
            let timing = nextPlanProgress.scheduledDate.map { calendar.isDateInToday($0) ? "Today" : "Start when you are ready" }
                ?? "Start when you are ready"
            return .init(
                kind: .planned,
                title: nextPlanProgress.plannedWorkoutName,
                subtitle: "\(activePlanRun.sourcePlanName) · Week \(nextPlanProgress.weekIndex + 1) · \(timing)"
            )
        }

        if let repeatingRun = activeRepeatingRuns.first {
            do {
                let next = try RepeatingPlanCoordinator.nextWorkout(in: repeatingRun)
                return .init(
                    kind: .repeating,
                    title: next.slot.templateNameSnapshot,
                    subtitle: String(
                        localized: "\(repeatingRun.sourcePlanName) · Cycle \(next.cycleIndex + 1) · Workout \(next.slotIndex + 1) of \(next.slotCount)"
                    )
                )
            } catch {
                let fallbackTitle = repeatingRun.orderedSlots.indices.contains(repeatingRun.currentSlotIndex)
                    ? repeatingRun.orderedSlots[repeatingRun.currentSlotIndex].templateNameSnapshot
                    : String(localized: "Rotation unavailable")
                return .init(
                    kind: .unavailable,
                    title: fallbackTitle,
                    subtitle: String(localized: "This rotation needs a workout restored in Train.")
                )
            }
        }

        if let activePlanRun = activeFixedRuns.first {
            return .init(
                kind: .unavailable,
                title: activePlanRun.sourcePlanName,
                subtitle: "No workout is currently available in this plan."
            )
        }

        return .init(kind: .free, title: "Free Workout", subtitle: "Jump in and add exercises as you go.")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
