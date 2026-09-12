import Foundation
import SwiftData

/// User-facing domains that can be included in a portable backup.
///
/// Restore still replaces the destination graph atomically. Omitting a
/// category writes an empty collection for that domain, so a later restore
/// leaves it empty rather than merging it with whatever is already on the
/// phone.
nonisolated enum BackupExportCategory: String, CaseIterable, Identifiable, Sendable, Hashable {
    case workoutHistory
    case savedWorkouts
    case plans
    case rotations
    case customExercises
    case mobility
    case nutrition
    case checkIns
    case bodyWeight
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workoutHistory: String(localized: "Workout History")
        case .savedWorkouts: String(localized: "Saved workouts")
        case .plans: String(localized: "Training plans")
        case .rotations: String(localized: "Rotations")
        case .customExercises: String(localized: "Custom Exercises")
        case .mobility: String(localized: "Mobility")
        case .nutrition: String(localized: "Nutrition")
        case .checkIns: String(localized: "Check-ins")
        case .bodyWeight: String(localized: "Body weight")
        case .preferences: String(localized: "Preferences")
        }
    }

    var icon: String {
        switch self {
        case .workoutHistory: AppIcon.history
        case .savedWorkouts: AppIcon.workout
        case .plans: AppIcon.plan
        case .rotations: AppIcon.repeatingPlan
        case .customExercises: AppIcon.exercise
        case .mobility: AppIcon.mobility
        case .nutrition: AppIcon.nutrition
        case .checkIns: AppIcon.checkIn
        case .bodyWeight: AppIcon.bodyWeight
        case .preferences: AppIcon.settings
        }
    }
}

/// The set of domains a person chose to put in one backup file.
nonisolated struct BackupExportSelection: Equatable, Sendable {
    var categories: Set<BackupExportCategory>

    static let everything = BackupExportSelection(categories: Set(BackupExportCategory.allCases))

    var isEmpty: Bool { categories.isEmpty }

    var includesEverything: Bool {
        categories == Set(BackupExportCategory.allCases)
    }

    func contains(_ category: BackupExportCategory) -> Bool {
        categories.contains(category)
    }

    mutating func set(_ category: BackupExportCategory, included: Bool) {
        if included {
            categories.insert(category)
        } else {
            categories.remove(category)
        }
    }
}

nonisolated enum BackupExportError: LocalizedError, Equatable {
    case nothingSelected

    var errorDescription: String? {
        String(localized: "Choose at least one category.")
    }
}

/// Glance counts for the export wizard. These are not the backup payload;
/// they only tell the person what each toggle currently holds.
nonisolated struct BackupExportInventory: Equatable, Sendable {
    var workoutCount: Int
    var templateCount: Int
    var planCount: Int
    var rotationCount: Int
    var customExerciseCount: Int
    var mobilityRoutineCount: Int
    var mobilitySessionCount: Int
    var loggedMealCount: Int
    var checkInCount: Int
    var bodyWeightCount: Int

    static let empty = BackupExportInventory(
        workoutCount: 0,
        templateCount: 0,
        planCount: 0,
        rotationCount: 0,
        customExerciseCount: 0,
        mobilityRoutineCount: 0,
        mobilitySessionCount: 0,
        loggedMealCount: 0,
        checkInCount: 0,
        bodyWeightCount: 0
    )

    func count(for category: BackupExportCategory) -> Int? {
        switch category {
        case .workoutHistory: workoutCount
        case .savedWorkouts: templateCount
        case .plans: planCount
        case .rotations: rotationCount
        case .customExercises: customExerciseCount
        case .mobility: mobilityRoutineCount + mobilitySessionCount
        case .nutrition: loggedMealCount
        case .checkIns: checkInCount
        case .bodyWeight: bodyWeightCount
        case .preferences: nil
        }
    }

    static func load(from context: ModelContext) throws -> BackupExportInventory {
        BackupExportInventory(
            workoutCount: try context.fetchCount(FetchDescriptor<Workout>()),
            templateCount: try context.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            planCount: try context.fetchCount(FetchDescriptor<WorkoutPlan>()),
            rotationCount: try context.fetchCount(FetchDescriptor<RepeatingPlan>()),
            customExerciseCount: try context.fetchCount(
                FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom })
            ),
            mobilityRoutineCount: try context.fetchCount(FetchDescriptor<MobilityRoutine>()),
            mobilitySessionCount: try context.fetchCount(FetchDescriptor<MobilitySession>()),
            loggedMealCount: try context.fetchCount(FetchDescriptor<LoggedMeal>()),
            checkInCount: try context.fetchCount(FetchDescriptor<DailyLogEntry>()),
            bodyWeightCount: try context.fetchCount(FetchDescriptor<BodyWeightEntry>())
        )
    }
}

