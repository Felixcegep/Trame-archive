import Foundation
import SwiftData

enum GeneratedWorkoutStartError: Error, Equatable {
    case activeWorkoutExists
    case emptyDraft
    case persistenceFailed
}

/// Turns a validated generated prescription into one ordinary active workout
/// without creating a hidden `WorkoutTemplate`. The temporary
/// `TemplateExercise` instances below are never inserted or related to a
/// template; they are used solely to reuse the app's established prescription
/// snapshot constructor for each `ExerciseEntry`.
@MainActor
enum GeneratedWorkoutStartService {
    static func start(
        _ draft: ValidatedWorkoutDraft,
        using modelContext: ModelContext,
        unitSystem: UnitSystem
    ) throws -> Workout {
        guard !draft.exercises.isEmpty else { throw GeneratedWorkoutStartError.emptyDraft }
        do {
            guard try modelContext.fetch(FetchDescriptor<Workout>()).contains(where: { $0.status == .active }) == false else {
                throw GeneratedWorkoutStartError.activeWorkoutExists
            }
        } catch let error as GeneratedWorkoutStartError {
            throw error
        } catch {
            throw GeneratedWorkoutStartError.persistenceFailed
        }

        let workout = Workout(name: draft.name)
        for (index, prescription) in draft.exercises.enumerated() {
            let transientTemplateExercise = TemplateExercise(
                exercise: prescription.exercise,
                order: index,
                targetSets: prescription.targetSets,
                repRangeMinimum: prescription.repRangeMinimum,
                repRangeMaximum: prescription.repRangeMaximum,
                restSeconds: prescription.restSeconds,
                targetRPE: prescription.targetRPE,
                targetRIR: prescription.targetRIR,
                notes: prescription.notes,
                supersetGroupID: prescription.supersetGroupID
            )
            workout.exercises.append(
                ExerciseEntry(
                    from: transientTemplateExercise,
                    orderIndex: index,
                    usedMetric: unitSystem,
                    supersetGroupID: prescription.supersetGroupID
                )
            )
        }

        modelContext.insert(workout)
        guard modelContext.saveOrRollback() else {
            throw GeneratedWorkoutStartError.persistenceFailed
        }
        return workout
    }
}
