import Foundation

/// Validates strength domain entities within a backup archive:
/// exercises, templates, workouts, set metrics, and execution blocks.
enum StrengthBackupValidator {
    static func validate(_ dto: BackupDTO) throws {
        let currentArchive = CurrentBackupArchive(adapting: dto)
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
            }
        }
    }
}
