import Foundation
import SwiftData

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

extension BackupDTO {

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
        let currentArchive = CurrentBackupArchive(adapting: self)
        do {
            try context.clearAllGymData(saveChanges: false)

            var restoreCtx = RestoreContext(context: context)

            try restoreExerciseCatalog(from: currentArchive.workout.exercises, into: &restoreCtx)
            // Mobility definitions/routines must exist before templates and
            // repeating slots resolve their optional preparation/recovery
            // links. Mobility sessions remain an independent performed graph;
            // restoring them here does not create an ownership edge to Workout.
            try restoreMobility(into: &restoreCtx)
            try restoreMobilityAssessments(into: &restoreCtx)
            try restoreFoldersAndTemplates(from: currentArchive.workout.templates, into: &restoreCtx)
            try restoreRepeatingPlansAndRuns(into: &restoreCtx)
            try restoreProgramDefinitions(into: &restoreCtx)
            try restoreMobilityProgramDefinitions(into: &restoreCtx)
            try restoreMobilityProgramRuns(into: &restoreCtx)
            try restoreMobilityProgressionRecommendations(into: &restoreCtx)
            try restorePlansAndRuns(into: &restoreCtx)
            try restoreWorkoutHistory(from: currentArchive.workout.workouts, into: &restoreCtx)
            try restoreRepeatingPlanOccurrences(into: &restoreCtx)
            try restoreDailyContextAndPreferences(into: &restoreCtx)
            try restoreNutrition(into: &restoreCtx)
            try restoreTrainingProfile(into: &restoreCtx)

#if !GYMTRACKER_EXTENSION
            // The manifest is rebuildable installation state, not backup
            // payload. Stage it before the final save so an interrupted
            // restore cannot leave restored user data without its catalogue
            // installation metadata.
            _ = try SystemSeedCatalogCoordinator.stageBundledCatalog(in: context)
#endif
            // Validate the restored graph itself immediately before the single
            // final commit. DTO validation and model materialization could
            // disagree, and rolling back here keeps the replacement atomic.
            let trackingIssues = try context.fetch(FetchDescriptor<WorkoutTemplate>())
                .flatMap { TrackingProfileValidator.validate(template: $0) }
                + context.fetch(FetchDescriptor<WorkoutPlan>())
                .flatMap { TrackingProfileValidator.validate(plan: $0) }
            guard trackingIssues.isEmpty else {
                throw TrackingProfileValidationFailure(issues: trackingIssues)
            }

            try beforeCommit?()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - Restore Sub-Handlers

    private func restoreExerciseCatalog(
        from exercises: [CurrentExerciseArchive],
        into restoreCtx: inout RestoreContext
    ) throws {
        let builtInExercises = ExerciseSeedData.templates()
        for exercise in builtInExercises {
            restoreCtx.context.insert(exercise)
        }

        restoreCtx.exerciseMap = Dictionary(builtInExercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        for normalizedExercise in exercises {
            let exerciseDTO = normalizedExercise.dto
            let primaryMuscles = exerciseDTO.primaryMuscles.compactMap { Muscle(rawValue: $0) }
            let secondaryMuscles = exerciseDTO.secondaryMuscles?.compactMap { Muscle(rawValue: $0) }

            if !exerciseDTO.isCustom, let existing = restoreCtx.exerciseMap[exerciseDTO.name] {
                if let id = normalizedExercise.stableID {
                    existing.id = id
                }
                if let fr = exerciseDTO.frenchName { existing.frenchName = fr }
                if let aliases = exerciseDTO.searchAliases { existing.searchAliases = aliases }
                if let sportDiscipline = exerciseDTO.sportDiscipline { existing.sportDisciplineRaw = sportDiscipline }
                if let eventFamily = exerciseDTO.strongmanEventFamily { existing.strongmanEventFamilyRaw = eventFamily }
                if let implementData = exerciseDTO.strongmanImplementProfileData {
                    existing.strongmanImplementProfileData = implementData
                }
            } else {
                let newExercise = Exercise(
                    name: exerciseDTO.name,
                    primaryMuscles: primaryMuscles,
                    secondaryMuscles: secondaryMuscles,
                    category: normalizedExercise.category,
                    trackingType: normalizedExercise.trackingType,
                    equipmentType: normalizedExercise.equipmentType,
                    resistanceType: normalizedExercise.resistanceType,
                    movementPattern: normalizedExercise.movementPattern,
                    forceType: normalizedExercise.forceType,
                    mechanics: normalizedExercise.mechanics,
                    gripStyle: normalizedExercise.gripStyle,
                    stance: normalizedExercise.stance,
                    rangeOfMotion: normalizedExercise.rangeOfMotion,
                    setupAngleDegrees: exerciseDTO.setupAngleDegrees,
                    variationFamilyID: exerciseDTO.variationFamilyID,
                    difficulty: normalizedExercise.difficulty,
                    tags: exerciseDTO.tags,
                    isFavorite: exerciseDTO.isFavorite,
                    isPlateLoaded: exerciseDTO.isPlateLoaded,
                    isCustom: exerciseDTO.isCustom,
                    isArchived: exerciseDTO.isArchived,
                    laterality: normalizedExercise.laterality,
                    repCountingStyle: normalizedExercise.repCountingStyle,
                    weightEntryStyle: normalizedExercise.weightEntryStyle,
                    loadUnitCount: normalizedExercise.loadUnitCount,
                    id: normalizedExercise.stableID ?? UUID()
                )
                newExercise.frenchName = exerciseDTO.frenchName
                newExercise.searchAliases = exerciseDTO.searchAliases ?? []
                newExercise.sportDisciplineRaw = exerciseDTO.sportDiscipline
                newExercise.strongmanEventFamilyRaw = exerciseDTO.strongmanEventFamily
                newExercise.strongmanImplementProfileData = exerciseDTO.strongmanImplementProfileData
                restoreCtx.context.insert(newExercise)
                if restoreCtx.exerciseMap[newExercise.name] == nil {
                    restoreCtx.exerciseMap[newExercise.name] = newExercise
                }
            }
        }

        for relationshipDTO in exerciseRelationships {
            guard
                let source = restoreCtx.exerciseMap[relationshipDTO.sourceExerciseName],
                let target = restoreCtx.exerciseMap[relationshipDTO.targetExerciseName],
                let type = ExerciseRelationshipType(rawValue: relationshipDTO.type)
            else {
                throw BackupValidationError.invalidExerciseRelationship
            }
            restoreCtx.context.insert(ExerciseRelationship(
                sourceExercise: source,
                targetExercise: target,
                type: type,
                // Absent provenance stays absent rather than being upgraded to
                // "reviewed" on restore: `resolvedProvenance` reads a nil as
                // `systemUnreviewed`, which is the honest default.
                provenance: relationshipDTO.provenance.flatMap(SubstitutionProvenance.init(rawValue:)),
                rationaleCode: relationshipDTO.rationaleCode,
                appliesToGoals: (relationshipDTO.appliesToGoals ?? []).compactMap(PlanGoal.init(rawValue:)),
                appliesToRoles: (relationshipDTO.appliesToRoles ?? []).compactMap(ExerciseRole.init(rawValue:)),
                reviewVersion: relationshipDTO.reviewVersion
            ))
        }
    }

    private func restoreFoldersAndTemplates(
        from templates: [CurrentWorkoutTemplateArchive],
        into restoreCtx: inout RestoreContext
    ) throws {
        for normalizedTemplate in templates {
            let templateDTO = normalizedTemplate.dto
            var templateExercises: [TemplateExercise] = []

            for normalizedTemplateExercise in normalizedTemplate.exercises {
                let teDTO = normalizedTemplateExercise.dto
                guard let exercise = restoreCtx.exerciseMap[teDTO.exerciseName] else { continue }
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
                    progressionRule: normalizedTemplateExercise.progressionRule,
                    supersetGroupID: normalizedTemplateExercise.supersetGroupID,
                    progressionKey: teDTO.progressionKey
                )
                te.orderIndex = teDTO.orderIndex
                te.executionBlockID = normalizedTemplateExercise.executionBlockID
                te.executionBlockComponentOrder = teDTO.executionBlockComponentOrder
                te.stimulus = normalizedTemplateExercise.stimulus
                templateExercises.append(te)
            }

            let exercises = templateExercises.map(\.exercise)
            let newTemplate = WorkoutTemplate(
                name: templateDTO.name,
                exercises: exercises,
                templateExercises: templateExercises,
                preWorkoutMobilityRoutine: templateDTO.preWorkoutMobilityRoutineName.flatMap {
                    restoreCtx.mobilityRoutinesByName[$0]
                },
                postWorkoutMobilityRoutine: templateDTO.postWorkoutMobilityRoutineName.flatMap {
                    restoreCtx.mobilityRoutinesByName[$0]
                }
            )
            newTemplate.executionBlocks = (templateDTO.executionBlocks ?? []).compactMap { blockDTO in
                guard let id = UUID(uuidString: blockDTO.id),
                      let kind = ExerciseBlockKind(rawValue: blockDTO.kind),
                      let clockMode = BlockClockMode(rawValue: blockDTO.clockMode),
                      let scoreKind = BlockScoreKind(rawValue: blockDTO.scoreKind) else {
                    return nil
                }
                let block = TemplateExerciseBlock(
                    orderIndex: blockDTO.orderIndex,
                    kind: kind,
                    name: blockDTO.name,
                    targetRounds: blockDTO.targetRounds,
                    isSharedLoad: blockDTO.isSharedLoad,
                    restSeconds: blockDTO.restSeconds,
                    clockMode: clockMode,
                    prescribedDurationSeconds: blockDTO.prescribedDurationSeconds,
                    timeCapSeconds: blockDTO.timeCapSeconds,
                    intervalSeconds: blockDTO.intervalSeconds,
                    scoreKind: scoreKind,
                    repetitionScheme: blockDTO.repetitionScheme.flatMap(BlockRepetitionScheme.init(rawValue:)) ?? .fixed,
                    repetitionStart: blockDTO.repetitionStart,
                    repetitionEnd: blockDTO.repetitionEnd,
                    repetitionStep: blockDTO.repetitionStep
                )
                block.id = id
                return block
            }
            restoreCtx.context.insert(newTemplate)
            restoreCtx.templateMap[newTemplate.name] = newTemplate
        }

        for collectionDTO in self.collections {
            let templates = collectionDTO.templateNames.compactMap { restoreCtx.templateMap[$0] }
            let newCollection = WorkoutCollection(
                name: collectionDTO.name,
                workoutTemplates: templates
            )
            restoreCtx.context.insert(newCollection)
        }
    }

    /// Repeating definitions and runs are restored before performed workouts so
    /// their copied slot order is already durable. Occurrence-to-workout links
    /// are intentionally deferred until `restoreWorkouts` has populated the
    /// identity map.
    private func restoreRepeatingPlansAndRuns(into restoreCtx: inout RestoreContext) throws {
        for planDTO in repeatingPlans {
            let slots = try planDTO.slots.map { slotDTO in
                let templateID = try requiredUUID(slotDTO.templateIDSnapshot, named: "repeating plan slot template")
                let slot = RepeatingPlanSlot(
                    orderIndex: slotDTO.orderIndex,
                    workoutTemplate: slotDTO.workoutTemplateName.flatMap { restoreCtx.templateMap[$0] },
                    templateIDSnapshot: templateID,
                    templateNameSnapshot: slotDTO.templateNameSnapshot,
                    preWorkoutMobilityRoutine: slotDTO.preWorkoutMobilityRoutineName.flatMap {
                        restoreCtx.mobilityRoutinesByName[$0]
                    },
                    preWorkoutMobilityRoutineIDSnapshot: try slotDTO.preWorkoutMobilityRoutineIDSnapshot.map {
                        try requiredUUID($0, named: "repeating plan slot pre-workout mobility routine")
                    },
                    preWorkoutMobilityRoutineNameSnapshot: slotDTO.preWorkoutMobilityRoutineNameSnapshot,
                    postWorkoutMobilityRoutine: slotDTO.postWorkoutMobilityRoutineName.flatMap {
                        restoreCtx.mobilityRoutinesByName[$0]
                    },
                    postWorkoutMobilityRoutineIDSnapshot: try slotDTO.postWorkoutMobilityRoutineIDSnapshot.map {
                        try requiredUUID($0, named: "repeating plan slot post-workout mobility routine")
                    },
                    postWorkoutMobilityRoutineNameSnapshot: slotDTO.postWorkoutMobilityRoutineNameSnapshot
                )
                slot.id = try requiredUUID(slotDTO.id, named: "repeating plan slot")
                return slot
            }
            let plan = RepeatingPlan(
                name: planDTO.name,
                goal: PlanGoal(rawValue: planDTO.goal) ?? .generalStrength,
                experienceLevel: PlanExperienceLevel(rawValue: planDTO.experienceLevel) ?? .beginner,
                requiredEquipment: planDTO.requiredEquipment.compactMap(EquipmentType.init(rawValue:)),
                notes: planDTO.notes,
                isArchived: planDTO.isArchived,
                isBuiltIn: planDTO.isBuiltIn,
                slots: slots
            )
            plan.id = try requiredUUID(planDTO.id, named: "repeating plan")
            plan.createdAt = planDTO.createdAt
            plan.updatedAt = planDTO.updatedAt
            restoreCtx.context.insert(plan)
            restoreCtx.repeatingPlanMap[planDTO.id] = plan
        }

        for runDTO in repeatingPlanRuns {
            let slots = try runDTO.slots.map { slotDTO in
                let slot = RepeatingPlanRunSlot(
                    sourceSlotID: try requiredUUID(slotDTO.sourceSlotID, named: "repeating plan run slot source"),
                    orderIndex: slotDTO.orderIndex,
                    templateIDSnapshot: try requiredUUID(slotDTO.templateIDSnapshot, named: "repeating plan run slot template"),
                    templateNameSnapshot: slotDTO.templateNameSnapshot,
                    workoutTemplate: slotDTO.workoutTemplateName.flatMap { restoreCtx.templateMap[$0] },
                    preWorkoutMobilityRoutine: slotDTO.preWorkoutMobilityRoutineName.flatMap {
                        restoreCtx.mobilityRoutinesByName[$0]
                    },
                    preWorkoutMobilityRoutineIDSnapshot: try slotDTO.preWorkoutMobilityRoutineIDSnapshot.map {
                        try requiredUUID($0, named: "repeating plan run slot pre-workout mobility routine")
                    },
                    preWorkoutMobilityRoutineNameSnapshot: slotDTO.preWorkoutMobilityRoutineNameSnapshot,
                    postWorkoutMobilityRoutine: slotDTO.postWorkoutMobilityRoutineName.flatMap {
                        restoreCtx.mobilityRoutinesByName[$0]
                    },
                    postWorkoutMobilityRoutineIDSnapshot: try slotDTO.postWorkoutMobilityRoutineIDSnapshot.map {
                        try requiredUUID($0, named: "repeating plan run slot post-workout mobility routine")
                    },
                    postWorkoutMobilityRoutineNameSnapshot: slotDTO.postWorkoutMobilityRoutineNameSnapshot
                )
                slot.id = try requiredUUID(slotDTO.id, named: "repeating plan run slot")
                return slot
            }
            let run = RepeatingPlanRun(
                sourcePlanID: try requiredUUID(runDTO.sourcePlanID, named: "repeating plan run source plan"),
                sourcePlanName: runDTO.sourcePlanName,
                status: RepeatingPlanRunStatus(rawValue: runDTO.status) ?? .active,
                currentSlotIndex: runDTO.currentSlotIndex,
                completedCycleCount: runDTO.completedCycleCount,
                startedAt: runDTO.startedAt,
                endedAt: runDTO.endedAt,
                updatedAt: runDTO.updatedAt,
                plan: runDTO.planID.flatMap { restoreCtx.repeatingPlanMap[$0] },
                slots: slots
            )
            run.id = try requiredUUID(runDTO.id, named: "repeating plan run")
            restoreCtx.context.insert(run)
            restoreCtx.repeatingPlanRunMap[runDTO.id] = run
        }
    }

    private func restoreProgramDefinitions(into restoreCtx: inout RestoreContext) throws {
        for definitionDTO in programDefinitions {
            let decoder = JSONDecoder()
            guard let payload = try? decoder.decode(ProgramDefinitionPayload.self, from: definitionDTO.definitionData) else {
                throw BackupValidationError.invalidProgramDefinition(definitionDTO.name)
            }
            let record: ProgramDefinitionRecord
            do {
                record = try ProgramDefinitionRecord(payload: payload, isBuiltIn: definitionDTO.isBuiltIn)
            } catch {
                throw BackupValidationError.invalidProgramDefinition(definitionDTO.name)
            }
            record.id = try requiredUUID(definitionDTO.id, named: "program definition")
            record.schemaVersion = definitionDTO.schemaVersion
            record.templateVersion = definitionDTO.templateVersion
            record.name = definitionDTO.name
            record.summary = definitionDTO.summary
            record.goal = PlanGoal(rawValue: definitionDTO.goal) ?? payload.goal
            record.experienceLevel = PlanExperienceLevel(rawValue: definitionDTO.experienceLevel) ?? payload.experienceLevel
            record.durationWeeks = definitionDTO.durationWeeks
            record.supportedDaysPerWeek = definitionDTO.supportedDaysPerWeek
            record.isArchived = definitionDTO.isArchived
            record.createdAt = definitionDTO.createdAt
            record.updatedAt = definitionDTO.updatedAt
            record.definitionData = definitionDTO.definitionData
            restoreCtx.context.insert(record)
        }
    }

    /// Mirrors `restoreProgramDefinitions` exactly: decode the versioned
    /// recipe blob, revalidate it structurally, and materialize the
    /// queryable metadata columns. No `MobilityDefinition` catalog check
    /// happens here — the structural validator is catalog-free, matching
    /// `ProgramDefinitionValidator`'s own split, and a dangling movement
    /// reference is a compile-time concern for a later slice, not a restore
    /// blocker.
    private func restoreMobilityProgramDefinitions(into restoreCtx: inout RestoreContext) throws {
        for definitionDTO in mobilityProgramDefinitions {
            let decoder = JSONDecoder()
            guard let payload = try? decoder.decode(MobilityProgramDefinitionPayload.self, from: definitionDTO.definitionData) else {
                throw BackupValidationError.invalidMobilityProgramDefinition(definitionDTO.name)
            }
            let record: MobilityProgramDefinitionRecord
            do {
                record = try MobilityProgramDefinitionRecord(payload: payload, isBuiltIn: definitionDTO.isBuiltIn)
            } catch {
                throw BackupValidationError.invalidMobilityProgramDefinition(definitionDTO.name)
            }
            record.id = try requiredUUID(definitionDTO.id, named: "mobility program definition")
            record.programKey = definitionDTO.programKey
            record.schemaVersion = definitionDTO.schemaVersion
            record.templateVersion = definitionDTO.templateVersion
            record.name = definitionDTO.name
            record.summary = definitionDTO.summary
            record.durationWeeks = definitionDTO.durationWeeks
            record.supportedDaysPerWeek = definitionDTO.supportedDaysPerWeek
            record.isArchived = definitionDTO.isArchived
            record.createdAt = definitionDTO.createdAt
            record.updatedAt = definitionDTO.updatedAt
            record.definitionData = definitionDTO.definitionData
            restoreCtx.context.insert(record)
        }
    }

    /// Restores the Release 8 part 2 runtime graph. Every run reconstructs
    /// its frozen `programSnapshotData` blob byte-for-byte (never
    /// re-derived from the live definition) and its full session-progress /
    /// progression-state graphs, mirroring `restorePlanRunProgress`'s idiom.
    /// `MobilitySession` ids are preserved verbatim by `restoreMobility`
    /// (which always runs before this), so `mobilitySessionID` is restored
    /// as the opaque ownership key it already is — no lookup map needed.
    private func restoreMobilityProgramRuns(into restoreCtx: inout RestoreContext) throws {
        for runDTO in mobilityProgramRuns {
            let run = try MobilityProgramRun(
                program: try decodeProgramSnapshot(runDTO.programSnapshotData),
                sourceProgramID: try requiredUUID(runDTO.sourceProgramID, named: "mobility program run source program"),
                startDate: runDTO.startDate,
                id: try requiredUUID(runDTO.id, named: "mobility program run")
            )
            run.programSnapshotData = runDTO.programSnapshotData
            run.sourceProgramName = runDTO.sourceProgramName
            run.endDate = runDTO.endDate
            run.status = MobilityProgramRunStatus(rawValue: runDTO.status) ?? .active
            run.currentWeekIndex = runDTO.currentWeekIndex
            run.currentSessionIndex = runDTO.currentSessionIndex
            run.createdAt = runDTO.createdAt
            run.updatedAt = runDTO.updatedAt

            for progressDTO in runDTO.sessionProgress {
                let progress = MobilityProgramSessionProgress(
                    sessionKey: progressDTO.sessionKey,
                    weekIndex: progressDTO.weekIndex,
                    dayIndex: progressDTO.dayIndex,
                    sameDayOrder: progressDTO.sameDayOrder,
                    isOptional: progressDTO.isOptional,
                    sessionNameSnapshot: progressDTO.sessionNameSnapshot,
                    scheduledDate: progressDTO.scheduledDate,
                    id: try requiredUUID(progressDTO.id, named: "mobility program session progress")
                )
                progress.originalScheduledDate = progressDTO.originalScheduledDate
                progress.lastRescheduledAt = progressDTO.lastRescheduledAt
                progress.status = MobilityProgramSessionStatus(rawValue: progressDTO.status) ?? .pending
                progress.startedAt = progressDTO.startedAt
                progress.completedAt = progressDTO.completedAt
                progress.mobilitySessionID = try progressDTO.mobilitySessionID.map {
                    try requiredUUID($0, named: "mobility program session progress mobility session")
                }
                run.sessionProgress.append(progress)
            }
            for stateDTO in runDTO.progressionStates {
                let state = MobilityProgressionState(
                    progressionKey: stateDTO.progressionKey,
                    side: MobilitySide(rawValue: stateDTO.side) ?? .none,
                    durationOffsetSeconds: stateDTO.durationOffsetSeconds,
                    repetitionOffset: stateDTO.repetitionOffset,
                    cycleOffset: stateDTO.cycleOffset,
                    loadOffset: stateDTO.loadOffset,
                    assistanceLevelOffset: stateDTO.assistanceLevelOffset,
                    supportLevelStepOffset: stateDTO.supportLevelStepOffset,
                    variationStepOffset: stateDTO.variationStepOffset,
                    consecutiveTargetMetSessionCount: stateDTO.consecutiveTargetMetSessionCount,
                    lastAppliedRecommendationID: try stateDTO.lastAppliedRecommendationID.map {
                        try requiredUUID($0, named: "mobility progression state recommendation")
                    },
                    id: try requiredUUID(stateDTO.id, named: "mobility progression state"),
                    updatedAt: stateDTO.updatedAt
                )
                run.progressionStates.append(state)
            }
            restoreCtx.context.insert(run)
        }
    }

    private func decodeProgramSnapshot(_ data: Data) throws -> MobilityProgramDefinitionPayload {
        guard let payload = try? JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: data) else {
            throw BackupValidationError.invalidMobilityProgramDefinition("mobility program run snapshot")
        }
        return payload
    }

