import Foundation
import SwiftData

/// Thin domain adapter used by App Intents. It deliberately delegates to the
/// same workout view-model and mutation service as the foreground app so
/// shortcut execution cannot create a second source of workout behavior.
@MainActor
enum WorkoutIntentService {
    enum StartWorkoutResult {
        case started(Workout)
        case resumed(Workout)
        case failed

        var workout: Workout? {
            switch self {
            case .started(let workout), .resumed(let workout): workout
            case .failed: nil
            }
        }
    }

    static func startFree(using modelContext: ModelContext) -> StartWorkoutResult {
        let workoutViewModel = WorkoutViewModel()
        if workoutViewModel.restoreActiveWorkout(using: modelContext),
           let workout = workoutViewModel.activeWorkout {
            return .resumed(workout)
        }
        guard workoutViewModel.startWorkout(using: modelContext),
              let workout = workoutViewModel.activeWorkout
        else {
            return .failed
        }
        return .started(workout)
    }

    static func startToday(
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Workout? {
        let workoutViewModel = WorkoutViewModel()
        if workoutViewModel.restoreActiveWorkout(using: modelContext) {
            return workoutViewModel.activeWorkout
        }

        let activeRun: PlanRun?
        do {
            activeRun = try modelContext.fetch(FetchDescriptor<PlanRun>(
                predicate: #Predicate { $0.endDate == nil }
            ))
                .filter { $0.status == .active }
                .sorted { $0.updatedAt > $1.updatedAt }
                .first
        } catch {
            return nil
        }

        if let activeRun,
           let progress = activeRun.orderedWorkoutProgress.first(where: {
               PlanReminderEligibility.isActionableToday($0, in: activeRun, now: now, calendar: calendar)
           }),
           let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: activeRun),
           workoutViewModel.startWorkout(
                from: plannedWorkout,
                progress: progress,
                in: activeRun,
                using: modelContext
           ) {
            return workoutViewModel.activeWorkout
        }

        guard workoutViewModel.startWorkout(using: modelContext) else { return nil }
        return workoutViewModel.activeWorkout
    }

    static func activeWorkout(using modelContext: ModelContext) -> Workout? {
        try? activeWorkoutRequiringStore(using: modelContext)
    }

    /// Store-sensitive callers such as widget snapshot publication must be
    /// able to distinguish "no active workout" from "the fetch failed" so
    /// they do not replace last-known-good data with an empty projection.
    static func activeWorkoutRequiringStore(using modelContext: ModelContext) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        return try modelContext.fetch(descriptor).first(where: { $0.status == .active })
    }

    static func reconcile(_ result: ActiveWorkoutMutationService.Result) async {
        switch result {
        case .applied(let projection), .invalid(let projection):
            await LiveActivityManager.shared.reconcile(projection)
        case .stale(let projection):
            if let projection {
                await LiveActivityManager.shared.reconcile(projection)
            }
        case .unavailable:
            await LiveActivityManager.shared.endOrphanedActivities()
        }
    }
}
