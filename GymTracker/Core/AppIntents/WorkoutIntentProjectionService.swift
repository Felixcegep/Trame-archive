import AppIntents
import Foundation
import SwiftData

/// Read-only projections for system surfaces. These values intentionally do
/// not mirror SwiftData models and never create or mutate workout records.
@MainActor
enum WorkoutIntentProjectionService {
    struct ExerciseSummary: Equatable {
        let name: String
        let setCount: Int
        let repSummary: String?
        let loadSummary: String?
        let isCurrent: Bool
    }

    struct TodayPlan: Equatable {
        enum State: Equatable {
            case activeWorkout
            case scheduledWorkout
            case noWorkout
        }

        let state: State
        let title: String
        let planName: String?
        let scheduledDate: Date?
        let exercises: [ExerciseSummary]
        let completedSetCount: Int
        let totalSetCount: Int
    }

    struct WeeklyVolume: Equatable {
        let weekStart: Date
        let weekEnd: Date
        let completedWorkoutCount: Int
        let workingSetCount: Int
        let loadVolume: Float?
        let unit: WeightType?
        let muscleGroupSetEstimate: Float?
        let subjectName: String?
    }

    static func todayPlan(
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TodayPlan {
        (try? todayPlanRequiringStore(using: modelContext, now: now, calendar: calendar))
            ?? emptyTodayPlan
    }

    /// Throwing projection for durable process-boundary publication. Unlike an
    /// App Intent dialog, a widget refresh must preserve the last valid value
    /// when the store cannot be read instead of publishing a truthful-looking
    /// empty state.
    static func todayPlanRequiringStore(
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> TodayPlan {
        if let workout = try WorkoutIntentService.activeWorkoutRequiringStore(using: modelContext) {
            let currentSet = WorkoutSetSelector.nextIncompleteSet(in: workout)
            let exercises = workout.orderedExercises.map { entry in
                ExerciseSummary(
                    name: entry.nameSnapshot.isEmpty ? entry.exercise.name : entry.nameSnapshot,
                    setCount: entry.orderedSets.count,
                    repSummary: entry.orderedSets.isEmpty ? nil : "\(entry.orderedSets.map { String(Int($0.repetitions)) }.joined(separator: ", ")) reps",
                    loadSummary: entry.orderedSets.isEmpty ? nil : entry.orderedSets.map { Formatters.formatFloat($0.weight) }.joined(separator: ", "),
                    isCurrent: entry === currentSet?.entry
                )
            }
            return TodayPlan(
                state: .activeWorkout,
                title: workout.name?.nilIfEmpty ?? "Active workout",
                planName: workout.sourcePlanName,
                scheduledDate: nil,
                exercises: exercises,
                completedSetCount: workout.completedSetCount,
                totalSetCount: workout.totalSetCount
            )
        }

        let activeRuns = try modelContext.fetch(FetchDescriptor<PlanRun>(
            predicate: #Predicate { $0.endDate == nil }
        ))
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }

        for run in activeRuns {
            guard let progress = run.orderedWorkoutProgress.first(where: {
                PlanReminderEligibility.isActionableToday($0, in: run, now: now, calendar: calendar)
            }), let plannedWorkout = PlanCoordinator.plannedWorkout(for: progress, in: run) else {
                continue
            }

            let exercises = plannedWorkout.orderedPlannedExercises.map { plannedExercise in
                let sets = plannedExercise.orderedPlannedSets
                let setCount = sets.isEmpty ? plannedExercise.targetSets : sets.count
                let repSummary: String?
                if let first = sets.first {
                    if let reps = first.repetitions {
                        repSummary = "\(reps) reps"
                    } else {
                        let minimum = first.repRangeMinimum ?? plannedExercise.repRangeMinimum
                        let maximum = first.repRangeMaximum ?? plannedExercise.repRangeMaximum
                        repSummary = minimum == maximum ? "\(minimum) reps" : "\(minimum)-\(maximum) reps"
                    }
                } else {
                    let minimum = plannedExercise.repRangeMinimum
                    let maximum = plannedExercise.repRangeMaximum
                    repSummary = minimum == maximum ? "\(minimum) reps" : "\(minimum)-\(maximum) reps"
                }
                let load = plannedExercise.suggestedLoad
                let loadType = plannedExercise.suggestedLoadType
                let loadSummary = load.map { value in
                    "\(Formatters.formatFloat(Float(value))) \(loadType?.rawValue ?? "")".trimmingCharacters(in: .whitespaces)
                }
                return ExerciseSummary(
                    name: plannedExercise.exercise.name,
                    setCount: setCount,
                    repSummary: repSummary,
                    loadSummary: loadSummary,
                    isCurrent: false
                )
            }

            return TodayPlan(
                state: .scheduledWorkout,
                title: plannedWorkout.name,
                planName: run.sourcePlanName,
                scheduledDate: progress.scheduledDate,
                exercises: exercises,
                completedSetCount: 0,
                totalSetCount: exercises.reduce(0) { $0 + $1.setCount }
            )
        }

        return emptyTodayPlan
    }

    static func weeklyVolume(
        using modelContext: ModelContext,
        scope: WeeklyVolumeScope = .total,
        exerciseID: UUID? = nil,
        muscleGroup: [Muscle]? = nil,
        now: Date = .now,
        calendar: Calendar = .current,
        preferredUnit: WeightType = .kg
    ) -> WeeklyVolume {
        (try? weeklyVolumeRequiringStore(
            using: modelContext,
            scope: scope,
            exerciseID: exerciseID,
            muscleGroup: muscleGroup,
            now: now,
            calendar: calendar,
            preferredUnit: preferredUnit
        )) ?? emptyWeeklyVolume(now: now, calendar: calendar)
    }

    static func weeklyVolumeRequiringStore(
        using modelContext: ModelContext,
        scope: WeeklyVolumeScope = .total,
        exerciseID: UUID? = nil,
        muscleGroup: [Muscle]? = nil,
        now: Date = .now,
        calendar: Calendar = .current,
        preferredUnit: WeightType = .kg
    ) throws -> WeeklyVolume {
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: calendar.startOfDay(for: now), duration: 7 * 24 * 60 * 60)
        let intervalStart = interval.start
        let intervalEnd = interval.end
        let workoutDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.startTime >= intervalStart && workout.startTime < intervalEnd
            }
        )
        let workouts = try modelContext.fetch(workoutDescriptor).filter { $0.status == .completed }
        let filteredEntries = workouts.flatMap { workout in
            workout.orderedExercises.compactMap { entry -> (Workout, ExerciseEntry)? in
                switch scope {
                case .total:
                    return (workout, entry)
                case .exercise:
                    return HistoricalExerciseIdentityPolicy.identity(of: entry) == exerciseID
                        ? (workout, entry)
                        : nil
                case .muscleGroup:
                    guard let group = muscleGroup else { return nil }
                    return group.contains(where: entry.exercise.primaryMuscles.contains)
                        || group.contains(where: (entry.exercise.secondaryMuscles ?? []).contains)
                        ? (workout, entry)
                        : nil
                }
            }
        }
        let qualifyingSets = filteredEntries.flatMap { workout, entry in
            entry.orderedSets.filter { set in
                StrengthAnalyticsPolicy.isEligibleForTraditionalSetRecord(set, entry: entry)
            }.map { (workout, entry, $0) }
        }
        let loadSets = qualifyingSets.filter { $0.1.trackingTypeSnapshot.usesWeight && $0.1.trackingTypeSnapshot.usesReps }
        let volume = loadSets.reduce(Float.zero) { partial, item in
            partial + VolumeCalculator.setVolume(
                weight: item.2.weight,
                weightType: item.2.weightType,
                repetitions: item.2.repetitions,
                semantics: item.1.loggingSemanticsSnapshot,
                in: preferredUnit
            )
        }
        let groupEstimate: Float?
        if scope == .muscleGroup, let muscleGroup {
            groupEstimate = qualifyingSets.reduce(Float.zero) { partial, item in
                partial + (item.1.exercise.primaryMuscles.contains(where: muscleGroup.contains) ? 1 : 0)
                    + ((item.1.exercise.secondaryMuscles ?? []).contains(where: muscleGroup.contains) ? 0.5 : 0)
            }
        } else {
            groupEstimate = nil
        }

        let subjectName: String?
        if scope == .exercise, let exerciseID {
            var exerciseDescriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.id == exerciseID }
            )
            exerciseDescriptor.fetchLimit = 1
            subjectName = try modelContext.fetch(exerciseDescriptor).first?.name
        } else {
            subjectName = nil
        }
        return WeeklyVolume(
            weekStart: interval.start,
            weekEnd: interval.end,
            completedWorkoutCount: Set(qualifyingSets.map { $0.0.id }).count,
            workingSetCount: qualifyingSets.count,
            loadVolume: loadSets.isEmpty ? nil : volume,
            unit: loadSets.isEmpty ? nil : preferredUnit,
            muscleGroupSetEstimate: groupEstimate,
            subjectName: subjectName
        )
    }

    private static var emptyTodayPlan: TodayPlan {
        TodayPlan(
            state: .noWorkout,
            title: "No workout scheduled",
            planName: nil,
            scheduledDate: nil,
            exercises: [],
            completedSetCount: 0,
            totalSetCount: 0
        )
    }

    private static func emptyWeeklyVolume(now: Date, calendar: Calendar) -> WeeklyVolume {
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: calendar.startOfDay(for: now), duration: 7 * 24 * 60 * 60)
        return WeeklyVolume(
            weekStart: interval.start,
            weekEnd: interval.end,
            completedWorkoutCount: 0,
            workingSetCount: 0,
            loadVolume: nil,
            unit: nil,
            muscleGroupSetEstimate: nil,
            subjectName: nil
        )
    }
}

