import Foundation

/// Which run a plan screen is currently talking about.
///
/// Lifted out of `PlanDetailView` when the plan screen gained segments. The
/// segmented shell has to know the run in order to build the Path and Review
/// segments, and the detail view has to know it in order to draw the rest of
/// the screen — two copies of "which run is current" is how one of them ends
/// up describing a different run than the tab beside it.
///
/// Pure and store-free, so the precedence can be asserted without building a
/// SwiftData graph.
enum PlanRunResolver {
    /// Active, else paused, else the one waiting on a test day.
    ///
    /// A status with more than one run in it resolves to `nil` rather than
    /// picking arbitrarily — an ambiguous plan is a state the screen reports,
    /// not one it guesses its way through (`PlanDetailView`
    /// `hasAmbiguousCurrentRuns`).
    static func currentRun(for plan: WorkoutPlan) -> PlanRun? {
        let currentRuns = plan.runs.filter {
            $0.status == .active || $0.status == .paused || $0.status == .testDayAvailable
        }
        guard currentRuns.count <= 1 else { return nil }
        return singularRun(in: plan, with: .active)
            ?? singularRun(in: plan, with: .paused)
            ?? singularRun(in: plan, with: .testDayAvailable)
    }

    static func singularRun(in plan: WorkoutPlan, with status: PlanRunStatus) -> PlanRun? {
        let runs = plan.runs.filter { $0.status == status }
        return runs.count == 1 ? runs[0] : nil
    }
}
