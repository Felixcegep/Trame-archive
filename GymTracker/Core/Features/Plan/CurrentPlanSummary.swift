import Foundation

/// What Train says about the plan you are following, resolved from runs alone.
///
/// The Train tab used to have no answer to "what am I following?" — the only
/// way to see or stop a plan was to remember it lived behind My Plans. This
/// type is that answer, kept free of SwiftUI so the state machine can be tested
/// directly.
struct CurrentPlanSummary: Equatable {
    enum Kind: Equatable {
        /// A fixed-length plan is running.
        case followingFixed
        /// A repeating rotation is running.
        case followingRepeating
        /// A run exists but is paused.
        case pausedFixed
        case pausedRepeating
        /// More than one run is open, so no single plan can be named.
        case ambiguous
        /// Nothing is running.
        case none
    }

    /// Identifies the plan behind the run, so the card can route to its detail
    /// screen without the view reaching back into the run.
    struct Target: Equatable {
        let planID: UUID
        let isRepeating: Bool
    }

    let kind: Kind
    let title: String
    let detail: String
    let target: Target?
    /// `nil` for rotations, which have no end to measure against.
    let completedWorkouts: Int?
    let totalWorkouts: Int?

    var isPaused: Bool {
        kind == .pausedFixed || kind == .pausedRepeating
    }

    var isFollowing: Bool {
        kind == .followingFixed || kind == .followingRepeating
    }

    var progressFraction: Double? {
        guard let completedWorkouts, let totalWorkouts, totalWorkouts > 0 else { return nil }
        return Double(completedWorkouts) / Double(totalWorkouts)
    }

    /// `testDayAvailable` counts as open: `PlanDetailView` already treats it as
    /// a live run, and leaving it out made Train claim no plan while the
    /// Training Calendar still listed that plan's scheduled sessions.
    static func isOpen(_ run: PlanRun) -> Bool {
        run.status == .active || run.status == .paused || run.status == .testDayAvailable
    }

    static func resolve(
        planRuns: [PlanRun],
        repeatingPlanRuns: [RepeatingPlanRun]
    ) -> CurrentPlanSummary {
        let activeFixed = planRuns.filter { $0.status == .active }
        let activeRepeating = repeatingPlanRuns.filter { $0.status == .active }
        let activeCount = activeFixed.count + activeRepeating.count

        // Pausing the previous source is how a guided-source switch preserves
        // its history. A single active source therefore wins over any number
        // of paused runs; treating active + paused as ambiguous made a
        // successful switch look like two plans were still running.
        if activeCount == 1 {
            if let run = activeFixed.first { return resolve(fixed: run) }
            if let run = activeRepeating.first { return resolve(repeating: run) }
        }

        guard activeCount == 0 else {
            return ambiguousSummary
        }

        let openFixed = planRuns.filter { isOpen($0) }
        let openRepeating = repeatingPlanRuns.filter { $0.status == .active || $0.status == .paused }

        guard openFixed.count + openRepeating.count <= 1 else {
            return ambiguousSummary
        }

        if let run = openFixed.first { return resolve(fixed: run) }
        if let run = openRepeating.first { return resolve(repeating: run) }

        return .init(
            kind: .none,
            title: String(localized: "No plan yet"),
            detail: String(localized: "Follow a plan and Today will tell you what to train."),
            target: nil,
            completedWorkouts: nil,
            totalWorkouts: nil
        )
    }

    private static var ambiguousSummary: CurrentPlanSummary {
        .init(
            kind: .ambiguous,
            title: String(localized: "More than one plan is running"),
            detail: String(localized: "Open Plans to stop the ones you are not following."),
            target: nil,
            completedWorkouts: nil,
            totalWorkouts: nil
        )
    }

    private static func resolve(fixed run: PlanRun) -> CurrentPlanSummary {
        let progress = run.orderedWorkoutProgress
        let completed = progress.filter { $0.status == .completed }.count
        let total = progress.count
        let weekCount = (progress.map(\.weekIndex).max() ?? 0) + 1
        let week = String(localized: "Week \(run.currentWeekIndex + 1) of \(weekCount)")

        if run.status == .paused {
            return .init(
                kind: .pausedFixed,
                title: run.sourcePlanName,
                detail: String(localized: "Paused · \(week)"),
                target: .init(planID: run.sourcePlanID, isRepeating: false),
                completedWorkouts: completed,
                totalWorkouts: total
            )
        }

        let next = PlanCoordinator.nextProgress(in: run)
        let detail = next.map { String(localized: "\(week) · Next: \($0.plannedWorkoutName)") }
            ?? week

        return .init(
            kind: .followingFixed,
            title: run.sourcePlanName,
            detail: detail,
            target: .init(planID: run.sourcePlanID, isRepeating: false),
            completedWorkouts: completed,
            totalWorkouts: total
        )
    }

    private static func resolve(repeating run: RepeatingPlanRun) -> CurrentPlanSummary {
        let slots = run.orderedSlots
        let cycle = String(localized: "Cycle \(run.completedCycleCount + 1)")

        if run.status == .paused {
            return .init(
                kind: .pausedRepeating,
                title: run.sourcePlanName,
                detail: String(localized: "Paused · \(cycle)"),
                target: .init(planID: run.sourcePlanID, isRepeating: true),
                completedWorkouts: nil,
                totalWorkouts: nil
            )
        }

        let nextName = slots.indices.contains(run.currentSlotIndex)
            ? slots[run.currentSlotIndex].workoutTemplate?.name
            : nil
        let detail = nextName.map { String(localized: "\(cycle) · Next: \($0)") } ?? cycle

        return .init(
            kind: .followingRepeating,
            title: run.sourcePlanName,
            detail: detail,
            target: .init(planID: run.sourcePlanID, isRepeating: true),
            completedWorkouts: nil,
            totalWorkouts: nil
        )
    }
}
