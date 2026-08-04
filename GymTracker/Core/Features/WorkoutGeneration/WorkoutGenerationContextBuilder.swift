import Foundation

/// Builds a value-only prompt context from the app's current data. This type
/// only reads completed workouts and reusable templates; it never writes to a
/// workout, plan, progression receipt, or profile.
@MainActor
enum WorkoutGenerationContextBuilder {
    static let recentHistoryDays = 14
    static let maximumExamples = 3

    static func build(
        request: WorkoutGenerationRequest,
        profile: TrainingProfile?,
        preferences: WorkoutGenerationPreferences,
        exercises: [Exercise],
        completedWorkouts: [Workout],
        templates: [WorkoutTemplate],
        now: Date = .now
    ) -> WorkoutGenerationInput {
        let profileSnapshot = profileSnapshot(profile, preferences: preferences)
        let availableExercises = WorkoutGenerationCatalogue.build(
            from: exercises,
            request: request,
            profile: profileSnapshot
        )
        let allowedIDs = Set(availableExercises.map(\.exerciseID))
        return WorkoutGenerationInput(
            request: request,
            profile: profileSnapshot,
            availableExercises: availableExercises,
            recentTraining: recentTrainingSummary(
                from: completedWorkouts,
                allowedExerciseIDs: allowedIDs,
                now: now
            ),
            examples: examples(from: templates, allowedExerciseIDs: allowedIDs)
        )
    }

    static func profileSnapshot(
        _ profile: TrainingProfile?,
        preferences: WorkoutGenerationPreferences
    ) -> WorkoutGenerationProfileSnapshot {
        WorkoutGenerationProfileSnapshot(
            experienceLevel: profile?.experienceLevel,
            primaryGoal: profile?.primaryGoal,
            preferredDurationMinutes: preferences.defaultDurationMinutes,
            availableEquipment: profile?.equipment ?? [],
            avoidedExerciseIDs: preferences.avoidedExerciseIDs,
            preferredStimulus: preferences.preferredStimulus
        )
    }

    static func recentTrainingSummary(
        from workouts: [Workout],
        allowedExerciseIDs: Set<UUID>,
        now: Date
    ) -> WorkoutGenerationRecentTrainingSummary {
        let since = Calendar.current.date(byAdding: .day, value: -recentHistoryDays, to: now) ?? now
        var exposures: [UUID: (lastPerformedAt: Date, count: Int)] = [:]

        for workout in workouts where workout.status == .completed && workout.startTime >= since {
            for entry in workout.orderedExercises {
                let exerciseID = HistoricalExerciseIdentityPolicy.identity(of: entry)
                guard allowedExerciseIDs.contains(exerciseID) else { continue }
                let existing = exposures[exerciseID]
                exposures[exerciseID] = (
                    lastPerformedAt: max(existing?.lastPerformedAt ?? workout.startTime, workout.startTime),
                    count: (existing?.count ?? 0) + 1
                )
            }
        }

        return WorkoutGenerationRecentTrainingSummary(
            since: since,
            exposures: exposures.map {
                WorkoutGenerationRecentTrainingSummary.ExerciseExposure(
                    exerciseID: $0.key,
                    lastPerformedAt: $0.value.lastPerformedAt,
                    completedWorkoutCount: $0.value.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.lastPerformedAt != rhs.lastPerformedAt { return lhs.lastPerformedAt > rhs.lastPerformedAt }
                return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
            }
        )
    }

    static func examples(
        from templates: [WorkoutTemplate],
        allowedExerciseIDs: Set<UUID>
    ) -> [WorkoutGenerationExample] {
        templates
            .filter { !$0.orderedTemplateExercises.isEmpty }
            .sorted { lhs, rhs in
                if lhs.isBuiltIn != rhs.isBuiltIn { return !lhs.isBuiltIn && rhs.isBuiltIn }
                let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .compactMap { template -> WorkoutGenerationExample? in
                let exercises = template.orderedTemplateExercises.compactMap { templateExercise -> WorkoutGenerationExample.Exercise? in
                    guard allowedExerciseIDs.contains(templateExercise.exercise.id) else { return nil }
                    return WorkoutGenerationExample.Exercise(
                        exerciseID: templateExercise.exercise.id,
                        name: templateExercise.exercise.name,
                        sets: templateExercise.targetSets,
                        minimumRepetitions: templateExercise.repRangeMinimum,
                        maximumRepetitions: templateExercise.repRangeMaximum,
                        restSeconds: templateExercise.restSeconds,
                        targetRIR: templateExercise.targetRIR,
                        targetRPE: templateExercise.targetRPE,
                        supersetGroupID: templateExercise.supersetGroupID?.uuidString
                    )
                }
                guard !exercises.isEmpty else { return nil }
                return WorkoutGenerationExample(name: template.name, exercises: exercises)
            }
            .prefix(maximumExamples)
            .map { $0 }
    }
}
