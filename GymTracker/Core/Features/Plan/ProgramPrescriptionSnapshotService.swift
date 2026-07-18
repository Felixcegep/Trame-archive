import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramPrescriptionSnapshotService {
    /// Re-resolves only incomplete derived sets after a source set (for
    /// example a top set or daily maximum) is completed. Performed values are
    /// never rewritten.
    static func refreshDerivedLoads(for workout: Workout) {
        let decoder = JSONDecoder()
        var context = LoadResolutionContext()
        for entry in workout.orderedExercises {
            guard let key = entry.progressionKey else { continue }
            for set in entry.orderedSets {
                guard let data = set.prescriptionDefinitionData,
                      let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { continue }
                if definition.role == .topSet || definition.role == .dailyMaximum, set.done {
                    context.completedTopSetByExposure[key] = Double(set.weight)
                    context.dailyMaximumByExposure[key] = Double(set.weight)
                }
            }
        }
        guard !context.completedTopSetByExposure.isEmpty || !context.dailyMaximumByExposure.isEmpty else { return }
        for entry in workout.orderedExercises {
            guard let key = entry.progressionKey else { continue }
            for set in entry.orderedSets where !set.done {
                guard let data = set.prescriptionDefinitionData,
                      let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { continue }
                guard let resolution = try? ProgramLoadResolver.resolve(definition.load, context: context),
                      let load = resolution.prescribedLoad else { continue }
                let targetType: WeightType = entry.usedMetric == .metric ? .kg : .lbs
                set.prescribedSuggestedLoad = Double(UnitConversion.weight(Float(load), from: .kg, to: targetType))
                set.prescribedSuggestedLoadType = targetType
                if entry.prescribedSuggestedLoad == nil {
                    entry.prescribedSuggestedLoad = set.prescribedSuggestedLoad
                    entry.prescribedSuggestedLoadType = targetType
                }
            }
        }
    }

    static func apply(
        to entry: ExerciseEntry,
        plannedExercise: PlannedExercise,
        run: PlanRun,
        unitSystem: UnitSystem
    ) {
        let decoder = JSONDecoder()
        let state = run.progressionStates.first { $0.progressionKey == plannedExercise.progressionKey }
        let inheritedOverrides = latestFutureOverrides(
            for: plannedExercise.progressionKey,
            in: run
        )
        var context = LoadResolutionContext()
        for progressionState in run.progressionStates {
            if let value = progressionState.trainingMax { context.trainingMaxByExposure[progressionState.progressionKey] = value }
            if let value = progressionState.estimatedOneRepMax { context.estimatedOneRepMaxByExposure[progressionState.progressionKey] = value }
            if let value = progressionState.actualOneRepMax { context.actualOneRepMaxByExposure[progressionState.progressionKey] = value }
            if let value = progressionState.currentLoad {
                context.previousOccurrenceByExposure[progressionState.progressionKey] = value
                context.previousWorkoutByExposure[progressionState.progressionKey] = value
                context.anotherPlannedExerciseByExposure[progressionState.progressionKey] = value
            }
            if let value = progressionState.lastSuccessfulLoad {
                context.previousSuccessfulSetByExposure[progressionState.progressionKey] = value
            }
        }
        let allPlannedExercises = run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises) ?? []
        for planned in allPlannedExercises {
            guard let state = run.progressionStates.first(where: { $0.progressionKey == planned.progressionKey }) else { continue }
            if let value = state.actualOneRepMax ?? state.trainingMax ?? state.estimatedOneRepMax ?? state.currentLoad {
                context.exerciseOneRepMaxByID[planned.exercise.id] = value
                context.referenceValuesByExerciseID[planned.exercise.id] = value
            }
        }

        let waveDefinitions: [ProgramWaveDefinition] = plannedExercise.progressionWavesData
            .flatMap { try? decoder.decode([ProgramWaveDefinition].self, from: $0) } ?? []
        let selectedWave = waveDefinitions
            .sorted { $0.orderIndex < $1.orderIndex }
            .dropFirst(min(max(0, state?.currentWaveIndex ?? 0), max(0, waveDefinitions.count - 1)))
            .first
        let prescriptions: [(definition: SetPrescriptionDefinition, data: Data)]
        if let selectedWave {
            prescriptions = selectedWave.plannedSets
                .sorted { $0.orderIndex < $1.orderIndex }
                .compactMap { definition in
                    guard let data = try? JSONEncoder().encode(definition) else { return nil }
                    return (definition, data)
                }
        } else {
            prescriptions = plannedExercise.orderedPlannedSets.compactMap { plannedSet in
                guard let data = plannedSet.definitionData,
                      let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { return nil }
                return (definition, data)
            }
        }
        for (index, prescription) in prescriptions.enumerated() {
            guard index < entry.orderedSets.count else { continue }
            let definition = prescription.definition
            let data = prescription.data
            let set = entry.orderedSets[index]
            set.prescriptionDefinitionData = data
            switch definition.role {
            case .warmup: set.prescribedSetType = .warmup
            case .dropSet: set.prescribedSetType = .dropSet
            case .backOff: set.prescribedSetType = .backoff
            case .topSet: set.prescribedSetType = .topSet
            case .amrap: set.prescribedSetType = .amrap
            case .technique: set.prescribedSetType = .technique
            case .dailyMaximum: set.prescribedSetType = .dailyMaximum
            case .test: set.prescribedSetType = .test
            case .recovery: set.prescribedSetType = .recovery
            case .working: set.prescribedSetType = .normal
            }
            switch definition.repetitions {
            case .fixed(let repetitions):
                set.prescribedRepetitions = max(1, repetitions + (state?.repetitionOffset ?? 0))
            case .range(let minimum, let maximum):
                let offset = state?.repetitionOffset ?? 0
                set.prescribedRepRangeMinimum = max(1, minimum + offset)
                set.prescribedRepRangeMaximum = max(set.prescribedRepRangeMinimum ?? maximum, maximum + offset)
            case .amrap(let minimum, let maximum):
                let offset = state?.repetitionOffset ?? 0
                set.prescribedRepRangeMinimum = minimum.map { max(0, $0 + offset) }
                set.prescribedRepRangeMaximum = maximum.map { max(set.prescribedRepRangeMinimum ?? 0, $0 + offset) }
            case .duration(let seconds):
                set.duration = seconds.map { $0 + (state?.durationOffset ?? 0) }
            case .distance(let meters):
                set.distance = meters.map { Float($0 + (state?.distanceOffset ?? 0)) }
            case .calories(let calories):
                set.calories = calories.map { $0 + (state?.caloriesOffset ?? 0) }
                set.prescribedCalories = set.calories
            case .sequence(let components):
                let repetitions = components.reduce(0) { $0 + $1.repetitions }
                set.prescribedRepetitions = max(1, repetitions + (state?.repetitionOffset ?? 0))
                if set.repetitions <= 0 {
                    set.repetitions = Float(set.prescribedRepetitions ?? repetitions)
                }
                let notation = components.map { String($0.repetitions) }.joined(separator: "+")
                set.prescriptionNotes = ["Complex: \(notation)", definition.notes]
                    .compactMap { $0 }
                    .joined(separator: " · ")
            case .open:
                break
            }
            set.prescribedRestSeconds = definition.restSeconds.map { max(0, $0 + (state?.restDurationOffset ?? 0)) }
            set.prescribedRPE = definition.targetRPE
            set.prescribedRIR = definition.targetRIR
            set.isPrescribedOptional = definition.isOptional
            if set.prescriptionNotes == nil {
                set.prescriptionNotes = definition.notes
            }
            if let load = try? ProgramLoadResolver.resolve(definition.load, context: context),
               let value = load.prescribedLoad {
                let sourceType = state?.currentLoadType ?? .kg
                let targetType: WeightType = unitSystem == .metric ? .kg : .lbs
                let converted = UnitConversion.weight(Float(value), from: sourceType, to: targetType)
                set.prescribedSuggestedLoad = Double(converted)
                set.prescribedSuggestedLoadType = targetType
            }
            applyFutureOverride(
                from: inheritedOverrides[set.orderIndex],
                to: set,
                trackingType: entry.trackingTypeSnapshot
            )
        }
        if let countOffset = state?.setCountOffset, countOffset > 0,
           let source = entry.orderedSets.last {
            entry.prescribedSets = (entry.prescribedSets ?? entry.orderedSets.count) + countOffset
            for _ in 0..<countOffset {
                let extra = ExerciseSet(
                    repetitions: 0,
                    weight: source.weight,
                    calories: source.calories,
                    setType: source.setType,
                    orderIndex: entry.orderedSets.count,
                    usedMetric: source.usedMetric
                )
                extra.prescribedSetType = source.prescribedSetType
                extra.prescribedRepetitions = source.prescribedRepetitions
                extra.prescribedRepRangeMinimum = source.prescribedRepRangeMinimum
                extra.prescribedRepRangeMaximum = source.prescribedRepRangeMaximum
                extra.prescribedSuggestedLoad = source.prescribedSuggestedLoad
                extra.prescribedSuggestedLoadType = source.prescribedSuggestedLoadType
                extra.prescribedRestSeconds = source.prescribedRestSeconds
                extra.prescribedRPE = source.prescribedRPE
                extra.prescribedRIR = source.prescribedRIR
                extra.prescribedCalories = source.prescribedCalories
                extra.isUserOverridden = source.isUserOverridden
                extra.userOverrideReason = source.userOverrideReason
                extra.userOverrideAffectsFuture = source.userOverrideAffectsFuture
                extra.isPrescribedOptional = source.isPrescribedOptional
                extra.prescriptionNotes = source.prescriptionNotes
                extra.prescriptionDefinitionData = source.prescriptionDefinitionData
                entry.sets.append(extra)
            }
            entry.normalizeSetOrder()
        }
    }

    private static func latestFutureOverrides(
        for progressionKey: String,
        in run: PlanRun
    ) -> [Int: ExerciseSet] {
        let entries = run.orderedWorkoutProgress
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { progress in
                progress.completedWorkout?.orderedExercises.first {
                    $0.progressionKey == progressionKey
                }
            }
        guard let latest = entries.first else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: latest.orderedSets
                .filter { $0.userOverrideAffectsFuture }
                .map { ($0.orderIndex, $0) }
        )
    }

    private static func applyFutureOverride(
        from source: ExerciseSet?,
        to target: ExerciseSet,
        trackingType: TrackingType
    ) {
        guard let source, source.userOverrideAffectsFuture else { return }
        if trackingType.usesReps { target.repetitions = source.repetitions }
        if trackingType.usesWeight {
            target.weight = UnitConversion.weight(source.weight, from: source.weightType, to: target.weightType)
        }
        if trackingType.usesDuration { target.duration = source.duration }
        if trackingType.usesDistance {
            if let distance = source.distance {
                target.distance = UnitConversion.distance(distance, from: source.distanceType, to: target.distanceType)
            } else {
                target.distance = nil
            }
        }
        if trackingType.usesCalories { target.calories = source.calories }
        target.isUserOverridden = true
        target.userOverrideReason = source.userOverrideReason
        target.userOverrideAffectsFuture = true
    }
}
#endif
