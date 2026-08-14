import Foundation

private struct ExecutionBlockValidationInput {
    let id: String
    let kind: String
    let targetRounds: Int?
    let restSeconds: Int?
    let clockMode: String
    let prescribedDurationSeconds: Int?
    let timeCapSeconds: Int?
    let intervalSeconds: Int?
    let scoreKind: String
    let repetitionScheme: String?
    let repetitionStart: Int?
    let repetitionEnd: Int?
    let repetitionStep: Int?
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
    case invalidProgramDefinition(String)
    case invalidMobilityProgramDefinition(String)
    case invalidTrackingProfile(String)

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
        case .invalidProgramDefinition(let message):
            return "The backup contains an invalid program definition: \(message)"
        case .invalidMobilityProgramDefinition(let message):
            return "The backup contains an invalid mobility program definition: \(message)"
        case .invalidTrackingProfile(let message):
            return "The backup contains an invalid tracking profile: \(message)"
        }
    }
}

nonisolated extension BackupDTO {
    nonisolated func validate() throws {
        try BackupEnvelopeValidator.validate(self)
        try ReceiptBackupValidator.validate(self)
        try StrengthBackupValidator.validate(self)
        try ProgramBackupValidator.validate(self)
        try MobilityBackupValidator.validate(self)
        try NutritionBackupValidator.validate(self)
#if !GYMTRACKER_EXTENSION
        try HealthKitBackupValidator.validate(self)
#endif
        let currentArchive = try CurrentBackupArchive(adapting: self)
        let workoutArchive = currentArchive.workout

        // A duplicate display name is only genuinely ambiguous when nothing
        // else can tell the exercises apart. From `programVersion` onward,
        // every exercise carries a required, separately-validated unique id
        // (below), so a custom exercise may legitimately share a built-in
        // one's name — its id remains its true, distinct identity. Older
        // backups never carry ids, so duplicate names there are unresolvable
        // and must still be rejected.
        let exerciseNames = workoutArchive.exercises.map { $0.dto.name }
        if version < Self.programVersion {
            guard Set(exerciseNames).count == exerciseNames.count else {
                let duplicate: String = Dictionary(grouping: exerciseNames, by: \.self)
                    .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
                throw BackupValidationError.duplicateExerciseName(duplicate)
            }
        }

        let availableExerciseNames = Set(exerciseNames)
        let exerciseNameCounts = Dictionary(grouping: workoutArchive.exercises, by: { $0.dto.name })
            .mapValues(\.count)
        let availableExerciseIDs = Set(exercises.compactMap(\.id))
        let mobilityRoutineNames = Set(mobilityRoutines.map(\.name))
        let mobilityRoutineIDsByName = Dictionary(
            mobilityRoutines.map { ($0.name, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        if version >= Self.mobilityLinkageVersion {
            guard
                mobilityRoutineNames.count == mobilityRoutines.count,
                mobilityRoutines.allSatisfy({
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                })
            else {
                throw BackupValidationError.duplicateIdentifier("mobility routine name")
            }
        }
        if version >= Self.mobilityRoutinePurposeVersion {
            guard mobilityRoutines.allSatisfy({
                $0.purpose.map { MobilityRoutinePurpose(rawValue: $0) != nil } ?? true
            }) else {
                throw BackupValidationError.invalidIdentifier("mobility routine purpose")
            }
        }
        for normalizedTemplate in workoutArchive.templates {
            let template = normalizedTemplate.dto
            try validateExecutionBlockGraph(
                template.executionBlocks?.map {
                    ExecutionBlockValidationInput(
                        id: $0.id,
                        kind: $0.kind,
                        targetRounds: $0.targetRounds,
                        restSeconds: $0.restSeconds,
                        clockMode: $0.clockMode,
                        prescribedDurationSeconds: $0.prescribedDurationSeconds,
                        timeCapSeconds: $0.timeCapSeconds,
                        intervalSeconds: $0.intervalSeconds,
                        scoreKind: $0.scoreKind,
                        repetitionScheme: $0.repetitionScheme,
                        repetitionStart: $0.repetitionStart,
                        repetitionEnd: $0.repetitionEnd,
                        repetitionStep: $0.repetitionStep
                    )
                } ?? [],
                memberships: template.templateExercises.map { ($0.executionBlockID, $0.executionBlockComponentOrder) },
                named: "template execution block"
            )
            for templateExercise in template.templateExercises where !availableExerciseNames.contains(templateExercise.exerciseName) {
                throw BackupValidationError.missingExercise(templateExercise.exerciseName)
            }
            for templateExercise in template.templateExercises {
                guard templateExercise.stimulus.map({ TrainingStimulus(rawValue: $0) != nil }) ?? true else {
                    throw BackupValidationError.invalidIdentifier("template exercise stimulus")
                }
            }
            guard
                validateMobilityRoutineReference(
                    template.preWorkoutMobilityRoutineName,
                    availableRoutineNames: mobilityRoutineNames
                ),
                validateMobilityRoutineReference(
                    template.postWorkoutMobilityRoutineName,
                    availableRoutineNames: mobilityRoutineNames
                )
            else {
                throw BackupValidationError.invalidIdentifier("workout template mobility routine")
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

        for normalizedWorkout in workoutArchive.workouts {
            let workout = normalizedWorkout.dto
            try validateExecutionBlockGraph(
                workout.executionBlocks?.map {
                    ExecutionBlockValidationInput(
                        id: $0.id,
                        kind: $0.kind,
                        targetRounds: $0.targetRounds,
                        restSeconds: $0.restSeconds,
                        clockMode: $0.clockMode,
                        prescribedDurationSeconds: $0.prescribedDurationSeconds,
                        timeCapSeconds: $0.timeCapSeconds,
                        intervalSeconds: $0.intervalSeconds,
                        scoreKind: $0.scoreKind,
                        repetitionScheme: $0.repetitionScheme,
                        repetitionStart: $0.repetitionStart,
                        repetitionEnd: $0.repetitionEnd,
                        repetitionStep: $0.repetitionStep
                    )
                } ?? [],
                memberships: workout.exercises.map { ($0.executionBlockID, $0.executionBlockComponentOrder) },
                named: "workout execution block"
            )
            if version >= Self.executionBlockSplitVersion {
                let workoutID = workout.id
                let splits = (workout.executionBlocks ?? []).flatMap { block in
                    (block.splits ?? []).map { (block.id, $0) }
                }
                let splitIDs = splits.map { $0.1.id }
                guard Set(splitIDs).count == splitIDs.count else {
                    throw BackupValidationError.duplicateIdentifier("execution block split")
                }
                for (blockID, split) in splits {
                    guard UUID(uuidString: split.id) != nil,
                          UUID(uuidString: blockID) != nil,
                          split.workoutID == workoutID,
                          WorkoutExecutionBlockSplitKind(rawValue: split.kind) != nil,
                          split.sequenceIndex >= 0,
                          split.roundIndex >= 0,
                          split.componentOrder >= 0,
                          split.elapsedDuration.isFinite,
                          split.elapsedDuration >= 0
                    else {
                        throw BackupValidationError.invalidIdentifier("execution block split")
                    }
                }
                for block in workout.executionBlocks ?? [] {
                    let indexes = (block.splits ?? []).map(\.sequenceIndex)
                    guard Set(indexes).count == indexes.count else {
                        throw BackupValidationError.duplicateIdentifier("execution block split sequence")
                    }
                }
            }
            for entry in workout.exercises where !availableExerciseNames.contains(entry.exerciseName) {
                throw BackupValidationError.missingExercise(entry.exerciseName)
            }
            if version >= Self.strengthExpansionVersion {
                for entry in workout.exercises {
                    for set in entry.sets {
                        try validateStrengthExpansionEvidence(in: set)
                    }
                }
            }
        }

        var relationshipKeys = Set<String>()
        for relationship in exerciseRelationships {
            let sourceReference = relationship.sourceExerciseID ?? relationship.sourceExerciseName
            let targetReference = relationship.targetExerciseID ?? relationship.targetExerciseName
            let sourceResolves = relationship.sourceExerciseID.map(availableExerciseIDs.contains)
                ?? (exerciseNameCounts[relationship.sourceExerciseName] == 1)
            let targetResolves = relationship.targetExerciseID.map(availableExerciseIDs.contains)
                ?? (exerciseNameCounts[relationship.targetExerciseName] == 1)
            guard
                sourceReference != targetReference,
                sourceResolves,
                targetResolves,
                availableExerciseNames.contains(relationship.sourceExerciseName),
                availableExerciseNames.contains(relationship.targetExerciseName),
                ExerciseRelationshipType(rawValue: relationship.type) != nil
            else {
                throw BackupValidationError.invalidExerciseRelationship
            }

            let key = "\(sourceReference)|\(targetReference)|\(relationship.type)"
            guard relationshipKeys.insert(key).inserted else {
                throw BackupValidationError.invalidExerciseRelationship
            }
        }

        if version >= Self.programVersion {
            guard exercises.allSatisfy({ $0.id != nil }) else {
                throw BackupValidationError.invalidIdentifier("exercise")
            }
            try validateUniqueIdentifiers(exercises.compactMap(\.id), named: "exercise")
            try validateUniqueIdentifiers(programDefinitions.map(\.id), named: "program definition")
            for definition in programDefinitions {
                guard PlanGoal(rawValue: definition.goal) != nil,
                      PlanExperienceLevel(rawValue: definition.experienceLevel) != nil,
                      definition.durationWeeks > 0,
                      !definition.supportedDaysPerWeek.isEmpty else {
                    throw BackupValidationError.invalidProgramDefinition(definition.name)
                }
                guard let payload = try? JSONDecoder().decode(ProgramDefinitionPayload.self, from: definition.definitionData) else {
                    throw BackupValidationError.invalidProgramDefinition(definition.name)
                }
                let issues = ProgramDefinitionValidator.validate(payload)
                guard issues.isEmpty else {
                    throw BackupValidationError.invalidProgramDefinition(issues.map(\.message).joined(separator: " "))
                }
            }
            // The mobility program definition graph (Release 8 part 1) is a
            // top-level array new to this slice; it decodes `[]` for every
            // payload older than it, so this check is a no-op for those and
            // does not need its own version gate. Mirrors the program
            // definition validation immediately above: reject before the
            // destination store is ever replaced.
            try validateUniqueIdentifiers(mobilityProgramDefinitions.map(\.id), named: "mobility program definition")
            for definition in mobilityProgramDefinitions {
                guard definition.durationWeeks > 0, !definition.supportedDaysPerWeek.isEmpty else {
                    throw BackupValidationError.invalidMobilityProgramDefinition(definition.name)
                }
                guard let payload = try? JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: definition.definitionData) else {
                    throw BackupValidationError.invalidMobilityProgramDefinition(definition.name)
                }
                let mobilityIssues = MobilityProgramDefinitionValidator.validate(payload, isBuiltIn: definition.isBuiltIn)
                guard mobilityIssues.isEmpty else {
                    throw BackupValidationError.invalidMobilityProgramDefinition(mobilityIssues.map(\.message).joined(separator: " "))
                }
            }
            try validateUniqueIdentifiers(progressionRecommendations.map(\.id), named: "progression recommendation")
            let runIDs = Set(planRuns.map(\.id))
            let completedWorkoutIDs = Set(workouts.compactMap(\.id))
            for recommendation in progressionRecommendations {
                guard runIDs.contains(recommendation.planRunID),
                      completedWorkoutIDs.contains(recommendation.workoutID),
                      UUID(uuidString: recommendation.ruleID) != nil,
                      ProgressionCadence(rawValue: recommendation.cadence) != nil,
                      ProgressionScope(rawValue: recommendation.scope) != nil,
                      ProgressionApplicationMode(rawValue: recommendation.applicationMode) != nil,
                      (try? JSONDecoder().decode(ProgressionAction.self, from: recommendation.actionData)) != nil else {
                    throw BackupValidationError.invalidIdentifier("progression recommendation")
                }
                // Absent for v1–v18 backups and for rows resolved before this
                // field existed; that decodes as `nil` above and must stay
                // `nil` here too. Only a *present* value is checked against
                // the known cases so an unrecognized future value fails
                // loudly instead of restoring as a silently fabricated
                // decision.
                if let decisionOutcome = recommendation.decisionOutcome {
                    guard ProgressionDecisionOutcome(rawValue: decisionOutcome) != nil else {
                        throw BackupValidationError.invalidIdentifier("progression recommendation decision outcome")
                    }
                }
                if let proposedLoadUnit = recommendation.proposedLoadUnit {
                    guard WeightType(rawValue: proposedLoadUnit) != nil else {
                        throw BackupValidationError.invalidIdentifier("progression recommendation load unit")
                    }
                }
            }

            // The Release 8 part 2 mobility program runtime graph is new to
            // this slice, added alongside `mobilityProgramDefinitions`
            // within Backup v26 (no new version constant). Both arrays
            // decode `[]` for every older payload, so this is a no-op there
            // and needs no separate version gate, mirroring the definition
            // validation immediately above.
            try validateUniqueIdentifiers(mobilityProgramRuns.map(\.id), named: "mobility program run")
            var mobilitySessionProgressIDs = Set<String>()
            var mobilitySessionProgressRunIDs = [String: String]()
            for runDTO in mobilityProgramRuns {
                guard let payload = try? JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: runDTO.programSnapshotData) else {
                    throw BackupValidationError.invalidMobilityProgramDefinition(runDTO.sourceProgramName)
                }
                let issues = MobilityProgramDefinitionValidator.validate(payload)
                guard issues.isEmpty else {
                    throw BackupValidationError.invalidMobilityProgramDefinition(issues.map(\.message).joined(separator: " "))
                }
                guard MobilityProgramRunStatus(rawValue: runDTO.status) != nil else {
                    throw BackupValidationError.invalidIdentifier("mobility program run status")
                }
                let progressIDs = runDTO.sessionProgress.map(\.id)
                guard Set(progressIDs).count == progressIDs.count else {
                    throw BackupValidationError.duplicateIdentifier("mobility program session progress")
                }
                for progressDTO in runDTO.sessionProgress {
                    guard mobilitySessionProgressIDs.insert(progressDTO.id).inserted else {
                        throw BackupValidationError.duplicateIdentifier("mobility program session progress")
                    }
                    mobilitySessionProgressRunIDs[progressDTO.id] = runDTO.id
                    guard MobilityProgramSessionStatus(rawValue: progressDTO.status) != nil,
                          progressDTO.dayIndex >= 0, progressDTO.dayIndex <= 6 else {
                        throw BackupValidationError.invalidIdentifier("mobility program session progress")
                    }
                }
                let stateIDs = runDTO.progressionStates.map(\.id)
                guard Set(stateIDs).count == stateIDs.count else {
                    throw BackupValidationError.duplicateIdentifier("mobility progression state")
                }
                for stateDTO in runDTO.progressionStates {
                    guard MobilitySide(rawValue: stateDTO.side) != nil else {
                        throw BackupValidationError.invalidIdentifier("mobility progression state side")
                    }
                }
            }

            try validateUniqueIdentifiers(mobilityProgressionRecommendations.map(\.id), named: "mobility progression recommendation")
            let mobilityRunIDs = Set(mobilityProgramRuns.map(\.id))
            for recommendation in mobilityProgressionRecommendations {
                guard mobilityRunIDs.contains(recommendation.runID),
                      mobilitySessionProgressRunIDs[recommendation.sessionProgressID] == recommendation.runID,
                      UUID(uuidString: recommendation.ruleID) != nil,
                      MobilitySide(rawValue: recommendation.side) != nil,
                      ProgressionApplicationMode(rawValue: recommendation.applicationMode) != nil,
                      (try? JSONDecoder().decode(MobilityProgressionAction.self, from: recommendation.actionData)) != nil
                else {
                    throw BackupValidationError.invalidIdentifier("mobility progression recommendation")
                }
                if let decisionOutcome = recommendation.decisionOutcome {
                    guard ProgressionDecisionOutcome(rawValue: decisionOutcome) != nil else {
                        throw BackupValidationError.invalidIdentifier("mobility progression recommendation decision outcome")
                    }
                }
            }
        }

        if version >= Self.dailyContextVersion {
            try validateUniqueIdentifiers(dailyLogEntries.map(\.id), named: "daily log entry")
            try validateUniqueIdentifiers(supplementOccurrences.map(\.id), named: "supplement occurrence")
            let dayKeys = dailyLogEntries.map(\.dayKey)
            guard Set(dayKeys).count == dayKeys.count,
                  dayKeys.allSatisfy(isValidLocalDayKey),
                  dailyLogEntries.allSatisfy({ DailyCheckInStatus(rawValue: $0.status) != nil }),
                  dailyLogEntries.allSatisfy({ entry in
                      [entry.sleepQuality, entry.energy, entry.workoutDifficulty].allSatisfy { score in
                          score.map { (1...5).contains($0) } ?? true
                      }
                  }),
                  supplementOccurrences.allSatisfy({
                      SupplementKind(rawValue: $0.kind) != nil &&
                      SupplementOccurrenceStatus(rawValue: $0.status) != nil &&
                      $0.occurrenceKey == "\($0.dayKey)|\($0.kind)"
                  }) else {
                throw BackupValidationError.invalidIdentifier("daily context")
            }
            let occurrenceKeys = supplementOccurrences.map(\.occurrenceKey)
            guard supplementOccurrences.allSatisfy({ isValidLocalDayKey($0.dayKey) }) else {
                throw BackupValidationError.invalidIdentifier("daily context")
            }
            guard Set(occurrenceKeys).count == occurrenceKeys.count else {
                throw BackupValidationError.duplicateIdentifier("supplement occurrence")
            }
        }

        if version >= Self.bodyWeightVersion {
            try validateUniqueIdentifiers(bodyWeightEntries.map(\.id), named: "body weight entry")
            let dayKeys = bodyWeightEntries.map(\.dayKey)
            guard Set(dayKeys).count == dayKeys.count,
                  dayKeys.allSatisfy(isValidLocalDayKey),
                  bodyWeightEntries.allSatisfy({ $0.value.isFinite && $0.value > 0 && $0.value <= 1_500 }),
                  bodyWeightEntries.allSatisfy({ WeightType(rawValue: $0.unit) != nil }),
                  bodyWeightEntries.allSatisfy({ BodyWeightSource(rawValue: $0.source) != nil }) else {
                throw BackupValidationError.invalidIdentifier("body weight entry")
            }
        }

        if version >= Self.mobilityVersion {
            try validateMobility()
        }
        if version >= Self.mobilityAssessmentVersion {
            try AssessmentBackupValidator.validate(self)
        }

        if version >= Self.nutritionVersion {
            try validateNutrition()
        }

        // No stimulus/tracking combination may enter persistence through a
        // restore, regardless of the backup's format version.
        if let issue = TrackingProfileValidator.validate(backup: self).first {
            throw BackupValidationError.invalidTrackingProfile(issue.message)
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

                        try validateExecutionBlockGraph(
                            plannedWorkout.executionBlocks?.map {
                                ExecutionBlockValidationInput(
                                    id: $0.id,
                                    kind: $0.kind,
                                    targetRounds: $0.targetRounds,
                                    restSeconds: $0.restSeconds,
                                    clockMode: $0.clockMode,
                                    prescribedDurationSeconds: $0.prescribedDurationSeconds,
                                    timeCapSeconds: $0.timeCapSeconds,
                                    intervalSeconds: $0.intervalSeconds,
                                    scoreKind: $0.scoreKind,
                                    repetitionScheme: $0.repetitionScheme,
                                    repetitionStart: $0.repetitionStart,
                                    repetitionEnd: $0.repetitionEnd,
                                    repetitionStep: $0.repetitionStep
                                )
                            } ?? [],
                            memberships: plannedWorkout.plannedExercises.map { ($0.executionBlockID, $0.executionBlockComponentOrder) },
                            named: "planned execution block"
                        )

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
                guard progress.lastRescheduledAt == nil || progress.originalScheduledDate != nil else {
                    throw BackupValidationError.invalidIdentifier("plan workout progress schedule evidence")
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

        if version >= Self.repeatingPlanVersion {
            try validateRepeatingPlans(
                templateNames: templateNames,
                mobilityRoutineNames: mobilityRoutineNames,
                mobilityRoutineIDsByName: mobilityRoutineIDsByName,
                workoutIDs: workoutIDs
            )
        }
    }

    private func validateRepeatingPlans(
        templateNames: Set<String>,
        mobilityRoutineNames: Set<String>,
        mobilityRoutineIDsByName: [String: String],
        workoutIDs: Set<String>
    ) throws {
        try validateUniqueIdentifiers(repeatingPlans.map(\.id), named: "repeating plan")
        try validateUniqueIdentifiers(repeatingPlanRuns.map(\.id), named: "repeating plan run")

        let repeatingPlanIDs = Set(repeatingPlans.map(\.id))
        var definitionSlotIDs = Set<String>()
        var definitionSlotIDsByPlan: [String: Set<String>] = [:]

        for plan in repeatingPlans {
            guard
                plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                PlanGoal(rawValue: plan.goal) != nil,
                PlanExperienceLevel(rawValue: plan.experienceLevel) != nil,
                plan.requiredEquipment.allSatisfy({ EquipmentType(rawValue: $0) != nil }),
                plan.slots.isEmpty == false
            else {
                throw BackupValidationError.invalidIdentifier("repeating plan")
            }

            let orderedSlots = try validateRepeatingSlots(
                plan.slots,
                templateNames: templateNames,
                mobilityRoutineNames: mobilityRoutineNames,
                mobilityRoutineIDsByName: mobilityRoutineIDsByName,
                named: "repeating plan slot"
            )
            for slot in plan.slots {
                guard definitionSlotIDs.insert(slot.id).inserted else {
                    throw BackupValidationError.duplicateIdentifier("repeating plan slot")
                }
            }
            definitionSlotIDsByPlan[plan.id] = Set(orderedSlots.map(\.id))
        }

        var occurrenceIDs = Set<String>()
        var sourcePlanIDByRunID: [String: String] = [:]
        var occurrenceLinkByID: [
            String: (runID: String, sourcePlanID: String, status: String, completedWorkoutID: String?)
        ] = [:]
        for run in repeatingPlanRuns {
            guard
                RepeatingPlanRunStatus(rawValue: run.status) != nil,
                run.sourcePlanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                run.completedCycleCount >= 0,
                run.slots.isEmpty == false
            else {
                throw BackupValidationError.invalidIdentifier("repeating plan run")
            }
            _ = try requiredUUID(run.sourcePlanID, named: "repeating plan run source plan")

            if let planID = run.planID {
                guard repeatingPlanIDs.contains(planID), run.sourcePlanID == planID else {
                    throw BackupValidationError.missingPlan(planID)
                }
            }

            let orderedSlots = try validateRepeatingRunSlots(
                run.slots,
                templateNames: templateNames,
                mobilityRoutineNames: mobilityRoutineNames,
                mobilityRoutineIDsByName: mobilityRoutineIDsByName
            )
            guard orderedSlots.indices.contains(run.currentSlotIndex) else {
                throw BackupValidationError.invalidIdentifier("repeating plan cursor")
            }
            if let planID = run.planID,
               let definitionSlotIDs = definitionSlotIDsByPlan[planID],
               !Set(run.slots.map(\.sourceSlotID)).isSubset(of: definitionSlotIDs) {
                throw BackupValidationError.invalidIdentifier("repeating plan run slot source")
            }
            sourcePlanIDByRunID[run.id] = run.sourcePlanID

            for occurrence in run.occurrences {
                guard
                    occurrenceIDs.insert(occurrence.id).inserted,
                    UUID(uuidString: occurrence.id) != nil,
                    RepeatingPlanOccurrenceKind(rawValue: occurrence.kind) != nil,
                    RepeatingPlanContinuationMode(rawValue: occurrence.continuationMode) != nil,
                    RepeatingPlanOccurrenceStatus(rawValue: occurrence.status) != nil,
                    occurrence.cycleIndex >= 0,
                    occurrence.cycleBefore >= 0,
                    occurrence.cycleAfter >= 0,
                    orderedSlots.indices.contains(occurrence.expectedSlotIndex),
                    occurrence.selectedSlotIndex.map(orderedSlots.indices.contains) ?? true,
                    orderedSlots.indices.contains(occurrence.cursorBefore),
                    orderedSlots.indices.contains(occurrence.cursorAfter)
                else {
                    throw BackupValidationError.invalidIdentifier("repeating plan occurrence")
                }
                if let completedWorkoutID = occurrence.completedWorkoutID,
                   !workoutIDs.contains(completedWorkoutID) {
                    throw BackupValidationError.missingWorkout(completedWorkoutID)
                }
                occurrenceLinkByID[occurrence.id] = (
                    runID: run.id,
                    sourcePlanID: run.sourcePlanID,
                    status: occurrence.status,
                    completedWorkoutID: occurrence.completedWorkoutID
                )
            }
        }

        for workout in workouts {
            let sourceIDs = [
                workout.sourceRepeatingPlanID,
                workout.sourceRepeatingPlanRunID,
                workout.sourceRepeatingPlanOccurrenceID
            ]
            guard sourceIDs.allSatisfy({ sourceID in
                guard let sourceID else { return true }
                return UUID(uuidString: sourceID) != nil
            }) else {
                throw BackupValidationError.invalidIdentifier("workout repeating plan source")
            }
            let hasRepeatingSource = sourceIDs.contains(where: { $0 != nil }) || workout.sourceRepeatingPlanName != nil
            guard !hasRepeatingSource || (
                workout.sourceRepeatingPlanID != nil
                    && workout.sourceRepeatingPlanRunID != nil
                    && workout.sourceRepeatingPlanOccurrenceID != nil
                    && workout.sourceRepeatingPlanName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ) else {
                throw BackupValidationError.invalidIdentifier("workout repeating plan source")
            }
            if let occurrenceID = workout.sourceRepeatingPlanOccurrenceID,
               let sourceRunID = workout.sourceRepeatingPlanRunID {
                guard
                    let occurrence = occurrenceLinkByID[occurrenceID],
                    sourcePlanIDByRunID[sourceRunID] == workout.sourceRepeatingPlanID,
                    occurrence.runID == sourceRunID,
                    occurrence.sourcePlanID == workout.sourceRepeatingPlanID
                else {
                    throw BackupValidationError.invalidIdentifier("workout repeating plan occurrence")
                }
                let occurrenceStatus = RepeatingPlanOccurrenceStatus(rawValue: occurrence.status)
                let hasValidWorkoutLink =
                    (occurrenceStatus == .inProgress && occurrence.completedWorkoutID == nil)
                    || ((occurrenceStatus == .completed || occurrenceStatus == .undone)
                        && occurrence.completedWorkoutID == workout.id)
                guard hasValidWorkoutLink else {
                    throw BackupValidationError.invalidIdentifier("workout repeating plan occurrence")
                }
            }
        }
    }

    private func validateRepeatingSlots(
        _ slots: [RepeatingPlanSlotDTO],
        templateNames: Set<String>,
        mobilityRoutineNames: Set<String>,
        mobilityRoutineIDsByName: [String: String],
        named: String
    ) throws -> [RepeatingPlanSlotDTO] {
        try validateUniqueIdentifiers(slots.map(\.id), named: named)
        let ordered = slots.sorted { $0.orderIndex < $1.orderIndex }
        guard ordered.enumerated().allSatisfy({ $0.element.orderIndex == $0.offset }) else {
            throw BackupValidationError.invalidIdentifier(named)
        }
        for slot in ordered {
            guard
                UUID(uuidString: slot.templateIDSnapshot) != nil,
                slot.templateNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                slot.workoutTemplateName.map(templateNames.contains) ?? true,
                validateMobilitySnapshotLink(
                    routineName: slot.preWorkoutMobilityRoutineName,
                    snapshotID: slot.preWorkoutMobilityRoutineIDSnapshot,
                    snapshotName: slot.preWorkoutMobilityRoutineNameSnapshot,
                    availableRoutineNames: mobilityRoutineNames,
                    routineIDsByName: mobilityRoutineIDsByName
                ),
                validateMobilitySnapshotLink(
                    routineName: slot.postWorkoutMobilityRoutineName,
                    snapshotID: slot.postWorkoutMobilityRoutineIDSnapshot,
                    snapshotName: slot.postWorkoutMobilityRoutineNameSnapshot,
                    availableRoutineNames: mobilityRoutineNames,
                    routineIDsByName: mobilityRoutineIDsByName
                )
            else {
                throw BackupValidationError.invalidIdentifier(named)
            }
        }
        return ordered
    }

    private func validateRepeatingRunSlots(
        _ slots: [RepeatingPlanRunSlotDTO],
        templateNames: Set<String>,
        mobilityRoutineNames: Set<String>,
        mobilityRoutineIDsByName: [String: String]
    ) throws -> [RepeatingPlanRunSlotDTO] {
        try validateUniqueIdentifiers(slots.map(\.id), named: "repeating plan run slot")
        let ordered = slots.sorted { $0.orderIndex < $1.orderIndex }
        guard ordered.enumerated().allSatisfy({ $0.element.orderIndex == $0.offset }) else {
            throw BackupValidationError.invalidIdentifier("repeating plan run slot")
        }
        for slot in ordered {
            guard
                UUID(uuidString: slot.sourceSlotID) != nil,
                UUID(uuidString: slot.templateIDSnapshot) != nil,
                slot.templateNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                slot.workoutTemplateName.map(templateNames.contains) ?? true,
                validateMobilitySnapshotLink(
                    routineName: slot.preWorkoutMobilityRoutineName,
                    snapshotID: slot.preWorkoutMobilityRoutineIDSnapshot,
                    snapshotName: slot.preWorkoutMobilityRoutineNameSnapshot,
                    availableRoutineNames: mobilityRoutineNames,
                    routineIDsByName: mobilityRoutineIDsByName
                ),
                validateMobilitySnapshotLink(
                    routineName: slot.postWorkoutMobilityRoutineName,
                    snapshotID: slot.postWorkoutMobilityRoutineIDSnapshot,
                    snapshotName: slot.postWorkoutMobilityRoutineNameSnapshot,
                    availableRoutineNames: mobilityRoutineNames,
                    routineIDsByName: mobilityRoutineIDsByName
                )
            else {
                throw BackupValidationError.invalidIdentifier("repeating plan run slot")
            }
        }
        return ordered
    }

    private func validateMobilityRoutineReference(
        _ routineName: String?,
        availableRoutineNames: Set<String>
    ) -> Bool {
        guard version >= Self.mobilityLinkageVersion else {
            return routineName == nil
        }
        return routineName.map(availableRoutineNames.contains) ?? true
    }

    private func validateMobilitySnapshotLink(
        routineName: String?,
        snapshotID: String?,
        snapshotName: String?,
        availableRoutineNames: Set<String>,
        routineIDsByName: [String: String]
    ) -> Bool {
        guard version >= Self.mobilityLinkageVersion else {
            return routineName == nil && snapshotID == nil && snapshotName == nil
        }
        guard routineName.map(availableRoutineNames.contains) ?? true else {
            return false
        }

        let hasSnapshotID = snapshotID != nil
        let hasSnapshotName = snapshotName != nil
        guard hasSnapshotID == hasSnapshotName else { return false }
        guard routineName == nil || hasSnapshotID else { return false }
        guard let snapshotID, let snapshotName else { return true }
        guard
            let snapshotUUID = UUID(uuidString: snapshotID),
            snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return false
        }
        guard let routineName else { return true }
        return routineIDsByName[routineName].flatMap(UUID.init(uuidString:)) == snapshotUUID
    }

    func requiredUUID(_ value: String, named name: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw BackupValidationError.invalidIdentifier(name)
        }
        return uuid
    }

    private func validateExecutionBlockGraph(
        _ blocks: [ExecutionBlockValidationInput],
        memberships: [(String?, Int?)],
        named: String
    ) throws {
        let blockIDs = blocks.map(\.id)
        try validateUniqueIdentifiers(blockIDs, named: named)
        for block in blocks {
            guard UUID(uuidString: block.id) != nil,
                  ExerciseBlockKind(rawValue: block.kind) != nil,
                  BlockClockMode(rawValue: block.clockMode) != nil,
                  BlockScoreKind(rawValue: block.scoreKind) != nil,
                  block.repetitionScheme.map({ BlockRepetitionScheme(rawValue: $0) != nil }) ?? true,
                  block.targetRounds.map({ $0 > 0 }) ?? true,
                  block.restSeconds.map({ $0 >= 0 }) ?? true,
                  block.prescribedDurationSeconds.map({ $0 > 0 }) ?? true,
                  block.timeCapSeconds.map({ $0 > 0 }) ?? true,
                  block.intervalSeconds.map({ $0 > 0 }) ?? true
            else {
                throw BackupValidationError.invalidIdentifier(named)
            }
            let scheme = block.repetitionScheme.flatMap(BlockRepetitionScheme.init(rawValue:)) ?? .fixed
            guard let kind = ExerciseBlockKind(rawValue: block.kind),
                  let clockMode = BlockClockMode(rawValue: block.clockMode)
            else {
                throw BackupValidationError.invalidIdentifier(named)
            }
            if ExecutionBlockConfigurationValidator.message(
                kind: kind,
                clockMode: clockMode,
                prescribedDurationSeconds: block.prescribedDurationSeconds,
                timeCapSeconds: block.timeCapSeconds,
                intervalSeconds: block.intervalSeconds,
                repetitionScheme: scheme,
                repetitionStart: block.repetitionStart,
                repetitionEnd: block.repetitionEnd,
                repetitionStep: block.repetitionStep
            ) != nil {
                throw BackupValidationError.invalidIdentifier(named)
            }
            if scheme == .ascendingLadder || scheme == .descendingLadder {
                guard let start = block.repetitionStart,
                      let end = block.repetitionEnd,
                      let step = block.repetitionStep,
                      start > 0, end > 0, step > 0, start != end else {
                    throw BackupValidationError.invalidIdentifier(named)
                }
            }
        }

        let validIDs = Set(blockIDs)
        var componentOrders: [String: Set<Int>] = [:]
        for (blockID, componentOrder) in memberships {
            guard blockID != nil || componentOrder == nil else {
                throw BackupValidationError.invalidIdentifier(named)
            }
            guard let blockID else { continue }
            guard validIDs.contains(blockID),
                  let componentOrder,
                  componentOrder >= 0,
                  componentOrders[blockID, default: []].insert(componentOrder).inserted
            else {
                throw BackupValidationError.invalidIdentifier(named)
            }
        }

        for block in blocks {
            let count = componentOrders[block.id]?.count ?? 0
            guard let kind = ExerciseBlockKind(rawValue: block.kind) else {
                throw BackupValidationError.invalidIdentifier(named)
            }
            let validCount: Bool
            switch kind {
            case .straight: validCount = count == 1
            case .pairedSet: validCount = count == 2
            case .triset: validCount = count == 3
            case .giantSet: validCount = count >= 4
            default: validCount = count > 0
            }
            guard validCount else { throw BackupValidationError.invalidIdentifier(named) }
        }
    }

    private func validateStrengthExpansionEvidence(in set: ExerciseSetDTO) throws {
        guard set.meanVelocity.map({ $0.isFinite && $0 > 0 }) ?? true,
              set.peakVelocity.map({ $0.isFinite && $0 > 0 }) ?? true,
              set.velocityMeasurementSource.map({ MeasurementSource(rawValue: $0) != nil }) ?? true,
              set.specializedMetricKind.map({ SpecializedPerformanceMetricKind(rawValue: $0) != nil }) ?? true,
              set.specializedMetricMeasurementSource.map({ MeasurementSource(rawValue: $0) != nil }) ?? true,
              set.setMethod.map({ SetMethod(rawValue: $0) != nil }) ?? true,
              [set.jumpHeightMeters, set.contactTimeMilliseconds, set.throwDistanceMeters, set.kettlebellCadenceRPM]
                .allSatisfy({ $0.map { $0.isFinite && $0 > 0 } ?? true })
        else {
            throw BackupValidationError.invalidIdentifier("strength expansion set")
        }

        let method = set.setMethod.flatMap(SetMethod.init(rawValue:)) ?? .standard
        let segments = set.segments ?? []
        guard method == .standard || segments.count >= method.minimumSegmentCount else {
            throw BackupValidationError.invalidIdentifier("strength expansion set")
        }

        var segmentIDs = Set<String>()
        for segment in segments {
            guard UUID(uuidString: segment.id) != nil,
                  segmentIDs.insert(segment.id).inserted,
                  segment.orderIndex >= 0,
                  segment.repetitions >= 0,
                  segment.weight >= 0,
                  WeightType(rawValue: segment.weightType) != nil,
                  segment.duration.map({ $0 >= 0 }) ?? true,
                  segment.restAfterSeconds.map({ $0 >= 0 }) ?? true,
                  segment.rpe.map({ (1.0...10.0).contains($0) }) ?? true,
                  segment.rir.map({ $0 >= 0 }) ?? true else {
                throw BackupValidationError.invalidIdentifier("exercise set segment")
            }
        }

        var componentIDs = Set<String>()
        for component in set.complexComponents ?? [] {
            guard UUID(uuidString: component.id) != nil,
                  componentIDs.insert(component.id).inserted,
                  component.orderIndex >= 0,
                  UUID(uuidString: component.exerciseID) != nil,
                  !component.exerciseNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  component.prescribedRepetitions > 0,
                  component.performedRepetitions >= 0,
                  component.performedRepetitions <= component.prescribedRepetitions,
                  ComplexComponentOutcome(rawValue: component.outcome) != nil,
                  component.liftQuality.map({ LiftQuality(rawValue: $0) != nil }) ?? true
            else {
                throw BackupValidationError.invalidIdentifier("complex component result")
            }
        }
    }

    private func isValidLocalDayKey(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[2].count == 2,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return false
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        guard let date = components.date else { return false }
        let normalized = components.calendar?.dateComponents([.year, .month, .day], from: date)
        return normalized?.year == year && normalized?.month == month && normalized?.day == day
    }

    private func validateMobility() throws {
        try validateUniqueIdentifiers(mobilityFamilies.map(\.id), named: "mobility family")
        try validateUniqueIdentifiers(mobilityDefinitions.map(\.id), named: "mobility definition")
        try validateUniqueIdentifiers(mobilityRoutines.map(\.id), named: "mobility routine")
        try validateUniqueIdentifiers(mobilitySessions.map(\.id), named: "mobility session")

        // MobilityFamily.name and MobilityDefinition.name lost their
        // @Attribute(.unique) constraint, so a restored backup can now carry
        // duplicate names; a duplicate would otherwise trap the seeder's
        // Dictionary(uniqueKeysWithValues:) lookup at restore/seed time
        // instead of failing validation cleanly here. Mirrors the
        // mobilityAssessmentDefinitions.catalogueKey uniqueness check below.
        let familyNames = mobilityFamilies.map(\.name)
        guard Set(familyNames).count == familyNames.count else {
            throw BackupValidationError.duplicateIdentifier("mobility family name")
        }
        let definitionNames = mobilityDefinitions.map(\.name)
        guard Set(definitionNames).count == definitionNames.count else {
            throw BackupValidationError.duplicateIdentifier("mobility definition name")
        }

        let familyIDs = Set(mobilityFamilies.map(\.id))
        let definitionIDs = Set(mobilityDefinitions.map(\.id))
        for definition in mobilityDefinitions {
            guard MobilityTrackingType(rawValue: definition.trackingType) != nil,
                  definition.defaultDurationSeconds.map({ $0 > 0 }) ?? true,
                  definition.defaultRepetitions.map({ $0 > 0 }) ?? true,
                  definition.familyID.map({ familyIDs.contains($0) }) ?? true else {
                throw BackupValidationError.invalidIdentifier("mobility definition")
            }
        }

        var routineItemIDs = [String]()
        var phasePrescriptionIDs = [String]()
        var allBlockKeys = [String]()
        for routine in mobilityRoutines {
            let blocks = routine.blocks ?? []
            let blockKeys = Set(blocks.map(\.blockKey))
            allBlockKeys.append(contentsOf: blocks.map(\.blockKey))
            for block in blocks {
                guard block.orderIndex >= 0,
                      MobilityBlockKind(rawValue: block.kind) != nil,
                      block.targetRounds.map({ $0 > 0 }) ?? true,
                      isValid(block.restPrescription) else {
                    throw BackupValidationError.invalidIdentifier("mobility routine block")
                }
            }
            for item in routine.items {
                routineItemIDs.append(item.id)
                guard definitionIDs.contains(item.definitionID),
                      item.orderIndex >= 0,
                      (item.cycleCount ?? 1) > 0,
                      MobilitySide(rawValue: item.side) != nil,
                      item.targetDurationSeconds.map({ $0 > 0 }) ?? true,
                      item.targetRepetitions.map({ $0 > 0 }) ?? true,
                      item.restSeconds.map({ $0 >= 0 }) ?? true,
                      item.method.map({ MobilityMethod(rawValue: $0) != nil }) ?? true,
                      item.trainingPurpose.map({ MobilityTrainingPurpose(rawValue: $0) != nil }) ?? true,
                      isValid(item.breathingPrescription),
                      isValid(item.tempoPrescription),
                      isValid(item.assistancePrescription),
                      isValid(item.metricProfile, targets: item.metricTargets),
                      item.supportLevel.map({ MobilitySupportLevel(rawValue: $0) != nil }) ?? true,
                      // A block never contains a block: an item's block
                      // membership must resolve to a block authored on this
                      // same routine, never to another item.
                      item.blockKey.map({ blockKeys.contains($0) }) ?? true,
                      item.sideStrategy.map({ MobilitySideStrategy(rawValue: $0) != nil }) ?? true,
                      isValid(item.restPrescription) else {
                    throw BackupValidationError.invalidIdentifier("mobility routine item")
                }
                let phases = item.phases ?? []
                let phaseOrder = phases.map(\.orderIndex)
                guard Set(phaseOrder).count == phaseOrder.count else {
                    throw BackupValidationError.invalidIdentifier("mobility phase prescription order")
                }
                for phase in phases {
                    phasePrescriptionIDs.append(phase.id)
                    guard phase.orderIndex >= 0,
                          PNFPhaseType(rawValue: phase.phaseType) != nil,
                          phase.durationSeconds > 0,
                          phase.contractionIntensity.map({ ContractionIntensity(rawValue: $0) != nil }) ?? true,
                          MobilitySide(rawValue: phase.side) != nil else {
                        throw BackupValidationError.invalidIdentifier("mobility phase prescription")
                    }
                }
            }
        }
        try validateUniqueIdentifiers(routineItemIDs, named: "mobility routine item")
        try validateUniqueIdentifiers(phasePrescriptionIDs, named: "mobility phase prescription")
        try validateUniqueIdentifiers(allBlockKeys, named: "mobility routine block")

        var entryIDs = [String]()
        var resultIDs = [String]()
        var phaseResultIDs = [String]()
        var activeSessionCount = 0
        for session in mobilitySessions {
            guard let sessionStatus = MobilitySessionStatus(rawValue: session.status),
                  MobilitySessionContext(rawValue: session.context) != nil,
                  session.currentEntryIndex >= 0,
                  session.sourceRoutineID.map({ UUID(uuidString: $0) != nil }) ?? true,
                  session.workoutID.map({ UUID(uuidString: $0) != nil }) ?? true else {
                throw BackupValidationError.invalidIdentifier("mobility session")
            }
            if sessionStatus == .active { activeSessionCount += 1 }
            guard Set(session.entries.map(\.orderIndex)).count == session.entries.count else {
                throw BackupValidationError.invalidIdentifier("mobility entry order")
            }
            for entry in session.entries {
                entryIDs.append(entry.id)
                let cycleCount = entry.cycleCount ?? 1
                let phaseResults = entry.phaseResults ?? []
                let phaseCountPerExecutionGroup = Dictionary(
                    grouping: phaseResults,
                    by: { "\($0.side)|\($0.cycleIndex)" }
                ).values.map(\.count)
                let maximumPhaseCount = phaseCountPerExecutionGroup.max() ?? 0
                guard entry.orderIndex >= 0,
                      UUID(uuidString: entry.definitionIDSnapshot) != nil,
                      MobilityTrackingType(rawValue: entry.trackingType) != nil,
                      MobilitySide(rawValue: entry.side) != nil,
                      cycleCount > 0,
                      (0..<cycleCount).contains(entry.currentCycleIndex ?? 0),
                      (entry.currentPhaseIndex ?? 0) >= 0,
                      maximumPhaseCount == 0 || (entry.currentPhaseIndex ?? 0) < maximumPhaseCount,
                      (entry.pausedElapsedSeconds ?? 0) >= 0,
                      entry.targetDurationSeconds.map({ $0 > 0 }) ?? true,
                      entry.targetRepetitions.map({ $0 > 0 }) ?? true,
                      entry.restSeconds.map({ $0 >= 0 }) ?? true,
                      entry.blockKindSnapshot.map({ MobilityBlockKind(rawValue: $0) != nil }) ?? true,
                      (entry.blockOrderIndexSnapshot ?? 0) >= 0,
                      entry.blockTargetRoundsSnapshot.map({ $0 > 0 }) ?? true,
                      isValid(entry.blockRestSnapshot),
                      (entry.roundIndexSnapshot ?? 0) >= 0,
                      entry.sideStrategySnapshot.map({ MobilitySideStrategy(rawValue: $0) != nil }) ?? true,
                      isValid(entry.restPrescriptionSnapshot) else {
                    throw BackupValidationError.invalidIdentifier("mobility entry")
                }
                for result in entry.results {
                    resultIDs.append(result.id)
                    guard let resultStatus = MobilityResultStatus(rawValue: result.status),
                          MobilitySide(rawValue: result.side) != nil,
                          result.prescribedDurationSeconds.map({ $0 > 0 }) ?? true,
                          result.prescribedRepetitions.map({ $0 > 0 }) ?? true,
                          result.performedDurationSeconds.map({ $0 >= 0 }) ?? true,
                          result.performedRepetitions.map({ $0 >= 0 }) ?? true,
                          result.perceivedIntensity.map({ (1...5).contains($0) }) ?? true,
                          result.methodSnapshot.map({ MobilityMethod(rawValue: $0) != nil }) ?? true,
                          result.trainingPurposeSnapshot.map({ MobilityTrainingPurpose(rawValue: $0) != nil }) ?? true,
                          result.sensation.map({ MobilitySensation(rawValue: $0) != nil }) ?? true,
                          result.movementQuality.map({ MobilityMovementQuality(rawValue: $0) != nil }) ?? true,
                          (result.compensationKeys ?? []).allSatisfy({ MobilityCompensationKey(rawValue: $0) != nil }),
                          Set(result.compensationKeys ?? []).count == (result.compensationKeys ?? []).count,
                          isValid(result.breathingPrescriptionSnapshot),
                          isValid(result.tempoPrescriptionSnapshot),
                          isValid(result.assistancePrescriptionSnapshot),
                          isValid(result.metricProfileSnapshot, targets: result.metricTargetsSnapshot),
                          result.supportLevelSnapshot.map({ MobilitySupportLevel(rawValue: $0) != nil }) ?? true,
                          result.performedBreathingCycles.map({ $0 >= 0 }) ?? true,
                          result.performedAssistanceLevel.map({ $0 >= 0 }) ?? true,
                          result.performedSupportLevel.map({ MobilitySupportLevel(rawValue: $0) != nil }) ?? true,
                          isValid(result.restSnapshot) else {
                        throw BackupValidationError.invalidIdentifier("mobility result")
                    }
                    if let sensation = result.sensation.flatMap(MobilitySensation.init(rawValue:)),
                       sensation.isStopSignal,
                       resultStatus != .stopped {
                        throw BackupValidationError.invalidIdentifier("mobility stop-signal result")
                    }
                }
                var phaseExecutionPositions = Set<String>()
                for phaseResult in phaseResults {
                    phaseResultIDs.append(phaseResult.id)
                    guard phaseResult.orderIndex >= 0,
                          PNFPhaseType(rawValue: phaseResult.phaseType) != nil,
                          phaseResult.prescribedDurationSeconds > 0,
                          phaseResult.performedDurationSeconds.map({ $0 >= 0 }) ?? true,
                          (0..<cycleCount).contains(phaseResult.cycleIndex),
                          MobilitySide(rawValue: phaseResult.side) != nil,
                          phaseResult.prescribedIntensity.map({ ContractionIntensity(rawValue: $0) != nil }) ?? true,
                          phaseResult.performedIntensity.map({ ContractionIntensity(rawValue: $0) != nil }) ?? true,
                          MobilityResultStatus(rawValue: phaseResult.status) != nil,
                          phaseExecutionPositions.insert(
                              "\(phaseResult.side)|\(phaseResult.cycleIndex)|\(phaseResult.orderIndex)"
                          ).inserted else {
                        throw BackupValidationError.invalidIdentifier("mobility phase result")
                    }
                }
            }
            try validateMobilityExecutionGraph(session, status: sessionStatus)
        }
        guard activeSessionCount <= 1 else {
            throw BackupValidationError.invalidIdentifier("active mobility session")
        }
        try validateUniqueIdentifiers(entryIDs, named: "mobility entry")
        try validateUniqueIdentifiers(resultIDs, named: "mobility result")
        try validateUniqueIdentifiers(phaseResultIDs, named: "mobility phase result")
    }

    private func validateMobilityExecutionGraph(
        _ session: MobilitySessionDTO,
        status: MobilitySessionStatus
    ) throws {
        let entries = session.entries.sorted {
            $0.orderIndex == $1.orderIndex ? $0.id < $1.id : $0.orderIndex < $1.orderIndex
        }
        guard entries.isEmpty == false else {
            throw BackupValidationError.invalidIdentifier("mobility session execution graph")
        }

        let terminal: (String) -> Bool = { raw in
            guard let status = MobilityResultStatus(rawValue: raw) else { return false }
            return switch status {
            case .notStarted, .inProgress: false
            case .completed, .partial, .skipped, .stopped: true
            }
        }
        let isNotStarted: (String) -> Bool = {
            MobilityResultStatus(rawValue: $0) == .notStarted
        }

        for entry in entries where (entry.phaseResults ?? []).isEmpty == false {
            let phases = entry.phaseResults ?? []
            let resultSides = Set(entry.results.map(\.side))
            let phaseSides = Set(phases.map(\.side))
            let cycles = entry.cycleCount ?? 1
            let groups = Dictionary(grouping: phases) { "\($0.side)|\($0.cycleIndex)" }
            let signatures = groups.values.map { group in
                group.sorted { $0.orderIndex < $1.orderIndex }.map {
                    "\($0.orderIndex)|\($0.phaseType)|\($0.prescribedDurationSeconds)|\($0.prescribedIntensity ?? "")"
                }
            }
            guard resultSides == phaseSides,
                  groups.count == resultSides.count * cycles,
                  Set(signatures).count == 1,
                  groups.values.allSatisfy({ group in
                      let order = group.map(\.orderIndex)
                      return Set(order).count == order.count
                  }) else {
                throw BackupValidationError.invalidIdentifier("mobility phase execution graph")
            }
        }

        switch status {
        case .active:
            guard session.endTime == nil,
                  let currentIndex = entries.firstIndex(where: { $0.orderIndex == session.currentEntryIndex })
            else {
                throw BackupValidationError.invalidIdentifier("active mobility cursor")
            }
            let current = entries[currentIndex]
            guard entries.enumerated().allSatisfy({ index, entry in
                if index < currentIndex {
                    return entry.results.allSatisfy { terminal($0.status) }
                        && (entry.phaseResults ?? []).allSatisfy { terminal($0.status) }
                        && entry.timerStartedAt == nil
                }
                if index > currentIndex {
                    return entry.results.allSatisfy { isNotStarted($0.status) }
                        && (entry.phaseResults ?? []).allSatisfy { isNotStarted($0.status) }
                        && entry.timerStartedAt == nil
                        && (entry.pausedElapsedSeconds ?? 0) == 0
                }
                return true
            }) else {
                throw BackupValidationError.invalidIdentifier("active mobility execution order")
            }

            let phaseResults = current.phaseResults ?? []
            if phaseResults.isEmpty {
                guard current.results.isEmpty == false,
                      current.results.allSatisfy({ MobilityResultStatus(rawValue: $0.status) == .inProgress })
                else {
                    throw BackupValidationError.invalidIdentifier("active mobility result")
                }
            } else {
                // Mirrors `MobilityEntry.executionOrderedPhaseResults(alternatingSides:)`
                // and `MobilityFlowResolver`'s node ordering: an
                // `.alternateEachRepetition` entry's active cursor is only
                // valid against a cycle-major traversal, never the default
                // side-major one.
                let alternatingSides = current.sideStrategySnapshot == MobilitySideStrategy.alternateEachRepetition.rawValue
                let ordered = phaseResults.sorted {
                    if alternatingSides {
                        if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
                        if mobilitySideOrder($0.side) != mobilitySideOrder($1.side) {
                            return mobilitySideOrder($0.side) < mobilitySideOrder($1.side)
                        }
                    } else {
                        if mobilitySideOrder($0.side) != mobilitySideOrder($1.side) {
                            return mobilitySideOrder($0.side) < mobilitySideOrder($1.side)
                        }
                        if $0.cycleIndex != $1.cycleIndex { return $0.cycleIndex < $1.cycleIndex }
                    }
                    if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
                    return $0.id < $1.id
                }
                let inProgress = ordered.filter {
                    MobilityResultStatus(rawValue: $0.status) == .inProgress
                }
                guard inProgress.count == 1,
                      let node = inProgress.first,
                      let nodeIndex = ordered.firstIndex(where: { $0.id == node.id }),
                      ordered.prefix(nodeIndex).allSatisfy({ terminal($0.status) }),
                      ordered.dropFirst(nodeIndex + 1).allSatisfy({ isNotStarted($0.status) }),
                      node.cycleIndex == (current.currentCycleIndex ?? 0),
                      phaseIndex(of: node, in: phaseResults) == (current.currentPhaseIndex ?? 0),
                      current.results.filter({ $0.side == node.side }).count == 1,
                      current.results.filter({ MobilityResultStatus(rawValue: $0.status) == .inProgress }).count == 1,
                      current.results.first(where: { $0.side == node.side }).map({
                          MobilityResultStatus(rawValue: $0.status) == .inProgress
                      }) == true else {
                    throw BackupValidationError.invalidIdentifier("active mobility phase cursor")
                }
            }

        case .completed, .stopped:
            guard session.endTime != nil,
                  entries.allSatisfy({ entry in
                      entry.timerStartedAt == nil
                          && entry.results.allSatisfy { terminal($0.status) }
                          && (entry.phaseResults ?? []).allSatisfy { terminal($0.status) }
                  }) else {
                throw BackupValidationError.invalidIdentifier("terminal mobility execution graph")
            }
        }
    }

    private func phaseIndex(
        of phase: MobilityPhaseResultDTO,
        in phases: [MobilityPhaseResultDTO]
    ) -> Int {
        phases
            .filter { $0.side == phase.side && $0.cycleIndex == phase.cycleIndex }
            .sorted {
                $0.orderIndex == $1.orderIndex ? $0.id < $1.id : $0.orderIndex < $1.orderIndex
            }
            .firstIndex(where: { $0.id == phase.id }) ?? -1
    }

    private func mobilitySideOrder(_ rawValue: String) -> Int {
        // `MobilitySide` has its own `.none` case, so over an optional the
        // bare `.none` pattern binds to `Optional.none` and leaves
        // `MobilitySide.none` unmatched. The explicit `.some(...)` patterns
        // keep the two distinct.
        switch MobilitySide(rawValue: rawValue) {
        case .some(.none): 0
        case .some(.left): 1
        case .some(.right): 2
        case .some(.bilateral): 3
        case .some(.alternating): 4
        case nil: Int.max
        }
    }

    private func validateMobilityAssessments() throws {
        try validateUniqueIdentifiers(
            mobilityAssessmentDefinitions.map(\.id),
            named: "mobility assessment definition"
        )
        try validateUniqueIdentifiers(
            mobilityAssessmentSessions.map(\.id),
            named: "mobility assessment session"
        )

        let catalogueKeys = mobilityAssessmentDefinitions.map(\.catalogueKey)
        guard Set(catalogueKeys).count == catalogueKeys.count,
              catalogueKeys.allSatisfy({ !$0.isEmpty }) else {
            throw BackupValidationError.duplicateIdentifier("mobility assessment catalogue key")
        }
        let definitionsByKey = Dictionary(
            uniqueKeysWithValues: mobilityAssessmentDefinitions.map { ($0.catalogueKey, $0) }
        )

        for definition in mobilityAssessmentDefinitions {
            guard let preferredMode = MobilityMeasurementMode(rawValue: definition.preferredMode),
                  let manualMode = MobilityMeasurementMode(rawValue: definition.manualMode),
                  let unit = MobilityMeasurementUnit(rawValue: definition.unit),
                  MobilityAssessmentZone(rawValue: definition.zone) != nil,
                  definition.definitionVersion > 0,
                  !definition.name.isEmpty,
                  !definition.nameLocalizationKey.isEmpty,
                  !definition.instructionsLocalizationKey.isEmpty,
                  !definition.setupInstructionsLocalizationKey.isEmpty,
                  !definition.measurementDescriptionLocalizationKey.isEmpty,
                  !definition.measurementLimitationsLocalizationKey.isEmpty,
                  manualMode.isManual,
                  manualMode != .cameraPose,
                  measurementUnit(unit, supports: manualMode),
                  preferredMode != .cameraPose,
                  !definition.supportedSides.isEmpty,
                  Set(definition.supportedSides).count == definition.supportedSides.count,
                  definition.supportedSides.allSatisfy({
                      MobilityAssessmentSide(rawValue: $0) != nil
                  }),
                  !definition.setupKeys.isEmpty,
                  Set(definition.setupKeys).count == definition.setupKeys.count,
                  definition.setupKeys.contains(definition.defaultSetupKey) else {
                throw BackupValidationError.invalidIdentifier("mobility assessment definition")
            }
        }

        var resultIDs = [String]()
        var sampleIDs = [String]()
        var activeSessionCount = 0
        for session in mobilityAssessmentSessions {
            guard let status = MobilityAssessmentSessionStatus(rawValue: session.status),
                  isValidLocalDayKey(session.dayKey),
                  !session.selectedDefinitionKeys.isEmpty,
                  Set(session.selectedDefinitionKeys).count == session.selectedDefinitionKeys.count,
                  session.selectedDefinitionKeys.allSatisfy({ definitionsByKey[$0] != nil }),
                  Set(session.skippedDefinitionKeys).count == session.skippedDefinitionKeys.count,
                  Set(session.skippedDefinitionKeys).isSubset(of: Set(session.selectedDefinitionKeys)),
                  (0...session.selectedDefinitionKeys.count).contains(session.currentDefinitionIndex),
                  (status == .active) == (session.completedAt == nil) else {
                throw BackupValidationError.invalidIdentifier("mobility assessment session")
            }
            if status == .active { activeSessionCount += 1 }

            var resultKeys = Set<String>()
            for result in session.results {
                resultIDs.append(result.id)
                guard let definition = definitionsByKey[result.definitionCatalogueKeySnapshot],
                      let side = MobilityAssessmentSide(rawValue: result.side),
                      let method = MobilityMeasurementMode(rawValue: result.method),
                      let unit = MobilityMeasurementUnit(rawValue: result.unit),
                      let source = MobilityMeasurementSource(rawValue: result.source),
                      let confidence = MobilityMeasurementConfidence(rawValue: result.confidence),
                      result.orderIndex >= 0,
                      isValidLocalDayKey(result.dayKey),
                      UUID(uuidString: result.definitionIDSnapshot) != nil,
                      result.definitionVersionSnapshot > 0,
                      !result.definitionNameSnapshot.isEmpty,
                      !result.instructionsLocalizationKeySnapshot.isEmpty,
                      !result.setupInstructionsLocalizationKeySnapshot.isEmpty,
                      !result.measurementDescriptionLocalizationKeySnapshot.isEmpty,
                      !result.measurementLimitationsLocalizationKeySnapshot.isEmpty,
                      session.selectedDefinitionKeys.contains(result.definitionCatalogueKeySnapshot),
                      definition.supportedSides.contains(side.rawValue),
                      definition.setupKeys.contains(result.setupKey),
                      method != .cameraPose,
                      method == MobilityMeasurementMode(rawValue: definition.manualMode)
                        || method == MobilityMeasurementMode(rawValue: definition.preferredMode),
                      measurementUnit(unit, supports: method),
                      resultKeys.insert("\(result.definitionCatalogueKeySnapshot)|\(result.side)").inserted else {
                    throw BackupValidationError.invalidIdentifier("mobility assessment result")
                }

                switch unit {
                case .criteria:
                    guard result.numericValue == nil,
                          result.criteria.flatMap(MobilityAssessmentCriteriaObservation.init(rawValue:)) != nil else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment result")
                    }
                case .degrees, .centimetres:
                    guard result.criteria == nil,
                          result.numericValue.map({ $0.isFinite }) == true else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment result")
                    }
                }

                if source == .manual {
                    guard method.isManual,
                          confidence.rank <= MobilityMeasurementConfidence.moderate.rank,
                          result.sample == nil else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment manual result")
                    }
                }

                if let sample = result.sample {
                    sampleIDs.append(sample.id)
                    guard sample.sampleCount > 0,
                          sample.captureDuration > 0,
                          sample.median.isFinite,
                          sample.minimum.isFinite,
                          sample.maximum.isFinite,
                          sample.standardDeviation.isFinite,
                          sample.offAxisExcessDegrees.isFinite,
                          sample.minimum <= sample.median,
                          sample.median <= sample.maximum,
                          sample.standardDeviation >= 0,
                          sample.offAxisExcessDegrees >= 0 else {
                        throw BackupValidationError.invalidIdentifier("mobility assessment sample")
                    }
                }
            }
        }
        guard activeSessionCount <= 1 else {
            throw BackupValidationError.invalidIdentifier("active mobility assessment session")
        }
        try validateUniqueIdentifiers(resultIDs, named: "mobility assessment result")
        try validateUniqueIdentifiers(sampleIDs, named: "mobility assessment sample")
    }

    private func measurementUnit(
        _ unit: MobilityMeasurementUnit,
        supports method: MobilityMeasurementMode
    ) -> Bool {
        switch method {
        case .manualAngle, .inclinometer, .axialRotation, .twoSegmentAngle, .dynamicRange:
            return unit == .degrees
        case .manualLinear:
            return unit == .centimetres
        case .manualCriteria, .cameraPose:
            return unit == .criteria
        }
    }

    private func validateNutrition() throws {
        try validateUniqueIdentifiers(foods.map(\.id), named: "food")
        try validateUniqueIdentifiers(mealTemplates.map(\.id), named: "meal template")
        try validateUniqueIdentifiers(loggedMeals.map(\.id), named: "logged meal")
        try validateUniqueIdentifiers(nutritionTargets.map(\.id), named: "nutrition target")

        let foodIDs = Set(foods.map(\.id))
        let foodNames = foods.map(\.name)
        guard Set(foodNames.map { $0.folding(options: [.caseInsensitive], locale: .current) }).count == foodNames.count else {
            throw BackupValidationError.duplicateIdentifier("food name")
        }
        var servingIDs = Set<String>()
        var foodIDByServingID = [String: String]()
        for food in foods {
            guard food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  food.referenceAmount > 0,
                  NutritionServingUnit(rawValue: food.referenceUnit) != nil,
                  FoodSourceKind(rawValue: food.sourceKind) != nil,
                  FoodConfidence(rawValue: food.confidence) != nil,
                  FoodPreparationState(rawValue: food.preparationState) != nil,
                  [food.calories, food.proteinGrams, food.carbohydrateGrams, food.fatGrams, food.caffeineMilligrams].allSatisfy({ $0.map { $0 >= 0 } ?? true }) else {
                throw BackupValidationError.invalidIdentifier("food")
            }
            for serving in food.servings {
                guard servingIDs.insert(serving.id).inserted,
                      UUID(uuidString: serving.id) != nil,
                      serving.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                      serving.amount > 0,
                      serving.equivalentReferenceAmount > 0,
                      NutritionServingUnit(rawValue: serving.unit) != nil else {
                    throw BackupValidationError.invalidIdentifier("food serving")
                }
                foodIDByServingID[serving.id] = food.id
            }
        }

        var templateItemIDs = Set<String>()
        var lineageVersions = Set<String>()
        for template in mealTemplates {
            guard UUID(uuidString: template.lineageID) != nil,
                  template.version > 0,
                  template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  FoodPreparationState(rawValue: template.preparationState) != nil,
                  template.finalCookedWeightGrams.map({ $0 > 0 }) ?? true,
                  lineageVersions.insert("\(template.lineageID)|\(template.version)").inserted else {
                throw BackupValidationError.invalidIdentifier("meal template")
            }
            guard template.items.isEmpty == false else {
                throw BackupValidationError.invalidIdentifier("meal template")
            }
            for item in template.items {
                guard templateItemIDs.insert(item.id).inserted,
                      UUID(uuidString: item.id) != nil,
                      foodIDs.contains(item.foodID),
                      item.orderIndex >= 0,
                      item.quantity > 0,
                      item.servingID.map({ foodIDByServingID[$0] == item.foodID }) ?? true else {
                    throw BackupValidationError.invalidIdentifier("meal template item")
                }
            }
        }

        var loggedItemIDs = Set<String>()
        for meal in loggedMeals {
            guard isValidLocalDayKey(meal.dayKey),
                  MealSlot(rawValue: meal.slot) != nil,
                  meal.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  meal.items.isEmpty == false,
                  meal.sourceMealTemplateID.map({ UUID(uuidString: $0) != nil }) ?? true else {
                throw BackupValidationError.invalidIdentifier("logged meal")
            }
            for item in meal.items {
                guard loggedItemIDs.insert(item.id).inserted,
                      UUID(uuidString: item.id) != nil,
                      item.sourceFoodID.map({ UUID(uuidString: $0) != nil }) ?? true,
                      item.orderIndex >= 0,
                      item.quantity > 0,
                      item.portionAmountSnapshot > 0,
                      NutritionServingUnit(rawValue: item.portionUnit) != nil,
                      FoodSourceKind(rawValue: item.sourceKind) != nil,
                      FoodConfidence(rawValue: item.confidence) != nil,
                      FoodPreparationState(rawValue: item.preparationState) != nil,
                      [item.caloriesSnapshot, item.proteinGramsSnapshot, item.carbohydrateGramsSnapshot, item.fatGramsSnapshot, item.caffeineMilligramsSnapshot].allSatisfy({ $0.map { $0 >= 0 } ?? true }) else {
                    throw BackupValidationError.invalidIdentifier("logged meal item")
                }
            }
        }

        for target in nutritionTargets {
            guard NutritionGoalPhase(rawValue: target.phase) != nil,
                  isValidLocalDayKey(target.effectiveStartDayKey),
                  target.effectiveEndDayKey.map(isValidLocalDayKey) ?? true,
                  target.effectiveEndDayKey.map({ $0 >= target.effectiveStartDayKey }) ?? true,
                  [target.trainingCalories, target.trainingProteinGrams, target.trainingCarbohydrateGrams, target.trainingFatGrams, target.restCalories, target.restProteinGrams, target.restCarbohydrateGrams, target.restFatGrams].allSatisfy({ $0.map { $0 >= 0 } ?? true }) else {
                throw BackupValidationError.invalidIdentifier("nutrition target")
            }
        }
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

    private func isValid(_ prescription: MobilityBreathingPrescriptionDTO?) -> Bool {
        guard let prescription else { return true }
        let values = [prescription.targetBreaths, prescription.inhaleSeconds, prescription.exhaleSeconds]
        let hasInstruction = prescription.instructionKey?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasContent = values.contains(where: { $0 != nil }) || hasInstruction
        return hasContent && values.allSatisfy { $0.map({ $0 > 0 }) ?? true }
    }

    private func isValid(_ prescription: MobilityTempoPrescriptionDTO?) -> Bool {
        guard let prescription else { return true }
        let values = [
            prescription.moveIntoRangeSeconds,
            prescription.holdSeconds,
            prescription.returnSeconds,
            prescription.pauseSeconds
        ]
        return values.contains(where: { $0 != nil })
            && values.allSatisfy { $0.map({ $0 > 0 }) ?? true }
    }

    private func isValid(_ prescription: MobilityAssistancePrescriptionDTO?) -> Bool {
        guard let prescription else { return true }
        return MobilityAssistanceType(rawValue: prescription.assistanceType) != nil
            && (prescription.level.map({ $0 >= 0 }) ?? true)
    }

    /// A `.none`/`.userControlled`/`.breatheUntilReady` directive has no
    /// numeric bounds to reject; `.exact` and `.range` reject a non-positive
    /// or inverted bound before the destination store is ever touched.
    private func isValid(_ prescription: MobilityRestPrescription?) -> Bool {
        prescription?.isValid ?? true
    }

    private func isValid(
        _ profile: MobilityMetricProfile?,
        targets: MobilityMetricTargets?
    ) -> Bool {
        guard targets?.isValid ?? true else { return false }
        guard let profile else { return true }
        guard profile.supportedMetrics.isEmpty == false,
              profile.primaryProgressMetric.map({ profile.supportedMetrics.contains($0) }) ?? true
        else { return false }
        switch profile.defaultCompletionRule {
        case .all(let metrics), .any(let metrics):
            return metrics.isEmpty == false
                && metrics.isSubset(of: profile.completionWritableMetrics)
        case .prescribedTargets:
            guard let targets else { return false }
            let metrics = targets.prescribedMetrics
            return metrics.isEmpty == false
                && metrics.isSubset(of: profile.completionWritableMetrics)
        case .phaseSequenceCompleted:
            return profile.supportedMetrics.contains(.cycles)
        }
    }
}
