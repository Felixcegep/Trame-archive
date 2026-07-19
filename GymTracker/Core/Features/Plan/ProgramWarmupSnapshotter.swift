import Foundation

#if !GYMTRACKER_EXTENSION

/// Builds warm-up rows from a planned warm-up scheme without changing the
/// existing prescription-snapshot orchestration.
enum ProgramWarmupSnapshotter {
    private static let generatedWarmupNote = "Generated warm-up"

    static func isGeneratedWarmup(_ set: ExerciseSet) -> Bool {
        set.prescriptionNotes == generatedWarmupNote
    }

    static func insertWarmups(
        into entry: ExerciseEntry,
        plannedExercise: PlannedExercise,
        decoder: JSONDecoder
    ) {
        guard let data = plannedExercise.warmupSchemeData,
              let scheme = try? decoder.decode(WarmupSchemeDefinition.self, from: data),
              !scheme.steps.isEmpty,
              !entry.orderedSets.contains(where: { isGeneratedWarmup($0) }),
              let workingLoad = entry.orderedSets.first?.prescribedSuggestedLoad ?? entry.prescribedSuggestedLoad
        else { return }

        let warmups = scheme.steps.enumerated().map { index, step in
            let set = ExerciseSet(
                repetitions: Float(step.repetitions),
                weight: Float(workingLoad * step.percentage),
                setType: .warmup,
                orderIndex: index,
                usedMetric: entry.usedMetric
            )
            set.prescribedSetType = .warmup
            set.prescribedRepetitions = step.repetitions
            set.prescribedSuggestedLoad = workingLoad * step.percentage
            set.prescribedSuggestedLoadType = entry.prescribedSuggestedLoadType
            set.prescribedUnroundedLoad = workingLoad * step.percentage
            set.prescribedReferenceValue = Double(
                UnitConversion.weight(
                    Float(workingLoad),
                    from: entry.orderedSets.first?.prescribedSuggestedLoadType
                        ?? entry.prescribedSuggestedLoadType
                        ?? .kg,
                    to: .kg
                )
            )
            set.prescriptionLoadExplanation = "Generated warm-up at \(Int((step.percentage * 100).rounded()))% of the first working load."
            set.prescribedRestSeconds = step.restSeconds
            set.prescriptionNotes = generatedWarmupNote
            return set
        }

        // Renumber before assigning: the fresh warm-ups and existing working
        // sets both start at zero, so normalization must see one ordered list.
        let combined = warmups + entry.orderedSets
        for (index, set) in combined.enumerated() { set.orderIndex = index }
        entry.sets = combined
        entry.prescribedSets = combined.count
    }
}
#endif
