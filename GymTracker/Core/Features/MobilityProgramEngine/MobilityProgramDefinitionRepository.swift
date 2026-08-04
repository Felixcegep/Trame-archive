import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

/// Persistence entry points for `MobilityProgramDefinitionRecord`, mirroring
/// `ProgramDefinitionRepository`'s idiom.
@MainActor
enum MobilityProgramDefinitionRepository {
    @discardableResult
    static func save(
        _ payload: MobilityProgramDefinitionPayload,
        isBuiltIn: Bool = false,
        in context: ModelContext
    ) throws -> MobilityProgramDefinitionRecord {
        let record = try MobilityProgramDefinitionRecord(payload: payload, isBuiltIn: isBuiltIn)
        if let existing = try context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>())
            .first(where: { $0.id == payload.id }) {
            existing.programKey = record.programKey
            existing.schemaVersion = record.schemaVersion
            existing.templateVersion = record.templateVersion
            existing.name = record.name
            existing.summary = record.summary
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

    static func archive(_ record: MobilityProgramDefinitionRecord, in context: ModelContext) throws {
        do {
            record.isArchived = true
            record.updatedAt = .now
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func activeDefinitions(in context: ModelContext) throws -> [MobilityProgramDefinitionRecord] {
        try context.fetch(
            FetchDescriptor<MobilityProgramDefinitionRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).filter { !$0.isArchived }
    }
}

#endif
