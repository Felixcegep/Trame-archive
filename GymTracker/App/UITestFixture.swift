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
    case progressionIncrease = "progression-increase"
    case progressionHold = "progression-hold"
    case progressionInsufficientHistory = "progression-insufficient-history"
    case progressionRestRunning = "progression-rest-running"
    case progressionRestPaused = "progression-rest-paused"
    case performanceComparison = "performance-comparison"
    case homeActiveConflict = "home-active-conflict"
    case planActiveRun = "plan-active-run"

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
        case .historyBench, .homeActiveConflict, .planActiveRun:
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
        }
    }

    private enum RestState {
        case running
        case paused
        case ready
    }

    private static func makeActiveWorkout(
        exercises: [ExerciceEntry],
        using context: ModelContext
    ) throws {
        let workout = Workout(nom: "Today’s workout")
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
        let workout = Workout(nom: "Today’s workout")
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
        let workout = Workout(nom: "Upper Body", endTime: Date.now.addingTimeInterval(-3_600))
        workout.startTime = Date.now.addingTimeInterval(-7_200)
        workout.exercises = [entry]
        context.insert(workout)
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
        let workout = Workout(nom: "Upper Body Progression")
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
            set.repetition = 8
            set.weight = 52.5
        }
        try makeActiveWorkout(exercises: [entry], using: context)
    }

    private static func makeActivePlanRun(using context: ModelContext) throws {
        let template = try workoutTemplate(named: "Jour 1 - Bas du Corps (Squat/Genoux)", using: context)
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

    private static func inProgressEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciceEntry {
        let entry = ExerciceEntry(from: try exercise(named: name, using: context), orderIndex: orderIndex, usedMetric: .metric)
        for set in entry.orderedSets {
            set.repetition = 8
            set.weight = 50
            set.weightType = .kg
        }
        return entry
    }

    private static func completedSetEntry(
        named name: String,
        orderIndex: Int = 0,
        using context: ModelContext
    ) throws -> ExerciceEntry {
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
    ) throws -> ExerciceEntry {
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
    ) throws -> ExerciceEntry {
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

    private static func exercise(named name: String, using context: ModelContext) throws -> ExerciceTemplate {
        let descriptor = FetchDescriptor<ExerciceTemplate>(predicate: #Predicate { $0.name == name })
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