    /// Distinct from `restoreProgressionRecommendations` — see
    /// `MobilityProgressionRecommendationRecord`'s doc comment for the
    /// audited reason a shared table was not safe.
    private func restoreMobilityProgressionRecommendations(into restoreCtx: inout RestoreContext) throws {
        for recommendationDTO in mobilityProgressionRecommendations {
            guard
                let action = try? JSONDecoder().decode(MobilityProgressionAction.self, from: recommendationDTO.actionData),
                let applicationMode = ProgressionApplicationMode(rawValue: recommendationDTO.applicationMode)
            else {
                throw BackupValidationError.invalidIdentifier("mobility progression recommendation")
            }
            let performance = recommendationDTO.performanceData.flatMap {
                try? JSONDecoder().decode(MobilityProgressionPerformance.self, from: $0)
            } ?? MobilityProgressionPerformance()
            let proposal = MobilityProgressionProposal(
                id: try requiredUUID(recommendationDTO.id, named: "mobility progression recommendation"),
                ruleID: try requiredUUID(recommendationDTO.ruleID, named: "mobility progression recommendation rule"),
                action: action,
                reason: recommendationDTO.reason,
                reasonKey: recommendationDTO.reasonKey ?? "",
                applicationMode: applicationMode,
                proposedState: MobilityProgressionProposedState(
                    durationOffsetSeconds: recommendationDTO.proposedDurationOffsetSeconds,
                    repetitionOffset: recommendationDTO.proposedRepetitionOffset,
                    cycleOffset: recommendationDTO.proposedCycleOffset,
                    loadOffset: recommendationDTO.proposedLoadOffset,
                    assistanceLevelOffset: recommendationDTO.proposedAssistanceLevelOffset,
                    supportLevelStepOffset: recommendationDTO.proposedSupportLevelStepOffset,
                    variationStepOffset: recommendationDTO.proposedVariationStepOffset
                ),
                performance: performance
            )
            let record = try MobilityProgressionRecommendationRecord(
                runID: try requiredUUID(recommendationDTO.runID, named: "mobility progression recommendation run"),
                sessionProgressID: try requiredUUID(recommendationDTO.sessionProgressID, named: "mobility progression recommendation session progress"),
                progressionKey: recommendationDTO.progressionKey,
                side: MobilitySide(rawValue: recommendationDTO.side) ?? .none,
                proposal: proposal
            )
            record.id = proposal.id
            record.createdAt = recommendationDTO.createdAt
            record.isResolved = recommendationDTO.isResolved
            record.resolvedAt = recommendationDTO.resolvedAt
            if let decisionOutcomeRawValue = recommendationDTO.decisionOutcome {
                guard let decisionOutcome = ProgressionDecisionOutcome(rawValue: decisionOutcomeRawValue) else {
                    throw BackupValidationError.invalidIdentifier("mobility progression recommendation decision outcome")
                }
                record.decisionOutcome = decisionOutcome
            }
            restoreCtx.context.insert(record)
        }
    }

