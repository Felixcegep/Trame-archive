import Foundation

/// Validates strength domain entities within a backup archive:
/// exercises, templates, workouts, set metrics, and execution blocks.
nonisolated enum StrengthBackupValidator {
    static func validate(_ dto: BackupDTO) throws {
        try validateWorkoutLifecycle(dto.workouts)
        let currentArchive = try CurrentBackupArchive(adapting: dto)
        let workoutArchive = currentArchive.workout

        let exerciseNames = workoutArchive.exercises.map { $0.dto.name }
        if dto.version < BackupDTO.programVersion {
            guard Set(exerciseNames).count == exerciseNames.count else {
                let duplicate: String = Dictionary(grouping: exerciseNames, by: \.self)
                    .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
                throw BackupValidationError.duplicateExerciseName(duplicate)
            }
        }

        let availableExerciseNames = Set(exerciseNames)

        for template in workoutArchive.templates {
            for entry in template.dto.templateExercises {
                guard availableExerciseNames.contains(entry.exerciseName) else {
                    throw BackupValidationError.missingExercise(entry.exerciseName)
                }
            }
        }

        for workout in workoutArchive.workouts {
            for entry in workout.dto.exercises {
                guard availableExerciseNames.contains(entry.exerciseName) else {
                    throw BackupValidationError.missingExercise(entry.exerciseName)
                }
                for set in entry.sets {
                    try validateBaseSet(set)
                }
            }
        }
    }

    /// The raw DTO is the trust boundary for performed-workout state. Validate
    /// it before the compatibility archive can materialize an enum value, so
    /// unknown values and impossible lifecycle combinations cannot be turned
    /// into completed history during restore.
    private static func validateWorkoutLifecycle(_ workouts: [WorkoutDTO]) throws {
        var activeWorkoutCount = 0

        for workout in workouts {
            guard let status = WorkoutStatus(rawValue: workout.status) else {
                throw BackupValidationError.invalidIdentifier("workout status")
            }
            guard (status == .active) == (workout.endTime == nil) else {
                throw BackupValidationError.invalidIdentifier("workout lifecycle")
            }
            if status == .active {
                activeWorkoutCount += 1
            }
        }

        guard activeWorkoutCount <= 1 else {
            throw BackupValidationError.invalidIdentifier("active workout")
        }
    }

    /// Validates the portable set fields that existed before the specialized
    /// strength-expansion validator. Zero remains legal for incomplete and
    /// legacy technique rows; negative and non-finite values are never valid
    /// performed or prescribed evidence.
    static func validateBaseSet(_ set: ExerciseSetDTO) throws {
        let optionalNonnegativeValues = [
            set.duration,
            set.distance.map { Double($0) },
            set.calories,
            set.prescribedSuggestedLoad,
            set.prescribedUnroundedLoad,
            set.prescribedReferenceValue,
            set.prescribedCalories,
            set.prescribedVelocityMinimum,
            set.prescribedVelocityMaximum
        ]
        guard set.orderIndex >= 0,
              set.repetition.isFinite,
              set.repetition >= 0,
              set.weight.isFinite,
              set.weight >= 0,
              optionalNonnegativeValues.allSatisfy({ $0.map { $0.isFinite && $0 >= 0 } ?? true }),
              WeightType(rawValue: set.weightType) != nil,
              DistanceType(rawValue: set.distanceType) != nil,
              UnitSystem(rawValue: set.usedMetric) != nil,
              SetType(rawValue: set.setType) != nil,
              set.rpe.map({ $0.isFinite && (1...10).contains($0) }) ?? true,
              set.rir.map({ (0...6).contains($0) }) ?? true,
              set.prescribedRPE.map({ $0.isFinite && (1...10).contains($0) }) ?? true,
              set.prescribedRIR.map({ $0 >= 0 }) ?? true,
              set.prescribedVelocityLossStopPercent.map({ $0.isFinite && (0...100).contains($0) }) ?? true,
              set.prescribedRepetitions.map({ $0 >= 0 }) ?? true,
              set.prescribedRepRangeMinimum.map({ $0 >= 0 }) ?? true,
              set.prescribedRepRangeMaximum.map({ $0 >= 0 }) ?? true,
              set.prescribedRestSeconds.map({ $0 >= 0 }) ?? true,
              set.prescribedSuggestedLoadType.map({ WeightType(rawValue: $0) != nil }) ?? true,
              set.prescribedSetType.map({ SetType(rawValue: $0) != nil }) ?? true
        else {
            throw BackupValidationError.invalidIdentifier("exercise set metrics")
        }

        if let minimum = set.prescribedRepRangeMinimum,
           let maximum = set.prescribedRepRangeMaximum,
           minimum > maximum {
            throw BackupValidationError.invalidIdentifier("exercise set repetition range")
        }
        if let minimum = set.prescribedVelocityMinimum,
           let maximum = set.prescribedVelocityMaximum,
           minimum > maximum {
            throw BackupValidationError.invalidIdentifier("exercise set velocity range")
        }
    }
}
