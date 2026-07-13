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
}

struct WorkoutDTO: Codable {
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

struct BackupDTO: Codable, Identifiable {
    var id: UUID { UUID() }
    let version: Int
    let preferences: PreferencesDTO
    let exercises: [ExerciseTemplateDTO]
    let templates: [WorkoutTemplateDTO]
    let collections: [WorkoutCollectionDTO]
    let workouts: [WorkoutDTO]
}

enum BackupValidationError: LocalizedError {
    case unsupportedVersion(Int)
    case duplicateExerciseName(String)
    case missingExercise(String)
    case missingTemplate(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup uses unsupported version \(version)."
        case .duplicateExerciseName(let name):
            return "The backup contains more than one exercise named \(name)."
        case .missingExercise(let name):
            return "The backup references an exercise that is missing: \(name)."
        case .missingTemplate(let name):
            return "The backup references a workout template that is missing: \(name)."
        }
    }
}

extension BackupDTO {
    static let currentVersion = 1

    static func create(from context: ModelContext, restTimer: Int, darkMode: Bool, unitSystem: UnitSystem) throws -> BackupDTO {
        let exercises = try context.fetch(FetchDescriptor<ExerciceTemplate>())
        let exerciseDTOs = exercises.map { exercise in
            ExerciseTemplateDTO(
                name: exercise.name,
                primaryMuscles: exercise.PrimaryMuscle.map(\.rawValue),
                secondaryMuscles: exercise.SecondaryMuscle?.map(\.rawValue),
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
                isArchived: exercise.isArchived
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
                        progressionRule: te.progressionRule.rawValue
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
                status: workout.status.rawValue,
                name: workout.nom,
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
                            repetition: set.repetition,
                            weight: set.weight,
                            duration: set.duration,
                            distance: set.distance,
                            done: set.done,
                            rpe: set.rpe,
                            setType: set.setType.rawValue,
                            usedMetric: set.usedMetric.rawValue
                        )
                    }
                    return ExerciseEntryDTO(
                        orderIndex: exercise.orderIndex,
                        comment: exercise.Comment,
                        exerciseName: exercise.exercice.name,
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
                        recommendationPriorWorkoutDate: exercise.recommendationPriorWorkoutDate
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
            workouts: workoutDTOs
        )
    }

    func restore(to context: ModelContext) throws {
        try validate()
        try context.clearAllGymData()

        let builtInTemplates = ExerciseSeedData.templates()
        for template in builtInTemplates {
            context.insert(template)
        }
        try context.save()

        let seededExercises = try context.fetch(FetchDescriptor<ExerciceTemplate>())
        var exerciseMap = Dictionary(uniqueKeysWithValues: seededExercises.map { ($0.name, $0) })

        for exerciseDTO in self.exercises {
            let primaryMuscles = exerciseDTO.primaryMuscles.compactMap { Muscle(rawValue: $0) }
            let secondaryMuscles = exerciseDTO.secondaryMuscles?.compactMap { Muscle(rawValue: $0) }
            let category = exerciseDTO.category.flatMap { ExerciseCategory(rawValue: $0) } ?? .strength
            let trackingType = TrackingType(rawValue: exerciseDTO.trackingType) ?? .weightAndReps
            let equipmentType = exerciseDTO.equipmentType.flatMap { EquipmentType(rawValue: $0) } ?? .other
            let resistanceType = exerciseDTO.resistanceType.flatMap { ResistanceType(rawValue: $0) }
            let movementPattern = exerciseDTO.movementPattern.flatMap { MovementPattern(rawValue: $0) }
            let difficulty = exerciseDTO.difficulty.flatMap { Difficulty(rawValue: $0) } ?? .beginner

            if let existing = exerciseMap[exerciseDTO.name] {
                existing.isFavorite = exerciseDTO.isFavorite
                existing.isArchived = exerciseDTO.isArchived
                existing.isPlateLoaded = exerciseDTO.isPlateLoaded
            } else {
                let newExercise = ExerciceTemplate(
                    name: exerciseDTO.name,
                    PrimaryMuscle: primaryMuscles,
                    SecondaryMuscle: secondaryMuscles,
                    category: category,
                    trackingType: trackingType,
                    equipmentType: equipmentType,
                    resistanceType: resistanceType,
                    movementPattern: movementPattern,
                    difficulty: difficulty,
                    tags: exerciseDTO.tags,
                    isFavorite: exerciseDTO.isFavorite,
                    isPlateLoaded: exerciseDTO.isPlateLoaded,
                    isCustom: exerciseDTO.isCustom,
                    isArchived: exerciseDTO.isArchived
                )
                context.insert(newExercise)
                exerciseMap[newExercise.name] = newExercise
            }
        }
        try context.save()

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
                    progressionRule: ProgressionRule(rawValue: teDTO.progressionRule ?? "") ?? .doubleProgression
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
        try context.save()

        for collectionDTO in self.collections {
            let templates = collectionDTO.templateNames.compactMap { templateMap[$0] }
            let newCollection = WorkoutCollection(
                name: collectionDTO.name,
                workoutTemplates: templates
            )
            context.insert(newCollection)
        }
        try context.save()

        for workoutDTO in self.workouts {
            let status = WorkoutStatus(rawValue: workoutDTO.status) ?? .completed
            let newWorkout = Workout(nom: workoutDTO.name, endTime: workoutDTO.endTime)
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

            var exercises: [ExerciceEntry] = []
            for entryDTO in workoutDTO.exercises {
                guard let exerciseTemplate = exerciseMap[entryDTO.exerciseName] else { continue }
                let usedMetric = UnitSystem(rawValue: entryDTO.usedMetric) ?? .metric
                
                let entry = ExerciceEntry(
                    Comment: entryDTO.comment,
                    exercice: exerciseTemplate,
                    orderIndex: entryDTO.orderIndex,
                    usedMetric: usedMetric
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

                var sets: [ExerciseSet] = []
                for setDTO in entryDTO.sets {
                    let weightType = WeightType(rawValue: setDTO.weightType) ?? .kg
                    let distanceType = DistanceType(rawValue: setDTO.distanceType) ?? .kilometers
                    let setType = SetType(rawValue: setDTO.setType) ?? .normal
                    let setUsedMetric = UnitSystem(rawValue: setDTO.usedMetric) ?? .metric
                    
                    let setObj = ExerciseSet(
                        repetition: setDTO.repetition,
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
                    sets.append(setObj)
                }
                entry.sets = sets
                exercises.append(entry)
            }
            newWorkout.exercises = exercises
            context.insert(newWorkout)
        }
        try context.save()
    }

    func validate() throws {
        guard version == Self.currentVersion else {
            throw BackupValidationError.unsupportedVersion(version)
        }

        let exerciseNames = exercises.map(\.name)
        guard Set(exerciseNames).count == exerciseNames.count else {
            let duplicate = Dictionary(grouping: exerciseNames, by: \.self)
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
    }
}
