import Foundation

enum WorkoutDraftValidationError: Error, Equatable, Sendable {
    case noEligibleExercises
}

/// Deterministic last boundary before generated data reaches existing workout
/// creation. It always re-resolves ids against the latest live catalogue so a
/// model response can neither revive an archived exercise nor persist a stale
/// identifier after the generation task suspended.
@MainActor
enum WorkoutDraftValidator {
    static let setsRange = 1...10
    static let repetitionsRange = 1...100
    static let restSecondsRange = 0...600
    static let estimatedDurationRange = 10...180
    static let maximumExercises = 12

    static func validate(
        _ draft: GeneratedWorkoutDraft,
        against exercises: [Exercise]
    ) throws -> ValidatedWorkoutDraft {
        let currentExercises = Dictionary(uniqueKeysWithValues: exercises
            .filter { !$0.isArchived }
            .map { ($0.id, $0) })
        var seenIDs = Set<UUID>()
        var warnings: [WorkoutDraftValidationWarning] = []
        var validated: [ValidatedWorkoutExercise] = []
        var rawGroupIDs: [String?] = []

        for generated in draft.exercises.prefix(maximumExercises) {
            guard let exercise = currentExercises[generated.exerciseID] else {
                warnings.append(.ignoredUnknownOrArchivedExercise(generated.exerciseID))
                continue
            }
            guard seenIDs.insert(generated.exerciseID).inserted else {
                warnings.append(.ignoredDuplicateExercise(generated.exerciseID))
                continue
            }

            let prescription = validatedPrescription(generated, for: exercise)
            if prescription.wasAdjusted { warnings.append(.adjustedPrescription(generated.exerciseID)) }
            validated.append(
                ValidatedWorkoutExercise(
                    exercise: exercise,
                    targetSets: prescription.sets,
                    repRangeMinimum: prescription.minimumRepetitions,
                    repRangeMaximum: prescription.maximumRepetitions,
                    restSeconds: prescription.restSeconds,
                    targetRIR: prescription.targetRIR,
                    targetRPE: prescription.targetRPE,
                    notes: generated.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    supersetGroupID: nil
                )
            )
            rawGroupIDs.append(generated.groupID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        }

        guard !validated.isEmpty else { throw WorkoutDraftValidationError.noEligibleExercises }
        assignValidSupersets(to: &validated, rawGroupIDs: rawGroupIDs, warnings: &warnings)

        return ValidatedWorkoutDraft(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Personalized Workout",
            estimatedDurationMinutes: min(max(draft.estimatedDurationMinutes, estimatedDurationRange.lowerBound), estimatedDurationRange.upperBound),
            rationale: draft.rationale.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: validated,
            assumptions: draft.assumptions.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty },
            warnings: draft.warnings.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty },
            validationWarnings: warnings
        )
    }

    private static func validatedPrescription(
        _ generated: GeneratedWorkoutExercise,
        for exercise: Exercise
    ) -> (sets: Int, minimumRepetitions: Int, maximumRepetitions: Int, restSeconds: Int, targetRIR: Int?, targetRPE: Double?, wasAdjusted: Bool) {
        let sets = min(max(generated.sets, setsRange.lowerBound), setsRange.upperBound)
        let rest = min(max(generated.restSeconds, restSecondsRange.lowerBound), restSecondsRange.upperBound)
        let rawMinimum = generated.minimumRepetitions ?? 1
        let rawMaximum = generated.maximumRepetitions ?? rawMinimum
        let minimum = min(max(rawMinimum, repetitionsRange.lowerBound), repetitionsRange.upperBound)
        let maximum = max(minimum, min(max(rawMaximum, repetitionsRange.lowerBound), repetitionsRange.upperBound))
        let rir = generated.targetRIR.map { min(max($0, 0), 10) }
        // Preserve one unambiguous effort target. RIR wins deterministically if
        // a malformed response supplies both, matching the app's common setup.
        let rpe = rir == nil ? generated.targetRPE.map { min(max($0, 1), 10) } : nil
        let adjusted = sets != generated.sets
            || rest != generated.restSeconds
            || minimum != rawMinimum
            || maximum != rawMaximum
            || (generated.targetRIR != nil && rir != generated.targetRIR)
            || (generated.targetRPE != nil && rpe != generated.targetRPE)
            || (generated.targetRIR != nil && generated.targetRPE != nil)

        // `TemplateExercise` has rep range columns for every tracking type.
        // For non-rep exercises retain its existing safe neutral placeholder;
        // we do not fabricate a duration prescription the model schema cannot
        // faithfully persist yet.
        if !exercise.trackingType.usesReps {
            return (sets, 1, 1, rest, rir, rpe, adjusted || rawMinimum != 1 || rawMaximum != 1)
        }
        return (sets, minimum, maximum, rest, rir, rpe, adjusted)
    }

    private static func assignValidSupersets(
        to exercises: inout [ValidatedWorkoutExercise],
        rawGroupIDs: [String?],
        warnings: inout [WorkoutDraftValidationWarning]
    ) {
        let indicesByGroup = Dictionary(grouping: rawGroupIDs.enumerated().compactMap { index, groupID in
            groupID.map { ($0, index) }
        }, by: \.0)
        for (rawGroupID, indexes) in indicesByGroup {
            let orderedIndexes = indexes.map(\.1).sorted()
            let contiguous = orderedIndexes.enumerated().allSatisfy { offset, index in
                index == orderedIndexes[0] + offset
            }
            guard orderedIndexes.count >= 2, contiguous else {
                warnings.append(.removedInvalidSuperset(rawGroupID))
                continue
            }
            let groupID = UUID()
            for index in orderedIndexes {
                exercises[index].supersetGroupID = groupID
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
