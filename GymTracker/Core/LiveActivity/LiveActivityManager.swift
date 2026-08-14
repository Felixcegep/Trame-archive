import ActivityKit
import Foundation

/// Owns the one system Live Activity that represents GymTracker's one active
/// workout. Every operation is idempotent so foregrounding and relaunch can
/// safely reconcile persisted workout truth with ActivityKit state.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// ActivityKit's `Activity` reference is not Sendable in Swift 6. Keep
    /// only stable value identity on the main actor; async helpers reacquire
    /// the system object and consume it within one nonisolated operation.
    private var activityID: String?

    private init() {}

    func startWorkout(_ projection: LiveActivityProjection) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let matching = Activity<GymTrackerAttributes>.activities.first(where: {
            $0.attributes.workoutID == projection.workoutID
        }) {
            activityID = matching.id
            endCurrentActivities(except: matching.id)
            return
        }

        // Snapshot stale identities before requesting the replacement. Reading
        // `Activity.activities` later inside the Task can otherwise observe and
        // immediately end the activity created below.
        endCurrentActivities(except: nil)
        let attributes = GymTrackerAttributes(workoutID: projection.workoutID, startTime: projection.startTime)
        do {
            let requested = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState(for: projection), staleDate: projection.restEndDate)
            )
            activityID = requested.id
        } catch {
            activityID = nil
        }
    }

    func reconcile(_ projection: LiveActivityProjection) async {
        startWorkout(projection)
        await update(projection)
    }

    func end() async {
        // End exactly the activities that existed when shutdown began. A new
        // workout can start while ActivityKit is suspended; enumerating after
        // that await would end the replacement and clear its identity.
        let endingActivityID = activityID
        let endingIDs = Activity<GymTrackerAttributes>.activities.map(\.id)
        await Self.endActivities(ids: endingIDs)
        if activityID == endingActivityID {
            activityID = nil
        }
    }

    func endOrphanedActivities() async {
        await end()
    }

    private func update(_ projection: LiveActivityProjection) async {
        guard let activityID else { return }
        let content = ActivityContent(
            state: contentState(for: projection),
            staleDate: projection.restEndDate
        )
        await Self.updateActivity(id: activityID, content: content)
    }

    private func contentState(for projection: LiveActivityProjection) -> GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: projection.currentExerciseName,
            currentSet: projection.currentSet,
            totalSeries: projection.totalSets,
            currentExerciseOrderIndex: projection.currentExerciseOrderIndex,
            currentSetOrderIndex: projection.currentSetOrderIndex,
            hasAnySets: projection.hasAnySets,
            restPhase: projection.restPhase,
            restEndDate: projection.restEndDate,
            pausedRemainingTime: projection.pausedRemainingTime
        )
    }

    private func endCurrentActivities(except keptID: String?) {
        let staleIDs = Activity<GymTrackerAttributes>.activities
            .map(\.id)
            .filter { $0 != keptID }
        Task {
            await Self.endActivities(ids: staleIDs)
        }
    }

    private nonisolated static func updateActivity(
        id: String,
        content: ActivityContent<GymTrackerAttributes.ContentState>
    ) async {
        guard let activity = Activity<GymTrackerAttributes>.activities.first(where: { $0.id == id }) else {
            return
        }
        await activity.update(content)
    }

    private nonisolated static func endActivities(ids: [String]) async {
        let staleIDs = Set(ids)
        for activity in Activity<GymTrackerAttributes>.activities where staleIDs.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
