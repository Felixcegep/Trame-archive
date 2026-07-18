import Foundation

#if !GYMTRACKER_EXTENSION

struct ProgramDefinitionPreviewSet: Hashable, Identifiable {
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
    let restSeconds: Int?
    let isOptional: Bool
}

struct ProgramDefinitionPreviewRow: Hashable, Identifiable {
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
    let alternativeCount: Int
    let deloadVolumeReductionPercent: Int?
    let deloadIntensityReductionPercent: Int?
}

enum ProgramDefinitionPreview {
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
                                    restSeconds: definition.restSeconds,
                                    isOptional: definition.isOptional
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