extension BackupDTO {
    /// Returns a still-valid portable archive that keeps only the selected
    /// domains. Required dependencies stay: referenced custom exercises, and
    /// saved workouts a plan or rotation still names. Cross-domain links into
    /// omitted domains are cleared rather than left dangling.
    func applying(_ selection: BackupExportSelection) throws -> BackupDTO {
        guard selection.isEmpty == false else {
            throw BackupExportError.nothingSelected
        }
        if selection.includesEverything {
            return droppingUnreachableCatalogMetadata()
        }

        let includeHistory = selection.contains(.workoutHistory)
        let includeSavedWorkouts = selection.contains(.savedWorkouts)
        let includePlans = selection.contains(.plans)
        let includeRotations = selection.contains(.rotations)
        let includeCustomExercises = selection.contains(.customExercises)
        let includeMobility = selection.contains(.mobility)
        let includeNutrition = selection.contains(.nutrition)
        let includeCheckIns = selection.contains(.checkIns)
        let includeBodyWeight = selection.contains(.bodyWeight)
        let includePreferences = selection.contains(.preferences)

        let workouts = includeHistory
            ? (includeRotations ? self.workouts : self.workouts.map { $0.strippingRepeatingPlanSource() })
            : []
        let plans = includePlans ? self.plans : []
        let planRuns = includePlans
            ? self.planRuns.map { includeHistory ? $0 : $0.clearingCompletedWorkouts() }
            : []
        var repeatingPlans = includeRotations ? self.repeatingPlans : []
        var repeatingPlanRuns = includeRotations ? self.repeatingPlanRuns : []
        if includeRotations && includeHistory == false {
            repeatingPlanRuns = repeatingPlanRuns.map { $0.clearingCompletedWorkouts() }
        }
        if includeRotations && includeMobility == false {
            repeatingPlans = repeatingPlans.map { $0.strippingLiveMobilityLinks() }
            repeatingPlanRuns = repeatingPlanRuns.map { $0.strippingLiveMobilityLinks() }
        }

        let referencedTemplateNames = templateNamesRequired(
            byPlans: plans,
            repeatingPlans: repeatingPlans,
            repeatingPlanRuns: repeatingPlanRuns
        )
        let templates: [WorkoutTemplateDTO]
        if includeSavedWorkouts {
            templates = includeMobility
                ? self.templates
                : self.templates.map { $0.strippingLiveMobilityLinks() }
        } else if referencedTemplateNames.isEmpty {
            templates = []
        } else {
            templates = self.templates
                .filter { referencedTemplateNames.contains($0.name) }
                .map { includeMobility ? $0 : $0.strippingLiveMobilityLinks() }
        }
        let templateNames = Set(templates.map(\.name))
        let collections = includeSavedWorkouts
            ? self.collections.map { collection in
                WorkoutCollectionDTO(
                    name: collection.name,
                    templateNames: collection.templateNames.filter(templateNames.contains)
                )
            }
            .filter { $0.templateNames.isEmpty == false }
            : []

        let needsExerciseGraph =
            includeHistory
            || templates.isEmpty == false
            || includePlans
            || includeRotations
            || includeCustomExercises
        let neededExerciseNames = exerciseNamesRequired(
            byWorkouts: workouts,
            templates: templates,
            plans: plans
        )
        let exercises: [ExerciseTemplateDTO]
        if needsExerciseGraph == false {
            exercises = []
        } else if includeCustomExercises {
            exercises = self.exercises
        } else {
            exercises = self.exercises.filter { exercise in
                exercise.isCustom == false || neededExerciseNames.contains(exercise.name)
            }
        }
        let remainingExerciseNames = Set(exercises.map(\.name))
        let exerciseRelationships = needsExerciseGraph
            ? self.exerciseRelationships.filter { relationship in
                remainingExerciseNames.contains(relationship.sourceExerciseName)
                    && remainingExerciseNames.contains(relationship.targetExerciseName)
            }
            : []

        let mobilitySessions = includeMobility
            ? self.mobilitySessions.map { includeHistory ? $0 : $0.strippingWorkoutLink() }
            : []

        let preferences = includePreferences
            ? self.preferences
            : PreferencesDTO(darkMode: false, restTimer: 0, unitSystem: UnitSystem.metric.rawValue)

        return BackupDTO(
            version: version,
            preferences: preferences,
            exercises: exercises,
            templates: templates,
            collections: collections,
            workouts: workouts,
            plans: plans,
            planRuns: planRuns,
            repeatingPlans: repeatingPlans,
            repeatingPlanRuns: repeatingPlanRuns,
            exerciseRelationships: exerciseRelationships,
            programDefinitions: includePlans ? programDefinitions : [],
            mobilityProgramDefinitions: includeMobility ? mobilityProgramDefinitions : [],
            mobilityProgramRuns: includeMobility ? mobilityProgramRuns : [],
            mobilityProgressionRecommendations: includeMobility ? mobilityProgressionRecommendations : [],
            progressionRecommendations: includeHistory ? progressionRecommendations : [],
            dailyLogEntries: includeCheckIns ? dailyLogEntries : [],
            bodyWeightEntries: includeBodyWeight ? bodyWeightEntries : [],
            healthKitBodyMassProvenance: includeBodyWeight ? healthKitBodyMassProvenance : [],
            healthKitWorkoutExportReceipts: includeHistory ? healthKitWorkoutExportReceipts : [],
            supplementOccurrences: includeCheckIns ? supplementOccurrences : [],
            mobilityFamilies: includeMobility ? mobilityFamilies : [],
            mobilityDefinitions: includeMobility ? mobilityDefinitions : [],
            catalogDefinitionMetadata: catalogDefinitionMetadata,
            programDiscoverySeeds: includePlans ? programDiscoverySeeds : [],
            mobilityRoutines: includeMobility ? mobilityRoutines : [],
            mobilitySessions: mobilitySessions,
            mobilityAssessmentDefinitions: includeMobility ? mobilityAssessmentDefinitions : [],
            mobilityAssessmentSessions: includeMobility ? mobilityAssessmentSessions : [],
            foods: includeNutrition ? foods : [],
            mealTemplates: includeNutrition ? mealTemplates : [],
            loggedMeals: includeNutrition ? loggedMeals : [],
            nutritionTargets: includeNutrition ? nutritionTargets : [],
            trainingProfile: includePreferences ? trainingProfile : nil
        )
        .droppingUnreachableCatalogMetadata()
    }

