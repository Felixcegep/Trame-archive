import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

nonisolated enum MobilityProgramDefinitionStoreError: LocalizedError, Equatable {
    case invalid([MobilityProgramValidationIssue])
    case missingMobilityDefinition(UUID)
    case unknownSession(String)
    case encodingFailed
    case decodingFailed
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            return issues.map(\.message).joined(separator: " ")
        case .missingMobilityDefinition(let id):
            return "The mobility program references missing movement \(id.uuidString)."
        case .unknownSession(let key):
            return "The mobility program has no session with key \(key)."
        case .encodingFailed:
            return "The mobility program definition could not be encoded."
        case .decodingFailed:
            return "The stored mobility program definition could not be decoded."
        case .persistenceFailed:
            return "The mobility program definition could not be saved."
        }
    }
}

/// Metadata is queryable SwiftData; the versioned recipe remains Codable data,
/// mirroring `ProgramDefinitionRecord`'s idiom so the two definition graphs
/// feel like one system without merging their persisted types.
@Model
final class MobilityProgramDefinitionRecord {
    var id: UUID
    var programKey: String
    var schemaVersion: Int
    var templateVersion: Int
    var name: String
    var summary: String?
    var durationWeeks: Int
    var supportedDaysPerWeek: [Int]
    var isBuiltIn: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var definitionData: Data

    init(
        payload: MobilityProgramDefinitionPayload,
        isBuiltIn: Bool = false,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let issues = MobilityProgramDefinitionValidator.validate(payload, isBuiltIn: isBuiltIn)
        guard issues.isEmpty else { throw MobilityProgramDefinitionStoreError.invalid(issues) }
        guard let data = try? encoder.encode(payload) else {
            throw MobilityProgramDefinitionStoreError.encodingFailed
        }
        id = payload.id
        programKey = payload.programKey
        schemaVersion = payload.schemaVersion
        templateVersion = payload.templateVersion
        name = payload.name
        summary = payload.summary
        durationWeeks = payload.durationWeeks
        supportedDaysPerWeek = payload.supportedDaysPerWeek
        self.isBuiltIn = isBuiltIn
        isArchived = false
        createdAt = .now
        updatedAt = .now
        definitionData = data
    }

    func payload(decoder: JSONDecoder = JSONDecoder()) throws -> MobilityProgramDefinitionPayload {
        guard let payload = try? decoder.decode(MobilityProgramDefinitionPayload.self, from: definitionData) else {
            throw MobilityProgramDefinitionStoreError.decodingFailed
        }
        return payload
    }
}

/// Compiles one authored `MobilityPlannedSessionDefinition` into a concrete
/// `MobilityRoutine` graph ready for `MobilitySessionService.start(routine:)`
/// — the existing session-start path is reused verbatim; this type never
/// duplicates execution logic.
@MainActor
enum MobilityProgramCompiler {
    struct CompiledSession {
        var routine: MobilityRoutine
        var session: MobilityPlannedSessionDefinition
        /// `occurrenceID` -> the fresh `MobilityRoutineItem.id` created for
        /// it. A later run/progression slice keys off this map rather than
        /// re-deriving item identity from occurrence order, so repeated
        /// occurrences of the same `MobilityDefinition` stay distinguishable
        /// after compilation.
        var routineItemIDsByOccurrenceID: [String: UUID]
    }

    /// Revalidates the whole program structurally (mirrors
    /// `ProgramDefinitionCompiler.compile` revalidating its whole definition
    /// even though only part of it may be used immediately), resolves the
    /// requested session's catalog references, and materializes it as a
    /// brand-new `MobilityRoutine`. Every identity created here — the
    /// routine, its items, phases, and evidence rows — is a fresh UUID; a
    /// mutable definition's own `id`/`occurrenceID` is never reused as a
    /// compiled identity.
    static func compile(
        program: MobilityProgramDefinitionPayload,
        sessionKey: String,
        mobilityDefinitionsByID: [UUID: MobilityDefinition],
        into context: ModelContext,
        now: Date = .now
    ) throws -> CompiledSession {
        let issues = MobilityProgramDefinitionValidator.validate(program)
        guard issues.isEmpty else { throw MobilityProgramDefinitionStoreError.invalid(issues) }
        guard let session = program.flattenedSessions.first(where: { $0.sessionKey == sessionKey }) else {
            throw MobilityProgramDefinitionStoreError.unknownSession(sessionKey)
        }
        try validateCatalogReferences(in: session, mobilityDefinitionsByID: mobilityDefinitionsByID)

        let routine = MobilityRoutine(
            name: uniqueCompiledRoutineName(program: program, session: session, in: context),
            purpose: nil,
            id: UUID(),
            createdAt: now,
            updatedAt: now
        )
        context.insert(routine)

        // The recipe's own structural validity (every occurrence.blockKey
        // resolves within this same recipe) was already proven by
        // `MobilityProgramDefinitionValidator.validate(program)` above, so no
        // lookup table is needed here — each compiled block only has to be
        // inserted with a globally-unique key.
        for blockDefinition in session.recipe.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let block = MobilityRoutineBlock(
                blockKey: "\(routine.id.uuidString).\(blockDefinition.blockKey)",
                routineID: routine.id,
                orderIndex: blockDefinition.orderIndex,
                name: blockDefinition.name,
                kind: blockDefinition.kind,
                targetRounds: blockDefinition.targetRounds,
                restPrescription: blockDefinition.restPrescription,
                id: UUID(),
                createdAt: now,
                updatedAt: now
            )
            context.insert(block)
        }

