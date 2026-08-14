import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION
@MainActor
enum ProgramDefinitionRepository {
    static func save(
        _ payload: ProgramDefinitionPayload,
        isBuiltIn: Bool = false,
        in context: ModelContext
    ) throws -> ProgramDefinitionRecord {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let trackingIssues = TrackingProfileValidator.validate(
            payload: payload,
            exercisesByID: exercisesByID
        )
        guard trackingIssues.isEmpty else {
            throw ProgramDefinitionStoreError.invalid(trackingIssues.map(\.asProgramValidationIssue))
        }
        let metricIssues = ProgramMetricCompletionValidator.validate(
            payload: payload,
            exercisesByID: exercisesByID
        )
        guard metricIssues.isEmpty else {
            throw ProgramDefinitionStoreError.invalid(metricIssues)
        }

        let record = try ProgramDefinitionRecord(payload: payload, isBuiltIn: isBuiltIn)
        let payloadID = payload.id
        var descriptor = FetchDescriptor<ProgramDefinitionRecord>(predicate: #Predicate { $0.id == payloadID })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.schemaVersion = record.schemaVersion
            existing.templateVersion = record.templateVersion
            existing.name = record.name
            existing.summary = record.summary
            existing.goal = record.goal
            existing.experienceLevel = record.experienceLevel
            existing.durationWeeks = record.durationWeeks
            existing.supportedDaysPerWeek = record.supportedDaysPerWeek
            existing.isBuiltIn = record.isBuiltIn
            existing.updatedAt = .now
            existing.definitionData = record.definitionData
            return existing
        }
        context.insert(record)
        return record
    }

    static func archive(_ record: ProgramDefinitionRecord, in context: ModelContext) throws {
        do {
            record.isArchived = true
            record.updatedAt = .now
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func activeDefinitions(in context: ModelContext) throws -> [ProgramDefinitionRecord] {
        try context.fetch(FetchDescriptor<ProgramDefinitionRecord>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))
    }

    static func compile(
        _ record: ProgramDefinitionRecord,
        using context: ModelContext
    ) throws -> WorkoutPlan {
        let payload = try record.payload()
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        return try ProgramDefinitionCompiler.compile(
            payload,
            exercisesByID: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        )
    }
}
#endif