    /// Catalogue metadata is additive and can outlive a deleted definition.
    /// Restore still rejects a file that already contains a dangling target;
    /// export drops those rows so a phone with leftover metadata can still
    /// write a valid archive.
    private func droppingUnreachableCatalogMetadata() -> BackupDTO {
        let exerciseIDs = Set(exercises.compactMap(\.id))
        let mobilityDefinitionIDs = Set(mobilityDefinitions.map(\.id))
        let workoutProgramIDs = Set(programDefinitions.map(\.id))
        let mobilityProgramIDs = Set(mobilityProgramDefinitions.map(\.id))
        let kept = catalogDefinitionMetadata.filter { row in
            guard let kind = CatalogDefinitionKind(rawValue: row.definitionKind) else {
                return false
            }
            switch kind {
            case .exercise:
                return exerciseIDs.contains(row.definitionID)
            case .mobilityDefinition:
                return mobilityDefinitionIDs.contains(row.definitionID)
            case .workoutProgram:
                return workoutProgramIDs.contains(row.definitionID)
            case .mobilityProgram:
                return mobilityProgramIDs.contains(row.definitionID)
            }
        }
        guard kept.count != catalogDefinitionMetadata.count else {
            return self
        }
        return replacingCatalogDefinitionMetadata(kept)
    }