    private func restorePlansAndRuns(into restoreCtx: inout RestoreContext) throws {
        for planDTO in plans {
            let blocks = try planDTO.blocks.map { blockDTO in
                let weeks = try blockDTO.weeks.map { weekDTO in
                    let plannedWorkouts = try weekDTO.plannedWorkouts.map { plannedWorkoutDTO in
                        let plannedExercises = try plannedWorkoutDTO.plannedExercises.map { plannedExerciseDTO in
                            guard let exercise = restoreCtx.exerciseMap[plannedExerciseDTO.exerciseName] else {
                                throw BackupValidationError.missingExercise(plannedExerciseDTO.exerciseName)
                            }
                            let alternativeExercises = (plannedExerciseDTO.alternativeExerciseNames ?? []).compactMap {
                                restoreCtx.exerciseMap[$0]
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
                                        tempo: plannedSetDTO.tempo,
                                        progressionEligible: plannedSetDTO.progressionEligible ?? true,
                                        isOptional: plannedSetDTO.isOptional,
                                        notes: plannedSetDTO.notes,
                                        definitionData: plannedSetDTO.definitionData
                                    )
                                },
                                supersetGroupID: plannedExerciseDTO.supersetGroupID.flatMap(UUID.init(uuidString:)),
                                progressionKey: plannedExerciseDTO.progressionKey,
                                progressionRulesData: plannedExerciseDTO.progressionRulesData,
                                progressionWavesData: plannedExerciseDTO.progressionWavesData,
                                progressionStagesData: plannedExerciseDTO.progressionStagesData,
                                variationLadderData: plannedExerciseDTO.variationLadderData,
                                initialVariationExerciseID: plannedExerciseDTO.initialVariationExerciseID.flatMap(UUID.init(uuidString:)),
                                initialVelocityBaseline: plannedExerciseDTO.initialVelocityBaseline,
                                initialTrainingMax: plannedExerciseDTO.initialTrainingMax,
                                initialEstimatedOneRepMax: plannedExerciseDTO.initialEstimatedOneRepMax,
                                initialActualOneRepMax: plannedExerciseDTO.initialActualOneRepMax,
                                automaticDeloadVolumeReductionPercent: plannedExerciseDTO.automaticDeloadVolumeReductionPercent,
                                automaticDeloadIntensityReductionPercent: plannedExerciseDTO.automaticDeloadIntensityReductionPercent,
                                warmupSchemeData: plannedExerciseDTO.warmupSchemeData
                            )
                            plannedExercise.id = try requiredUUID(plannedExerciseDTO.id, named: "planned exercise")
                            plannedExercise.executionBlockID = plannedExerciseDTO.executionBlockID.flatMap(UUID.init(uuidString:))
                            plannedExercise.executionBlockComponentOrder = plannedExerciseDTO.executionBlockComponentOrder
                            return plannedExercise
                        }
                        let plannedWorkout = PlannedWorkout(
                            name: plannedWorkoutDTO.name,
                            orderIndex: plannedWorkoutDTO.orderIndex,
                            dayOffset: plannedWorkoutDTO.dayOffset,
                            isOptional: plannedWorkoutDTO.isOptional,
                            isTestDay: plannedWorkoutDTO.isTestDay,
                            estimatedDurationSeconds: plannedWorkoutDTO.estimatedDurationSeconds,
                            notes: plannedWorkoutDTO.notes,
                            sourceTemplate: plannedWorkoutDTO.sourceTemplateName.flatMap { restoreCtx.templateMap[$0] },
                            plannedExercises: plannedExercises
                        )
                        plannedWorkout.executionBlocks = (plannedWorkoutDTO.executionBlocks ?? []).compactMap { blockDTO in
                            guard let id = UUID(uuidString: blockDTO.id),
                                  let kind = ExerciseBlockKind(rawValue: blockDTO.kind),
                                  let clockMode = BlockClockMode(rawValue: blockDTO.clockMode),
                                  let scoreKind = BlockScoreKind(rawValue: blockDTO.scoreKind) else {
                                return nil
                            }
                            let block = PlannedExerciseBlock(
                                orderIndex: blockDTO.orderIndex,
                                kind: kind,
                                name: blockDTO.name,
                                targetRounds: blockDTO.targetRounds,
                                isSharedLoad: blockDTO.isSharedLoad,
                                restSeconds: blockDTO.restSeconds,
                                clockMode: clockMode,
                                prescribedDurationSeconds: blockDTO.prescribedDurationSeconds,
                                timeCapSeconds: blockDTO.timeCapSeconds,
                                intervalSeconds: blockDTO.intervalSeconds,
                                scoreKind: scoreKind,
                                repetitionScheme: blockDTO.repetitionScheme.flatMap(BlockRepetitionScheme.init(rawValue:)) ?? .fixed,
                                repetitionStart: blockDTO.repetitionStart,
                                repetitionEnd: blockDTO.repetitionEnd,
                                repetitionStep: blockDTO.repetitionStep,
                                sourceTemplateBlockID: blockDTO.sourceTemplateBlockID.flatMap(UUID.init(uuidString:)),
                                definitionBlockKey: blockDTO.definitionBlockKey
                            )
                            block.id = id
                            return block
                        }
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
                scheduleMode: planDTO.scheduleMode.flatMap(PlanScheduleMode.init(rawValue:)) ?? .fixedWeekdays,
                scheduleIntervalDays: planDTO.scheduleIntervalDays ?? 1,
                notes: planDTO.notes,
                blocks: blocks,
                sourceProgramDefinitionID: planDTO.sourceProgramDefinitionID.flatMap(UUID.init(uuidString:)),
                sourceProgramDefinitionVersion: planDTO.sourceProgramDefinitionVersion
            )
            plan.id = try requiredUUID(planDTO.id, named: "plan")
            plan.completionPolicyData = planDTO.completionPolicyData
            plan.createdAt = planDTO.createdAt
            plan.updatedAt = planDTO.updatedAt
            plan.isArchived = planDTO.isArchived
            restoreCtx.context.insert(plan)
            restoreCtx.planMap[planDTO.id] = plan
        }
    }

    /// Workout history restores in three passes because each depends on the
    /// previous one's identity map: performed workouts first, then the plan-run
    /// progress that points at them, then the progression recommendations that
    /// reference both.
    private func restoreWorkoutHistory(
        from workouts: [CurrentWorkoutHistoryArchive],
        into restoreCtx: inout RestoreContext
    ) throws {
        try restoreWorkouts(from: workouts, into: &restoreCtx)
        try restorePlanRunProgress(into: &restoreCtx)
        try restoreProgressionRecommendations(into: &restoreCtx)
    }

