import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

extension WorkoutPlan {
    var programCompletionPolicy: CompletionPolicy {
        get {
            guard let completionPolicyData,
                  let policy = try? JSONDecoder().decode(CompletionPolicy.self, from: completionPolicyData)
            else { return .end }
            return policy
        }
        set {
            completionPolicyData = try? JSONEncoder().encode(newValue)
        }
    }
}

nonisolated enum ProgramDefinitionStoreError: LocalizedError, Equatable {
    case invalid([ProgramValidationIssue])
    case missingExercise(UUID)
    case encodingFailed
    case decodingFailed
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            return issues.map(\.message).joined(separator: " ")
        case .missingExercise(let id):
            return "The program references missing exercise \(id.uuidString)."
        case .encodingFailed:
            return "The program definition could not be encoded."
        case .decodingFailed:
            return "The stored program definition could not be decoded."
        case .persistenceFailed:
            return "The program definition could not be saved."
        }
    }
}

/// Metadata is queryable SwiftData; the versioned recipe remains Codable data
/// so definition migrations do not become a second object graph.
@Model
final class ProgramDefinitionRecord {
    var id: UUID
    var schemaVersion: Int
    var templateVersion: Int
    var name: String
    var summary: String?
    var goal: PlanGoal
    var experienceLevel: PlanExperienceLevel
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var isBuiltIn: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var definitionData: Data

    init(
        payload: ProgramDefinitionPayload,
        isBuiltIn: Bool = false,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let issues = ProgramDefinitionValidator.validate(payload, isBuiltIn: isBuiltIn)
        guard issues.isEmpty else { throw ProgramDefinitionStoreError.invalid(issues) }
        guard let data = try? encoder.encode(payload) else {
            throw ProgramDefinitionStoreError.encodingFailed
        }
        id = payload.id
        schemaVersion = payload.schemaVersion
        templateVersion = payload.templateVersion
        name = payload.name
        summary = payload.description
        goal = payload.goal
        experienceLevel = payload.experienceLevel
        durationWeeks = payload.durationWeeks
        supportedDaysPerWeek = payload.supportedDaysPerWeek
        self.isBuiltIn = isBuiltIn
        isArchived = false
        createdAt = .now
        updatedAt = .now
        definitionData = data
    }

    func payload(decoder: JSONDecoder = JSONDecoder()) throws -> ProgramDefinitionPayload {
        guard let payload = try? decoder.decode(ProgramDefinitionPayload.self, from: definitionData) else {
            throw ProgramDefinitionStoreError.decodingFailed
        }
        return payload
    }
}

enum ProgramDefinitionCompiler {
    static func compile(
        _ definition: ProgramDefinitionPayload,
        exercisesByID: [UUID: Exercise]
    ) throws -> WorkoutPlan {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionStoreError.invalid(issues) }
        try validateCatalogReferences(in: definition, exercisesByID: exercisesByID)

        let trackingIssues = TrackingProfileValidator.validate(payload: definition, exercisesByID: exercisesByID)
        guard trackingIssues.isEmpty else {
            throw ProgramDefinitionStoreError.invalid(trackingIssues.map(\.asProgramValidationIssue))
        }