enum WeeklyVolumeScope: String, AppEnum {
    case total
    case exercise
    case muscleGroup

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Volume scope")
    static let caseDisplayRepresentations: [WeeklyVolumeScope: DisplayRepresentation] = [
        .total: DisplayRepresentation(title: "Total"),
        .exercise: DisplayRepresentation(title: "Exercise"),
        .muscleGroup: DisplayRepresentation(title: "Muscle group")
    ]
}

enum MuscleGroupIntentOption: String, AppEnum {
    case chest
    case shoulders
    case arms
    case back
    case core
    case glutes
    case legs
    case other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Muscle group")
    static let caseDisplayRepresentations: [MuscleGroupIntentOption: DisplayRepresentation] = [
        .chest: DisplayRepresentation(title: "Chest"),
        .shoulders: DisplayRepresentation(title: "Shoulders"),
        .arms: DisplayRepresentation(title: "Arms"),
        .back: DisplayRepresentation(title: "Back"),
        .core: DisplayRepresentation(title: "Core"),
        .glutes: DisplayRepresentation(title: "Glutes"),
        .legs: DisplayRepresentation(title: "Legs"),
        .other: DisplayRepresentation(title: "Other muscles")
    ]

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .back: "Back"
        case .core: "Core"
        case .glutes: "Glutes"
        case .legs: "Legs"
        case .other: "Other muscles"
        }
    }

    var muscles: [Muscle] {
        let group: Muscle.Group
        switch self {
        case .chest: group = .chest
        case .shoulders: group = .shoulders
        case .arms: group = .arms
        case .back: group = .back
        case .core: group = .core
        case .glutes: group = .glutes
        case .legs: group = .legs
        case .other: group = .other
        }
        return group.muscles
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
