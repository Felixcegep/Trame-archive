import Foundation
import SwiftData

struct PreferencesDTO: Codable {
    let darkMode: Bool
    let restTimer: Int
    let unitSystem: String
}

struct ExerciseTemplateDTO: Codable {
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]?
    let category: String?
    let trackingType: String
    let equipmentType: String?
    let resistanceType: String?
    let movementPattern: String?
    let difficulty: String?
    let tags: [String]
    let isFavorite: Bool
    let isPlateLoaded: Bool
    let isCustom: Bool
    let isArchived: Bool
    var forceType: String? = nil
    var mechanics: String? = nil
    var laterality: String? = nil
    var repCountingStyle: String? = nil
    var weightEntryStyle: String? = nil
    var loadUnitCount: Int? = nil
    var gripStyle: String? = nil
    var stance: String? = nil
    var rangeOfMotion: String? = nil
    var setupAngleDegrees: Int? = nil
    var variationFamilyID: String? = nil
}

struct ExerciseRelationshipDTO: Codable {
    let sourceExerciseName: String
    let targetExerciseName: String
    let type: String
}

struct TemplateExerciseDTO: Codable {
    let exerciseName: String
    let orderIndex: Int
    let targetSets: Int
    let repRangeMinimum: Int
    let repRangeMaximum: Int
    let restSeconds: Int
    let targetRPE: Double?
    let targetRIR: Int?
    let notes: String?
    let progressionRule: String?
    var supersetGroupID: String? = nil
}

struct WorkoutTemplateDTO: Codable {
    let name: String
    let templateExercises: [TemplateExerciseDTO]
}

struct WorkoutCollectionDTO: Codable {
    let name: String
    let templateNames: [String]
}

struct ExerciseSetDTO: Codable {
    let orderIndex: Int
    let weightType: String
    let distanceType: String
    let repetition: Float
    let weight: Float
    let duration: Double?
    let distance: Float?
    let done: Bool
    let rpe: Int?
    let setType: String
    let usedMetric: String
    var prescribedSetType: String? = nil
    var prescribedRepetitions: Int? = nil
    var prescribedRepRangeMinimum: Int? = nil
    var prescribedRepRangeMaximum: Int? = nil
    var prescribedSuggestedLoad: Double? = nil
    var prescribedSuggestedLoadType: String? = nil
    var prescribedRestSeconds: Int? = nil
    var prescribedRPE: Double? = nil
    var prescribedRIR: Int? = nil
    var isPrescribedOptional: Bool? = nil
    var prescriptionNotes: String? = nil
}

struct ExerciseEntryDTO: Codable {
    let orderIndex: Int
    let comment: String?
    let exerciseName: String
    let usedMetric: String
    let sets: [ExerciseSetDTO]
    
    let prescribedSets: Int?
    let prescribedRepRangeMinimum: Int?
    let prescribedRepRangeMaximum: Int?
    let prescribedRestSeconds: Int?
    let prescribedRPE: Double?
    let prescribedRIR: Int?
    let prescriptionNotes: String?
    let sourcePlannedExerciseID: String?
    let prescribedRole: String?
    let isPrescribedOptional: Bool?
    let prescribedSuggestedLoad: Double?
    let prescribedSuggestedLoadType: String?
    let prescribedProgressionRule: String?
    let recommendedDecision: String?
    let recommendedLoad: Float?
    let recommendedUnit: String?
    let recommendationPriorLoad: Float?
    let recommendationRequiredSets: Int?
    let recommendationRepCeiling: Int?
    let recommendationCompletedSets: Int?
    let recommendationPriorWorkoutDate: Date?
    let accumulatedActiveDuration: Double?
    let activeDurationStartedAt: Date?
    var supersetGroupID: String? = nil
}

struct WorkoutDTO: Codable {
    let id: String?
    let status: String
    let name: String?
    let notes: String?
    let startTime: Date
    let endTime: Date?
    let restEndDate: Date?
    let pausedRemainingTime: Double?
    let sourceTemplateName: String?
    let sourcePlanID: String?
    let sourcePlanRunID: String?
    let sourcePlanBlockID: String?
    let sourcePlanWeekID: String?
    let sourcePlannedWorkoutID: String?
    let sourcePlanName: String?
    let exercises: [ExerciseEntryDTO]
}

struct PlannedExerciseDTO: Codable {
    let id: String
    let exerciseName: String
    let orderIndex: Int
    let role: String
    let isOptional: Bool
    let targetSets: Int
    let repRangeMinimum: Int
    let repRangeMaximum: Int
    let suggestedLoad: Double?
    let suggestedLoadType: String?
    let restSeconds: Int
    let targetRPE: Double?
    let targetRIR: Int?
    let notes: String?
    let progressionRule: String
    var stimulus: String? = nil
    var alternativeExerciseNames: [String]? = nil
    var supersetGroupID: String? = nil
    var plannedSets: [PlannedSetDTO]? = nil
}

struct PlannedSetDTO: Codable {
    let orderIndex: Int
    let setType: String
    let repetitions: Int?
    let repRangeMinimum: Int?
    let repRangeMaximum: Int?
    let suggestedLoad: Double?
    let suggestedLoadType: String?
    let restSeconds: Int?
    let targetRPE: Double?
    let targetRIR: Int?
    let isOptional: Bool
    let notes: String?
}

struct PlannedWorkoutDTO: Codable {
    let id: String
    let name: String
    let orderIndex: Int
    let dayOffset: Int
    let estimatedDurationSeconds: Int?
    let notes: String?
    let sourceTemplateName: String?
    let plannedExercises: [PlannedExerciseDTO]
}

struct PlanWeekDTO: Codable {
    let id: String
    let weekIndex: Int
    let name: String?
    let notes: String?
    let plannedWorkouts: [PlannedWorkoutDTO]
}

struct PlanBlockDTO: Codable {
    let id: String
    let name: String
    let phaseType: String
    let goal: String?
    let notes: String?
    let deloadVolumeReductionPercent: Int?
    let deloadIntensityReductionPercent: Int?
    let orderIndex: Int
    let weeks: [PlanWeekDTO]
}

struct WorkoutPlanDTO: Codable {
    let id: String
    let name: String
    let goal: String
    let experienceLevel: String
    let requiredEquipment: [String]
    let daysPerWeek: Int
    let durationWeeks: Int
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    let blocks: [PlanBlockDTO]
}

struct PlanWorkoutProgressDTO: Codable {
    let id: String
    let plannedWorkoutID: String
    let plannedWorkoutName: String
    let weekIndex: Int
    let workoutIndex: Int
    let scheduledDate: Date?
    let status: String
    let startedAt: Date?
    let completedAt: Date?
    let skipReason: String?
    let completedWorkoutID: String?
}

