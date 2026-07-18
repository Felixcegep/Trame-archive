import Foundation

#if !GYMTRACKER_EXTENSION

nonisolated struct ProgramDefinitionPreviewSet: Hashable, Identifiable {
    let id: UUID
    let orderIndex: Int
    let role: ProgramSetRole
    let repetitions: RepPrescription
    let loadReference: LoadReferenceKind
    let unroundedLoad: Double?
    let prescribedLoad: Double?
    let loadExplanation: String
    let targetRPE: Double?
    let targetRIR: Int?
    let tempo: String?
    let progressionEligible: Bool
    let restSeconds: Int?
    let isOptional: Bool
    /// A source-based back-off is a future conditional row, not a set shown
    /// at workout start. The preview must make that timing explicit.
    let generatesAfterSourceCompletion: Bool
}

nonisolated struct ProgramDefinitionPreviewTransition: Hashable, Identifiable {
    let id: UUID
    let trigger: String
    let successAction: String
    let failureAction: String?
    let cadence: ProgressionCadence
    let scope: ProgressionScope
    let applicationMode: ProgressionApplicationMode
}

nonisolated struct ProgramDefinitionPreviewRow: Hashable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let phaseType: PlanPhaseType
    let weekIndex: Int
    let weekName: String?
    let workoutName: String
    let workoutRole: String
    let dayOffset: Int
    let exerciseID: UUID
    let exposureKey: String
    let setCount: Int
    let waveCount: Int
    let roles: [ProgramSetRole]
    let repPrescriptions: [RepPrescription]
    let loadReferences: [LoadReferenceKind]
    let sets: [ProgramDefinitionPreviewSet]
    let progressionRuleCount: Int
    let transitions: [ProgramDefinitionPreviewTransition]
    let alternativeCount: Int
    let deloadVolumeReductionPercent: Int?
    let deloadIntensityReductionPercent: Int?
}

