import Foundation

#if !GYMTRACKER_EXTENSION

/// Catalog-aware validation for authored set-completion rules. Structural
/// validation runs without a catalog; this boundary proves the selected
/// exercise's legacy tracking profile can actually collect every requirement.
nonisolated enum ProgramMetricCompletionValidator {
    static func validate(
        payload: ProgramDefinitionPayload,
        exercisesByID: [UUID: Exercise]
    ) -> [ProgramValidationIssue] {
        var issues: [ProgramValidationIssue] = []
        for (blockIndex, block) in payload.blocks.enumerated() {
            for (weekIndex, week) in block.weeks.enumerated() {
                for (workoutIndex, workout) in week.workouts.enumerated() {
                    for (exerciseIndex, definition) in workout.plannedExercises.enumerated() {
                        guard let exercise = exercisesByID[definition.exerciseID] else { continue }
                        let root = "blocks[\(blockIndex)].weeks[\(weekIndex)].workouts[\(workoutIndex)].exercises[\(exerciseIndex)]"
                        issues += validate(
                            sets: definition.plannedSets,
                            path: "\(root).sets",
                            exercise: exercise
                        )
                        for (waveIndex, wave) in definition.waves.enumerated() {
                            issues += validate(
                                sets: wave.plannedSets,
                                path: "\(root).waves[\(waveIndex)].sets",
                                exercise: exercise
                            )
                        }
                        for (stageIndex, stage) in definition.stages.enumerated() {
                            issues += validate(
                                sets: stage.plannedSets,
                                path: "\(root).stages[\(stageIndex)].sets",
                                exercise: exercise
                            )
                        }
                    }
                }
            }
        }
        return issues
    }

    private static func validate(
        sets: [SetPrescriptionDefinition],
        path: String,
        exercise: Exercise
    ) -> [ProgramValidationIssue] {
        let supported = exercise.trackingType.capabilityProfile.completionWritableMetrics
        return sets.enumerated().compactMap { index, set in
            guard let rule = set.completionRule else { return nil }
            let required: Set<TrackingMetric>
            switch rule {
            case .all(let metrics), .any(let metrics): required = metrics
            case .prescribedTargets: required = set.prescribedCompletionMetrics
            }
            let unsupported = required.subtracting(supported)
            guard !unsupported.isEmpty else { return nil }
            let names = unsupported.sorted { $0.rawValue < $1.rawValue }
                .map(\.title)
                .joined(separator: ", ")
            return ProgramValidationIssue(
                path: "\(path)[\(index)].completionRule",
                code: .invalidCompletionRule,
                message: "\(exercise.name) uses \(exercise.trackingType.rawValue) tracking, which cannot collect: \(names)."
            )
        }
    }
}

#endif