        var blocks: [PlanBlock] = []
        for blockDefinition in definition.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let weeks = try blockDefinition.weeks.sorted(by: { $0.weekIndex < $1.weekIndex }).map { weekDefinition in
                let workouts = try weekDefinition.workouts.sorted(by: { $0.orderIndex < $1.orderIndex }).map { workoutDefinition in
                    let exercises = try workoutDefinition.plannedExercises
                        .sorted(by: { $0.orderIndex < $1.orderIndex })
                        .map { exerciseDefinition in
                            guard let exercise = exercisesByID[exerciseDefinition.exerciseID] else {
                                throw ProgramDefinitionStoreError.missingExercise(exerciseDefinition.exerciseID)
                            }
                            let candidateIDs = (exerciseDefinition.alternativeExerciseIDs + (exerciseDefinition.variationExerciseIDs ?? []))
                                .filter { $0 != exerciseDefinition.exerciseID }
                                .reduce(into: [UUID]()) { result, id in
                                    if !result.contains(id) { result.append(id) }
                                }
                            let alternatives = try candidateIDs.enumerated().map { index, alternativeID in
                                guard let alternative = exercisesByID[alternativeID] else {
                                    throw ProgramDefinitionStoreError.missingExercise(alternativeID)
                                }
                                return PlannedExerciseAlternative(exercise: alternative, orderIndex: index)
                            }
                            return try compileExercise(exerciseDefinition, exercise: exercise, alternatives: alternatives)
                        }
                    return PlannedWorkout(
                        name: workoutDefinition.name,
                        orderIndex: workoutDefinition.orderIndex,
                        dayOffset: workoutDefinition.dayOffset,
                        isOptional: workoutDefinition.isOptional,
                        isTestDay: workoutDefinition.plannedExercises.contains { exercise in
                            exercise.plannedSets.contains { $0.role == .test }
                                || exercise.waves.flatMap(\.plannedSets).contains { $0.role == .test }
                                || exercise.stages.flatMap(\.plannedSets).contains { $0.role == .test }
                        },
                        plannedExercises: exercises
                    )
                }
                return PlanWeek(
                    weekIndex: weekDefinition.weekIndex,
                    name: weekDefinition.name,
                    plannedWorkouts: workouts
                )
            }
            blocks.append(
                PlanBlock(
                    name: blockDefinition.name,
                    phaseType: blockDefinition.phaseType,
                    orderIndex: blockDefinition.orderIndex,
                    deloadVolumeReductionPercent: blockDefinition.deloadVolumeReductionPercent,
                    deloadIntensityReductionPercent: blockDefinition.deloadIntensityReductionPercent,
                    weeks: weeks
                )
            )
        }

        let plan = WorkoutPlan(
            name: definition.name,
            goal: definition.goal,
            experienceLevel: definition.experienceLevel,
            requiredEquipment: definition.requiredEquipment,
            daysPerWeek: definition.supportedDaysPerWeek.first ?? 1,
            durationWeeks: definition.durationWeeks,
            scheduleMode: definition.scheduleMode,
            scheduleIntervalDays: definition.scheduleIntervalDays,
            notes: definition.description,
            blocks: blocks,
            sourceProgramDefinitionID: definition.id,
            sourceProgramDefinitionVersion: definition.templateVersion
        )
        plan.programCompletionPolicy = definition.completionPolicy
        return plan
    }

    /// A definition is valid on its own without the local exercise catalog,
    /// but activation must prove every nested exercise identifier resolves.
    /// This includes complex components and reference lifts, not just the
    /// visible exercise row and its substitution options.
    private static func validateCatalogReferences(
        in definition: ProgramDefinitionPayload,
        exercisesByID: [UUID: Exercise]
    ) throws {
        for block in definition.blocks {
            for week in block.weeks {
                for workout in week.workouts {
                    for exercise in workout.plannedExercises {
                        try requireExercise(exercise.exerciseID, in: exercisesByID)
                        for alternativeID in exercise.alternativeExerciseIDs {
                            try requireExercise(alternativeID, in: exercisesByID)
                        }
                        for variationID in exercise.variationExerciseIDs ?? [] {
                            try requireExercise(variationID, in: exercisesByID)
                        }
                        for prescription in exercise.plannedSets + exercise.waves.flatMap(\.plannedSets) {
                            if let referenceID = prescription.load.reference.exerciseID {
                                try requireExercise(referenceID, in: exercisesByID)
                            }
                            if case .sequence(let components) = prescription.repetitions {
                                for component in components {
                                    try requireExercise(component.exerciseID, in: exercisesByID)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private static func requireExercise(
        _ id: UUID,
        in exercisesByID: [UUID: Exercise]
    ) throws {
        guard exercisesByID[id] != nil else {
            throw ProgramDefinitionStoreError.missingExercise(id)
        }
    }

    private static func compileExercise(
        _ definition: ProgramExerciseDefinition,
        exercise: Exercise,
        alternatives: [PlannedExerciseAlternative]
    ) throws -> PlannedExercise {
        let initialStage = definition.stages.first { $0.stageID == definition.initialStageID }
        let orderedSets = (initialStage?.plannedSets ?? definition.waves.first?.plannedSets ?? definition.plannedSets)
            .sorted { $0.orderIndex < $1.orderIndex }
        let plannedSets = try orderedSets.map { prescription in
            let data = try JSONEncoder().encode(prescription)
            let legacy = legacyValues(for: prescription.repetitions)
            return PlannedSet(
                orderIndex: prescription.orderIndex,
                setType: legacySetType(for: prescription.role),
                repetitions: legacy.exact,
                repRangeMinimum: legacy.minimum,
                repRangeMaximum: legacy.maximum,
                suggestedLoad: prescription.load.fixedValue ?? (prescription.orderIndex == orderedSets.first?.orderIndex ? definition.initialLoad : nil),
                suggestedLoadType: (prescription.load.fixedValue ?? (prescription.orderIndex == orderedSets.first?.orderIndex ? definition.initialLoad : nil)) == nil ? nil : .kg,
                restSeconds: prescription.restSeconds,
                targetRPE: prescription.targetRPE,
                targetRIR: prescription.targetRIR,
                tempo: prescription.tempo,
                progressionEligible: prescription.progressionEligible,
                isOptional: prescription.isOptional,
                notes: prescription.notes,
                definitionData: data
            )
        }
        let first = orderedSets.first
        let firstLegacy = first.map { legacyValues(for: $0.repetitions) }
            ?? (exact: nil, minimum: 1, maximum: 1)
        let rulesData = try JSONEncoder().encode(definition.progressionRules)
        return PlannedExercise(
            exercise: exercise,
            orderIndex: definition.orderIndex,
            role: definition.role ?? .main,
            isOptional: definition.isOptional,
            targetSets: max(1, plannedSets.count),
            repRangeMinimum: firstLegacy.minimum,
            repRangeMaximum: max(firstLegacy.minimum, firstLegacy.maximum),
            suggestedLoad: first?.load.fixedValue ?? definition.initialLoad,
            suggestedLoadType: (first?.load.fixedValue ?? definition.initialLoad) == nil ? nil : .kg,
            restSeconds: first?.restSeconds ?? 90,
            targetRPE: first?.targetRPE,
            targetRIR: first?.targetRIR,
            progressionRule: .none,
            stimulus: TrainingStimulusResolver.inferredStimulus(for: exercise) ?? .strength,
            alternatives: alternatives,
            plannedSets: plannedSets,
            progressionKey: definition.exposureKey,
            progressionRulesData: rulesData,
            progressionWavesData: definition.waves.isEmpty ? nil : try? JSONEncoder().encode(definition.waves),
            progressionStagesData: definition.stages.isEmpty ? nil : try? JSONEncoder().encode(
                ProgramStageConfiguration(
                    stages: definition.stages,
                    initialStageID: definition.initialStageID ?? definition.stages[0].stageID
                )
            ),
            variationLadderData: definition.variationExerciseIDs.flatMap { try? JSONEncoder().encode($0) },
            initialVariationExerciseID: definition.initialVariationExerciseID,
            initialVelocityBaseline: definition.initialVelocityBaseline,
            initialTrainingMax: definition.initialTrainingMax,
            initialEstimatedOneRepMax: definition.initialEstimatedOneRepMax,
            initialActualOneRepMax: definition.initialActualOneRepMax,
            automaticDeloadVolumeReductionPercent: definition.automaticDeload?.volumeReductionPercent,
            automaticDeloadIntensityReductionPercent: definition.automaticDeload?.intensityReductionPercent,
            warmupSchemeData: definition.warmupScheme.flatMap { try? JSONEncoder().encode($0) }
        )
    }

    private static func legacyValues(for prescription: RepPrescription) -> (exact: Int?, minimum: Int, maximum: Int) {
        switch prescription {
        case .fixed(let repetitions):
            return (repetitions, repetitions, repetitions)
        case .range(let minimum, let maximum):
            return (nil, minimum, maximum)
        case .amrap(let minimum, let maximum):
            let lower = minimum ?? 1
            return (nil, lower, max(lower, maximum ?? lower))
        case .sequence, .duration, .distance, .calories, .open:
            return (nil, 1, 1)
        }
    }

    private static func legacySetType(for role: ProgramSetRole) -> SetType {
        switch role {
        case .warmup: return .warmup
        case .dropSet: return .dropSet
        case .recovery, .backOff: return .backoff
        case .topSet: return .topSet
        case .amrap: return .amrap
        case .technique: return .technique
        case .dailyMaximum: return .dailyMaximum
        case .test: return .test
        case .working: return .normal
        }
    }
}

/// Starts a new run without ever mutating the terminal run that produced it.
/// Carry-forward copies only progression values; workout markers and pending
/// cadence events belong to the old run and must not be replayed.
enum ProgramRunLifecycleService {
    @discardableResult
    static func activateTestDay(
        for run: PlanRun,
        using modelContext: ModelContext
    ) -> PlanWorkoutProgress? {
        guard run.status == .testDayAvailable,
              let progress = run.orderedWorkoutProgress.first(where: { progress in
                  progress.status == .available
                      && run.plan?.orderedWeeks
                          .flatMap(\.orderedPlannedWorkouts)
                          .first(where: { $0.id == progress.plannedWorkoutID })?.isTestDay == true
              })
        else { return nil }

        run.status = .active
        run.endDate = nil
        run.updatedAt = .now
        PlanCoordinator.refreshAvailability(for: run)
        do {
            try modelContext.save()
            return progress
        } catch {
            modelContext.rollback()
            return nil
        }
    }

    @discardableResult
    static func restartRun(
        for plan: WorkoutPlan,
        from previousRun: PlanRun,
        startDate: Date = .now,
        carryState: Bool,
        using modelContext: ModelContext
    ) -> PlanRun? {
        guard previousRun.status == .completed || previousRun.status == .archived else {
            return nil
        }
        guard previousRun.sourcePlanID == plan.id else { return nil }
        guard TrackingProfileValidator.validate(plan: plan).isEmpty else { return nil }
        guard let run = PlanCoordinator.startRun(for: plan, startDate: startDate) else { return nil }

        if carryState {
            for target in run.progressionStates {
                guard let source = previousRun.progressionStates.first(where: {
                    $0.progressionKey == target.progressionKey
                        && $0.scopeRaw == target.scopeRaw
                        && $0.scopeOwnerKey == target.scopeOwnerKey
                }) else { continue }
                target.currentLoad = source.currentLoad
                target.currentLoadType = source.currentLoadType
                target.repetitionOffset = source.repetitionOffset
                target.setCountOffset = source.setCountOffset
                target.durationOffset = source.durationOffset
                target.distanceOffset = source.distanceOffset
                target.restDurationOffset = source.restDurationOffset
                target.caloriesOffset = source.caloriesOffset
                target.currentStageID = source.currentStageID
                target.currentVariationExerciseID = source.currentVariationExerciseID
                target.trainingMax = source.trainingMax
                target.estimatedOneRepMax = source.estimatedOneRepMax
                target.actualOneRepMax = source.actualOneRepMax
                target.failureCount = source.failureCount
                target.successCount = source.successCount
                target.currentWaveIndex = source.currentWaveIndex
                target.currentBlockIndex = source.currentBlockIndex
                target.previousAMRAPRepetitions = source.previousAMRAPRepetitions
                target.previousActualRPE = source.previousActualRPE
                target.previousActualRIR = source.previousActualRIR
                target.velocityBaseline = source.velocityBaseline
                target.lastSuccessfulLoad = source.lastSuccessfulLoad
                target.isDeloading = source.isDeloading
                target.lastCompletedOccurrence = nil
                target.lastAppliedOutcomeID = nil
                target.lastAppliedSetID = nil
                target.appliedProgressionEventsData = nil
                target.pendingProgressionData = nil
            }
        }

        modelContext.insert(run)
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
            return run
        } catch {
            modelContext.rollback()
            return nil
        }
    }
}

@MainActor
extension ProgramDefinitionRepository {
    /// Saves a validated definition, compiles it into the normal plan graph,
    /// and commits both records together for the custom-program authoring flow.
    static func saveAndCompile(
        _ payload: ProgramDefinitionPayload,
        in context: ModelContext
    ) throws -> WorkoutPlan {
        _ = try save(payload, isBuiltIn: false, in: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let plan = try ProgramDefinitionCompiler.compile(
            payload,
            exercisesByID: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        )
        context.insert(plan)
        guard saveModelContext(context) else {
            throw ProgramDefinitionStoreError.persistenceFailed
        }
        return plan
    }
}
#endif
