import Foundation
import SwiftData

/// Deterministic, persisted data graphs used exclusively by screenshot and
/// state-focused UI tests. Journey tests deliberately do not use these
/// fixtures: they exercise the user actions that create the graph.
enum UITestFixture: String {
    case activeEmpty = "active-empty"
    case activeInProgress = "active-in-progress"
    case activeCompletedSet = "active-completed-set"
    case activeCompletedExercise = "active-completed-exercise"
    case activePartialSave = "active-partial-save"
    case activeRestRunning = "active-rest-running"
    case activeRestPaused = "active-rest-paused"
    case activeRestReady = "active-rest-ready"
    case historyBench = "history-bench"
    case exerciseInsights = "exercise-insights"
    case muscleBalance = "muscle-balance"
    case progressionIncrease = "progression-increase"
    case progressionHold = "progression-hold"
    case progressionInsufficientHistory = "progression-insufficient-history"
    case progressionRestRunning = "progression-rest-running"
    case progressionRestPaused = "progression-rest-paused"
    case performanceComparison = "performance-comparison"
    case homeActiveConflict = "home-active-conflict"
    case planActiveRun = "plan-active-run"
    case planPartialSave = "plan-partial-save"
    case backupImportTarget = "backup-import-target"

    static var launchFixture: UITestFixture? {
        guard
            let index = CommandLine.arguments.firstIndex(of: "-ui-test-fixture"),
            CommandLine.arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return UITestFixture(rawValue: CommandLine.arguments[index + 1])
    }

    var opensActiveWorkout: Bool {
        switch self {
        case .historyBench, .exerciseInsights, .muscleBalance, .homeActiveConflict, .planActiveRun, .backupImportTarget:
            false
        default:
            true
        }
    }

    var showsActiveWorkoutConflict: Bool {
        self == .homeActiveConflict
    }

    static func apply(_ fixture: UITestFixture, using context: ModelContext) throws {
        switch fixture {
        case .activeEmpty:
            try makeActiveWorkout(exercises: [], using: context)
        case .activeInProgress:
            try makeActiveWorkout(exercises: [inProgressEntry(named: "Bench Press", using: context)], using: context)
        case .activeCompletedSet:
            try makeActiveWorkout(exercises: [completedSetEntry(named: "Bench Press", using: context)], using: context)
        case .activeCompletedExercise:
            let bench = try completedExerciseEntry(named: "Bench Press", orderIndex: 0, using: context)
            let row = try inProgressEntry(named: "Barbell Row", orderIndex: 1, using: context)
            try makeActiveWorkout(exercises: [bench, row], using: context)
        case .activePartialSave:
            try makeActiveWorkout(exercises: [completedSetEntry(named: "Bench Press", using: context)], using: context)
        case .activeRestRunning:
            try makeRestWorkout(state: .running, using: context)
        case .activeRestPaused:
            try makeRestWorkout(state: .paused, using: context)
        case .activeRestReady:
            try makeRestWorkout(state: .ready, using: context)
        case .historyBench:
            try makeCompletedBenchHistory(using: context)
        case .exerciseInsights:
            try makeExerciseInsightsHistory(using: context)
        case .muscleBalance:
            try makeMuscleBalanceHistory(using: context)
        case .progressionIncrease:
            try makeProgressionWorkout(decision: .increase, using: context)
        case .progressionHold:
            try makeProgressionWorkout(decision: .hold, using: context)
        case .progressionInsufficientHistory:
            try makeProgressionWorkout(decision: nil, using: context)
        case .progressionRestRunning:
            try makeProgressionAndRestWorkout(restState: .running, using: context)
        case .progressionRestPaused:
            try makeProgressionAndRestWorkout(restState: .paused, using: context)
        case .performanceComparison:
            try makePerformanceComparisonWorkout(using: context)
        case .homeActiveConflict:
            try makeActiveWorkout(exercises: [inProgressEntry(named: "Bench Press", using: context)], using: context)
        case .planActiveRun:
            try makeActivePlanRun(using: context)
        case .planPartialSave:
            try makePartialPlannedWorkout(using: context)
        case .backupImportTarget:
            try makeBackupImportTarget(using: context)
        }
    }

    @MainActor
    enum UITestImportPayload {
        static var validData: Data?
    }

    private enum RestState {
        case running
        case paused
        case ready
    }

    private static func makeActiveWorkout(
        exercises: [ExerciseEntry],
        using context: ModelContext
    ) throws {
        let workout = Workout(name: "Today’s workout")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = exercises
        context.insert(workout)
        try context.save()
    }

    private static func makeRestWorkout(
        state: RestState,
        using context: ModelContext
    ) throws {
        let entry = try completedSetEntry(named: "Bench Press", using: context)
        let workout = Workout(name: "Today’s workout")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = [entry]

        switch state {
        case .running:
            workout.restEndDate = Date.now.addingTimeInterval(45)
        case .paused:
            workout.pausedRemainingTime = 45
        case .ready:
            // Restoring an expired persisted end date intentionally enters the
            // visible ready state instead of silently removing the card.
            workout.restEndDate = Date.now.addingTimeInterval(-1)
        }

        context.insert(workout)
        try context.save()
    }

