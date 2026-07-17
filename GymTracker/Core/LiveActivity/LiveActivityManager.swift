import ActivityKit
import Foundation

/// Owns the one system Live Activity that represents GymTracker's one active
/// workout. Every operation is idempotent so foregrounding and relaunch can
/// safely reconcile persisted workout truth with ActivityKit state.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<GymTrackerAttributes>?

    private init() {}

    func startWorkout(_ projection: LiveActivityProjection) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let matching = Activity<GymTrackerAttributes>.activities.first(where: {
            $0.attributes.workoutID == projection.workoutID
        }) {
            activity = matching
            endActivities(except: matching.id)
            return
        }

        endActivities(except: nil)
        let attributes = GymTrackerAttributes(workoutID: projection.workoutID, startTime: projection.startTime)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState(for: projection), staleDate: projection.restEndDate)
            )
        } catch {
            activity = nil
        }
    }

    func reconcile(_ projection: LiveActivityProjection) async {
        startWorkout(projection)
        await update(projection)
    }

    func end() async {
        let activities = Activity<GymTrackerAttributes>.activities
        for item in activities {
            await item.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    func endOrphanedActivities() async {
        await end()
    }

    private func update(_ projection: LiveActivityProjection) async {
        guard let activity else { return }
        await activity.update(
            ActivityContent(
                state: contentState(for: projection),
                staleDate: projection.restEndDate
            )
        )
    }

    private func contentState(for projection: LiveActivityProjection) -> GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: projection.currentExerciseName,
            currentSet: projection.currentSet,
            totalSeries: projection.totalSets,
            currentExerciseOrderIndex: projection.currentExerciseOrderIndex,
            currentSetOrderIndex: projection.currentSetOrderIndex,
            restPhase: projection.restPhase,
            restEndDate: projection.restEndDate,
            pausedRemainingTime: projection.pausedRemainingTime
        )
    }

    private func endActivities(except keptID: String?) {
        let stale = Activity<GymTrackerAttributes>.activities.filter { $0.id != keptID }
        guard !stale.isEmpty else { return }
        Task {
            for item in stale {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
