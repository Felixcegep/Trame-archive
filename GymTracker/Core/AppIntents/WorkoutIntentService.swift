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

        let activeRun = (try? modelContext.fetch(FetchDescriptor<PlanRun>()))?
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first

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
        (try? modelContext.fetch(FetchDescriptor<Workout>()))?
            .filter { $0.status == .active }
            .sorted { $0.startTime > $1.startTime }
            .first
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
