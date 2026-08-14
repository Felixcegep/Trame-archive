import Foundation

/// Internal compatibility boundary for the workout-facing portion of a
/// portable backup. `BackupDTO` remains the public v1-v25 JSON contract; this
/// value records the current semantic interpretation before validation and
/// materialization.
///
/// The first slice deliberately covers only the exercise catalogue, workout
/// templates, and performed workout history. Other domains continue to read
/// their DTOs directly until they receive their own evidence-backed adapter.
nonisolated struct CurrentBackupArchive {
    let sourceVersion: Int
    let workout: CurrentWorkoutBackupArchive

    init(adapting backup: BackupDTO) throws {
        sourceVersion = backup.version
        workout = CurrentWorkoutBackupArchive(
            exercises: backup.exercises.map(CurrentExerciseArchive.init),
            templates: backup.templates.map(CurrentWorkoutTemplateArchive.init),
            workouts: try backup.workouts.map(CurrentWorkoutHistoryArchive.init)
        )
    }
}

nonisolated struct CurrentWorkoutBackupArchive {
    let exercises: [CurrentExerciseArchive]
    let templates: [CurrentWorkoutTemplateArchive]
    let workouts: [CurrentWorkoutHistoryArchive]
}

/// Current typed interpretation of catalogue defaults. A missing legacy UUID
/// remains `nil`; materialization retains the existing seeded-ID/new-UUID rule
/// rather than inventing portable history.
nonisolated struct CurrentExerciseArchive {
    let dto: ExerciseTemplateDTO
    let stableID: UUID?
    let category: ExerciseCategory
    let trackingType: TrackingType
    let equipmentType: EquipmentType
    let resistanceType: ResistanceType?
    let movementPattern: MovementPattern?
    let forceType: ForceType?
    let mechanics: ExerciseMechanics?
    let laterality: Laterality
    let repCountingStyle: RepCountingStyle
    let weightEntryStyle: WeightEntryStyle
    let loadUnitCount: Int
    let gripStyle: GripStyle?
    let stance: ExerciseStance?
    let rangeOfMotion: RangeOfMotion?
    let difficulty: Difficulty

    init(_ dto: ExerciseTemplateDTO) {
        self.dto = dto
        stableID = dto.id.flatMap(UUID.init(uuidString:))
        category = dto.category.flatMap(ExerciseCategory.init(rawValue:)) ?? .strength
        trackingType = TrackingType(rawValue: dto.trackingType) ?? .weightAndReps
        equipmentType = dto.equipmentType.flatMap(EquipmentType.init(rawValue:)) ?? .other
        resistanceType = dto.resistanceType.flatMap(ResistanceType.init(rawValue:))
        movementPattern = dto.movementPattern.flatMap(MovementPattern.init(rawValue:))
        forceType = dto.forceType.flatMap(ForceType.init(rawValue:))
        mechanics = dto.mechanics.flatMap(ExerciseMechanics.init(rawValue:))
        laterality = dto.laterality.flatMap(Laterality.init(rawValue:)) ?? .bilateral
        repCountingStyle = dto.repCountingStyle.flatMap(RepCountingStyle.init(rawValue:)) ?? .total
        weightEntryStyle = dto.weightEntryStyle.flatMap(WeightEntryStyle.init(rawValue:)) ?? .totalLoad
        loadUnitCount = dto.loadUnitCount ?? 1
        gripStyle = dto.gripStyle.flatMap(GripStyle.init(rawValue:))
        stance = dto.stance.flatMap(ExerciseStance.init(rawValue:))
        rangeOfMotion = dto.rangeOfMotion.flatMap(RangeOfMotion.init(rawValue:))
        difficulty = dto.difficulty.flatMap(Difficulty.init(rawValue:)) ?? .beginner
    }
}

nonisolated struct CurrentWorkoutTemplateArchive {
    let dto: WorkoutTemplateDTO
    let exercises: [CurrentTemplateExerciseArchive]

    init(_ dto: WorkoutTemplateDTO) {
        self.dto = dto
        exercises = dto.templateExercises.map(CurrentTemplateExerciseArchive.init)
    }
}

nonisolated struct CurrentTemplateExerciseArchive {
    let dto: TemplateExerciseDTO
    let progressionRule: ProgressionRule
    let supersetGroupID: UUID?
    let executionBlockID: UUID?
    let stimulus: TrainingStimulus?

    init(_ dto: TemplateExerciseDTO) {
        self.dto = dto
        progressionRule = dto.progressionRule.flatMap(ProgressionRule.init(rawValue:)) ?? .doubleProgression
        supersetGroupID = dto.supersetGroupID.flatMap(UUID.init(uuidString:))
        executionBlockID = dto.executionBlockID.flatMap(UUID.init(uuidString:))
        // Absence stays absent. This is an authored semantic, not a default.
        stimulus = dto.stimulus.flatMap(TrainingStimulus.init(rawValue:))
    }
}

nonisolated struct CurrentWorkoutHistoryArchive {
    let dto: WorkoutDTO
    let status: WorkoutStatus
    let entries: [CurrentExerciseEntryArchive]

    init(_ dto: WorkoutDTO) throws {
        guard let status = WorkoutStatus(rawValue: dto.status) else {
            throw BackupValidationError.invalidIdentifier("workout status")
        }
        self.dto = dto
        self.status = status
        entries = dto.exercises.map(CurrentExerciseEntryArchive.init)
    }
}

nonisolated struct CurrentExerciseEntryArchive {
    let dto: ExerciseEntryDTO
    let usedMetric: UnitSystem
    let historicalNameSnapshot: String?
    let explicitHistoricalExerciseID: UUID?
    let trackingTypeSnapshot: TrackingType?
    let lateralitySnapshot: Laterality?
    let repCountingStyleSnapshot: RepCountingStyle?
    let weightEntryStyleSnapshot: WeightEntryStyle?
    let loadUnitCountSnapshot: Int?

    init(_ dto: ExerciseEntryDTO) {
        self.dto = dto
        usedMetric = UnitSystem(rawValue: dto.usedMetric) ?? .metric
        historicalNameSnapshot = dto.nameSnapshot.flatMap { $0.isEmpty ? nil : $0 }
        explicitHistoricalExerciseID = dto.exerciseIDSnapshot.flatMap(UUID.init(uuidString:))
        trackingTypeSnapshot = dto.trackingTypeSnapshot.flatMap(TrackingType.init(rawValue:))
        lateralitySnapshot = dto.lateralitySnapshot.flatMap(Laterality.init(rawValue:))
        repCountingStyleSnapshot = dto.repCountingStyleSnapshot.flatMap(RepCountingStyle.init(rawValue:))
        weightEntryStyleSnapshot = dto.weightEntryStyleSnapshot.flatMap(WeightEntryStyle.init(rawValue:))
        loadUnitCountSnapshot = dto.loadUnitCountSnapshot
    }
}