    private func replacingCatalogDefinitionMetadata(
        _ metadata: [CatalogDefinitionMetadataDTO]
    ) -> BackupDTO {
        BackupDTO(
            version: version,
            preferences: preferences,
            exercises: exercises,
            templates: templates,
            collections: collections,
            workouts: workouts,
            plans: plans,
            planRuns: planRuns,
            repeatingPlans: repeatingPlans,
            repeatingPlanRuns: repeatingPlanRuns,
            exerciseRelationships: exerciseRelationships,
            programDefinitions: programDefinitions,
            mobilityProgramDefinitions: mobilityProgramDefinitions,
            mobilityProgramRuns: mobilityProgramRuns,
            mobilityProgressionRecommendations: mobilityProgressionRecommendations,
            progressionRecommendations: progressionRecommendations,
            dailyLogEntries: dailyLogEntries,
            bodyWeightEntries: bodyWeightEntries,
            healthKitBodyMassProvenance: healthKitBodyMassProvenance,
            healthKitWorkoutExportReceipts: healthKitWorkoutExportReceipts,
            supplementOccurrences: supplementOccurrences,
            mobilityFamilies: mobilityFamilies,
            mobilityDefinitions: mobilityDefinitions,
            catalogDefinitionMetadata: metadata,
            programDiscoverySeeds: programDiscoverySeeds,
            mobilityRoutines: mobilityRoutines,
            mobilitySessions: mobilitySessions,
            mobilityAssessmentDefinitions: mobilityAssessmentDefinitions,
            mobilityAssessmentSessions: mobilityAssessmentSessions,
            foods: foods,
            mealTemplates: mealTemplates,
            loggedMeals: loggedMeals,
            nutritionTargets: nutritionTargets,
            trainingProfile: trainingProfile
        )
    }

    private func templateNamesRequired(
        byPlans plans: [WorkoutPlanDTO],
        repeatingPlans: [RepeatingPlanDTO],
        repeatingPlanRuns: [RepeatingPlanRunDTO]
    ) -> Set<String> {
        var names = Set<String>()
        for plan in plans {
            for block in plan.blocks {
                for week in block.weeks {
                    for workout in week.plannedWorkouts {
                        if let name = workout.sourceTemplateName {
                            names.insert(name)
                        }
                    }
                }
            }
        }
        for plan in repeatingPlans {
            for slot in plan.slots {
                if let name = slot.workoutTemplateName {
                    names.insert(name)
                }
            }
        }
        for run in repeatingPlanRuns {
            for slot in run.slots {
                if let name = slot.workoutTemplateName {
                    names.insert(name)
                }
            }
        }
        return names
    }

    private func exerciseNamesRequired(
        byWorkouts workouts: [WorkoutDTO],
        templates: [WorkoutTemplateDTO],
        plans: [WorkoutPlanDTO]
    ) -> Set<String> {
        var names = Set<String>()
        for workout in workouts {
            for entry in workout.exercises {
                names.insert(entry.exerciseName)
            }
        }
        for template in templates {
            for exercise in template.templateExercises {
                names.insert(exercise.exerciseName)
            }
        }
        for plan in plans {
            for block in plan.blocks {
                for week in block.weeks {
                    for workout in week.plannedWorkouts {
                        for exercise in workout.plannedExercises {
                            names.insert(exercise.exerciseName)
                            for alternative in exercise.alternativeExerciseNames ?? [] {
                                names.insert(alternative)
                            }
                        }
                    }
                }
            }
        }
        return names
    }
}

private extension WorkoutDTO {
    func strippingRepeatingPlanSource() -> WorkoutDTO {
        WorkoutDTO(
            id: id,
            status: status,
            name: name,
            notes: notes,
            startTime: startTime,
            endTime: endTime,
            restEndDate: restEndDate,
            pausedRemainingTime: pausedRemainingTime,
            sourceTemplateName: sourceTemplateName,
            sourcePlanID: sourcePlanID,
            sourcePlanRunID: sourcePlanRunID,
            sourcePlanBlockID: sourcePlanBlockID,
            sourcePlanWeekID: sourcePlanWeekID,
            sourcePlannedWorkoutID: sourcePlannedWorkoutID,
            sourcePlanName: sourcePlanName,
            sourceProgramDefinitionID: sourceProgramDefinitionID,
            sourceProgramDefinitionVersion: sourceProgramDefinitionVersion,
            sourceRepeatingPlanID: nil,
            sourceRepeatingPlanRunID: nil,
            sourceRepeatingPlanOccurrenceID: nil,
            sourceRepeatingPlanName: nil,
            exercises: exercises,
            executionBlocks: executionBlocks
        )
    }
}

private extension WorkoutTemplateDTO {
    func strippingLiveMobilityLinks() -> WorkoutTemplateDTO {
        WorkoutTemplateDTO(
            id: id,
            name: name,
            templateExercises: templateExercises,
            executionBlocks: executionBlocks,
            preWorkoutMobilityRoutineName: nil,
            postWorkoutMobilityRoutineName: nil,
            isBuiltIn: isBuiltIn,
            isArchived: isArchived
        )
    }
}