struct PlanRunDTO: Codable {
    let id: String
    let sourcePlanID: String
    let sourcePlanName: String
    let planID: String?
    let startDate: Date
    let endDate: Date?
    let status: String
    let currentWeekIndex: Int
    let currentWorkoutIndex: Int
    let createdAt: Date
    let updatedAt: Date
    let workoutProgress: [PlanWorkoutProgressDTO]
}

struct BackupDTO: Codable, Identifiable {
    var id: UUID { UUID() }
    let version: Int
    let preferences: PreferencesDTO
    let exercises: [ExerciseTemplateDTO]
    let templates: [WorkoutTemplateDTO]
    let collections: [WorkoutCollectionDTO]
    let workouts: [WorkoutDTO]
    let plans: [WorkoutPlanDTO]
    let planRuns: [PlanRunDTO]
    let exerciseRelationships: [ExerciseRelationshipDTO]

    init(
        version: Int,
        preferences: PreferencesDTO,
        exercises: [ExerciseTemplateDTO],
        templates: [WorkoutTemplateDTO],
        collections: [WorkoutCollectionDTO],
        workouts: [WorkoutDTO],
        plans: [WorkoutPlanDTO] = [],
        planRuns: [PlanRunDTO] = [],
        exerciseRelationships: [ExerciseRelationshipDTO] = []
    ) {
        self.version = version
        self.preferences = preferences
        self.exercises = exercises
        self.templates = templates
        self.collections = collections
        self.workouts = workouts
        self.plans = plans
        self.planRuns = planRuns
        self.exerciseRelationships = exerciseRelationships
    }

    private enum CodingKeys: String, CodingKey {
        case version, preferences, exercises, templates, collections, workouts, plans, planRuns, exerciseRelationships
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        preferences = try container.decode(PreferencesDTO.self, forKey: .preferences)
        exercises = try container.decode([ExerciseTemplateDTO].self, forKey: .exercises)
        templates = try container.decode([WorkoutTemplateDTO].self, forKey: .templates)
        collections = try container.decode([WorkoutCollectionDTO].self, forKey: .collections)
        workouts = try container.decode([WorkoutDTO].self, forKey: .workouts)
        plans = try container.decodeIfPresent([WorkoutPlanDTO].self, forKey: .plans) ?? []
        planRuns = try container.decodeIfPresent([PlanRunDTO].self, forKey: .planRuns) ?? []
        exerciseRelationships = try container.decodeIfPresent([ExerciseRelationshipDTO].self, forKey: .exerciseRelationships) ?? []
    }
}

/// Shared import boundary used by both the Settings UI and integration tests.
/// Keeping decode, validation, and replacement behind one service prevents the
/// file-import path from drifting away from the data-loss guarantees of Backup v2.
enum BackupImportService {
    static func decodeAndValidate(_ data: Data) throws -> BackupDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupDTO.self, from: data)
        try backup.validate()
        return backup
    }

    @discardableResult
    static func restore(_ backup: BackupDTO, to context: ModelContext) throws -> PreferencesDTO {
        try backup.restore(to: context)
        return backup.preferences
    }
}

enum BackupValidationError: LocalizedError {
    case unsupportedVersion(Int)
    case duplicateExerciseName(String)
    case duplicateTemplateName(String)
    case duplicateIdentifier(String)
    case invalidIdentifier(String)
    case missingExercise(String)
    case missingTemplate(String)
    case missingPlan(String)
    case missingPlannedWorkout(String)
    case missingWorkout(String)
    case invalidExerciseRelationship

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup uses unsupported version \(version)."
        case .duplicateExerciseName(let name):
            return "The backup contains more than one exercise named \(name)."
        case .duplicateTemplateName(let name):
            return "The backup contains more than one workout template named \(name)."
        case .duplicateIdentifier(let identifier):
            return "The backup contains a duplicate \(identifier) identifier."
        case .invalidIdentifier(let identifier):
            return "The backup contains an invalid \(identifier) identifier."
        case .missingExercise(let name):
            return "The backup references an exercise that is missing: \(name)."
        case .missingTemplate(let name):
            return "The backup references a workout template that is missing: \(name)."
        case .missingPlan(let identifier):
            return "The backup references a plan that is missing: \(identifier)."
        case .missingPlannedWorkout(let identifier):
            return "The backup references a planned workout that is missing: \(identifier)."
        case .missingWorkout(let identifier):
            return "The backup references a workout that is missing: \(identifier)."
        case .invalidExerciseRelationship:
            return "The backup contains an invalid exercise relationship."
        }
    }
}

extension BackupDTO {
    static let currentVersion = 4
    static let supersetVersion = 3
    static let planVersion = 2
    static let legacyVersion = 1

