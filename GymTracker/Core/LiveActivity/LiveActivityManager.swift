import ActivityKit
import Foundation

/// Owns the one system Live Activity that represents GymTracker's one active
/// workout. Every operation is idempotent so foregrounding and relaunch can
/// safely reconcile persisted workout truth with ActivityKit state.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<GymTrackerAttributes>?
    private var workoutID: UUID?
    private var currentExerciseName: String?
    private var currentSet: Int?
    private var totalSets: Int?

    private init() {}

    func startWorkout(workoutID: UUID, startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let matching = Activity<GymTrackerAttributes>.activities.first(where: {
            $0.attributes.workoutID == workoutID
        }) {
            activity = matching
            self.workoutID = workoutID
            endActivities(except: matching.id)
            return
        }

        endActivities(except: nil)
        let attributes = GymTrackerAttributes(workoutID: workoutID, startTime: startTime)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState(restEndDate: nil), staleDate: nil)
            )
            self.workoutID = workoutID
        } catch {
            activity = nil
            self.workoutID = nil
        }
    }

    func reconcile(
        workoutID: UUID,
        startTime: Date,
        exerciseName: String?,
        currentSet: Int?,
        totalSets: Int?,
        restEndDate: Date?
    ) async {
        self.currentExerciseName = exerciseName
        self.currentSet = currentSet
        self.totalSets = totalSets
        startWorkout(workoutID: workoutID, startTime: startTime)
        await update(restEndDate: restEndDate)
    }

    func updateExercise(name: String, currentSet: Int, totalSets: Int) async {
        currentExerciseName = name
        self.currentSet = currentSet
        self.totalSets = totalSets
        await update(restEndDate: nil)
    }

    func startPause(timerEndDate: Date) async {
        await update(restEndDate: timerEndDate)
    }

    func pausePause() async {
        await update(restEndDate: nil)
    }

    func end() async {
        let activities = Activity<GymTrackerAttributes>.activities
        for item in activities {
            await item.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        workoutID = nil
        currentExerciseName = nil
        currentSet = nil
        totalSets = nil
    }

    func endOrphanedActivities() async {
        await end()
    }

    private func update(restEndDate: Date?) async {
        guard let activity else { return }
        let state = contentState(restEndDate: restEndDate)
        await activity.update(ActivityContent(state: state, staleDate: restEndDate))
    }

    private func contentState(restEndDate: Date?) -> GymTrackerAttributes.ContentState {
        GymTrackerAttributes.ContentState(
            currentExerciseName: currentExerciseName,
            currentSerie: currentSet,
            totalSeries: totalSets,
            restTimeActive: restEndDate != nil,
            RestTime: restEndDate
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