        var items: [MobilityRoutineItem] = []
        var routineItemIDsByOccurrenceID: [String: UUID] = [:]
        for occurrence in session.recipe.occurrences.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let definition = mobilityDefinitionsByID[occurrence.mobilityDefinitionID] else {
                throw MobilityProgramDefinitionStoreError.missingMobilityDefinition(occurrence.mobilityDefinitionID)
            }
            let item = MobilityRoutineItem(
                definition: definition,
                orderIndex: occurrence.orderIndex,
                targetDurationSeconds: representativeInt(occurrence.targets.durationSeconds),
                targetRepetitions: representativeInt(occurrence.targets.repetitions),
                targetLoadValue: representativeDouble(occurrence.targets.load),
                targetLoadUnit: occurrence.targetLoadUnit,
                side: occurrence.side,
                restSeconds: nil,
                notes: occurrence.notes,
                id: UUID()
            )
            item.cycleCount = max(1, occurrence.cycleCount)
            item.phases = occurrence.phases
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { phase in
                    MobilityPhasePrescription(
                        orderIndex: phase.orderIndex,
                        phaseType: phase.phaseType,
                        durationSeconds: phase.durationSeconds,
                        contractionIntensity: phase.contractionIntensity,
                        instructions: phase.instructions,
                        side: phase.side,
                        id: UUID()
                    )
                }
            item.routine = routine
            context.insert(item)
            items.append(item)
            routineItemIDsByOccurrenceID[occurrence.occurrenceID] = item.id

            let evidence = MobilityRoutineItemEvidence(
                routineItemID: item.id,
                method: occurrence.method,
                purpose: occurrence.purpose,
                breathingPrescription: occurrence.breathingPrescription,
                tempoPrescription: occurrence.tempoPrescription,
                assistancePrescription: occurrence.assistancePrescription,
                supportLevel: occurrence.supportLevel,
                metricProfile: occurrence.metricProfile,
                metricTargets: occurrence.targets,
                blockKey: occurrence.blockKey.map { "\(routine.id.uuidString).\($0)" },
                sideStrategy: occurrence.sideStrategy,
                restPrescription: occurrence.restPrescription,
                progressionKeySnapshot: occurrence.progressionKey,
                id: UUID(),
                createdAt: now,
                updatedAt: now
            )
            context.insert(evidence)
        }
        routine.items = items

        return CompiledSession(
            routine: routine,
            session: session,
            routineItemIDsByOccurrenceID: routineItemIDsByOccurrenceID
        )
    }

    /// A definition is valid on its own without the local mobility catalog,
    /// but compilation must prove every occurrence's movement reference
    /// resolves before a single model is materialized.
    private static func validateCatalogReferences(
        in session: MobilityPlannedSessionDefinition,
        mobilityDefinitionsByID: [UUID: MobilityDefinition]
    ) throws {
        for occurrence in session.recipe.occurrences {
            guard mobilityDefinitionsByID[occurrence.mobilityDefinitionID] != nil else {
                throw MobilityProgramDefinitionStoreError.missingMobilityDefinition(occurrence.mobilityDefinitionID)
            }
        }
    }

    /// `MobilityRoutine.name` is `@Attribute(.unique)` across every routine in
    /// the store, including standalone user-authored ones. Two compiles of the
    /// same session (a second run, a rescheduled week with an identical session
    /// name) must never collide.
    ///
    /// The name is user-visible in the routine library, so uniqueness is
    /// resolved the way the rest of the platform resolves it — a readable base
    /// name, disambiguated with a counted suffix only when that exact name is
    /// already taken. A UUID fragment would guarantee uniqueness too, but it
    /// would put opaque identifiers in front of the user on every compiled
    /// session.
    private static func uniqueCompiledRoutineName(
        program: MobilityProgramDefinitionPayload,
        session: MobilityPlannedSessionDefinition,
        in context: ModelContext
    ) -> String {
        let base = "\(program.name) — \(session.name)"
        let taken = Set(
            ((try? context.fetch(FetchDescriptor<MobilityRoutine>())) ?? []).map(\.name)
        )
        guard taken.contains(base) else { return base }
        var suffix = 2
        while taken.contains("\(base) (\(suffix))") { suffix += 1 }
        return "\(base) (\(suffix))"
    }

    private static func representativeInt(_ target: MobilityIntTarget?) -> Int? {
        guard let target else { return nil }
        switch target {
        case .exact(let value), .minimum(let value), .maximum(let value): return value
        case .range(let minimum, _): return minimum
        case .open: return nil
        }
    }

    private static func representativeDouble(_ target: MobilityDoubleTarget?) -> Double? {
        guard let target else { return nil }
        switch target {
        case .exact(let value), .minimum(let value), .maximum(let value): return value
        case .range(let minimum, _): return minimum
        case .open: return nil
        }
    }
}

#endif