    private static func makeCompletedBenchHistory(using context: ModelContext) throws {
        let entry = try completedExerciseEntry(named: "Bench Press", using: context)
        let workout = Workout(name: "Upper Body", endTime: Date.now.addingTimeInterval(-3_600))
        workout.startTime = Date.now.addingTimeInterval(-7_200)
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
    }

    private static func makeExerciseInsightsHistory(using context: ModelContext) throws {
        let olderDate = Date.now.addingTimeInterval(-14 * 86_400)
        let recentDate = Date.now.addingTimeInterval(-3 * 86_400)

        let olderEntry = try completedExerciseEntry(named: "Bench Press", using: context)
        olderEntry.comment = "Paused the last rep and kept the bar path steady."
        for (index, set) in olderEntry.orderedSets.enumerated() {
            set.weight = 45
            set.repetitions = Float(8 + min(index, 1))
        }
        let olderWorkout = Workout(name: "Older Bench Session", endTime: olderDate.addingTimeInterval(3_600))
        olderWorkout.startTime = olderDate
        olderWorkout.exercises = [olderEntry]

        let recentEntry = try completedExerciseEntry(named: "Bench Press", using: context)
        recentEntry.comment = "Add a small amount next time if all sets reach 10 reps."
        for (index, set) in recentEntry.orderedSets.enumerated() {
            set.weight = 50
            set.repetitions = Float(8 - min(index, 1))
        }
        let recentWorkout = Workout(name: "Recent Bench Session", endTime: recentDate.addingTimeInterval(3_600))
        recentWorkout.startTime = recentDate
        recentWorkout.exercises = [recentEntry]

        context.insert(olderWorkout)
        context.insert(recentWorkout)
        try context.save()
    }

    private static func makeMuscleBalanceHistory(using context: ModelContext) throws {
        let olderWorkout = Workout(name: "Lower Balance", endTime: Date.now.addingTimeInterval(-70 * 86_400))
        olderWorkout.startTime = Date.now.addingTimeInterval(-71 * 86_400)
        olderWorkout.exercises = [
            try completedExerciseEntry(named: "Deadlift", using: context),
            try completedExerciseEntry(named: "Bench Press", using: context)
        ]

        let previousWorkout = Workout(name: "Lower Balance", endTime: Date.now.addingTimeInterval(-63 * 86_400))
        previousWorkout.startTime = Date.now.addingTimeInterval(-64 * 86_400)
        previousWorkout.exercises = [try completedExerciseEntry(named: "Deadlift", using: context)]

        let recentWorkout = Workout(name: "Upper Balance", endTime: Date.now.addingTimeInterval(-14 * 86_400))
        recentWorkout.startTime = Date.now.addingTimeInterval(-15 * 86_400)
        recentWorkout.exercises = [
            try completedExerciseEntry(named: "Bench Press", using: context),
            try completedExerciseEntry(named: "Back Squat", using: context)
        ]

        let latestWorkout = Workout(name: "Upper Balance", endTime: Date.now.addingTimeInterval(-3 * 86_400))
        latestWorkout.startTime = Date.now.addingTimeInterval(-4 * 86_400)
        latestWorkout.exercises = [try completedExerciseEntry(named: "Bench Press", using: context)]

        context.insert(olderWorkout)
        context.insert(previousWorkout)
        context.insert(recentWorkout)
        context.insert(latestWorkout)
        try context.save()
    }

    private static func makeProgressionWorkout(
        decision: DoubleProgressionDecision?,
        using context: ModelContext
    ) throws {
        try makeCompletedBenchHistory(using: context)
        let entry = try progressionEntry(named: "Bench Press", decision: decision, orderIndex: 0, using: context)
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeProgressionAndRestWorkout(
        restState: RestState,
        using context: ModelContext
    ) throws {
        try makeCompletedBenchHistory(using: context)
        let completed = try completedSetEntry(named: "Barbell Row", orderIndex: 0, using: context)
        let recommended = try progressionEntry(named: "Bench Press", decision: .increase, orderIndex: 1, using: context)
        let workout = Workout(name: "Upper Body Progression")
        workout.startTime = Date.now.addingTimeInterval(-47)
        workout.exercises = [completed, recommended]

        switch restState {
        case .running:
            workout.restEndDate = Date.now.addingTimeInterval(45)
        case .paused:
            workout.pausedRemainingTime = 45
        case .ready:
            workout.restEndDate = Date.now.addingTimeInterval(-1)
        }

        context.insert(workout)
        try context.save()
    }

    private static func makePerformanceComparisonWorkout(using context: ModelContext) throws {
        try makeCompletedBenchHistory(using: context)
        let entry = try progressionEntry(named: "Bench Press", decision: .increase, orderIndex: 0, using: context)
        for set in entry.orderedSets {
            set.done = true
            set.repetitions = 8
            set.weight = 52.5
        }
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeActivePlanRun(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Screenshot Plan Run",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0]
        )
        context.insert(plan)
        guard let run = PlanCoordinator.startRun(for: plan) else {
            throw FixtureError.invalidPlan
        }
        context.insert(run)
        try context.save()
    }

    private static func makePartialPlannedWorkout(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Day 1 – Lower Body (Squat Focus)", using: context)
        let plan = PlanCoordinator.createRepeatedPlan(
            name: "Integration Fixture Plan",
            goal: .generalStrength,
            experienceLevel: .beginner,
            durationWeeks: 1,
            template: template,
            dayOffsets: [0, 2]
        )

        // Give the two sessions stable, distinguishable titles for UI assertions.
        let plannedWorkouts = plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts)
        plannedWorkouts.first?.name = "Fixture Day 1"
        plannedWorkouts.dropFirst().first?.name = "Fixture Day 2"

        context.insert(plan)
        guard
            let run = PlanCoordinator.startRun(for: plan),
            let progress = run.orderedWorkoutProgress.first,
            let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: run)
        else {
            throw FixtureError.invalidPlan
        }

