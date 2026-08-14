import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
/// Applies the small subset of progression actions whose meaning exists only
/// while the performed workout graph is still active.
///
/// This service never saves. `PlanProgressionRecommendationService` owns the
/// surrounding decision transaction, so the prescription mutation, receipt
/// resolution and one persistence save either commit together or roll back
/// together.
@MainActor
enum ActiveWorkoutRecommendationMutationService {
    enum MutationError: Error, Equatable {
        case invalidActionParameters
        case activeWorkoutNotFound
        case exerciseOccurrenceNotFound
        case insufficientRecommendationEvidence
        case successfulDailyMaximumNotFound
        case generatedBackOffMismatch
    }

    /// Returns `false` when this is an ordinary future-plan action. A supported
    /// active action that cannot be truthfully applied throws instead of being
    /// silently treated as a normal state mutation.
    static func applyIfSupported(
        _ recommendation: PlanProgressionRecommendationRecord,
        in context: ModelContext
    ) throws -> Bool {
        let action = try recommendation.action()
        guard case let .endActiveDailyMaximumAndGenerateBackOffs(
            setCount,
            repetitions,
            percentage
        ) = action else {
            return false
        }
        guard setCount > 0, repetitions > 0, percentage > 0, percentage <= 1 else {
            throw MutationError.invalidActionParameters
        }
        guard recommendation.applicationMode == .recommendation,
              recommendation.cadence == .nextSet,
              (recommendation.performance()?.consecutiveMissedAttempts ?? 0) >= 3 else {
            throw MutationError.insufficientRecommendationEvidence
        }

        let workoutID = recommendation.workoutID
        let planRunID = recommendation.planRunID
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate {
                $0.id == workoutID && $0.sourcePlanRunID == planRunID && $0.endTime == nil
            }
        )
        descriptor.fetchLimit = 1
        guard let workout = try context.fetch(descriptor).first,
              workout.status == .active else {
            throw MutationError.activeWorkoutNotFound
        }
        guard let entry = workout.orderedExercises.first(where: {
            $0.progressionKey == recommendation.progressionKey
        }) else {
            throw MutationError.exerciseOccurrenceNotFound
        }

        let successfulAttempts = entry.orderedSets.filter { set in
            guard set.done, isDailyMaximum(set) else { return false }
            if !set.orderedComplexComponents.isEmpty {
                return set.olympicAttemptOutcome == .made
            }
            return set.liftQuality == .excellent || set.liftQuality == .acceptable
        }
        guard let best = successfulAttempts.max(by: {
            canonicalKilograms($0) < canonicalKilograms($1)
        }), canonicalKilograms(best) > 0 else {
            throw MutationError.successfulDailyMaximumNotFound
        }

        // The receipt says to end further maximum attempts, not that they were
        // performed. Remove only incomplete attempt prescriptions; completed
        // made/missed evidence remains immutable.
        let incompleteMaximums = entry.sets.filter {
            !$0.done && isDailyMaximum($0)
        }
        let incompleteMaximumIDs = Set(incompleteMaximums.map(\.id))
        for set in incompleteMaximums {
            context.delete(set)
        }
        entry.sets.removeAll { incompleteMaximumIDs.contains($0.id) }

        for set in entry.sets where isDailyMaximum(set) {
            set.isSelectedDailyMaximum = set.id == best.id
        }

        let generatedDefinitions = (0..<setCount).map { index in
            SetPrescriptionDefinition(
                orderIndex: index,
                role: .backOff,
                repetitions: .fixed(repetitions),
                load: LoadPrescription(
                    reference: LoadReference(
                        kind: .dailyMaximum,
                        exposureKey: recommendation.progressionKey
                    ),
                    percentage: percentage
                ),
                progressionEligible: false,
                notes: "Generated after accepted daily-maximum stop recommendation.",
                generatesAfterSourceCompletion: true
            )
        }
        let decoder = JSONDecoder()
        var deferred = entry.deferredBackOffDefinitionsData.flatMap {
            try? decoder.decode([SetPrescriptionDefinition].self, from: $0)
        } ?? []
        deferred.append(contentsOf: generatedDefinitions)
        entry.deferredBackOffDefinitionsData = try JSONEncoder().encode(deferred)

        ProgramPrescriptionSnapshotService.refreshDerivedLoads(for: workout)

        let generatedIDs = Set(generatedDefinitions.map(\.id))
        let generatedSets = entry.orderedSets.filter {
            $0.generatedBackOffDefinitionID.map(generatedIDs.contains) == true
        }
        guard generatedSets.count == setCount,
              generatedSets.allSatisfy({ set in
                  !set.done
                      && set.prescribedSetType == .backoff
                      && set.prescribedRepetitions == repetitions
                      && set.prescribedSuggestedLoad != nil
              }) else {
            throw MutationError.generatedBackOffMismatch
        }

        entry.prescribedSets = entry.orderedSets.filter {
            $0.prescribedSetType != .warmup && $0.setType != .warmup
        }.count
        entry.normalizeSetOrder()
        return true
    }

    private static func isDailyMaximum(_ set: ExerciseSet) -> Bool {
        set.prescribedSetType == .dailyMaximum || set.setType == .dailyMaximum
    }

    private static func canonicalKilograms(_ set: ExerciseSet) -> Double {
        Double(UnitConversion.weight(set.weight, from: set.weightType, to: .kg))
    }
}
#endif