    static func create(from context: ModelContext, restTimer: Int, darkMode: Bool, unitSystem: UnitSystem) throws -> BackupDTO {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exerciseDTOs = exercises.map { exercise in
            ExerciseTemplateDTO(
                name: exercise.name,
                primaryMuscles: exercise.primaryMuscles.map(\.rawValue),
                secondaryMuscles: exercise.secondaryMuscles?.map(\.rawValue),
                category: exercise.category?.rawValue,
                trackingType: exercise.trackingType.rawValue,
                equipmentType: exercise.equipmentType?.rawValue,
                resistanceType: exercise.resistanceType?.rawValue,
                movementPattern: exercise.movementPattern?.rawValue,
                difficulty: exercise.difficulty?.rawValue,
                tags: exercise.tags,
                isFavorite: exercise.isFavorite,
                isPlateLoaded: exercise.isPlateLoaded,
                isCustom: exercise.isCustom,
                isArchived: exercise.isArchived,
                forceType: exercise.forceType?.rawValue,
                mechanics: exercise.mechanics?.rawValue,
                laterality: exercise.laterality.rawValue,
                repCountingStyle: exercise.repCountingStyle.rawValue,
                weightEntryStyle: exercise.weightEntryStyle.rawValue,
                loadUnitCount: exercise.loadUnitCount,
                gripStyle: exercise.gripStyle?.rawValue,
                stance: exercise.stance?.rawValue,
                rangeOfMotion: exercise.rangeOfMotion?.rawValue,
                setupAngleDegrees: exercise.setupAngleDegrees,
                variationFamilyID: exercise.variationFamilyID
            )
        }

        let relationshipDTOs: [ExerciseRelationshipDTO] = try context.fetch(FetchDescriptor<ExerciseRelationship>()).compactMap { relationship in
            guard let source = relationship.sourceExercise, let target = relationship.targetExercise else {
                return nil
            }
            return ExerciseRelationshipDTO(
                sourceExerciseName: source.name,
                targetExerciseName: target.name,
                type: relationship.type.rawValue
            )
        }

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let templateDTOs = templates.map { template in
            WorkoutTemplateDTO(
                name: template.name,
                templateExercises: template.templateExercises.map { te in
                    TemplateExerciseDTO(
                        exerciseName: te.exercise.name,
                        orderIndex: te.orderIndex,
                        targetSets: te.targetSets,
                        repRangeMinimum: te.repRangeMinimum,
                        repRangeMaximum: te.repRangeMaximum,
                        restSeconds: te.restSeconds,
                        targetRPE: te.targetRPE,
                        targetRIR: te.targetRIR,
                        notes: te.notes,
                        progressionRule: te.progressionRule.rawValue,
                        supersetGroupID: te.supersetGroupID?.uuidString
                    )
                }
            )
        }

        let collections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        let collectionDTOs = collections.map { collection in
            WorkoutCollectionDTO(
                name: collection.name,
                templateNames: collection.workoutTemplates.map(\.name)
            )
        }

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let workoutDTOs = workouts.map { workout in
            WorkoutDTO(
                id: workout.id.uuidString,
                status: workout.status.rawValue,
                name: workout.name,
                notes: workout.notes,
                startTime: workout.startTime,
                endTime: workout.endTime,
                restEndDate: workout.restEndDate,
                pausedRemainingTime: workout.pausedRemainingTime,
                sourceTemplateName: workout.sourceTemplate?.name,
                sourcePlanID: workout.sourcePlanID?.uuidString,
                sourcePlanRunID: workout.sourcePlanRunID?.uuidString,
                sourcePlanBlockID: workout.sourcePlanBlockID?.uuidString,
                sourcePlanWeekID: workout.sourcePlanWeekID?.uuidString,
                sourcePlannedWorkoutID: workout.sourcePlannedWorkoutID?.uuidString,
                sourcePlanName: workout.sourcePlanName,
                exercises: workout.exercises.map { exercise in
                    let setsDTO = exercise.sets.map { set in
                        ExerciseSetDTO(
                            orderIndex: set.orderIndex,
                            weightType: set.weightType.rawValue,
                            distanceType: set.distanceType.rawValue,
                            repetition: set.repetitions,
                            weight: set.weight,
                            duration: set.duration,
                            distance: set.distance,
                            done: set.done,
                            rpe: set.rpe,
                            setType: set.setType.rawValue,
                            usedMetric: set.usedMetric.rawValue,
                            prescribedSetType: set.prescribedSetType?.rawValue,
                            prescribedRepetitions: set.prescribedRepetitions,
                            prescribedRepRangeMinimum: set.prescribedRepRangeMinimum,
                            prescribedRepRangeMaximum: set.prescribedRepRangeMaximum,
                            prescribedSuggestedLoad: set.prescribedSuggestedLoad,
                            prescribedSuggestedLoadType: set.prescribedSuggestedLoadType?.rawValue,
                            prescribedRestSeconds: set.prescribedRestSeconds,
                            prescribedRPE: set.prescribedRPE,
                            prescribedRIR: set.prescribedRIR,
                            isPrescribedOptional: set.isPrescribedOptional,
                            prescriptionNotes: set.prescriptionNotes
                        )
                    }
                    return ExerciseEntryDTO(
                        orderIndex: exercise.orderIndex,
                        comment: exercise.comment,
                        exerciseName: exercise.exercise.name,
                        usedMetric: exercise.usedMetric.rawValue,
                        sets: setsDTO,
                        prescribedSets: exercise.prescribedSets,
                        prescribedRepRangeMinimum: exercise.prescribedRepRangeMinimum,
                        prescribedRepRangeMaximum: exercise.prescribedRepRangeMaximum,
                        prescribedRestSeconds: exercise.prescribedRestSeconds,
                        prescribedRPE: exercise.prescribedRPE,
                        prescribedRIR: exercise.prescribedRIR,
                        prescriptionNotes: exercise.prescriptionNotes,
                        sourcePlannedExerciseID: exercise.sourcePlannedExerciseID?.uuidString,
                        prescribedRole: exercise.prescribedRole?.rawValue,
                        isPrescribedOptional: exercise.isPrescribedOptional,
                        prescribedSuggestedLoad: exercise.prescribedSuggestedLoad,
                        prescribedSuggestedLoadType: exercise.prescribedSuggestedLoadType?.rawValue,
                        prescribedProgressionRule: exercise.prescribedProgressionRule?.rawValue,
                        recommendedDecision: exercise.recommendedDecision?.rawValue,
                        recommendedLoad: exercise.recommendedLoad,
                        recommendedUnit: exercise.recommendedUnit?.rawValue,
                        recommendationPriorLoad: exercise.recommendationPriorLoad,
                        recommendationRequiredSets: exercise.recommendationRequiredSets,
                        recommendationRepCeiling: exercise.recommendationRepCeiling,
                        recommendationCompletedSets: exercise.recommendationCompletedSets,
                        recommendationPriorWorkoutDate: exercise.recommendationPriorWorkoutDate,
                        accumulatedActiveDuration: exercise.accumulatedActiveDuration,
                        activeDurationStartedAt: exercise.activeDurationStartedAt,
                        supersetGroupID: exercise.supersetGroupID?.uuidString
                    )
                }
            )
        }

        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        let planDTOs = plans.map { plan in
            WorkoutPlanDTO(
                id: plan.id.uuidString,
                name: plan.name,
                goal: plan.goal.rawValue,
                experienceLevel: plan.experienceLevel.rawValue,
                requiredEquipment: plan.requiredEquipment.map(\.rawValue),
                daysPerWeek: plan.daysPerWeek,
                durationWeeks: plan.durationWeeks,
                notes: plan.notes,
                createdAt: plan.createdAt,
                updatedAt: plan.updatedAt,
                isArchived: plan.isArchived,
                blocks: plan.orderedBlocks.map { block in
                    PlanBlockDTO(
                        id: block.id.uuidString,
                        name: block.name,
                        phaseType: block.phaseType.rawValue,
                        goal: block.goal,
                        notes: block.notes,
                        deloadVolumeReductionPercent: block.deloadVolumeReductionPercent,
                        deloadIntensityReductionPercent: block.deloadIntensityReductionPercent,
                        orderIndex: block.orderIndex,
                        weeks: block.orderedWeeks.map { week in
                            PlanWeekDTO(
                                id: week.id.uuidString,
                                weekIndex: week.weekIndex,
                                name: week.name,
                                notes: week.notes,
                                plannedWorkouts: week.orderedPlannedWorkouts.map { plannedWorkout in
                                    PlannedWorkoutDTO(
                                        id: plannedWorkout.id.uuidString,
                                        name: plannedWorkout.name,
                                        orderIndex: plannedWorkout.orderIndex,
                                        dayOffset: plannedWorkout.dayOffset,
                                        estimatedDurationSeconds: plannedWorkout.estimatedDurationSeconds,
                                        notes: plannedWorkout.notes,
                                        sourceTemplateName: plannedWorkout.sourceTemplate?.name,
                                        plannedExercises: plannedWorkout.orderedPlannedExercises.map { plannedExercise in
                                            PlannedExerciseDTO(
                                                id: plannedExercise.id.uuidString,
                                                exerciseName: plannedExercise.exercise.name,
                                                orderIndex: plannedExercise.orderIndex,
                                                role: plannedExercise.role.rawValue,
                                                isOptional: plannedExercise.isOptional,
                                                targetSets: plannedExercise.targetSets,
                                                repRangeMinimum: plannedExercise.repRangeMinimum,
                                                repRangeMaximum: plannedExercise.repRangeMaximum,
                                                suggestedLoad: plannedExercise.suggestedLoad,
                                                suggestedLoadType: plannedExercise.suggestedLoadType?.rawValue,
                                                restSeconds: plannedExercise.restSeconds,
                                                targetRPE: plannedExercise.targetRPE,
                                                targetRIR: plannedExercise.targetRIR,
                                                notes: plannedExercise.notes,
                                                progressionRule: plannedExercise.progressionRule.rawValue,
                                                stimulus: plannedExercise.resolvedStimulus.rawValue,
                                                alternativeExerciseNames: plannedExercise.alternatives
                                                    .sorted { $0.orderIndex < $1.orderIndex }
                                                    .map { $0.exercise.name },
                                                supersetGroupID: plannedExercise.supersetGroupID?.uuidString,
                                                plannedSets: plannedExercise.orderedPlannedSets.map { plannedSet in
                                                    PlannedSetDTO(
                                                        orderIndex: plannedSet.orderIndex,
                                                        setType: plannedSet.setType.rawValue,
                                                        repetitions: plannedSet.repetitions,
                                                        repRangeMinimum: plannedSet.repRangeMinimum,
                                                        repRangeMaximum: plannedSet.repRangeMaximum,
                                                        suggestedLoad: plannedSet.suggestedLoad,
                                                        suggestedLoadType: plannedSet.suggestedLoadType?.rawValue,
                                                        restSeconds: plannedSet.restSeconds,
                                                        targetRPE: plannedSet.targetRPE,
                                                        targetRIR: plannedSet.targetRIR,
                                                        isOptional: plannedSet.isOptional,
                                                        notes: plannedSet.notes
                                                    )
                                                }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            )
        }

        let planRuns = try context.fetch(FetchDescriptor<PlanRun>())
        let planRunDTOs = planRuns.map { run in
            PlanRunDTO(
                id: run.id.uuidString,
                sourcePlanID: run.sourcePlanID.uuidString,
                sourcePlanName: run.sourcePlanName,
                planID: run.plan?.id.uuidString,
                startDate: run.startDate,
                endDate: run.endDate,
                status: run.status.rawValue,
                currentWeekIndex: run.currentWeekIndex,
                currentWorkoutIndex: run.currentWorkoutIndex,
                createdAt: run.createdAt,
                updatedAt: run.updatedAt,
                workoutProgress: run.orderedWorkoutProgress.map { progress in
                    PlanWorkoutProgressDTO(
                        id: progress.id.uuidString,
                        plannedWorkoutID: progress.plannedWorkoutID.uuidString,
                        plannedWorkoutName: progress.plannedWorkoutName,
                        weekIndex: progress.weekIndex,
                        workoutIndex: progress.workoutIndex,
                        scheduledDate: progress.scheduledDate,
                        status: progress.status.rawValue,
                        startedAt: progress.startedAt,
                        completedAt: progress.completedAt,
                        skipReason: progress.skipReason,
                        completedWorkoutID: progress.completedWorkout?.id.uuidString
                    )
                }
            )
        }

        return BackupDTO(
            version: currentVersion,
            preferences: PreferencesDTO(
                darkMode: darkMode,
                restTimer: restTimer,
                unitSystem: unitSystem.rawValue
            ),
            exercises: exerciseDTOs,
            templates: templateDTOs,
            collections: collectionDTOs,
            workouts: workoutDTOs,
            plans: planDTOs,
            planRuns: planRunDTOs,
            exerciseRelationships: relationshipDTOs
        )
    }

    func restore(to context: ModelContext) throws {
        try restore(to: context, beforeCommit: nil)
    }

    /// Restores the validated graph as one replacement transaction. The
    /// checkpoint is internal so integration tests can simulate an interruption
    /// immediately before the final save without exposing failure hooks to UI.
    func restore(
        to context: ModelContext,
        beforeCommit: (() throws -> Void)?
    ) throws {
        try validate()
        do {
            try context.clearAllGymData(saveChanges: false)

            let builtInExercises = ExerciseSeedData.templates()
            for exercise in builtInExercises {
                context.insert(exercise)
            }

            var exerciseMap = Dictionary(uniqueKeysWithValues: builtInExercises.map { ($0.name, $0) })

            for exerciseDTO in self.exercises {
            let primaryMuscles = exerciseDTO.primaryMuscles.compactMap { Muscle(rawValue: $0) }
            let secondaryMuscles = exerciseDTO.secondaryMuscles?.compactMap { Muscle(rawValue: $0) }
            let category = exerciseDTO.category.flatMap { ExerciseCategory(rawValue: $0) } ?? .strength
            let trackingType = TrackingType(rawValue: exerciseDTO.trackingType) ?? .weightAndReps
            let equipmentType = exerciseDTO.equipmentType.flatMap { EquipmentType(rawValue: $0) } ?? .other
            let resistanceType = exerciseDTO.resistanceType.flatMap { ResistanceType(rawValue: $0) }
            let movementPattern = exerciseDTO.movementPattern.flatMap { MovementPattern(rawValue: $0) }
            let forceType = exerciseDTO.forceType.flatMap { ForceType(rawValue: $0) }
            let mechanics = exerciseDTO.mechanics.flatMap { ExerciseMechanics(rawValue: $0) }
            let laterality = exerciseDTO.laterality.flatMap { Laterality(rawValue: $0) } ?? .bilateral
            let repCountingStyle = exerciseDTO.repCountingStyle.flatMap { RepCountingStyle(rawValue: $0) } ?? .total
            let weightEntryStyle = exerciseDTO.weightEntryStyle.flatMap { WeightEntryStyle(rawValue: $0) } ?? .totalLoad
            let loadUnitCount = exerciseDTO.loadUnitCount ?? 1
            let gripStyle = exerciseDTO.gripStyle.flatMap { GripStyle(rawValue: $0) }
            let stance = exerciseDTO.stance.flatMap { ExerciseStance(rawValue: $0) }
            let rangeOfMotion = exerciseDTO.rangeOfMotion.flatMap { RangeOfMotion(rawValue: $0) }
            let difficulty = exerciseDTO.difficulty.flatMap { Difficulty(rawValue: $0) } ?? .beginner

            if let existing = exerciseMap[exerciseDTO.name] {
                existing.isFavorite = exerciseDTO.isFavorite
                existing.isArchived = exerciseDTO.isArchived
                existing.isPlateLoaded = exerciseDTO.isPlateLoaded
            } else {
                let newExercise = Exercise(
                    name: exerciseDTO.name,
                    primaryMuscles: primaryMuscles,
                    secondaryMuscles: secondaryMuscles,
                    category: category,
                    trackingType: trackingType,
                    equipmentType: equipmentType,
                    resistanceType: resistanceType,
                    movementPattern: movementPattern,
                    forceType: forceType,
                    mechanics: mechanics,
                    gripStyle: gripStyle,
                    stance: stance,
                    rangeOfMotion: rangeOfMotion,
                    setupAngleDegrees: exerciseDTO.setupAngleDegrees,
                    variationFamilyID: exerciseDTO.variationFamilyID,
                    difficulty: difficulty,
                    tags: exerciseDTO.tags,
                    isFavorite: exerciseDTO.isFavorite,
                    isPlateLoaded: exerciseDTO.isPlateLoaded,
                    isCustom: exerciseDTO.isCustom,
                    isArchived: exerciseDTO.isArchived,
                    laterality: laterality,
                    repCountingStyle: repCountingStyle,
                    weightEntryStyle: weightEntryStyle,
                    loadUnitCount: loadUnitCount
                )
                context.insert(newExercise)
                exerciseMap[newExercise.name] = newExercise
            }

            }

            for relationshipDTO in exerciseRelationships {
                guard
                    let source = exerciseMap[relationshipDTO.sourceExerciseName],
                    let target = exerciseMap[relationshipDTO.targetExerciseName],
                    let type = ExerciseRelationshipType(rawValue: relationshipDTO.type)
                else {
                    throw BackupValidationError.invalidExerciseRelationship
                }
                context.insert(ExerciseRelationship(
                    sourceExercise: source,
                    targetExercise: target,
                    type: type
                ))
            }

            var templateMap: [String: WorkoutTemplate] = [:]
            for templateDTO in self.templates {
            var templateExercises: [TemplateExercise] = []
            
            for teDTO in templateDTO.templateExercises {
                guard let exercise = exerciseMap[teDTO.exerciseName] else { continue }
                let te = TemplateExercise(
                    exercise: exercise,
                    order: teDTO.orderIndex,
                    targetSets: teDTO.targetSets,
                    repRangeMinimum: teDTO.repRangeMinimum,
                    repRangeMaximum: teDTO.repRangeMaximum,
                    restSeconds: teDTO.restSeconds,
                    targetRPE: teDTO.targetRPE,
                    targetRIR: teDTO.targetRIR,
                    notes: teDTO.notes,
                    progressionRule: ProgressionRule(rawValue: teDTO.progressionRule ?? "") ?? .doubleProgression,
                    supersetGroupID: teDTO.supersetGroupID.flatMap(UUID.init(uuidString:))
                )
                te.orderIndex = teDTO.orderIndex
                templateExercises.append(te)
            }
            
            let exercises = templateExercises.map(\.exercise)
            let newTemplate = WorkoutTemplate(
                name: templateDTO.name,
                exercises: exercises,
                templateExercises: templateExercises
            )
            context.insert(newTemplate)
            templateMap[newTemplate.name] = newTemplate
            }

            for collectionDTO in self.collections {
            let templates = collectionDTO.templateNames.compactMap { templateMap[$0] }
            let newCollection = WorkoutCollection(
                name: collectionDTO.name,
                workoutTemplates: templates
            )
            context.insert(newCollection)
            }

            var planMap: [String: WorkoutPlan] = [:]
            for planDTO in plans {
                let blocks = try planDTO.blocks.map { blockDTO in
                    let weeks = try blockDTO.weeks.map { weekDTO in
                        let plannedWorkouts = try weekDTO.plannedWorkouts.map { plannedWorkoutDTO in
                            let plannedExercises = try plannedWorkoutDTO.plannedExercises.map { plannedExerciseDTO in
                                guard let exercise = exerciseMap[plannedExerciseDTO.exerciseName] else {
                                    throw BackupValidationError.missingExercise(plannedExerciseDTO.exerciseName)
                                }
                                let alternativeExercises = (plannedExerciseDTO.alternativeExerciseNames ?? []).compactMap {
                                    exerciseMap[$0]
                                }
                                let plannedExercise = PlannedExercise(
                                    exercise: exercise,
                                    orderIndex: plannedExerciseDTO.orderIndex,
                                    role: ExerciseRole(rawValue: plannedExerciseDTO.role) ?? .main,
                                    isOptional: plannedExerciseDTO.isOptional,
                                    targetSets: plannedExerciseDTO.targetSets,
                                    repRangeMinimum: plannedExerciseDTO.repRangeMinimum,
                                    repRangeMaximum: plannedExerciseDTO.repRangeMaximum,
                                    suggestedLoad: plannedExerciseDTO.suggestedLoad,
                                    suggestedLoadType: plannedExerciseDTO.suggestedLoadType.flatMap(WeightType.init(rawValue:)),
                                    restSeconds: plannedExerciseDTO.restSeconds,
                                    targetRPE: plannedExerciseDTO.targetRPE,
                                    targetRIR: plannedExerciseDTO.targetRIR,
                                    notes: plannedExerciseDTO.notes,
                                    progressionRule: ProgressionRule(rawValue: plannedExerciseDTO.progressionRule) ?? .none,
                                    stimulus: plannedExerciseDTO.stimulus.flatMap(TrainingStimulus.init(rawValue:)) ?? .strength,
                                    alternatives: alternativeExercises.enumerated().map {
                                        PlannedExerciseAlternative(exercise: $0.element, orderIndex: $0.offset)
                                    },
                                    plannedSets: (plannedExerciseDTO.plannedSets ?? []).map { plannedSetDTO in
                                        PlannedSet(
                                            orderIndex: plannedSetDTO.orderIndex,
                                            setType: SetType(rawValue: plannedSetDTO.setType) ?? .normal,
                                            repetitions: plannedSetDTO.repetitions,
                                            repRangeMinimum: plannedSetDTO.repRangeMinimum,
                                            repRangeMaximum: plannedSetDTO.repRangeMaximum,
                                            suggestedLoad: plannedSetDTO.suggestedLoad,
                                            suggestedLoadType: plannedSetDTO.suggestedLoadType.flatMap(WeightType.init(rawValue:)),
                                            restSeconds: plannedSetDTO.restSeconds,
                                            targetRPE: plannedSetDTO.targetRPE,
                                            targetRIR: plannedSetDTO.targetRIR,
                                            isOptional: plannedSetDTO.isOptional,
                                            notes: plannedSetDTO.notes
                                        )
                                    },
                                    supersetGroupID: plannedExerciseDTO.supersetGroupID.flatMap(UUID.init(uuidString:))
                                )
                                plannedExercise.id = try requiredUUID(plannedExerciseDTO.id, named: "planned exercise")
                                return plannedExercise
                            }
                            let plannedWorkout = PlannedWorkout(
                                name: plannedWorkoutDTO.name,
                                orderIndex: plannedWorkoutDTO.orderIndex,
                                dayOffset: plannedWorkoutDTO.dayOffset,
                                estimatedDurationSeconds: plannedWorkoutDTO.estimatedDurationSeconds,
                                notes: plannedWorkoutDTO.notes,
                                sourceTemplate: plannedWorkoutDTO.sourceTemplateName.flatMap { templateMap[$0] },
                                plannedExercises: plannedExercises
                            )
                            plannedWorkout.id = try requiredUUID(plannedWorkoutDTO.id, named: "planned workout")
                            return plannedWorkout
                        }
                        let week = PlanWeek(
                            weekIndex: weekDTO.weekIndex,
                            name: weekDTO.name,
                            notes: weekDTO.notes,
                            plannedWorkouts: plannedWorkouts
                        )
                        week.id = try requiredUUID(weekDTO.id, named: "plan week")
                        return week
                    }
                    let block = PlanBlock(
                        name: blockDTO.name,
                        phaseType: PlanPhaseType(rawValue: blockDTO.phaseType) ?? .accumulation,
                        orderIndex: blockDTO.orderIndex,
                        goal: blockDTO.goal,
                        notes: blockDTO.notes,
                        deloadVolumeReductionPercent: blockDTO.deloadVolumeReductionPercent,
                        deloadIntensityReductionPercent: blockDTO.deloadIntensityReductionPercent,
                        weeks: weeks
                    )
                    block.id = try requiredUUID(blockDTO.id, named: "plan block")
                    return block
                }
                let plan = WorkoutPlan(
                    name: planDTO.name,
                    goal: PlanGoal(rawValue: planDTO.goal) ?? .generalStrength,
                    experienceLevel: PlanExperienceLevel(rawValue: planDTO.experienceLevel) ?? .beginner,
                    requiredEquipment: planDTO.requiredEquipment.compactMap(EquipmentType.init(rawValue:)),
                    daysPerWeek: planDTO.daysPerWeek,
                    durationWeeks: planDTO.durationWeeks,
                    notes: planDTO.notes,
                    blocks: blocks
                )
                plan.id = try requiredUUID(planDTO.id, named: "plan")
                plan.createdAt = planDTO.createdAt
                plan.updatedAt = planDTO.updatedAt
                plan.isArchived = planDTO.isArchived
                context.insert(plan)
                planMap[planDTO.id] = plan
            }

            var workoutMap: [String: Workout] = [:]
            for workoutDTO in self.workouts {
            let status = WorkoutStatus(rawValue: workoutDTO.status) ?? .completed
            let newWorkout = Workout(name: workoutDTO.name, endTime: workoutDTO.endTime)
            if let identifier = workoutDTO.id {
                newWorkout.id = try requiredUUID(identifier, named: "workout")
            }
            newWorkout.status = status
            newWorkout.notes = workoutDTO.notes
            newWorkout.startTime = workoutDTO.startTime
            newWorkout.restEndDate = workoutDTO.restEndDate
            newWorkout.pausedRemainingTime = workoutDTO.pausedRemainingTime
            
            if let templateName = workoutDTO.sourceTemplateName, let template = templateMap[templateName] {
                newWorkout.sourceTemplate = template
            }
            if let planIDStr = workoutDTO.sourcePlanID, let uuid = UUID(uuidString: planIDStr) {
                newWorkout.sourcePlanID = uuid
            }
            if let planRunIDStr = workoutDTO.sourcePlanRunID, let uuid = UUID(uuidString: planRunIDStr) {
                newWorkout.sourcePlanRunID = uuid
            }
            if let planBlockIDStr = workoutDTO.sourcePlanBlockID, let uuid = UUID(uuidString: planBlockIDStr) {
                newWorkout.sourcePlanBlockID = uuid
            }
            if let planWeekIDStr = workoutDTO.sourcePlanWeekID, let uuid = UUID(uuidString: planWeekIDStr) {
                newWorkout.sourcePlanWeekID = uuid
            }
            if let plannedWorkoutIDStr = workoutDTO.sourcePlannedWorkoutID, let uuid = UUID(uuidString: plannedWorkoutIDStr) {
                newWorkout.sourcePlannedWorkoutID = uuid
            }
            newWorkout.sourcePlanName = workoutDTO.sourcePlanName

            var exercises: [ExerciseEntry] = []
            for entryDTO in workoutDTO.exercises {
                guard let exerciseTemplate = exerciseMap[entryDTO.exerciseName] else { continue }
                let usedMetric = UnitSystem(rawValue: entryDTO.usedMetric) ?? .metric
                
                let entry = ExerciseEntry(
                    comment: entryDTO.comment,
                    exercise: exerciseTemplate,
                    orderIndex: entryDTO.orderIndex,
                    usedMetric: usedMetric,
                    supersetGroupID: entryDTO.supersetGroupID.flatMap(UUID.init(uuidString:))
                )
                entry.prescribedSets = entryDTO.prescribedSets
                entry.prescribedRepRangeMinimum = entryDTO.prescribedRepRangeMinimum
                entry.prescribedRepRangeMaximum = entryDTO.prescribedRepRangeMaximum
                entry.prescribedRestSeconds = entryDTO.prescribedRestSeconds
                entry.prescribedRPE = entryDTO.prescribedRPE
                entry.prescribedRIR = entryDTO.prescribedRIR
                entry.prescriptionNotes = entryDTO.prescriptionNotes
                if let specIDStr = entryDTO.sourcePlannedExerciseID, let uuid = UUID(uuidString: specIDStr) {
                    entry.sourcePlannedExerciseID = uuid
                }
                if let roleStr = entryDTO.prescribedRole, let role = ExerciseRole(rawValue: roleStr) {
                    entry.prescribedRole = role
                }
                entry.isPrescribedOptional = entryDTO.isPrescribedOptional
                entry.prescribedSuggestedLoad = entryDTO.prescribedSuggestedLoad
                if let typeStr = entryDTO.prescribedSuggestedLoadType, let wt = WeightType(rawValue: typeStr) {
                    entry.prescribedSuggestedLoadType = wt
                }
                if let ruleStr = entryDTO.prescribedProgressionRule, let rule = ProgressionRule(rawValue: ruleStr) {
                    entry.prescribedProgressionRule = rule
                }
                if let decision = entryDTO.recommendedDecision.flatMap(DoubleProgressionDecision.init(rawValue:)) {
                    entry.recommendedDecision = decision
                }
                entry.recommendedLoad = entryDTO.recommendedLoad
                if let unit = entryDTO.recommendedUnit.flatMap(WeightType.init(rawValue:)) {
                    entry.recommendedUnit = unit
                }
                entry.recommendationPriorLoad = entryDTO.recommendationPriorLoad
                entry.recommendationRequiredSets = entryDTO.recommendationRequiredSets
                entry.recommendationRepCeiling = entryDTO.recommendationRepCeiling
                entry.recommendationCompletedSets = entryDTO.recommendationCompletedSets
                entry.recommendationPriorWorkoutDate = entryDTO.recommendationPriorWorkoutDate
                entry.accumulatedActiveDuration = entryDTO.accumulatedActiveDuration ?? 0
                entry.activeDurationStartedAt = entryDTO.activeDurationStartedAt

                var sets: [ExerciseSet] = []
                for setDTO in entryDTO.sets {
                    let weightType = WeightType(rawValue: setDTO.weightType) ?? .kg
                    let distanceType = DistanceType(rawValue: setDTO.distanceType) ?? .kilometers
                    let setType = SetType(rawValue: setDTO.setType) ?? .normal
                    let setUsedMetric = UnitSystem(rawValue: setDTO.usedMetric) ?? .metric
                    
                    let setObj = ExerciseSet(
                        repetitions: setDTO.repetition,
                        weight: setDTO.weight,
                        duration: setDTO.duration,
                        distance: setDTO.distance,
                        done: setDTO.done,
                        rpe: setDTO.rpe,
                        setType: setType,
                        orderIndex: setDTO.orderIndex,
                        usedMetric: setUsedMetric
                    )
                    setObj.weightType = weightType
                    setObj.distanceType = distanceType
                    setObj.prescribedSetType = setDTO.prescribedSetType.flatMap(SetType.init(rawValue:))
                    setObj.prescribedRepetitions = setDTO.prescribedRepetitions
                    setObj.prescribedRepRangeMinimum = setDTO.prescribedRepRangeMinimum
                    setObj.prescribedRepRangeMaximum = setDTO.prescribedRepRangeMaximum
                    setObj.prescribedSuggestedLoad = setDTO.prescribedSuggestedLoad
                    setObj.prescribedSuggestedLoadType = setDTO.prescribedSuggestedLoadType.flatMap(WeightType.init(rawValue:))
                    setObj.prescribedRestSeconds = setDTO.prescribedRestSeconds
                    setObj.prescribedRPE = setDTO.prescribedRPE
                    setObj.prescribedRIR = setDTO.prescribedRIR
                    setObj.isPrescribedOptional = setDTO.isPrescribedOptional
                    setObj.prescriptionNotes = setDTO.prescriptionNotes
                    sets.append(setObj)
                }
                entry.sets = sets
                exercises.append(entry)
            }
            newWorkout.exercises = exercises
            context.insert(newWorkout)
            if let identifier = workoutDTO.id {
                workoutMap[identifier] = newWorkout
            }
        }

            for runDTO in planRuns {
                let sourcePlanID = try requiredUUID(runDTO.sourcePlanID, named: "plan run source plan")
                let run = PlanRun(
                    sourcePlanID: sourcePlanID,
                    sourcePlanName: runDTO.sourcePlanName,
                    startDate: runDTO.startDate,
                    plan: runDTO.planID.flatMap { planMap[$0] }
                )
                run.id = try requiredUUID(runDTO.id, named: "plan run")
                run.endDate = runDTO.endDate
                run.status = PlanRunStatus(rawValue: runDTO.status) ?? .active
                run.currentWeekIndex = runDTO.currentWeekIndex
                run.currentWorkoutIndex = runDTO.currentWorkoutIndex
                run.createdAt = runDTO.createdAt
                run.updatedAt = runDTO.updatedAt

                for progressDTO in runDTO.workoutProgress {
                    let progress = PlanWorkoutProgress(
                        plannedWorkoutID: try requiredUUID(progressDTO.plannedWorkoutID, named: "plan workout progress"),
                        plannedWorkoutName: progressDTO.plannedWorkoutName,
                        weekIndex: progressDTO.weekIndex,
                        workoutIndex: progressDTO.workoutIndex,
                        scheduledDate: progressDTO.scheduledDate
                    )
                    progress.id = try requiredUUID(progressDTO.id, named: "plan workout progress")
                    progress.status = PlanWorkoutStatus(rawValue: progressDTO.status) ?? .upcoming
                    progress.startedAt = progressDTO.startedAt
                    progress.completedAt = progressDTO.completedAt
                    progress.skipReason = progressDTO.skipReason
                    if let workoutID = progressDTO.completedWorkoutID {
                        progress.completedWorkout = workoutMap[workoutID]
                    }
                    run.workoutProgress.append(progress)
                }
                context.insert(run)
            }
            try beforeCommit?()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func validate() throws {
        guard version == Self.legacyVersion || version == Self.planVersion || version == Self.supersetVersion || version == Self.currentVersion else {
            throw BackupValidationError.unsupportedVersion(version)
        }

        let exerciseNames = exercises.map(\.name)
        guard Set(exerciseNames).count == exerciseNames.count else {
            let duplicate: String = Dictionary(grouping: exerciseNames, by: \.self)
                .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
            throw BackupValidationError.duplicateExerciseName(duplicate)
        }

        let availableExerciseNames = Set(exerciseNames)
        for template in templates {
            for templateExercise in template.templateExercises where !availableExerciseNames.contains(templateExercise.exerciseName) {
                throw BackupValidationError.missingExercise(templateExercise.exerciseName)
            }
        }

        let templateNames = Set(templates.map(\.name))
        guard templateNames.count == templates.count else {
            let duplicate: String = Dictionary(grouping: templates.map(\.name), by: \.self)
                .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
            throw BackupValidationError.duplicateTemplateName(duplicate)
        }
        for collection in collections {
            for templateName in collection.templateNames where !templateNames.contains(templateName) {
                throw BackupValidationError.missingTemplate(templateName)
            }
        }

        for workout in workouts {
            for entry in workout.exercises where !availableExerciseNames.contains(entry.exerciseName) {
                throw BackupValidationError.missingExercise(entry.exerciseName)
            }
        }

        var relationshipKeys = Set<String>()
        for relationship in exerciseRelationships {
            guard
                relationship.sourceExerciseName != relationship.targetExerciseName,
                availableExerciseNames.contains(relationship.sourceExerciseName),
                availableExerciseNames.contains(relationship.targetExerciseName),
                ExerciseRelationshipType(rawValue: relationship.type) != nil
            else {
                throw BackupValidationError.invalidExerciseRelationship
            }

            let key = "\(relationship.sourceExerciseName)|\(relationship.targetExerciseName)|\(relationship.type)"
            guard relationshipKeys.insert(key).inserted else {
                throw BackupValidationError.invalidExerciseRelationship
            }
        }

        guard version != Self.legacyVersion else { return }

        try validateUniqueIdentifiers(plans.map(\.id), named: "plan")
        try validateUniqueIdentifiers(workouts.compactMap(\.id), named: "workout")
        guard workouts.allSatisfy({ $0.id != nil }) else {
            throw BackupValidationError.invalidIdentifier("workout")
        }
        try validateUniqueIdentifiers(planRuns.map(\.id), named: "plan run")

        let planIDs = Set(plans.map(\.id))
        let workoutIDs = Set(workouts.compactMap(\.id))
        var plannedWorkoutIDs = Set<String>()
        var planIDByPlannedWorkout: [String: String] = [:]
        var blockIDs: [String] = []
        var weekIDs: [String] = []
        var plannedExerciseIDs: [String] = []

        for plan in plans {
            guard PlanGoal(rawValue: plan.goal) != nil,
                  PlanExperienceLevel(rawValue: plan.experienceLevel) != nil,
                  plan.requiredEquipment.allSatisfy({ EquipmentType(rawValue: $0) != nil }) else {
                throw BackupValidationError.invalidIdentifier("plan configuration")
            }

            for block in plan.blocks {
                guard PlanPhaseType(rawValue: block.phaseType) != nil else {
                    throw BackupValidationError.invalidIdentifier("plan block phase")
                }
                guard
                    block.deloadVolumeReductionPercent.map({ (0...90).contains($0) }) ?? true,
                    block.deloadIntensityReductionPercent.map({ (0...90).contains($0) }) ?? true
                else {
                    throw BackupValidationError.invalidIdentifier("plan deload configuration")
                }
                blockIDs.append(block.id)

                for week in block.weeks {
                    weekIDs.append(week.id)
                    for plannedWorkout in week.plannedWorkouts {
                        if !plannedWorkoutIDs.insert(plannedWorkout.id).inserted {
                            throw BackupValidationError.duplicateIdentifier("planned workout")
                        }
                        planIDByPlannedWorkout[plannedWorkout.id] = plan.id
                        if let templateName = plannedWorkout.sourceTemplateName,
                           !templateNames.contains(templateName) {
                            throw BackupValidationError.missingTemplate(templateName)
                        }

                        for plannedExercise in plannedWorkout.plannedExercises {
                            plannedExerciseIDs.append(plannedExercise.id)
                            guard availableExerciseNames.contains(plannedExercise.exerciseName) else {
                                throw BackupValidationError.missingExercise(plannedExercise.exerciseName)
                            }
                            for alternativeName in plannedExercise.alternativeExerciseNames ?? [] where !availableExerciseNames.contains(alternativeName) {
                                throw BackupValidationError.missingExercise(alternativeName)
                            }
                            guard ExerciseRole(rawValue: plannedExercise.role) != nil,
                                  ProgressionRule(rawValue: plannedExercise.progressionRule) != nil,
                                  plannedExercise.stimulus.map({ TrainingStimulus(rawValue: $0) != nil }) ?? true,
                                  plannedExercise.suggestedLoadType.map({ WeightType(rawValue: $0) != nil }) ?? true else {
                                throw BackupValidationError.invalidIdentifier("planned exercise configuration")
                            }
                        }
                    }
                }
            }
        }

        try validateUniqueIdentifiers(blockIDs, named: "plan block")
        try validateUniqueIdentifiers(weekIDs, named: "plan week")
        try validateUniqueIdentifiers(plannedExerciseIDs, named: "planned exercise")

        var progressIDs: [String] = []
        for run in planRuns {
            guard PlanRunStatus(rawValue: run.status) != nil else {
                throw BackupValidationError.invalidIdentifier("plan run status")
            }
            _ = try requiredUUID(run.sourcePlanID, named: "plan run source plan")
            if let planID = run.planID {
                guard planIDs.contains(planID) else {
                    throw BackupValidationError.missingPlan(planID)
                }
                guard run.sourcePlanID == planID else {
                    throw BackupValidationError.invalidIdentifier("plan run source plan")
                }
            }

            for progress in run.workoutProgress {
                progressIDs.append(progress.id)
                guard PlanWorkoutStatus(rawValue: progress.status) != nil else {
                    throw BackupValidationError.invalidIdentifier("plan workout progress status")
                }
                if let planID = run.planID {
                    guard planIDByPlannedWorkout[progress.plannedWorkoutID] == planID else {
                        throw BackupValidationError.missingPlannedWorkout(progress.plannedWorkoutID)
                    }
                }
                if let workoutID = progress.completedWorkoutID,
                   !workoutIDs.contains(workoutID) {
                    throw BackupValidationError.missingWorkout(workoutID)
                }
            }
        }
        try validateUniqueIdentifiers(progressIDs, named: "plan workout progress")
    }

    private func requiredUUID(_ value: String, named name: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw BackupValidationError.invalidIdentifier(name)
        }
        return uuid
    }

    private func validateUniqueIdentifiers(_ identifiers: [String], named name: String) throws {
        var seen = Set<String>()
        for identifier in identifiers {
            _ = try requiredUUID(identifier, named: name)
            guard seen.insert(identifier).inserted else {
                throw BackupValidationError.duplicateIdentifier(name)
            }
        }
    }
}