        let workout = Workout(plannedWorkout: plannedWorkout, planRun: run, unitSystem: .metric)
        workout.startTime = Date.now.addingTimeInterval(-47)
        progress.status = .inProgress
        progress.startedAt = workout.startTime

        // One completed set is enough for a valid partial save. All remaining
        // sets and exercises stay incomplete so the Review warning and pruning
        // behavior are exercised in one deterministic journey.
        if let firstExercise = workout.orderedExercises.first,
           let firstSet = firstExercise.orderedSets.first {
            firstSet.repetitions = 8
            firstSet.weight = 50
            firstSet.done = true
        }

        context.insert(run)
        context.insert(workout)
        try context.save()
    }

    private static func makeBackupImportTarget(using context: ModelContext) throws {
        let exercise = Exercise(
            name: "Sentinel Exercise",
            primaryMuscles: [.upperChest],
            equipmentType: .dumbbell,
            resistanceType: .externalWeight,
            movementPattern: .horizontalPush,
            isCustom: true
        )
        context.insert(exercise)

        let entry = ExerciseEntry(from: exercise, orderIndex: 0, usedMetric: .metric)
        if let set = entry.orderedSets.first {
            set.repetitions = 8
            set.weight = 25
            set.done = true
        }
        let workout = Workout(name: "Sentinel Workout", endTime: Date.now.addingTimeInterval(-300))
        workout.startTime = Date.now.addingTimeInterval(-900)
        workout.exercises = [entry]
        context.insert(workout)
        try context.save()
    }

    private static func inProgressEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = ExerciseEntry(from: try exercise(named: name, using: context), orderIndex: orderIndex, usedMetric: .metric)
        for set in entry.orderedSets {
            set.repetitions = 8
            set.weight = 50
            set.weightType = .kg
        }
        return entry
    }

    private static func completedSetEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        if let first = entry.orderedSets.first {
            first.done = true
            first.rpe = 8
        }
        return entry
    }

    private static func completedExerciseEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        for set in entry.orderedSets {
            set.done = true
            set.rpe = 8
        }
        return entry
    }

    private static func progressionEntry(
        named name: String,
        decision: DoubleProgressionDecision?,
        orderIndex: Int,
        using context: ModelContext
    ) throws -> ExerciseEntry {
        let entry = try inProgressEntry(named: name, orderIndex: orderIndex, using: context)
        entry.prescribedSets = 3
        entry.prescribedRepRangeMinimum = 6
        entry.prescribedRepRangeMaximum = 8
        entry.prescribedProgressionRule = .doubleProgression

        if let decision {
            entry.recommendedDecision = decision
            entry.recommendedLoad = decision == .increase ? 52.5 : 50
            entry.recommendedUnit = .kg
            entry.recommendationPriorLoad = 50
            entry.recommendationRequiredSets = 3
            entry.recommendationRepCeiling = 8
            entry.recommendationCompletedSets = decision == .increase ? 3 : 2
            entry.recommendationPriorWorkoutDate = Date.now.addingTimeInterval(-86_400)
        }
        return entry
    }

    private static func exercise(named name: String, using context: ModelContext) throws -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        guard let exercise = try context.fetch(descriptor).first else {
            throw FixtureError.missingSeededExercise(name)
        }
        return exercise
    }

    private static func workoutTemplate(named name: String, using context: ModelContext) throws -> WorkoutTemplate {
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == name })
        guard let template = try context.fetch(descriptor).first else {
            throw FixtureError.missingSeededWorkoutTemplate(name)
        }
        return template
    }

    private enum FixtureError: LocalizedError {
        case missingSeededExercise(String)
        case missingSeededWorkoutTemplate(String)
        case invalidPlan

        var errorDescription: String? {
            switch self {
            case let .missingSeededExercise(name):
                return "UI-test fixture requires seeded exercise: \(name)"
            case let .missingSeededWorkoutTemplate(name):
                return "UI-test fixture requires seeded workout template: \(name)"
            case .invalidPlan:
                return "UI-test fixture could not start its seeded plan run."
            }
        }
    }
}
