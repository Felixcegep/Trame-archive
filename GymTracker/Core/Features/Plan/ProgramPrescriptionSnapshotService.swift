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
        var context = LoadResolutionContext()
        for progressionState in run.progressionStates {
            if let value = progressionState.trainingMax { context.trainingMaxByExposure[progressionState.progressionKey] = value }
            if let value = progressionState.estimatedOneRepMax { context.estimatedOneRepMaxByExposure[progressionState.progressionKey] = value }
            if let value = progressionState.currentLoad {
                context.previousOccurrenceByExposure[progressionState.progressionKey] = value
                context.anotherPlannedExerciseByExposure[progressionState.progressionKey] = value
            }
        }
        let allPlannedExercises = run.plan?.orderedWeeks
            .flatMap(\.orderedPlannedWorkouts)
            .flatMap(\.orderedPlannedExercises) ?? []
        for planned in allPlannedExercises {
            guard let state = run.progressionStates.first(where: { $0.progressionKey == planned.progressionKey }) else { continue }
            if let value = state.trainingMax ?? state.estimatedOneRepMax ?? state.currentLoad {
                context.exerciseOneRepMaxByID[planned.exercise.id] = value
                context.referenceValuesByExerciseID[planned.exercise.id] = value
            }
        }

        for (index, plannedSet) in plannedExercise.orderedPlannedSets.enumerated() {
            guard index < entry.orderedSets.count,
                  let data = plannedSet.definitionData,
                  let definition = try? decoder.decode(SetPrescriptionDefinition.self, from: data) else { continue }
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
            case .calories, .sequence, .open:
                break
            }
            set.prescribedRestSeconds = definition.restSeconds.map { max(0, $0 + (state?.restDurationOffset ?? 0)) }
            set.prescribedRPE = definition.targetRPE
            set.prescribedRIR = definition.targetRIR
            set.isPrescribedOptional = definition.isOptional
            set.prescriptionNotes = definition.notes
            if let load = try? ProgramLoadResolver.resolve(definition.load, context: context),
               let value = load.prescribedLoad {
                let sourceType = state?.currentLoadType ?? .kg
                let targetType: WeightType = unitSystem == .metric ? .kg : .lbs
                let converted = UnitConversion.weight(Float(value), from: sourceType, to: targetType)
                set.prescribedSuggestedLoad = Double(converted)
                set.prescribedSuggestedLoadType = targetType
            }
        }
        if let countOffset = state?.setCountOffset, countOffset > 0,
           let source = entry.orderedSets.last {
            entry.prescribedSets = (entry.prescribedSets ?? entry.orderedSets.count) + countOffset
            for _ in 0..<countOffset {
                let extra = ExerciseSet(
                    repetitions: 0,
                    weight: source.weight,
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
                extra.isPrescribedOptional = source.isPrescribedOptional
                extra.prescriptionNotes = source.prescriptionNotes
                extra.prescriptionDefinitionData = source.prescriptionDefinitionData
                entry.sets.append(extra)
            }
            entry.normalizeSetOrder()
        }
    }
}
#endif
