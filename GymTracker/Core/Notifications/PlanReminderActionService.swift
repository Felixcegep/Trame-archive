import Foundation
import SwiftData

/// Notification actions operate only on a current, run-owned occurrence. The
/// policy deliberately keeps reminder state derived from the plan run instead
/// of introducing another persisted reminder entity.
enum PlanReminderEligibility {
    static func canSchedule(_ progress: PlanWorkoutProgress, in run: PlanRun) -> Bool {
        run.status == .active
            && (progress.status == .available || progress.status == .upcoming)
            && progress.scheduledDate != nil
            && progress.completedWorkout == nil
    }

    static func isActionableToday(
        _ progress: PlanWorkoutProgress,
        in run: PlanRun,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard canSchedule(progress, in: run), let scheduledDate = progress.scheduledDate else {
            return false
        }
        return calendar.isDate(scheduledDate, inSameDayAs: now)
    }
}

@MainActor
enum PlanReminderActionService {
    static func resolve(
        _ destination: PlanNotificationDestination,
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (run: PlanRun, progress: PlanWorkoutProgress)? {
        guard let run = try? modelContext.fetch(FetchDescriptor<PlanRun>()).first(where: { $0.id == destination.runID }),
              run.sourcePlanID == destination.planID,
              let progress = run.workoutProgress.first(where: { $0.id == destination.progressID }),
              PlanReminderEligibility.isActionableToday(progress, in: run, now: now, calendar: calendar)
        else {
            return nil
        }
        return (run, progress)
    }

    /// Skip is the only action that changes persisted domain truth. It relies
    /// on PlanCoordinator's existing transaction and never touches the plan
    /// definition or a completed Workout.
    static func skipToday(
        _ destination: PlanNotificationDestination,
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let resolved = resolve(destination, using: modelContext, now: now, calendar: calendar) else {
            return false
        }
        return PlanCoordinator.skip(resolved.progress, in: resolved.run, using: modelContext)
    }
}

@MainActor
final class PlanNotificationRouter {
    static let shared = PlanNotificationRouter()

    private var pendingDestination: PlanNotificationDestination?
    private init() {}

    func submit(_ destination: PlanNotificationDestination) {
        pendingDestination = destination
        NotificationCenter.default.post(name: .planNotificationOpened, object: destination)
    }

    func consumePendingDestination() -> PlanNotificationDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }
}