nonisolated enum ProgramDefinitionPreview {
    /// Flattens the complete recipe into reviewable rows. Loads are resolved
    /// against the definition's initial values when available; missing values
    /// remain visible as an explanation instead of making preview impossible.
    static func rows(
        for definition: ProgramDefinitionPayload,
        loadContext: LoadResolutionContext? = nil
    ) throws -> [ProgramDefinitionPreviewRow] {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionCodecError.validation(issues) }
        let context = loadContext ?? initialLoadContext(for: definition)
        return definition.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .flatMap { block in
                block.weeks.sorted { $0.weekIndex < $1.weekIndex }.flatMap { week in
                    week.workouts.sorted { $0.orderIndex < $1.orderIndex }.flatMap { workout in
                        workout.plannedExercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
                            let definitions = previewSets(for: exercise)
                            let sets = definitions.map { definition in
                                let resolution = try? ProgramLoadResolver.resolve(definition.load, context: context)
                                return ProgramDefinitionPreviewSet(
                                    id: definition.id,
                                    orderIndex: definition.orderIndex,
                                    role: definition.role,
                                    repetitions: definition.repetitions,
                                    loadReference: definition.load.reference.kind,
                                    unroundedLoad: resolution?.unroundedLoad,
                                    prescribedLoad: resolution?.prescribedLoad,
                                    loadExplanation: resolution?.explanation ?? "Load requires a starting value or a completed-session reference.",
                                    targetRPE: definition.targetRPE,
                                    targetRIR: definition.targetRIR,
                                    tempo: definition.tempo,
                                    progressionEligible: definition.progressionEligible,
                                    restSeconds: definition.restSeconds,
                                    isOptional: definition.isOptional,
                                    generatesAfterSourceCompletion: definition.generatesAfterSourceCompletion
                                )
                            }
                            return ProgramDefinitionPreviewRow(
                                id: exercise.id,
                                blockIndex: block.orderIndex,
                                phaseType: block.phaseType,
                                weekIndex: week.weekIndex,
                                weekName: week.name,
                                workoutName: workout.name,
                                workoutRole: workout.role,
                                dayOffset: workout.dayOffset,
                                exerciseID: exercise.exerciseID,
                                exposureKey: exercise.exposureKey,
                                setCount: sets.count,
                                waveCount: exercise.waves.count,
                                roles: sets.map(\.role),
                                repPrescriptions: sets.map(\.repetitions),
                                loadReferences: sets.map(\.loadReference),
                                sets: sets,
                                progressionRuleCount: exercise.progressionRules.count,
                                transitions: exercise.progressionRules.map { rule in
                                    ProgramDefinitionPreviewTransition(
                                        id: rule.id,
                                        trigger: triggerText(rule.trigger),
                                        successAction: actionText(rule.successAction),
                                        failureAction: rule.failureAction.map(actionText),
                                        cadence: rule.cadence,
                                        scope: rule.scope,
                                        applicationMode: rule.applicationMode
                                    )
                                },
                                alternativeCount: exercise.alternativeExerciseIDs.count,
                                deloadVolumeReductionPercent: block.deloadVolumeReductionPercent,
                                deloadIntensityReductionPercent: block.deloadIntensityReductionPercent
                            )
                        }
                    }
                }
            }
    }

    private static func previewSets(for exercise: ProgramExerciseDefinition) -> [SetPrescriptionDefinition] {
        if let firstWave = exercise.waves.sorted(by: { $0.orderIndex < $1.orderIndex }).first {
            return firstWave.plannedSets.sorted { $0.orderIndex < $1.orderIndex }
        }
        return exercise.plannedSets.sorted { $0.orderIndex < $1.orderIndex }
    }

    private static func triggerText(_ trigger: ProgressionTrigger) -> String {
        switch trigger {
        case .allRequiredSetsCompleted: return "All required sets completed"
        case .allRequiredRepetitionsCompleted: return "All required repetitions completed"
        case .allSetsReachedUpperRepBound: return "All sets reach upper rep bound"
        case .totalRepetitionsReached(let value): return "Total repetitions reach \(value)"
        case .totalCaloriesReached(let value): return "Total calories reach \(value)"
        case .totalVolumeReached(let value): return "Total volume reaches \(value)"
        case .amrapResultReached(let value): return "AMRAP result reaches \(value)"
        case .extraRepetitionsCompleted(let value): return "Extra repetitions reach \(value)"
        case .targetRPEMatched(let tolerance): return "Target RPE matched (±\(tolerance))"
        case .actualRPEBelowTarget(let tolerance): return "Actual RPE below target (\(tolerance))"
        case .actualRPEAboveTarget(let tolerance): return "Actual RPE above target (\(tolerance))"
        case .targetRIRMatched(let tolerance): return "Target RIR matched (±\(tolerance))"
        case .failureCountReached(let value): return "Failure count reaches \(value)"
        case .successfulAttemptRatioReached(let value): return "Successful attempts reach \(value)"
        case .technicalQualityReached: return "Technical quality reached"
        case .workoutCompleted: return "Workout completed"
        case .weekCompleted: return "Week completed"
        case .waveCompleted: return "Wave completed"
        case .blockCompleted: return "Block completed"
        case .cycleCompleted: return "Cycle completed"
        case .scheduledDateReached: return "Scheduled date reached"
        case .manualApproval: return "Manual approval"
        }
    }

    private static func actionText(_ action: ProgressionAction) -> String {
        switch action {
        case .addLoad(let value): return "Add load \(value)"
        case .reduceLoad(let value): return "Reduce load \(value)"
        case .addLoadPercentage(let value): return "Add load \(value * 100)%"
        case .reduceLoadPercentage(let value): return "Reduce load \(value * 100)%"
        case .addAssistance(let value): return "Add assistance \(value)"
        case .reduceAssistance(let value): return "Reduce assistance \(value)"
        case .addRepetitions(let value): return "Add \(value) repetitions"
        case .reduceRepetitions(let value): return "Reduce \(value) repetitions"
        case .addSets(let value): return "Add \(value) sets"
        case .reduceSets(let value): return "Reduce \(value) sets"
        case .addDuration(let value): return "Add duration \(value)s"
        case .reduceDuration(let value): return "Reduce duration \(value)s"
        case .addDistance(let value): return "Add distance \(value)m"
        case .reduceDistance(let value): return "Reduce distance \(value)m"
        case .addRestDuration(let value): return "Add rest \(value)s"
        case .reduceRestDuration(let value): return "Reduce rest \(value)s"
        case .addCalories(let value): return "Add \(value) calories"
        case .reduceCalories(let value): return "Reduce \(value) calories"
        case .updateTrainingMax: return "Update Training Max"
        case .updateEstimatedOneRepMax: return "Update estimated 1RM"
        case .updateActualOneRepMax: return "Update actual 1RM"
        case .repeatPrescription: return "Repeat prescription"
        case .changeStage(let value): return "Change stage to \(value)"
        case .advanceExerciseVariation: return "Advance exercise variation"
        case .regressExerciseVariation: return "Regress exercise variation"
        case .advanceWeek: return "Advance week"
        case .repeatWeek: return "Repeat week"
        case .advanceWave: return "Advance wave"
        case .advanceBlock: return "Advance block"
        case .restartBlock: return "Restart block"
        case .startDeload: return "Start deload"
        case .resetFailureCount: return "Reset failure count"
        case .resetProgressionOffsets: return "Reset progression offsets"
        case .endExercise: return "End exercise"
        case .endProgram: return "End program"
        case .generateRecommendation: return "Generate recommendation"
        case .noChange: return "No change"
        }
    }

    private static func initialLoadContext(for definition: ProgramDefinitionPayload) -> LoadResolutionContext {
        var context = LoadResolutionContext()
        for exercise in definition.blocks.flatMap(\.weeks).flatMap(\.workouts).flatMap(\.plannedExercises) {
            if let value = exercise.initialTrainingMax {
                context.trainingMaxByExposure[exercise.exposureKey] = value
            }
            if let value = exercise.initialEstimatedOneRepMax {
                context.estimatedOneRepMaxByExposure[exercise.exposureKey] = value
            }
            if let value = exercise.initialActualOneRepMax {
                context.actualOneRepMaxByExposure[exercise.exposureKey] = value
            }
            if let value = exercise.initialLoad {
                context.previousOccurrenceByExposure[exercise.exposureKey] = value
                context.previousSuccessfulSetByExposure[exercise.exposureKey] = value
                context.anotherPlannedExerciseByExposure[exercise.exposureKey] = value
            }
            if let value = exercise.initialActualOneRepMax ?? exercise.initialTrainingMax ?? exercise.initialEstimatedOneRepMax ?? exercise.initialLoad {
                context.exerciseOneRepMaxByID[exercise.exerciseID] = value
                context.referenceValuesByExerciseID[exercise.exerciseID] = value
            }
        }
        return context
    }
}

#endif
