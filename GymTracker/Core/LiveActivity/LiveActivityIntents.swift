import AppIntents
import SwiftData

/// Interactive Live Activity actions execute in GymTracker's app process. They
/// use persisted identifiers and reject stale state, so repeated taps can never
/// complete a later set by accident.
struct CompleteCurrentSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete current set"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Workout ID") var workoutID: String
    @Parameter(title: "Exercise order") var expectedExerciseOrderIndex: Int
    @Parameter(title: "Set order") var expectedSetOrderIndex: Int

    init() {}

    init(workoutID: UUID, expectedExerciseOrderIndex: Int, expectedSetOrderIndex: Int) {
        self.workoutID = workoutID.uuidString
        self.expectedExerciseOrderIndex = expectedExerciseOrderIndex
        self.expectedSetOrderIndex = expectedSetOrderIndex
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let workoutID = UUID(uuidString: workoutID) else {
            return .result()
        }

        let context = ModelContext(GymTrackerModelContainer.shared)
        let result = ActiveWorkoutMutationService(modelContext: context).completeCurrentSet(
            workoutID: workoutID,
            expectedExerciseOrderIndex: expectedExerciseOrderIndex,
            expectedSetOrderIndex: expectedSetOrderIndex
        )
        await LiveActivityIntentCoordinator.reconcile(result)
        return .result()
    }
}

struct PauseRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause rest"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Workout ID") var workoutID: String

    init() {}

    init(workoutID: UUID) {
        self.workoutID = workoutID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let workoutID = UUID(uuidString: workoutID) else { return .result() }
        let context = ModelContext(GymTrackerModelContainer.shared)
        let result = ActiveWorkoutMutationService(modelContext: context).pauseRest(workoutID: workoutID)
        await LiveActivityIntentCoordinator.reconcile(result)
        return .result()
    }
}

struct ResumeRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume rest"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Workout ID") var workoutID: String

    init() {}

    init(workoutID: UUID) {
        self.workoutID = workoutID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let workoutID = UUID(uuidString: workoutID) else { return .result() }
        let context = ModelContext(GymTrackerModelContainer.shared)
        let result = ActiveWorkoutMutationService(modelContext: context).resumeRest(workoutID: workoutID)
        await LiveActivityIntentCoordinator.reconcile(result)
        return .result()
    }
}

struct ExtendRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Extend rest"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Workout ID") var workoutID: String
    @Parameter(title: "Seconds") var seconds: Int

    init() {}

    init(workoutID: UUID, seconds: Int) {
        self.workoutID = workoutID.uuidString
        self.seconds = seconds
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let workoutID = UUID(uuidString: workoutID) else { return .result() }
        let context = ModelContext(GymTrackerModelContainer.shared)
        let result = ActiveWorkoutMutationService(modelContext: context)
            .extendRest(workoutID: workoutID, by: TimeInterval(seconds))
        await LiveActivityIntentCoordinator.reconcile(result)
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip rest"
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Workout ID") var workoutID: String

    init() {}

    init(workoutID: UUID) {
        self.workoutID = workoutID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let workoutID = UUID(uuidString: workoutID) else { return .result() }
        let context = ModelContext(GymTrackerModelContainer.shared)
        let result = ActiveWorkoutMutationService(modelContext: context).skipRest(workoutID: workoutID)
        await LiveActivityIntentCoordinator.reconcile(result)
        return .result()
    }
}

@MainActor
private enum LiveActivityIntentCoordinator {
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