    private func restoreWorkouts(
        from workouts: [CurrentWorkoutHistoryArchive],
        into restoreCtx: inout RestoreContext
    ) throws {
        for normalizedWorkout in workouts {
            let workoutDTO = normalizedWorkout.dto
            let newWorkout = Workout(name: workoutDTO.name, endTime: workoutDTO.endTime)
            if let identifier = workoutDTO.id {
                newWorkout.id = try requiredUUID(identifier, named: "workout")
            }
            newWorkout.status = normalizedWorkout.status
            newWorkout.notes = workoutDTO.notes
            newWorkout.startTime = workoutDTO.startTime
            newWorkout.restEndDate = workoutDTO.restEndDate
            newWorkout.pausedRemainingTime = workoutDTO.pausedRemainingTime

            if let templateName = workoutDTO.sourceTemplateName, let template = restoreCtx.templateMap[templateName] {
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
            if let programID = workoutDTO.sourceProgramDefinitionID {
                newWorkout.sourceProgramDefinitionID = UUID(uuidString: programID)
            }
            newWorkout.sourceProgramDefinitionVersion = workoutDTO.sourceProgramDefinitionVersion
            newWorkout.sourceRepeatingPlanID = workoutDTO.sourceRepeatingPlanID.flatMap(UUID.init(uuidString:))
            newWorkout.sourceRepeatingPlanRunID = workoutDTO.sourceRepeatingPlanRunID.flatMap(UUID.init(uuidString:))
            newWorkout.sourceRepeatingPlanOccurrenceID = workoutDTO.sourceRepeatingPlanOccurrenceID.flatMap(UUID.init(uuidString:))
            newWorkout.sourceRepeatingPlanName = workoutDTO.sourceRepeatingPlanName

            newWorkout.exercises = try restoreExerciseEntries(
                from: normalizedWorkout.entries,
                into: &restoreCtx
            )
            newWorkout.executionBlocks = (workoutDTO.executionBlocks ?? []).compactMap { blockDTO in
                guard let blockID = UUID(uuidString: blockDTO.id),
                      let kind = ExerciseBlockKind(rawValue: blockDTO.kind),
                      let clockMode = BlockClockMode(rawValue: blockDTO.clockMode),
                      let scoreKind = BlockScoreKind(rawValue: blockDTO.scoreKind),
                      let status = WorkoutBlockStatus(rawValue: blockDTO.status) else {
                    return nil
                }
                let block = WorkoutExecutionBlock(
                    orderIndex: blockDTO.orderIndex,
                    kind: kind,
                    name: blockDTO.name,
                    targetRounds: blockDTO.targetRounds,
                    isSharedLoad: blockDTO.isSharedLoad,
                    restSeconds: blockDTO.restSeconds,
                    clockMode: clockMode,
                    prescribedDurationSeconds: blockDTO.prescribedDurationSeconds,
                    timeCapSeconds: blockDTO.timeCapSeconds,
                    intervalSeconds: blockDTO.intervalSeconds,
                    scoreKind: scoreKind,
                    repetitionScheme: blockDTO.repetitionScheme.flatMap(BlockRepetitionScheme.init(rawValue:)) ?? .fixed,
                    repetitionStart: blockDTO.repetitionStart,
                    repetitionEnd: blockDTO.repetitionEnd,
                    repetitionStep: blockDTO.repetitionStep
                )
                block.id = blockID
                block.status = status
                block.completedRounds = blockDTO.completedRounds
                block.additionalRepetitions = blockDTO.additionalRepetitions
                block.scoreValue = blockDTO.scoreValue
                block.scoreTiebreakValue = blockDTO.scoreTiebreakValue
                block.accumulatedElapsedDuration = blockDTO.accumulatedElapsedDuration
                block.elapsedStartedAt = blockDTO.elapsedStartedAt
                block.sourceTemplateBlockID = blockDTO.sourceTemplateBlockID.flatMap(UUID.init(uuidString:))
                block.sourcePlannedBlockID = blockDTO.sourcePlannedBlockID.flatMap(UUID.init(uuidString:))
                block.sourceDefinitionBlockKey = blockDTO.sourceDefinitionBlockKey
                return block
            }
            restoreCtx.context.insert(newWorkout)
            if let identifier = workoutDTO.id {
                restoreCtx.workoutMap[identifier] = newWorkout
            }
        }

    }


    /// Rebuilds one workout's exercise entries and their sets. Split out of
    /// `restoreWorkouts` for size only — it stays inside the same transaction
    /// and mutates the same identity maps.
    private func restoreExerciseEntries(
        from normalizedEntries: [CurrentExerciseEntryArchive],
        into restoreCtx: inout RestoreContext
    ) throws -> [ExerciseEntry] {
        var exercises: [ExerciseEntry] = []
        for normalizedEntry in normalizedEntries {
            let entryDTO = normalizedEntry.dto
            guard let exerciseTemplate = restoreCtx.exerciseMap[entryDTO.exerciseName] else { continue }

            let entry = ExerciseEntry(
                comment: entryDTO.comment,
                exercise: exerciseTemplate,
                orderIndex: entryDTO.orderIndex,
                usedMetric: normalizedEntry.usedMetric,
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
            entry.progressionKey = entryDTO.progressionKey
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
            entry.executionBlockID = entryDTO.executionBlockID.flatMap(UUID.init(uuidString:))
            entry.executionBlockComponentOrder = entryDTO.executionBlockComponentOrder
            entry.originalExerciseIDSnapshot = entryDTO.originalExerciseIDSnapshot.flatMap(UUID.init(uuidString:))
            entry.originalExerciseNameSnapshot = entryDTO.originalExerciseNameSnapshot
            entry.selectedSubstituteExerciseIDSnapshot = entryDTO.selectedSubstituteExerciseIDSnapshot.flatMap(UUID.init(uuidString:))
            entry.substitutionReason = entryDTO.substitutionReason
            entry.substitutionSharesProgressionState = entryDTO.substitutionSharesProgressionState ?? false
            entry.substitutionReasonCode = entryDTO.substitutionReasonCode
            entry.substitutionSuitabilityRaw = entryDTO.substitutionSuitability
            entry.substitutionComparabilityRaw = entryDTO.substitutionComparability
            entry.substitutionProgressionPolicyRaw = entryDTO.substitutionProgressionPolicy
            entry.substitutionScopeRaw = entryDTO.substitutionScope
            entry.substitutionEvidenceConfidenceRaw = entryDTO.substitutionEvidenceConfidence
            entry.substitutionEvaluationVersion = entryDTO.substitutionEvaluationVersion
            entry.substitutionEvaluationData = entryDTO.substitutionEvaluationData
            // The invariant restore must not break: a payload whose policy and
            // Boolean disagree (hand-edited, or written by a build with a bug)
            // is resolved in favor of the conservative reading. Shared
            // progression is only ever restored when the policy explicitly
            // says so.
            if let policy = entryDTO.substitutionProgressionPolicy
                .flatMap(ProgressionTransferPolicy.init(rawValue:)) {
                entry.substitutionSharesProgressionState = policy.sharesProgressionState
            }
            entry.variationSourceExerciseIDSnapshot = entryDTO.variationSourceExerciseIDSnapshot.flatMap(UUID.init(uuidString:))
            entry.variationSelectedExerciseIDSnapshot = entryDTO.variationSelectedExerciseIDSnapshot.flatMap(UUID.init(uuidString:))
            entry.prescriptionDefinitionData = entryDTO.prescriptionDefinitionData
            entry.prescriptionRulesData = entryDTO.prescriptionRulesData
            entry.deferredBackOffDefinitionsData = entryDTO.deferredBackOffDefinitionsData

            if let historicalName = normalizedEntry.historicalNameSnapshot {
                entry.nameSnapshot = historicalName
            }
            entry.exerciseIDSnapshot = normalizedEntry.explicitHistoricalExerciseID ?? exerciseTemplate.id
            if let tracking = normalizedEntry.trackingTypeSnapshot {
                entry.trackingTypeSnapshot = tracking
            }
            if let laterality = normalizedEntry.lateralitySnapshot {
                entry.lateralitySnapshot = laterality
            }
            if let style = normalizedEntry.repCountingStyleSnapshot {
                entry.repCountingStyleSnapshot = style
            }
            if let style = normalizedEntry.weightEntryStyleSnapshot {
                entry.weightEntryStyleSnapshot = style
            }
            if let count = normalizedEntry.loadUnitCountSnapshot {
                entry.loadUnitCountSnapshot = count
            }
            entry.sportDisciplineSnapshotRaw = entryDTO.sportDisciplineSnapshot
            entry.strongmanEventFamilySnapshotRaw = entryDTO.strongmanEventFamilySnapshot

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
                    calories: setDTO.calories,
                    done: setDTO.done,
                    isUserOverridden: setDTO.isUserOverridden,
                    userOverrideReason: setDTO.userOverrideReason,
                    userOverrideAffectsFuture: setDTO.userOverrideAffectsFuture,
                    rpe: setDTO.rpe,
                    meanVelocity: setDTO.meanVelocity,
                    peakVelocity: setDTO.peakVelocity,
                    velocityMeasurementSource: setDTO.velocityMeasurementSource.flatMap(MeasurementSource.init(rawValue:)),
                    specializedMetricKind: setDTO.specializedMetricKind.flatMap(SpecializedPerformanceMetricKind.init(rawValue:)) ?? .none,
                    jumpHeightMeters: setDTO.jumpHeightMeters,
                    contactTimeMilliseconds: setDTO.contactTimeMilliseconds,
                    throwDistanceMeters: setDTO.throwDistanceMeters,
                    kettlebellCadenceRPM: setDTO.kettlebellCadenceRPM,
                    specializedMetricMeasurementSource: setDTO.specializedMetricMeasurementSource.flatMap(MeasurementSource.init(rawValue:)),
                    setMethod: setDTO.setMethod.flatMap(SetMethod.init(rawValue:)) ?? .standard,
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
                setObj.prescribedUnroundedLoad = setDTO.prescribedUnroundedLoad
                setObj.prescribedReferenceValue = setDTO.prescribedReferenceValue
                setObj.prescriptionLoadExplanation = setDTO.prescriptionLoadExplanation
                setObj.prescribedRestSeconds = setDTO.prescribedRestSeconds
                setObj.prescribedRPE = setDTO.prescribedRPE
                setObj.prescribedRIR = setDTO.prescribedRIR
                setObj.prescribedTempo = setDTO.prescribedTempo
                setObj.prescribedProgressionEligible = setDTO.prescribedProgressionEligible
                setObj.prescribedCalories = setDTO.prescribedCalories
                setObj.prescribedVelocityMinimum = setDTO.prescribedVelocityMinimum
                setObj.prescribedVelocityMaximum = setDTO.prescribedVelocityMaximum
                setObj.prescribedVelocityLossStopPercent = setDTO.prescribedVelocityLossStopPercent
                setObj.isVelocityProbe = setDTO.isVelocityProbe ?? false
                setObj.isPrescribedOptional = setDTO.isPrescribedOptional
                setObj.prescriptionNotes = setDTO.prescriptionNotes
                setObj.prescriptionDefinitionData = setDTO.prescriptionDefinitionData
                setObj.rir = setDTO.rir
                setObj.tempo = setDTO.tempo
                setObj.movementQuality = setDTO.movementQuality
                setObj.descriptiveROM = setDTO.descriptiveROM
                setObj.discomfortScore = setDTO.discomfortScore
                setObj.liftQuality = setDTO.liftQuality.flatMap(LiftQuality.init(rawValue:))
                setObj.strongmanLoadConventionRaw = setDTO.strongmanLoadConvention
                setObj.strongmanImplementProfileData = setDTO.strongmanImplementProfileData
                setObj.strongmanEventFamilyRaw = setDTO.strongmanEventFamily
                setObj.segments = (setDTO.segments ?? []).compactMap { segmentDTO in
                    guard let segmentID = UUID(uuidString: segmentDTO.id) else { return nil }
                    let segment = ExerciseSetSegment(
                        orderIndex: segmentDTO.orderIndex,
                        repetitions: segmentDTO.repetitions,
                        weight: segmentDTO.weight,
                        weightType: WeightType(rawValue: segmentDTO.weightType) ?? .kg,
                        duration: segmentDTO.duration,
                        restAfterSeconds: segmentDTO.restAfterSeconds,
                        done: segmentDTO.done,
                        variationNote: segmentDTO.variationNote,
                        rpe: segmentDTO.rpe,
                        rir: segmentDTO.rir,
                        splitKind: segmentDTO.splitKind.flatMap(WorkoutSplitKind.init(rawValue:)),
                        startedAt: segmentDTO.startedAt,
                        endedAt: segmentDTO.endedAt,
                        distanceMeters: segmentDTO.distanceMeters,
                        heartRateBPM: segmentDTO.heartRateBPM,
                        perceivedExertion: segmentDTO.perceivedExertion
                    )
                    segment.id = segmentID
                    return segment
                }
                setObj.complexComponents = (setDTO.complexComponents ?? []).compactMap { componentDTO in
                    guard let id = UUID(uuidString: componentDTO.id),
                          let exerciseID = UUID(uuidString: componentDTO.exerciseID),
                          let outcome = ComplexComponentOutcome(rawValue: componentDTO.outcome)
                    else { return nil }
                    let component = ComplexComponentResult(
                        orderIndex: componentDTO.orderIndex,
                        exerciseID: exerciseID,
                        exerciseNameSnapshot: componentDTO.exerciseNameSnapshot,
                        prescribedRepetitions: componentDTO.prescribedRepetitions,
                        performedRepetitions: componentDTO.performedRepetitions,
                        outcome: outcome,
                        liftQuality: componentDTO.liftQuality.flatMap(LiftQuality.init(rawValue:))
                    )
                    component.id = id
                    return component
                }
                setObj.isSelectedDailyMaximum = setDTO.isSelectedDailyMaximum ?? false
                setObj.generatedBackOffDefinitionID = setDTO.generatedBackOffDefinitionID.flatMap(UUID.init(uuidString:))
                if let id = setDTO.id.flatMap(UUID.init(uuidString:)) {
                    setObj.id = id
                }
                sets.append(setObj)
            }
            entry.sets = sets
            exercises.append(entry)
        }
        return exercises
    }

    private func restoreRepeatingPlanOccurrences(into restoreCtx: inout RestoreContext) throws {
        for runDTO in repeatingPlanRuns {
            guard let run = restoreCtx.repeatingPlanRunMap[runDTO.id] else {
                throw BackupValidationError.invalidIdentifier("repeating plan run")
            }
            for occurrenceDTO in runDTO.occurrences {
                let occurrence = RepeatingPlanOccurrence(
                    cycleIndex: occurrenceDTO.cycleIndex,
                    expectedSlotIndex: occurrenceDTO.expectedSlotIndex,
                    selectedSlotIndex: occurrenceDTO.selectedSlotIndex,
                    kind: RepeatingPlanOccurrenceKind(rawValue: occurrenceDTO.kind) ?? .expected,
                    continuationMode: RepeatingPlanContinuationMode(rawValue: occurrenceDTO.continuationMode) ?? .continueAfterSelected,
                    status: RepeatingPlanOccurrenceStatus(rawValue: occurrenceDTO.status) ?? .upcoming,
                    cursorBefore: occurrenceDTO.cursorBefore,
                    cursorAfter: occurrenceDTO.cursorAfter,
                    cycleBefore: occurrenceDTO.cycleBefore,
                    cycleAfter: occurrenceDTO.cycleAfter,
                    createdAt: occurrenceDTO.createdAt,
                    startedAt: occurrenceDTO.startedAt,
                    completedAt: occurrenceDTO.completedAt,
                    undoneAt: occurrenceDTO.undoneAt,
                    completedWorkout: occurrenceDTO.completedWorkoutID.flatMap { restoreCtx.workoutMap[$0] }
                )
                occurrence.id = try requiredUUID(occurrenceDTO.id, named: "repeating plan occurrence")
                run.occurrences.append(occurrence)
            }
        }
    }

    private func restorePlanRunProgress(into restoreCtx: inout RestoreContext) throws {
        for runDTO in planRuns {
            let sourcePlanID = try requiredUUID(runDTO.sourcePlanID, named: "plan run source plan")
            let run = PlanRun(
                sourcePlanID: sourcePlanID,
                sourcePlanName: runDTO.sourcePlanName,
                startDate: runDTO.startDate,
                plan: runDTO.planID.flatMap { restoreCtx.planMap[$0] }
            )
            run.id = try requiredUUID(runDTO.id, named: "plan run")
            run.endDate = runDTO.endDate
            run.status = PlanRunStatus(rawValue: runDTO.status) ?? .active
            run.currentWeekIndex = runDTO.currentWeekIndex
            run.currentWorkoutIndex = runDTO.currentWorkoutIndex
            run.endedProgressionKeysData = runDTO.endedProgressionKeysData
            run.createdAt = runDTO.createdAt
            run.updatedAt = runDTO.updatedAt

            for progressDTO in runDTO.workoutProgress {
                let progress = PlanWorkoutProgress(
                    plannedWorkoutID: try requiredUUID(progressDTO.plannedWorkoutID, named: "plan workout progress"),
                    plannedWorkoutName: progressDTO.plannedWorkoutName,
                    weekIndex: progressDTO.weekIndex,
                    sourceWeekIndex: progressDTO.sourceWeekIndex,
                    workoutIndex: progressDTO.workoutIndex,
                    scheduledDate: progressDTO.scheduledDate
                )
                progress.id = try requiredUUID(progressDTO.id, named: "plan workout progress")
                progress.originalScheduledDate = progressDTO.originalScheduledDate
                progress.lastRescheduledAt = progressDTO.lastRescheduledAt
                progress.status = PlanWorkoutStatus(rawValue: progressDTO.status) ?? .upcoming
                progress.startedAt = progressDTO.startedAt
                progress.completedAt = progressDTO.completedAt
                progress.skipReason = progressDTO.skipReason
                if let workoutID = progressDTO.completedWorkoutID {
                    progress.completedWorkout = restoreCtx.workoutMap[workoutID]
                }
                run.workoutProgress.append(progress)
            }
            for stateDTO in runDTO.progressionStates {
                let state = PlanExerciseProgressionState(
                    progressionKey: stateDTO.progressionKey,
                    scopeRaw: stateDTO.scope ?? "exerciseExposure",
                    scopeOwnerKey: stateDTO.scopeOwnerKey,
                    currentLoad: stateDTO.currentLoad,
                    currentLoadType: stateDTO.currentLoadType.flatMap(WeightType.init(rawValue:)),
                    repetitionOffset: stateDTO.repetitionOffset,
                    setCountOffset: stateDTO.setCountOffset,
                    durationOffset: stateDTO.durationOffset,
                    distanceOffset: stateDTO.distanceOffset,
                    restDurationOffset: stateDTO.restDurationOffset,
                    caloriesOffset: stateDTO.caloriesOffset,
                    currentStageID: stateDTO.currentStageID,
                    currentVariationExerciseID: stateDTO.currentVariationExerciseID.flatMap(UUID.init(uuidString:)),
                    trainingMax: stateDTO.trainingMax,
                    estimatedOneRepMax: stateDTO.estimatedOneRepMax,
                    actualOneRepMax: stateDTO.actualOneRepMax,
                    failureCount: stateDTO.failureCount,
                    successCount: stateDTO.successCount,
                    currentWaveIndex: stateDTO.currentWaveIndex,
                    currentBlockIndex: stateDTO.currentBlockIndex,
                    previousAMRAPRepetitions: stateDTO.previousAMRAPRepetitions,
                    previousActualRPE: stateDTO.previousActualRPE,
                    previousActualRIR: stateDTO.previousActualRIR,
                    velocityBaseline: stateDTO.velocityBaseline,
                    lastCompletedOccurrence: stateDTO.lastCompletedOccurrence,
                    lastSuccessfulLoad: stateDTO.lastSuccessfulLoad,
                    isDeloading: stateDTO.isDeloading,
                    lastAppliedOutcomeID: stateDTO.lastAppliedOutcomeID.flatMap(UUID.init(uuidString:)),
                    lastAppliedSetID: stateDTO.lastAppliedSetID.flatMap(UUID.init(uuidString:)),
                    appliedProgressionEventsData: stateDTO.appliedProgressionEventsData,
                    pendingProgressionData: stateDTO.pendingProgressionData
                )
                state.id = try requiredUUID(stateDTO.id, named: "progression state")
                run.progressionStates.append(state)
            }
            restoreCtx.context.insert(run)
        }

    }

    private func restoreProgressionRecommendations(into restoreCtx: inout RestoreContext) throws {
        for recommendationDTO in progressionRecommendations {
            guard
                let action = try? JSONDecoder().decode(ProgressionAction.self, from: recommendationDTO.actionData),
                let cadence = ProgressionCadence(rawValue: recommendationDTO.cadence),
                let scope = ProgressionScope(rawValue: recommendationDTO.scope),
                let applicationMode = ProgressionApplicationMode(rawValue: recommendationDTO.applicationMode)
            else {
                throw BackupValidationError.invalidIdentifier("progression recommendation")
            }
            let recommendation = ProgressionRecommendation(
                id: try requiredUUID(recommendationDTO.id, named: "progression recommendation"),
                ruleID: try requiredUUID(recommendationDTO.ruleID, named: "progression recommendation rule"),
                action: action,
                cadence: cadence,
                scope: scope,
                reason: recommendationDTO.reason,
                reasonKey: recommendationDTO.reasonKey,
                applicationMode: applicationMode,
                proposedState: ProgressionEvaluationState(
                    currentLoad: recommendationDTO.proposedLoad,
                    repetitionOffset: recommendationDTO.proposedRepetitionOffset,
                    setCountOffset: recommendationDTO.proposedSetCountOffset,
                    durationOffset: recommendationDTO.proposedDurationOffset,
                    distanceOffset: recommendationDTO.proposedDistanceOffset,
                    restDurationOffset: recommendationDTO.proposedRestDurationOffset,
                    caloriesOffset: recommendationDTO.proposedCaloriesOffset,
                    currentStageID: recommendationDTO.proposedStageID,
                    currentVariationExerciseID: recommendationDTO.proposedVariationExerciseID.flatMap(UUID.init(uuidString:)),
                    currentWaveIndex: recommendationDTO.proposedWaveIndex,
                    currentBlockIndex: recommendationDTO.proposedBlockIndex,
                    trainingMax: recommendationDTO.proposedTrainingMax,
                    estimatedOneRepMax: recommendationDTO.proposedEstimatedOneRepMax,
                    actualOneRepMax: recommendationDTO.proposedActualOneRepMax,
                    isDeloading: recommendationDTO.proposedIsDeloading
                ),
                performance: (recommendationDTO.performanceData.flatMap {
                    try? JSONDecoder().decode(ProgressionPerformance.self, from: $0)
                }) ?? ProgressionPerformance(),
                ruleVersion: recommendationDTO.ruleVersion
            )
            let record = try PlanProgressionRecommendationRecord(
                recommendation: recommendation,
                planRunID: try requiredUUID(recommendationDTO.planRunID, named: "progression recommendation plan run"),
                workoutID: try requiredUUID(recommendationDTO.workoutID, named: "progression recommendation workout"),
                scopeOwnerKey: recommendationDTO.scopeOwnerKey ?? "",
                proposedLoadUnit: recommendationDTO.proposedLoadUnit.flatMap(WeightType.init(rawValue:))
            )
            record.id = recommendation.id
            record.progressionKey = recommendationDTO.progressionKey
            record.createdAt = recommendationDTO.createdAt
            record.isResolved = recommendationDTO.isResolved
            record.resolvedAt = recommendationDTO.resolvedAt
            // Legacy backups (< progressionReceiptVersion) carry no decision
            // outcome; decoding leaves these `nil`, which must never be
            // back-filled or inferred from `isResolved` — a restored legacy
            // row means "resolved without a recorded outcome," not a
            // fabricated decision.
            if let decisionOutcomeRawValue = recommendationDTO.decisionOutcome {
                guard let decisionOutcome = ProgressionDecisionOutcome(rawValue: decisionOutcomeRawValue) else {
                    throw BackupValidationError.invalidIdentifier("progression recommendation decision outcome")
                }
                record.decisionOutcome = decisionOutcome
            }
            record.appliedLoad = recommendationDTO.appliedLoad
            restoreCtx.context.insert(record)
        }
    }

    /// Restores the lifter's stated preferences.
    ///
    /// Nothing here can fail the restore. Every value is decoded leniently: an
    /// identifier this build does not recognise — a discipline added in a later
    /// version, say — is dropped, and the rest of the profile lands intact. A
    /// preference is never worth losing a backup over.
    private func restoreTrainingProfile(into restoreCtx: inout RestoreContext) throws {
#if !GYMTRACKER_EXTENSION
        guard let dto = trainingProfile else { return }
        let profile = TrainingProfile()
        profile.schemaVersion = dto.schemaVersion ?? 1
        profile.onboardingVersion = dto.onboardingVersion ?? 1
        profile.preferredTrainingStructureRaw = validated(dto.preferredTrainingStructure, as: TrainingStructureChoice.self)
        profile.primaryDisciplineRaw = validated(dto.primaryDiscipline, as: TrainingDisciplinePreference.self)
        profile.secondaryDisciplineIDs = dto.secondaryDisciplineIDs ?? []
        profile.primaryGoalRaw = validated(dto.primaryGoal, as: TrainingGoalPreference.self)
        profile.experienceLevelRaw = validated(dto.experienceLevel, as: ProfileExperienceLevel.self)
        profile.preferredDaysPerWeek = dto.preferredDaysPerWeek
        profile.preferredWeekdays = (dto.preferredWeekdays ?? []).filter { (1...7).contains($0) }
        profile.scheduleFlexibilityRaw = validated(dto.scheduleFlexibility, as: ScheduleFlexibility.self)
        profile.rotationCadenceRaw = validated(dto.rotationCadence, as: RotationCadencePreference.self)
        profile.sessionDurationRaw = validated(dto.sessionDuration, as: SessionDurationPreference.self)
        profile.trainingLocationRaw = validated(dto.trainingLocation, as: TrainingLocationPreference.self)
        profile.equipmentCapabilityIDs = (dto.equipmentCapabilityIDs ?? [])
            .filter { EquipmentType(rawValue: $0) != nil }
        // Specialized implements are deliberately *not* filtered against a
        // known list: they are versioned capability identifiers, and an
        // unrecognised one means this build is older than the backup, not that
        // the value is wrong. Dropping it would quietly lose the answer on the
        // round trip back to the newer build.
        profile.specializedEquipmentCapabilityIDs = dto.specializedEquipmentCapabilityIDs ?? []
        profile.focusAreaIDs = (dto.focusAreaIDs ?? []).filter { FocusArea(rawValue: $0) != nil }

        let competition = CompetitionProfileDraft(
            discipline: dto.competitionDiscipline.flatMap(CompetitionDiscipline.init(rawValue:)),
            eventDate: dto.competitionEventDateTimestamp.map(Date.init(timeIntervalSince1970:)),
            standards: dto.competitionStandards.flatMap(CompetitionStandards.init(rawValue:))
        )
        if !competition.isEmpty {
            profile.competitionProfileData = try? JSONEncoder().encode(competition)
        }

        profile.mobilityGoalRaw = validated(dto.mobilityGoal, as: MobilityGoalPreference.self)
        profile.mobilityExperienceRaw = validated(dto.mobilityExperience, as: MobilityExperiencePreference.self)
        profile.mobilityFrequencyRaw = validated(dto.mobilityFrequency, as: MobilityFrequencyPreference.self)

        profile.completedCoreOnboardingAt = dto.completedCoreOnboardingAtTimestamp
            .map(Date.init(timeIntervalSince1970:))
        profile.createdAt = dto.createdAtTimestamp.map(Date.init(timeIntervalSince1970:)) ?? .now
        profile.updatedAt = dto.updatedAtTimestamp.map(Date.init(timeIntervalSince1970:)) ?? .now

        restoreCtx.context.insert(profile)
#endif
    }

    /// Keeps a raw identifier only when this build understands it.
    private func validated<T: RawRepresentable>(
        _ raw: String?,
        as type: T.Type
    ) -> String? where T.RawValue == String {
        guard let raw, T(rawValue: raw) != nil else { return nil }
        return raw
    }

    private func restoreDailyContextAndPreferences(into restoreCtx: inout RestoreContext) throws {
        for entryDTO in dailyLogEntries {
            guard let status = DailyCheckInStatus(rawValue: entryDTO.status) else {
                throw BackupValidationError.invalidIdentifier("daily log entry")
            }
            let entry = DailyLogEntry(
                day: LocalDay(rawValue: entryDTO.dayKey),
                status: status,
                sleepQuality: entryDTO.sleepQuality,
                energy: entryDTO.energy,
                workoutDifficulty: entryDTO.workoutDifficulty,
                note: entryDTO.note,
                createdAt: entryDTO.createdAt,
                updatedAt: entryDTO.updatedAt,
                id: try requiredUUID(entryDTO.id, named: "daily log entry")
            )
            restoreCtx.context.insert(entry)
        }

        for entryDTO in bodyWeightEntries {
            guard let unit = WeightType(rawValue: entryDTO.unit),
                  let source = BodyWeightSource(rawValue: entryDTO.source) else {
                throw BackupValidationError.invalidIdentifier("body weight entry")
            }
            restoreCtx.context.insert(BodyWeightEntry(
                day: LocalDay(rawValue: entryDTO.dayKey),
                value: entryDTO.value,
                unit: unit,
                source: source,
                measuredAt: entryDTO.measuredAt,
                createdAt: entryDTO.createdAt,
                updatedAt: entryDTO.updatedAt,
                id: try requiredUUID(entryDTO.id, named: "body weight entry")
            ))
        }

        for occurrenceDTO in supplementOccurrences {
            guard let kind = SupplementKind(rawValue: occurrenceDTO.kind),
                  let status = SupplementOccurrenceStatus(rawValue: occurrenceDTO.status) else {
                throw BackupValidationError.invalidIdentifier("supplement occurrence")
            }
            let occurrence = SupplementOccurrence(
                kind: kind,
                day: LocalDay(rawValue: occurrenceDTO.dayKey),
                status: status,
                completedAt: occurrenceDTO.completedAt,
                createdAt: occurrenceDTO.createdAt,
                updatedAt: occurrenceDTO.updatedAt,
                id: try requiredUUID(occurrenceDTO.id, named: "supplement occurrence")
            )
            restoreCtx.context.insert(occurrence)
        }
    }

    private func restoreMobility(into restoreCtx: inout RestoreContext) throws {
        for familyDTO in mobilityFamilies {
            let family = MobilityFamily(
                name: familyDTO.name,
                id: try requiredUUID(familyDTO.id, named: "mobility family"),
                createdAt: familyDTO.createdAt,
                updatedAt: familyDTO.updatedAt
            )
            restoreCtx.mobilityFamiliesByID[familyDTO.id] = family
            restoreCtx.context.insert(family)
        }

        for definitionDTO in mobilityDefinitions {
            guard let trackingType = MobilityTrackingType(rawValue: definitionDTO.trackingType) else {
                throw BackupValidationError.invalidIdentifier("mobility definition")
            }
            let definition = MobilityDefinition(
                name: definitionDTO.name,
                instructions: definitionDTO.instructions,
                trackingType: trackingType,
                defaultDurationSeconds: definitionDTO.defaultDurationSeconds,
                defaultRepetitions: definitionDTO.defaultRepetitions,
                isFavorite: definitionDTO.isFavorite,
                isCustom: definitionDTO.isCustom,
                isArchived: definitionDTO.isArchived,
                family: definitionDTO.familyID.flatMap { restoreCtx.mobilityFamiliesByID[$0] },
                id: try requiredUUID(definitionDTO.id, named: "mobility definition"),
                createdAt: definitionDTO.createdAt,
                updatedAt: definitionDTO.updatedAt
            )
            restoreCtx.mobilityDefinitionsByID[definitionDTO.id] = definition
            restoreCtx.context.insert(definition)
        }

        for routineDTO in mobilityRoutines {
            let routine = MobilityRoutine(
                name: routineDTO.name,
                notes: routineDTO.notes,
                // Purpose keys in an older-format payload predate this field's
                // meaning, so they are deliberately ignored rather than trusted.
                purpose: version >= Self.mobilityRoutinePurposeVersion
                    ? routineDTO.purpose.flatMap(MobilityRoutinePurpose.init(rawValue:))
                    : nil,
                isArchived: routineDTO.isArchived,
                id: try requiredUUID(routineDTO.id, named: "mobility routine"),
                createdAt: routineDTO.createdAt,
                updatedAt: routineDTO.updatedAt
            )
            routine.items = try routineDTO.items.map { itemDTO in
                guard let definition = restoreCtx.mobilityDefinitionsByID[itemDTO.definitionID],
                      let side = MobilitySide(rawValue: itemDTO.side) else {
                    throw BackupValidationError.invalidIdentifier("mobility routine item")
                }
                let item = MobilityRoutineItem(
                    definition: definition,
                    orderIndex: itemDTO.orderIndex,
                    targetDurationSeconds: itemDTO.targetDurationSeconds,
                    targetRepetitions: itemDTO.targetRepetitions,
                    targetLoadValue: itemDTO.targetLoadValue,
                    targetLoadUnit: itemDTO.targetLoadUnit.flatMap(MobilityLoadUnit.init(rawValue:)),
                    side: side,
                    restSeconds: itemDTO.restSeconds,
                    notes: itemDTO.notes,
                    id: try requiredUUID(itemDTO.id, named: "mobility routine item")
                )
                item.cycleCount = itemDTO.cycleCount ?? 1
                item.phases = try (itemDTO.phases ?? []).map { phaseDTO in
                    guard let phaseType = PNFPhaseType(rawValue: phaseDTO.phaseType),
                          let phaseSide = MobilitySide(rawValue: phaseDTO.side) else {
                        throw BackupValidationError.invalidIdentifier("mobility phase prescription")
                    }
                    return MobilityPhasePrescription(
                        orderIndex: phaseDTO.orderIndex,
                        phaseType: phaseType,
                        durationSeconds: phaseDTO.durationSeconds,
                        contractionIntensity: phaseDTO.contractionIntensity.flatMap(ContractionIntensity.init(rawValue:)),
                        instructions: phaseDTO.instructions,
                        side: phaseSide,
                        id: try requiredUUID(phaseDTO.id, named: "mobility phase prescription")
                    )
                }
                if version >= Self.advancedMobilityEvidenceVersion,
                   itemDTO.method != nil
                    || itemDTO.trainingPurpose != nil
                    || itemDTO.breathingPrescription != nil
                    || itemDTO.tempoPrescription != nil
                    || itemDTO.assistancePrescription != nil
                    || itemDTO.supportLevel != nil
                    || itemDTO.metricProfile != nil
                    || itemDTO.metricTargets != nil
                    || itemDTO.blockKey != nil
                    || itemDTO.sideStrategy != nil
                    || itemDTO.restPrescription != nil {
                    let evidence = MobilityRoutineItemEvidence(
                        routineItemID: item.id,
                        method: itemDTO.method.flatMap(MobilityMethod.init(rawValue:)),
                        purpose: itemDTO.trainingPurpose.flatMap(MobilityTrainingPurpose.init(rawValue:)),
                        breathingPrescription: itemDTO.breathingPrescription.map {
                            MobilityBreathingPrescription(
                                targetBreaths: $0.targetBreaths,
                                inhaleSeconds: $0.inhaleSeconds,
                                exhaleSeconds: $0.exhaleSeconds,
                                instructionKey: $0.instructionKey
                            )
                        },
                        tempoPrescription: itemDTO.tempoPrescription.map {
                            MobilityTempoPrescription(
                                moveIntoRangeSeconds: $0.moveIntoRangeSeconds,
                                holdSeconds: $0.holdSeconds,
                                returnSeconds: $0.returnSeconds,
                                pauseSeconds: $0.pauseSeconds
                            )
                        },
                        assistancePrescription: itemDTO.assistancePrescription.map {
                            MobilityAssistancePrescription(
                                assistanceTypeRaw: $0.assistanceType,
                                level: $0.level,
                                equipmentRaw: $0.equipment
                            )
                        },
                        supportLevel: itemDTO.supportLevel.flatMap(MobilitySupportLevel.init(rawValue:)),
                        metricProfile: itemDTO.metricProfile,
                        metricTargets: itemDTO.metricTargets,
                        blockKey: itemDTO.blockKey,
                        sideStrategy: itemDTO.sideStrategy.flatMap(MobilitySideStrategy.init(rawValue:)),
                        restPrescription: itemDTO.restPrescription,
                        createdAt: routineDTO.createdAt,
                        updatedAt: routineDTO.updatedAt
                    )
                    restoreCtx.context.insert(evidence)
                }
                return item
            }
            if version >= Self.advancedMobilityEvidenceVersion {
                for blockDTO in routineDTO.blocks ?? [] {
                    guard let kind = MobilityBlockKind(rawValue: blockDTO.kind) else {
                        throw BackupValidationError.invalidIdentifier("mobility routine block")
                    }
                    let block = MobilityRoutineBlock(
                        blockKey: blockDTO.blockKey,
                        routineID: routine.id,
                        orderIndex: blockDTO.orderIndex,
                        name: blockDTO.name,
                        kind: kind,
                        targetRounds: blockDTO.targetRounds,
                        restPrescription: blockDTO.restPrescription,
                        createdAt: routineDTO.createdAt,
                        updatedAt: routineDTO.updatedAt
                    )
                    restoreCtx.context.insert(block)
                }
            }
            restoreCtx.mobilityRoutinesByName[routineDTO.name] = routine
            restoreCtx.context.insert(routine)
        }

        for sessionDTO in mobilitySessions {
            guard let status = MobilitySessionStatus(rawValue: sessionDTO.status),
                  let sessionContext = MobilitySessionContext(rawValue: sessionDTO.context) else {
                throw BackupValidationError.invalidIdentifier("mobility session")
            }
            let session = MobilitySession(
                nameSnapshot: sessionDTO.nameSnapshot,
                sourceRoutineID: try sessionDTO.sourceRoutineID.map { try requiredUUID($0, named: "mobility session routine") },
                sourceRoutineName: sessionDTO.sourceRoutineName,
                workoutID: try sessionDTO.workoutID.map { try requiredUUID($0, named: "mobility session workout") },
                context: sessionContext,
                id: try requiredUUID(sessionDTO.id, named: "mobility session"),
                startTime: sessionDTO.startTime,
                createdAt: sessionDTO.createdAt,
                updatedAt: sessionDTO.updatedAt
            )
            session.status = status
            session.endTime = sessionDTO.endTime
            session.currentEntryIndex = sessionDTO.currentEntryIndex
            session.entries = try sessionDTO.entries.map { entryDTO in
                guard let trackingType = MobilityTrackingType(rawValue: entryDTO.trackingType),
                      let side = MobilitySide(rawValue: entryDTO.side) else {
                    throw BackupValidationError.invalidIdentifier("mobility entry")
                }
                let entry = MobilityEntry(
                    definitionIDSnapshot: try requiredUUID(entryDTO.definitionIDSnapshot, named: "mobility entry definition"),
                    definitionNameSnapshot: entryDTO.definitionNameSnapshot,
                    instructionsSnapshot: entryDTO.instructionsSnapshot,
                    trackingType: trackingType,
                    targetDurationSeconds: entryDTO.targetDurationSeconds,
                    targetRepetitions: entryDTO.targetRepetitions,
                    prescribedLoadValue: entryDTO.prescribedLoadValue,
                    prescribedLoadUnit: entryDTO.prescribedLoadUnit.flatMap(MobilityLoadUnit.init(rawValue:)),
                    side: side,
                    restSeconds: entryDTO.restSeconds,
                    notesSnapshot: entryDTO.notesSnapshot,
                    timerStartedAt: entryDTO.timerStartedAt,
                    orderIndex: entryDTO.orderIndex,
                    id: try requiredUUID(entryDTO.id, named: "mobility entry")
                )
                entry.cycleCount = entryDTO.cycleCount ?? 1
                entry.currentCycleIndex = entryDTO.currentCycleIndex ?? 0
                entry.currentPhaseIndex = entryDTO.currentPhaseIndex ?? 0
                entry.pausedElapsedSeconds = entryDTO.pausedElapsedSeconds ?? 0
                entry.results = try entryDTO.results.map { resultDTO in
                    guard let resultSide = MobilitySide(rawValue: resultDTO.side),
                          let resultStatus = MobilityResultStatus(rawValue: resultDTO.status) else {
                        throw BackupValidationError.invalidIdentifier("mobility result")
                    }
                    let result = MobilityResult(
                        side: resultSide,
                        prescribedDurationSeconds: resultDTO.prescribedDurationSeconds,
                        prescribedRepetitions: resultDTO.prescribedRepetitions,
                        id: try requiredUUID(resultDTO.id, named: "mobility result")
                    )
                    result.status = resultStatus
                    result.performedDurationSeconds = resultDTO.performedDurationSeconds
                    result.performedRepetitions = resultDTO.performedRepetitions
                    result.performedLoadValue = resultDTO.performedLoadValue
                    result.performedLoadUnit = resultDTO.performedLoadUnit.flatMap(MobilityLoadUnit.init(rawValue:))
                    result.perceivedIntensity = resultDTO.perceivedIntensity
                    result.discomfortNote = resultDTO.discomfortNote
                    result.startedAt = resultDTO.startedAt
                    result.completedAt = resultDTO.completedAt
                    if version >= Self.advancedMobilityEvidenceVersion {
                        let evidence = MobilityResultEvidence(
                            resultID: result.id,
                            entryIDSnapshot: entry.id,
                            side: resultSide,
                            methodSnapshot: resultDTO.methodSnapshot.flatMap(MobilityMethod.init(rawValue:)),
                            purposeSnapshot: resultDTO.trainingPurposeSnapshot.flatMap(MobilityTrainingPurpose.init(rawValue:)),
                            breathingPrescriptionSnapshot: resultDTO.breathingPrescriptionSnapshot.map {
                                MobilityBreathingPrescription(
                                    targetBreaths: $0.targetBreaths,
                                    inhaleSeconds: $0.inhaleSeconds,
                                    exhaleSeconds: $0.exhaleSeconds,
                                    instructionKey: $0.instructionKey
                                )
                            },
                            tempoPrescriptionSnapshot: resultDTO.tempoPrescriptionSnapshot.map {
                                MobilityTempoPrescription(
                                    moveIntoRangeSeconds: $0.moveIntoRangeSeconds,
                                    holdSeconds: $0.holdSeconds,
                                    returnSeconds: $0.returnSeconds,
                                    pauseSeconds: $0.pauseSeconds
                                )
                            },
                            assistancePrescriptionSnapshot: resultDTO.assistancePrescriptionSnapshot.map {
                                MobilityAssistancePrescription(
                                    assistanceTypeRaw: $0.assistanceType,
                                    level: $0.level,
                                    equipmentRaw: $0.equipment
                                )
                            },
                            supportLevelSnapshot: resultDTO.supportLevelSnapshot.flatMap(MobilitySupportLevel.init(rawValue:)),
                            metricProfileSnapshot: resultDTO.metricProfileSnapshot,
                            metricTargetsSnapshot: resultDTO.metricTargetsSnapshot,
                            performedBreathingCycles: resultDTO.performedBreathingCycles,
                            performedAssistanceLevel: resultDTO.performedAssistanceLevel,
                            performedSupportLevel: resultDTO.performedSupportLevel.flatMap(MobilitySupportLevel.init(rawValue:)),
                            sensation: resultDTO.sensation.flatMap(MobilitySensation.init(rawValue:)),
                            movementQuality: resultDTO.movementQuality.flatMap(MobilityMovementQuality.init(rawValue:)),
                            compensationKeys: Set((resultDTO.compensationKeys ?? []).compactMap(MobilityCompensationKey.init(rawValue:))),
                            restSnapshot: resultDTO.restSnapshot,
                            recordedAt: resultDTO.completedAt ?? resultDTO.startedAt ?? sessionDTO.startTime
                        )
                        restoreCtx.context.insert(evidence)
                    }
                    return result
                }
                entry.phaseResults = try (entryDTO.phaseResults ?? []).map { phaseResultDTO in
                    guard let phaseType = PNFPhaseType(rawValue: phaseResultDTO.phaseType),
                          let phaseSide = MobilitySide(rawValue: phaseResultDTO.side),
                          let phaseStatus = MobilityResultStatus(rawValue: phaseResultDTO.status) else {
                        throw BackupValidationError.invalidIdentifier("mobility phase result")
                    }
                    let phaseResult = MobilityPhaseResult(
                        orderIndex: phaseResultDTO.orderIndex,
                        phaseType: phaseType,
                        prescribedDurationSeconds: phaseResultDTO.prescribedDurationSeconds,
                        cycleIndex: phaseResultDTO.cycleIndex,
                        side: phaseSide,
                        prescribedIntensity: phaseResultDTO.prescribedIntensity.flatMap(ContractionIntensity.init(rawValue:)),
                        id: try requiredUUID(phaseResultDTO.id, named: "mobility phase result")
                    )
                    phaseResult.performedDurationSeconds = phaseResultDTO.performedDurationSeconds
                    phaseResult.performedIntensity = phaseResultDTO.performedIntensity.flatMap(ContractionIntensity.init(rawValue:))
                    phaseResult.status = phaseStatus
                    phaseResult.startedAt = phaseResultDTO.startedAt
                    phaseResult.completedAt = phaseResultDTO.completedAt
                    return phaseResult
                }
                if version >= Self.advancedMobilityEvidenceVersion,
                   entryDTO.blockKeySnapshot != nil
                    || entryDTO.roundIndexSnapshot.map({ $0 != 0 }) ?? false
                    || entryDTO.sideStrategySnapshot != nil
                    || entryDTO.restPrescriptionSnapshot != nil {
                    let blockKindSnapshot = try entryDTO.blockKindSnapshot.map { raw -> MobilityBlockKind in
                        guard let kind = MobilityBlockKind(rawValue: raw) else {
                            throw BackupValidationError.invalidIdentifier("mobility entry block snapshot")
                        }
                        return kind
                    }
                    let sideStrategySnapshot = try entryDTO.sideStrategySnapshot.map { raw -> MobilitySideStrategy in
                        guard let strategy = MobilitySideStrategy(rawValue: raw) else {
                            throw BackupValidationError.invalidIdentifier("mobility entry side strategy snapshot")
                        }
                        return strategy
                    }
                    restoreCtx.context.insert(
                        MobilityEntryEvidence(
                            entryID: entry.id,
                            blockKeySnapshot: entryDTO.blockKeySnapshot,
                            blockKindSnapshot: blockKindSnapshot,
                            blockNameSnapshot: entryDTO.blockNameSnapshot,
                            blockOrderIndexSnapshot: entryDTO.blockOrderIndexSnapshot,
                            blockTargetRoundsSnapshot: entryDTO.blockTargetRoundsSnapshot,
                            blockRestSnapshot: entryDTO.blockRestSnapshot,
                            roundIndexSnapshot: entryDTO.roundIndexSnapshot ?? 0,
                            sideStrategySnapshot: sideStrategySnapshot,
                            restPrescriptionSnapshot: entryDTO.restPrescriptionSnapshot,
                            createdAt: sessionDTO.startTime
                        )
                    )
                }
                return entry
            }
            restoreCtx.context.insert(session)
        }
    }

    private func restoreMobilityAssessments(into restoreCtx: inout RestoreContext) throws {
        guard version >= Self.mobilityAssessmentVersion else { return }

        for definitionDTO in mobilityAssessmentDefinitions {
            guard let zone = MobilityAssessmentZone(rawValue: definitionDTO.zone),
                  let preferredMode = MobilityMeasurementMode(rawValue: definitionDTO.preferredMode),
                  let manualMode = MobilityMeasurementMode(rawValue: definitionDTO.manualMode),
                  let unit = MobilityMeasurementUnit(rawValue: definitionDTO.unit) else {
                throw BackupValidationError.invalidIdentifier("mobility assessment definition")
            }
            let definition = MobilityAssessmentDefinition(
                catalogueKey: definitionDTO.catalogueKey,
                name: definitionDTO.name,
                nameLocalizationKey: definitionDTO.nameLocalizationKey,
                instructionsLocalizationKey: definitionDTO.instructionsLocalizationKey,
                setupInstructionsLocalizationKey: definitionDTO.setupInstructionsLocalizationKey,
                measurementDescriptionLocalizationKey: definitionDTO.measurementDescriptionLocalizationKey,
                measurementLimitationsLocalizationKey: definitionDTO.measurementLimitationsLocalizationKey,
                zone: zone,
                definitionVersion: definitionDTO.definitionVersion,
                preferredMode: preferredMode,
                manualMode: manualMode,
                unit: unit,
                supportedSides: try definitionDTO.supportedSides.map {
                    guard let side = MobilityAssessmentSide(rawValue: $0) else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment definition side")
                    }
                    return side
                },
                setupKeys: definitionDTO.setupKeys,
                defaultSetupKey: definitionDTO.defaultSetupKey,
                defaultIsActiveRange: definitionDTO.defaultIsActiveRange,
                sortOrder: definitionDTO.sortOrder,
                isArchived: definitionDTO.isArchived,
                id: try requiredUUID(definitionDTO.id, named: "mobility assessment definition"),
                createdAt: definitionDTO.createdAt,
                updatedAt: definitionDTO.updatedAt
            )
            restoreCtx.mobilityAssessmentDefinitionsByKey[definition.catalogueKey] = definition
            restoreCtx.context.insert(definition)
        }

        for sessionDTO in mobilityAssessmentSessions {
            guard let status = MobilityAssessmentSessionStatus(rawValue: sessionDTO.status) else {
                throw BackupValidationError.invalidIdentifier("mobility assessment session")
            }
            let session = MobilityAssessmentSession(
                day: LocalDay(rawValue: sessionDTO.dayKey),
                selectedDefinitionKeys: sessionDTO.selectedDefinitionKeys,
                id: try requiredUUID(sessionDTO.id, named: "mobility assessment session"),
                startedAt: sessionDTO.startedAt,
                createdAt: sessionDTO.createdAt,
                updatedAt: sessionDTO.updatedAt
            )
            session.status = status
            session.skippedDefinitionKeys = sessionDTO.skippedDefinitionKeys
            session.currentDefinitionIndex = sessionDTO.currentDefinitionIndex
            session.completedAt = sessionDTO.completedAt
            session.results = try sessionDTO.results.map { resultDTO in
                guard let definition = restoreCtx.mobilityAssessmentDefinitionsByKey[
                    resultDTO.definitionCatalogueKeySnapshot
                ],
                    let side = MobilityAssessmentSide(rawValue: resultDTO.side),
                    let method = MobilityMeasurementMode(rawValue: resultDTO.method),
                    let unit = MobilityMeasurementUnit(rawValue: resultDTO.unit),
                    let source = MobilityMeasurementSource(rawValue: resultDTO.source),
                    let confidence = MobilityMeasurementConfidence(rawValue: resultDTO.confidence) else {
                    throw BackupValidationError.invalidIdentifier("mobility assessment result")
                }
                let input = MobilityAssessmentResultInput(
                    numericValue: resultDTO.numericValue,
                    criteria: resultDTO.criteria.flatMap(MobilityAssessmentCriteriaObservation.init(rawValue:)),
                    side: side,
                    isWarm: resultDTO.isWarm,
                    setupKey: resultDTO.setupKey,
                    method: method,
                    unit: unit,
                    isActiveRange: resultDTO.isActiveRange,
                    day: LocalDay(rawValue: resultDTO.dayKey),
                    source: source,
                    confidence: confidence
                )
                let result = MobilityAssessmentResult(
                    definition: definition,
                    input: input,
                    orderIndex: resultDTO.orderIndex,
                    id: try requiredUUID(resultDTO.id, named: "mobility assessment result"),
                    createdAt: resultDTO.createdAt,
                    updatedAt: resultDTO.updatedAt
                )
                result.definitionIDSnapshot = try requiredUUID(
                    resultDTO.definitionIDSnapshot,
                    named: "mobility assessment result definition"
                )
                result.definitionCatalogueKeySnapshot = resultDTO.definitionCatalogueKeySnapshot
                result.definitionNameSnapshot = resultDTO.definitionNameSnapshot
                result.definitionVersionSnapshot = resultDTO.definitionVersionSnapshot
                result.instructionsLocalizationKeySnapshot = resultDTO.instructionsLocalizationKeySnapshot
                result.setupInstructionsLocalizationKeySnapshot = resultDTO.setupInstructionsLocalizationKeySnapshot
                result.measurementDescriptionLocalizationKeySnapshot = resultDTO.measurementDescriptionLocalizationKeySnapshot
                result.measurementLimitationsLocalizationKeySnapshot = resultDTO.measurementLimitationsLocalizationKeySnapshot
                if let sampleDTO = resultDTO.sample {
                    let sample = MobilityAssessmentSample(
                        sampleCount: sampleDTO.sampleCount,
                        median: sampleDTO.median,
                        minimum: sampleDTO.minimum,
                        maximum: sampleDTO.maximum,
                        standardDeviation: sampleDTO.standardDeviation,
                        offAxisExcessDegrees: sampleDTO.offAxisExcessDegrees,
                        captureDuration: sampleDTO.captureDuration,
                        id: try requiredUUID(sampleDTO.id, named: "mobility assessment sample"),
                        createdAt: sampleDTO.createdAt
                    )
                    result.sample = sample
                }
                return result
            }
            restoreCtx.context.insert(session)
        }
    }

