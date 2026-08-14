import Foundation

nonisolated enum TrackingProfileValidationError: Error, Equatable, LocalizedError {
    case invalidCombination(stimulus: TrainingStimulus, trackingType: TrackingType)

    var errorDescription: String? {
        switch self {
        case let .invalidCombination(stimulus, trackingType):
            return "The combination of \(stimulus.title) stimulus and \(trackingType.rawValue) tracking is invalid."
        }
    }
}

/// One structured tracking-profile problem found while validating a
/// prescription graph. `path` identifies the entity inside its graph so
/// program authoring and backup errors can point at the exact payload node.
nonisolated struct TrackingProfileIssue: Equatable, Identifiable, Sendable {
    let path: String
    let exerciseName: String
    let stimulus: TrainingStimulus
    let trackingType: TrackingType

    var id: String { path }

    /// Localized corrective message naming the exercise, the incompatible
    /// combination, and the tracking choices that remain compatible.
    var message: String {
        let compatible = TrackingProfileValidator.compatibleTrackingTypes(for: stimulus)
            .map(\.rawValue)
            .joined(separator: ", ")
        return String(
            format: String(
                localized: "“%1$@” pairs a %2$@ stimulus with %3$@ tracking, which cannot be logged. Compatible tracking types: %4$@.",
                comment: "Tracking-profile validation failure. 1: exercise name, 2: stimulus, 3: tracking type, 4: compatible tracking types"
            ),
            exerciseName, stimulus.title, trackingType.rawValue, compatible
        )
    }
}

/// A tracking-profile validation failure raised at a persistence boundary.
/// It carries every structured issue so UI can keep the draft open and list
/// the exact incompatible combinations.
nonisolated struct TrackingProfileValidationFailure: Error, Equatable, LocalizedError {
    let issues: [TrackingProfileIssue]

    var errorDescription: String? {
        issues.map(\.message).joined(separator: "\n")
    }
}

