import Foundation

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
        }
    }
}

extension BackupDTO {
    func validate() throws {
        guard version == Self.legacyVersion || version == Self.planVersion || version == Self.supersetVersion || version == Self.programVersion || version == Self.dailyContextVersion || version == Self.currentVersion else {
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

        if version >= Self.mobilityVersion {
            try validateMobility()
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

    func requiredUUID(_ value: String, named name: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw BackupValidationError.invalidIdentifier(name)
        }
        return uuid
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
        for routine in mobilityRoutines {
            for item in routine.items {
                routineItemIDs.append(item.id)
                guard definitionIDs.contains(item.definitionID),
                      item.orderIndex >= 0,
                      MobilitySide(rawValue: item.side) != nil,
                      item.targetDurationSeconds.map({ $0 > 0 }) ?? true,
                      item.targetRepetitions.map({ $0 > 0 }) ?? true,
                      item.restSeconds.map({ $0 >= 0 }) ?? true else {
                    throw BackupValidationError.invalidIdentifier("mobility routine item")
                }
            }
        }
        try validateUniqueIdentifiers(routineItemIDs, named: "mobility routine item")

        var entryIDs = [String]()
        var resultIDs = [String]()
        for session in mobilitySessions {
            guard MobilitySessionStatus(rawValue: session.status) != nil,
                  MobilitySessionContext(rawValue: session.context) != nil,
                  session.currentEntryIndex >= 0,
                  session.sourceRoutineID.map({ UUID(uuidString: $0) != nil }) ?? true,
                  session.workoutID.map({ UUID(uuidString: $0) != nil }) ?? true else {
                throw BackupValidationError.invalidIdentifier("mobility session")
            }
            for entry in session.entries {
                entryIDs.append(entry.id)
                guard entry.orderIndex >= 0,
                      UUID(uuidString: entry.definitionIDSnapshot) != nil,
                      MobilityTrackingType(rawValue: entry.trackingType) != nil,
                      MobilitySide(rawValue: entry.side) != nil,
                      entry.targetDurationSeconds.map({ $0 > 0 }) ?? true,
                      entry.targetRepetitions.map({ $0 > 0 }) ?? true,
                      entry.restSeconds.map({ $0 >= 0 }) ?? true else {
                    throw BackupValidationError.invalidIdentifier("mobility entry")
                }
                for result in entry.results {
                    resultIDs.append(result.id)
                    guard MobilitySide(rawValue: result.side) != nil,
                          MobilityResultStatus(rawValue: result.status) != nil,
                          result.prescribedDurationSeconds.map({ $0 > 0 }) ?? true,
                          result.prescribedRepetitions.map({ $0 > 0 }) ?? true,
                          result.performedDurationSeconds.map({ $0 >= 0 }) ?? true,
                          result.performedRepetitions.map({ $0 >= 0 }) ?? true,
                          result.perceivedIntensity.map({ (1...5).contains($0) }) ?? true else {
                        throw BackupValidationError.invalidIdentifier("mobility result")
                    }
                }
            }
        }
        try validateUniqueIdentifiers(entryIDs, named: "mobility entry")
        try validateUniqueIdentifiers(resultIDs, named: "mobility result")
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