    private func restoreNutrition(into restoreCtx: inout RestoreContext) throws {
        for foodDTO in foods {
            guard let referenceUnit = NutritionServingUnit(rawValue: foodDTO.referenceUnit),
                  let sourceKind = FoodSourceKind(rawValue: foodDTO.sourceKind),
                  let confidence = FoodConfidence(rawValue: foodDTO.confidence),
                  let preparationState = FoodPreparationState(rawValue: foodDTO.preparationState) else {
                throw BackupValidationError.invalidIdentifier("food")
            }
            let food = FoodItem(
                name: foodDTO.name,
                referenceAmount: foodDTO.referenceAmount,
                referenceUnit: referenceUnit,
                calories: foodDTO.calories,
                proteinGrams: foodDTO.proteinGrams,
                carbohydrateGrams: foodDTO.carbohydrateGrams,
                fatGrams: foodDTO.fatGrams,
                caffeineMilligrams: foodDTO.caffeineMilligrams,
                npn: foodDTO.npn,
                sourceKind: sourceKind,
                confidence: confidence,
                preparationState: preparationState,
                isFavorite: foodDTO.isFavorite,
                isArchived: foodDTO.isArchived,
                id: try requiredUUID(foodDTO.id, named: "food"),
                createdAt: foodDTO.createdAt,
                updatedAt: foodDTO.updatedAt
            )
            food.frenchName = foodDTO.frenchName
            food.categoryName = foodDTO.categoryName
            food.searchAliases = foodDTO.searchAliases ?? []
            food.servings = try foodDTO.servings.map {
                guard let unit = NutritionServingUnit(rawValue: $0.unit) else {
                    throw BackupValidationError.invalidIdentifier("food serving")
                }
                return FoodServing(
                    name: $0.name,
                    amount: $0.amount,
                    unit: unit,
                    equivalentReferenceAmount: $0.equivalentReferenceAmount,
                    id: try requiredUUID($0.id, named: "food serving")
                )
            }
            restoreCtx.foodsByID[foodDTO.id] = food
            restoreCtx.context.insert(food)
        }

        for templateDTO in mealTemplates {
            guard let preparationState = FoodPreparationState(rawValue: templateDTO.preparationState) else {
                throw BackupValidationError.invalidIdentifier("meal template")
            }
            let template = MealTemplate(
                name: templateDTO.name,
                preparationState: preparationState,
                finalCookedWeightGrams: templateDTO.finalCookedWeightGrams,
                lineageID: try requiredUUID(templateDTO.lineageID, named: "meal template lineage"),
                version: templateDTO.version,
                isCurrent: templateDTO.isCurrent,
                isArchived: templateDTO.isArchived,
                id: try requiredUUID(templateDTO.id, named: "meal template"),
                createdAt: templateDTO.createdAt,
                updatedAt: templateDTO.updatedAt
            )
            template.items = try templateDTO.items.map { itemDTO in
                guard let food = restoreCtx.foodsByID[itemDTO.foodID] else {
                    throw BackupValidationError.invalidIdentifier("meal template food")
                }
                return MealTemplateItem(
                    food: food,
                    orderIndex: itemDTO.orderIndex,
                    servingID: try itemDTO.servingID.map { try requiredUUID($0, named: "meal template serving") },
                    quantity: itemDTO.quantity,
                    id: try requiredUUID(itemDTO.id, named: "meal template item")
                )
            }
            if let originalID = templateDTO.photoIdentifier {
                if let existing = restoreCtx.restoredRecipePhotoIdentifiers[originalID] {
                    template.photoIdentifier = existing
                } else if let data = templateDTO.photoData, let stored = RecipePhotoStore.store(data) {
                    restoreCtx.restoredRecipePhotoIdentifiers[originalID] = stored
                    template.photoIdentifier = stored
                }
            }
            restoreCtx.context.insert(template)
        }

        for mealDTO in loggedMeals {
            guard let slot = MealSlot(rawValue: mealDTO.slot) else {
                throw BackupValidationError.invalidIdentifier("logged meal")
            }
            let meal = LoggedMeal(
                day: LocalDay(rawValue: mealDTO.dayKey),
                slot: slot,
                loggedAt: mealDTO.loggedAt,
                nameSnapshot: mealDTO.nameSnapshot,
                sourceMealTemplateID: try mealDTO.sourceMealTemplateID.map { try requiredUUID($0, named: "logged meal template") },
                sourceMealTemplateName: mealDTO.sourceMealTemplateName,
                id: try requiredUUID(mealDTO.id, named: "logged meal"),
                createdAt: mealDTO.createdAt,
                updatedAt: mealDTO.updatedAt
            )
            meal.items = try mealDTO.items.map { itemDTO in
                guard let unit = NutritionServingUnit(rawValue: itemDTO.portionUnit),
                      let sourceKind = FoodSourceKind(rawValue: itemDTO.sourceKind),
                      let confidence = FoodConfidence(rawValue: itemDTO.confidence),
                      let preparationState = FoodPreparationState(rawValue: itemDTO.preparationState) else {
                    throw BackupValidationError.invalidIdentifier("logged meal item")
                }
                return LoggedMealItem(
                    sourceFoodID: try itemDTO.sourceFoodID.map { try requiredUUID($0, named: "logged meal food") },
                    foodNameSnapshot: itemDTO.foodNameSnapshot,
                    servingNameSnapshot: itemDTO.servingNameSnapshot,
                    quantity: itemDTO.quantity,
                    portionAmountSnapshot: itemDTO.portionAmountSnapshot,
                    portionUnit: unit,
                    caloriesSnapshot: itemDTO.caloriesSnapshot,
                    proteinGramsSnapshot: itemDTO.proteinGramsSnapshot,
                    carbohydrateGramsSnapshot: itemDTO.carbohydrateGramsSnapshot,
                    fatGramsSnapshot: itemDTO.fatGramsSnapshot,
                    caffeineMilligramsSnapshot: itemDTO.caffeineMilligramsSnapshot,
                    sourceKind: sourceKind,
                    confidence: confidence,
                    preparationState: preparationState,
                    orderIndex: itemDTO.orderIndex,
                    id: try requiredUUID(itemDTO.id, named: "logged meal item")
                )
            }
            restoreCtx.context.insert(meal)
        }

        for targetDTO in nutritionTargets {
            guard let phase = NutritionGoalPhase(rawValue: targetDTO.phase) else {
                throw BackupValidationError.invalidIdentifier("nutrition target")
            }
            let target = NutritionTarget(
                phase: phase,
                effectiveStartDay: LocalDay(rawValue: targetDTO.effectiveStartDayKey),
                effectiveEndDay: targetDTO.effectiveEndDayKey.map(LocalDay.init(rawValue:)),
                training: NutritionTargetValues(calories: targetDTO.trainingCalories, protein: targetDTO.trainingProteinGrams, carbohydrates: targetDTO.trainingCarbohydrateGrams, fat: targetDTO.trainingFatGrams),
                rest: NutritionTargetValues(calories: targetDTO.restCalories, protein: targetDTO.restProteinGrams, carbohydrates: targetDTO.restCarbohydrateGrams, fat: targetDTO.restFatGrams),
                isArchived: targetDTO.isArchived,
                id: try requiredUUID(targetDTO.id, named: "nutrition target"),
                createdAt: targetDTO.createdAt,
                updatedAt: targetDTO.updatedAt
            )
            restoreCtx.context.insert(target)
        }
    }
}

private struct RestoreContext {
    let context: ModelContext
    var exerciseMap: [String: Exercise] = [:]
    var templateMap: [String: WorkoutTemplate] = [:]
    var planMap: [String: WorkoutPlan] = [:]
    var repeatingPlanMap: [String: RepeatingPlan] = [:]
    var repeatingPlanRunMap: [String: RepeatingPlanRun] = [:]
    var workoutMap: [String: Workout] = [:]
    var mobilityFamiliesByID: [String: MobilityFamily] = [:]
    var mobilityDefinitionsByID: [String: MobilityDefinition] = [:]
    var mobilityRoutinesByName: [String: MobilityRoutine] = [:]
    var mobilityAssessmentDefinitionsByKey: [String: MobilityAssessmentDefinition] = [:]
    var foodsByID: [String: FoodItem] = [:]
    var restoredRecipePhotoIdentifiers: [String: String] = [:]
}
