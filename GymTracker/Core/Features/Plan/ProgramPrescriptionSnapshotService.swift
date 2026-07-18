import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramPrescriptionSnapshotService {
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
            default: break
            }
            switch definition.repetitions {
            case .fixed(let repetitions):
                set.prescribedRepetitions = repetitions
            case .range(let minimum, let maximum):
                set.prescribedRepRangeMinimum = minimum
                set.prescribedRepRangeMaximum = maximum
            case .amrap(let minimum, let maximum):
                set.prescribedRepRangeMinimum = minimum
                set.prescribedRepRangeMaximum = maximum
            case .duration(let seconds):
                set.duration = seconds
            case .distance(let meters):
                set.distance = meters.map(Float.init)
            case .calories, .sequence, .open:
                break
            }
            set.prescribedRestSeconds = definition.restSeconds
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
    }
}
#endif
