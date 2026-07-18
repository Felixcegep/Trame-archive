import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

enum ProgramDefinitionStoreError: LocalizedError, Equatable {
    case invalid([ProgramValidationIssue])
    case missingExercise(UUID)
    case encodingFailed
    case decodingFailed

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
        let issues = ProgramDefinitionValidator.validate(payload)
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

        var blocks: [PlanBlock] = []
        for blockDefinition in definition.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let weeks = blockDefinition.weeks.sorted(by: { $0.weekIndex < $1.weekIndex }).map { weekDefinition in
                let workouts = weekDefinition.workouts.sorted(by: { $0.orderIndex < $1.orderIndex }).map { workoutDefinition in
                    let exercises = workoutDefinition.plannedExercises
                        .sorted(by: { $0.orderIndex < $1.orderIndex })
                        .map { exerciseDefinition in
                            guard let exercise = exercisesByID[exerciseDefinition.exerciseID] else {
                                throw ProgramDefinitionStoreError.missingExercise(exerciseDefinition.exerciseID)
                            }
                            let alternatives = try exerciseDefinition.alternativeExerciseIDs.map { alternativeID in
                                guard let alternative = exercisesByID[alternativeID] else {
                                    throw ProgramDefinitionStoreError.missingExercise(alternativeID)
                                }
                                return PlannedExerciseAlternative(exercise: alternative, orderIndex: exerciseDefinition.alternativeExerciseIDs.firstIndex(of: alternativeID) ?? 0)
                            }
                            return try compileExercise(exerciseDefinition, exercise: exercise, alternatives: alternatives)
                        }
                    return PlannedWorkout(
                        name: workoutDefinition.name,
                        orderIndex: workoutDefinition.orderIndex,
                        dayOffset: workoutDefinition.dayOffset,
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

        return WorkoutPlan(
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
    }

    private static func compileExercise(
        _ definition: ProgramExerciseDefinition,
        exercise: Exercise,
        alternatives: [PlannedExerciseAlternative]
    ) throws -> PlannedExercise {
        let orderedSets = (definition.waves.first?.plannedSets ?? definition.plannedSets).sorted { $0.orderIndex < $1.orderIndex }
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
                isOptional: prescription.isOptional,
                notes: prescription.notes,
                definitionData: data
            )
        }
        let first = orderedSets.first
        let firstLegacy = first.map { legacyValues(for: $0.repetitions) } ?? (nil, 1, 1)
        let rulesData = try JSONEncoder().encode(definition.progressionRules)
        return PlannedExercise(
            exercise: exercise,
            orderIndex: definition.orderIndex,
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
            alternatives: alternatives,
            plannedSets: plannedSets,
            progressionKey: definition.exposureKey,
            progressionRulesData: rulesData,
            progressionWavesData: definition.waves.isEmpty ? nil : try? JSONEncoder().encode(definition.waves),
            initialTrainingMax: definition.initialTrainingMax,
            initialEstimatedOneRepMax: definition.initialEstimatedOneRepMax,
            initialActualOneRepMax: definition.initialActualOneRepMax
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
#endif