nonisolated struct TrackingProfileValidator {
    // MARK: Rule engine

    static func validate(
        stimulus: TrainingStimulus,
        trackingType: TrackingType,
        exercise: Exercise? = nil
    ) -> Result<Void, TrackingProfileValidationError> {
        switch (stimulus, trackingType) {
        case (.hypertrophy, .calories):
            return .failure(.invalidCombination(stimulus: stimulus, trackingType: trackingType))
        case (.strength, .calories):
            return .failure(.invalidCombination(stimulus: stimulus, trackingType: trackingType))
        default:
            return .success(())
        }
    }

    static func isValid(stimulus: TrainingStimulus?, trackingType: TrackingType) -> Bool {
        // An absent stimulus means "not classifiable", not "invalid": there is
        // no combination to reject until intent exists.
        guard let stimulus else { return true }
        if case .failure = validate(stimulus: stimulus, trackingType: trackingType) {
            return false
        }
        return true
    }

    static func compatibleTrackingTypes(for stimulus: TrainingStimulus) -> [TrackingType] {
        TrackingType.allCases.filter { isValid(stimulus: stimulus, trackingType: $0) }
    }

    static func compatibleStimuli(for trackingType: TrackingType) -> [TrainingStimulus] {
        TrainingStimulus.allCases.filter { isValid(stimulus: $0, trackingType: trackingType) }
    }

    // MARK: Graph validation

    private static func issue(
        path: String,
        exerciseName: String,
        stimulus: TrainingStimulus?,
        trackingType: TrackingType
    ) -> TrackingProfileIssue? {
        guard let stimulus, !isValid(stimulus: stimulus, trackingType: trackingType) else {
            return nil
        }
        return TrackingProfileIssue(
            path: path,
            exerciseName: exerciseName,
            stimulus: stimulus,
            trackingType: trackingType
        )
    }

    static func validate(
        templateExercise: TemplateExercise,
        path: String = "templateExercise"
    ) -> [TrackingProfileIssue] {
        issue(
            path: path,
            exerciseName: templateExercise.exercise.name,
            stimulus: templateExercise.resolvedStimulus,
            trackingType: templateExercise.resolvedTrackingType
        ).map { [$0] } ?? []
    }

    static func validate(template: WorkoutTemplate) -> [TrackingProfileIssue] {
        template.templateExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .enumerated()
            .flatMap { index, templateExercise in
                validate(
                    templateExercise: templateExercise,
                    path: "template(\(template.name)).exercises[\(index)]"
                )
            }
    }

    static func validate(
        plannedExercise: PlannedExercise,
        path: String = "plannedExercise"
    ) -> [TrackingProfileIssue] {
        issue(
            path: path,
            exerciseName: plannedExercise.exercise.name,
            stimulus: plannedExercise.resolvedStimulus,
            trackingType: plannedExercise.resolvedTrackingType
        ).map { [$0] } ?? []
    }

    static func validate(plan: WorkoutPlan) -> [TrackingProfileIssue] {
        var issues: [TrackingProfileIssue] = []
        for (weekIndex, week) in plan.orderedWeeks.enumerated() {
            for (workoutIndex, workout) in week.orderedPlannedWorkouts.enumerated() {
                for (exerciseIndex, plannedExercise) in workout.orderedPlannedExercises.enumerated() {
                    issues += validate(
                        plannedExercise: plannedExercise,
                        path: "plan(\(plan.name)).weeks[\(weekIndex)].workouts[\(workoutIndex)].exercises[\(exerciseIndex)]"
                    )
                }
            }
        }
        return issues
    }

#if !GYMTRACKER_EXTENSION
    /// Validates a program definition against the tracking profile the
    /// compiler will materialize: an exercise-derived default when one is
    /// unambiguous (e.g. a cardio exercise resolves to endurance), otherwise
    /// the same strength fallback `ProgramDefinitionCompiler` assigns.
    static func validate(
        payload: ProgramDefinitionPayload,
        exercisesByID: [UUID: Exercise]
    ) -> [TrackingProfileIssue] {
        var issues: [TrackingProfileIssue] = []
        for (blockIndex, block) in payload.blocks.enumerated() {
            for (weekIndex, week) in block.weeks.enumerated() {
                for (workoutIndex, workout) in week.workouts.enumerated() {
                    for (exerciseIndex, definition) in workout.plannedExercises.enumerated() {
                        guard let exercise = exercisesByID[definition.exerciseID] else { continue }
                        if let found = issue(
                            path: "blocks[\(blockIndex)].weeks[\(weekIndex)].workouts[\(workoutIndex)].exercises[\(exerciseIndex)]",
                            exerciseName: exercise.name,
                            stimulus: TrainingStimulusResolver.inferredStimulus(for: exercise) ?? .strength,
                            trackingType: exercise.trackingType
                        ) {
                            issues.append(found)
                        }
                    }
                }
            }
        }
        return issues
    }

    /// Validates every template and planned exercise carried by a backup
    /// before its graph is allowed to replace persisted data. Resolution
    /// mirrors what restore will materialize: explicit stimulus, then the
    /// exercise-derived default for templates or the legacy strength default
    /// for planned exercises.
    static func validate(backup: BackupDTO) -> [TrackingProfileIssue] {
        var profileByName: [String: (category: ExerciseCategory?, trackingType: TrackingType)] = [:]
        for exercise in backup.exercises {
            profileByName[exercise.name] = (
                category: exercise.category.flatMap(ExerciseCategory.init(rawValue:)),
                trackingType: TrackingType(rawValue: exercise.trackingType) ?? .weightAndReps
            )
        }

        var issues: [TrackingProfileIssue] = []

        for template in backup.templates {
            for (index, templateExercise) in template.templateExercises.enumerated() {
                guard let profile = profileByName[templateExercise.exerciseName] else { continue }
                let stimulus = templateExercise.stimulus.flatMap(TrainingStimulus.init(rawValue:))
                    ?? TrainingStimulusResolver.inferredStimulus(
                        category: profile.category,
                        trackingType: profile.trackingType
                    )
                if let found = issue(
                    path: "templates(\(template.name)).exercises[\(index)]",
                    exerciseName: templateExercise.exerciseName,
                    stimulus: stimulus,
                    trackingType: profile.trackingType
                ) {
                    issues.append(found)
                }
            }
        }

        for plan in backup.plans {
            for (blockIndex, block) in plan.blocks.enumerated() {
                for (weekIndex, week) in block.weeks.enumerated() {
                    for (workoutIndex, workout) in week.plannedWorkouts.enumerated() {
                        for (exerciseIndex, plannedExercise) in workout.plannedExercises.enumerated() {
                            guard let profile = profileByName[plannedExercise.exerciseName] else { continue }
                            let stimulus = plannedExercise.stimulus.flatMap(TrainingStimulus.init(rawValue:))
                                ?? .strength
                            let trackingType = plannedExercise.trackingTypeOverride
                                .flatMap(TrackingType.init(rawValue:))
                                ?? profile.trackingType
                            if let found = issue(
                                path: "plans(\(plan.name)).blocks[\(blockIndex)].weeks[\(weekIndex)].workouts[\(workoutIndex)].exercises[\(exerciseIndex)]",
                                exerciseName: plannedExercise.exerciseName,
                                stimulus: stimulus,
                                trackingType: trackingType
                            ) {
                                issues.append(found)
                            }
                        }
                    }
                }
            }
        }

        return issues
    }
#endif
}