private extension PlanRunDTO {
    func clearingCompletedWorkouts() -> PlanRunDTO {
        PlanRunDTO(
            id: id,
            sourcePlanID: sourcePlanID,
            sourcePlanName: sourcePlanName,
            planID: planID,
            startDate: startDate,
            endDate: endDate,
            status: status,
            currentWeekIndex: currentWeekIndex,
            currentWorkoutIndex: currentWorkoutIndex,
            endedProgressionKeysData: endedProgressionKeysData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            workoutProgress: workoutProgress.map { $0.clearingCompletedWorkout() },
            progressionStates: progressionStates
        )
    }
}

private extension PlanWorkoutProgressDTO {
    func clearingCompletedWorkout() -> PlanWorkoutProgressDTO {
        PlanWorkoutProgressDTO(
            id: id,
            plannedWorkoutID: plannedWorkoutID,
            plannedWorkoutName: plannedWorkoutName,
            weekIndex: weekIndex,
            sourceWeekIndex: sourceWeekIndex,
            workoutIndex: workoutIndex,
            originalScheduledDate: originalScheduledDate,
            scheduledDate: scheduledDate,
            lastRescheduledAt: lastRescheduledAt,
            status: status,
            startedAt: startedAt,
            completedAt: completedAt,
            skipReason: skipReason,
            completedWorkoutID: nil
        )
    }
}

private extension RepeatingPlanDTO {
    func strippingLiveMobilityLinks() -> RepeatingPlanDTO {
        RepeatingPlanDTO(
            id: id,
            name: name,
            goal: goal,
            experienceLevel: experienceLevel,
            requiredEquipment: requiredEquipment,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived,
            isBuiltIn: isBuiltIn,
            slots: slots.map { slot in
                var copy = slot
                copy.preWorkoutMobilityRoutineName = nil
                copy.postWorkoutMobilityRoutineName = nil
                return copy
            }
        )
    }
}

private extension RepeatingPlanRunDTO {
    func clearingCompletedWorkouts() -> RepeatingPlanRunDTO {
        RepeatingPlanRunDTO(
            id: id,
            sourcePlanID: sourcePlanID,
            sourcePlanName: sourcePlanName,
            status: status,
            currentSlotIndex: currentSlotIndex,
            completedCycleCount: completedCycleCount,
            startedAt: startedAt,
            endedAt: endedAt,
            updatedAt: updatedAt,
            planID: planID,
            slots: slots,
            occurrences: occurrences.map { $0.clearingCompletedWorkout() }
        )
    }

    func strippingLiveMobilityLinks() -> RepeatingPlanRunDTO {
        RepeatingPlanRunDTO(
            id: id,
            sourcePlanID: sourcePlanID,
            sourcePlanName: sourcePlanName,
            status: status,
            currentSlotIndex: currentSlotIndex,
            completedCycleCount: completedCycleCount,
            startedAt: startedAt,
            endedAt: endedAt,
            updatedAt: updatedAt,
            planID: planID,
            slots: slots.map { slot in
                var copy = slot
                copy.preWorkoutMobilityRoutineName = nil
                copy.postWorkoutMobilityRoutineName = nil
                return copy
            },
            occurrences: occurrences
        )
    }
}

private extension RepeatingPlanOccurrenceDTO {
    func clearingCompletedWorkout() -> RepeatingPlanOccurrenceDTO {
        RepeatingPlanOccurrenceDTO(
            id: id,
            cycleIndex: cycleIndex,
            expectedSlotIndex: expectedSlotIndex,
            selectedSlotIndex: selectedSlotIndex,
            kind: kind,
            continuationMode: continuationMode,
            status: status,
            cursorBefore: cursorBefore,
            cursorAfter: cursorAfter,
            cycleBefore: cycleBefore,
            cycleAfter: cycleAfter,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: completedAt,
            undoneAt: undoneAt,
            completedWorkoutID: nil
        )
    }
}

private extension MobilitySessionDTO {
    func strippingWorkoutLink() -> MobilitySessionDTO {
        MobilitySessionDTO(
            id: id,
            status: status,
            nameSnapshot: nameSnapshot,
            sourceRoutineID: sourceRoutineID,
            sourceRoutineName: sourceRoutineName,
            workoutID: nil,
            context: context,
            startTime: startTime,
            endTime: endTime,
            currentEntryIndex: currentEntryIndex,
            createdAt: createdAt,
            updatedAt: updatedAt,
            entries: entries
        )
    }
}
