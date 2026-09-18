import Foundation
import SwiftData

struct SystemSeedInstallReport: Equatable {
    var inserted = 0
    var adopted = 0
    var updated = 0
    var unchanged = 0
    var deprecated = 0

    static func += (lhs: inout Self, rhs: Self) {
        lhs.inserted += rhs.inserted
        lhs.adopted += rhs.adopted
        lhs.updated += rhs.updated
        lhs.unchanged += rhs.unchanged
        lhs.deprecated += rhs.deprecated
    }
}

struct SystemExerciseSeed {
    let seedKey: String
    let template: Exercise
}

enum SystemSeedError: LocalizedError, Equatable {
    case duplicateSeedKey(String)
    case invalidSeedKey(String)
    case wrongEntityKind(key: String, expected: SystemSeedEntityKind, found: SystemSeedEntityKind)
    case danglingEntity(key: String, entityID: UUID)
    case ambiguousLegacyMatch(key: String, count: Int)
    case unresolvedDependency(key: String, dependency: String)

    var errorDescription: String? {
        switch self {
        case .duplicateSeedKey(let key):
            return "The bundled seed manifest contains duplicate key \(key)."
        case .invalidSeedKey(let key):
            return "The bundled seed manifest contains invalid key \(key)."
        case let .wrongEntityKind(key, expected, found):
            return "Seed \(key) expected \(expected.rawValue), but its record points to \(found.rawValue)."
        case let .danglingEntity(key, entityID):
            return "Seed \(key) points to missing entity \(entityID.uuidString)."
        case let .ambiguousLegacyMatch(key, count):
            return "Seed \(key) has \(count) possible legacy records; adoption would be unsafe."
        case let .unresolvedDependency(key, dependency):
            return "Seed \(key) requires missing seed \(dependency)."
        }
    }
}

@MainActor
final class SystemSeedRegistry {
    private let context: ModelContext
    private(set) var recordsByKey: [String: SystemSeedRecord]

    init(context: ModelContext) throws {
        self.context = context
        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        var mapped: [String: SystemSeedRecord] = [:]
        for record in records {
            guard mapped.updateValue(record, forKey: record.seedKey) == nil else {
                throw SystemSeedError.duplicateSeedKey(record.seedKey)
            }
        }
        recordsByKey = mapped
    }

    func record(for key: String, expectedKind: SystemSeedEntityKind) throws -> SystemSeedRecord? {
        guard isValid(key) else { throw SystemSeedError.invalidSeedKey(key) }
        guard let record = recordsByKey[key] else { return nil }
        guard record.entityKind == expectedKind else {
            throw SystemSeedError.wrongEntityKind(key: key, expected: expectedKind, found: record.entityKind)
        }
        return record
    }

    @discardableResult
    func register(
        key: String,
        kind: SystemSeedEntityKind,
        entityID: UUID,
        seedVersion: Int,
        contentVersion: Int,
        sourceKind: SystemSeedSourceKind,
        isSystemProvided: Bool = true,
        isDeprecated: Bool = false,
        replacementSeedKey: String? = nil
    ) throws -> SystemSeedRecord {
        guard isValid(key) else { throw SystemSeedError.invalidSeedKey(key) }
        if let existing = recordsByKey[key] {
            guard existing.entityKind == kind else {
                throw SystemSeedError.wrongEntityKind(key: key, expected: kind, found: existing.entityKind)
            }
            existing.entityID = entityID
            existing.seedVersion = seedVersion
            existing.contentVersion = contentVersion
            existing.sourceKind = sourceKind
            existing.isSystemProvided = isSystemProvided
            existing.isDeprecated = isDeprecated
            existing.replacementSeedKey = replacementSeedKey
            existing.updatedAt = .now
            return existing
        }
        let record = SystemSeedRecord(
            seedKey: key,
            entityKind: kind,
            entityID: entityID,
            seedVersion: seedVersion,
            contentVersion: contentVersion,
            sourceKind: sourceKind,
            isSystemProvided: isSystemProvided,
            isDeprecated: isDeprecated,
            replacementSeedKey: replacementSeedKey
        )
        context.insert(record)
        recordsByKey[key] = record
        return record
    }

    func validateUniqueKeys(_ keys: [String]) throws {
        var seen = Set<String>()
        for key in keys {
            guard isValid(key) else { throw SystemSeedError.invalidSeedKey(key) }
            guard seen.insert(key).inserted else { throw SystemSeedError.duplicateSeedKey(key) }
        }
    }

    func deprecate(key: String, replacementSeedKey: String? = nil) throws {
        guard let record = recordsByKey[key] else { return }
        if let replacementSeedKey, recordsByKey[replacementSeedKey] == nil {
            throw SystemSeedError.unresolvedDependency(key: key, dependency: replacementSeedKey)
        }
        record.isDeprecated = true
        record.replacementSeedKey = replacementSeedKey
        record.updatedAt = .now
    }

    private func isValid(_ key: String) -> Bool {
        key.contains(".") && key == key.lowercased() && !key.contains(" ")
    }
}

@MainActor
enum ExerciseSystemSeedInstaller {
    static let seedVersion = 1
    static let contentVersion = 1

    static func install(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        try install(
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )
    }

    static func install(
        in context: ModelContext,
        registry: SystemSeedRegistry,
        seedVersion: Int,
        contentVersion: Int
    ) throws -> SystemSeedInstallReport {
        let desired = ExerciseSeedData.templates().map {
            SystemExerciseSeed(
                seedKey: SystemSeedKey.make(namespace: "exercise", legacyName: $0.name),
                template: $0
            )
        }
        return try install(
            desired,
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )
    }

    static func install(
        _ desired: [SystemExerciseSeed],
        in context: ModelContext,
        registry: SystemSeedRegistry,
        seedVersion: Int = 1,
        contentVersion: Int = 1
    ) throws -> SystemSeedInstallReport {
        let keys = desired.map(\.seedKey)
        try registry.validateUniqueKeys(keys)

        var existing = try context.fetch(FetchDescriptor<Exercise>())
        var existingByID = Dictionary(
            existing.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var report = SystemSeedInstallReport()

        for seed in desired {
            let template = seed.template
            let key = seed.seedKey
            let entity: Exercise
            if let record = try registry.record(for: key, expectedKind: .exercise) {
                guard let matched = existingByID[record.entityID] else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                entity = matched
                applySystemFields(from: template, to: entity)
                record.seedVersion = seedVersion
                record.contentVersion = contentVersion
                record.updatedAt = .now
                report.updated += 1
            } else {
                let candidates = existing.filter {
                    !$0.isCustom && $0.name.compare(template.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
                }
                if let adopted = candidates.first {
                    entity = adopted
                    applySystemFields(from: template, to: entity)
                    try registry.register(
                        key: key,
                        kind: .exercise,
                        entityID: entity.id,
                        seedVersion: seedVersion,
                        contentVersion: contentVersion,
                        sourceKind: .migratedLegacy
                    )
                    report.adopted += 1
                } else {
                    entity = template
                    context.insert(entity)
                    existing.append(entity)
                    existingByID[entity.id] = entity
                    try registry.register(
                        key: key,
                        kind: .exercise,
                        entityID: entity.id,
                        seedVersion: seedVersion,
                        contentVersion: contentVersion,
                        sourceKind: .bundled
                    )
                    report.inserted += 1
                }
            }
        }

        try retireDuplicateExercises(
            in: context,
            registry: registry,
            existingByID: existingByID,
            report: &report
        )

        return report
    }

    /// Exercises seeded before the punctuation-insensitive dedupe fix in
    /// `ExerciseSeedData.templates()` (see its comment): the legacy
    /// catalogue's unpunctuated name and ExerciseCatalogSeedData's
    /// hyphenated spelling of the same movement produced two distinct
    /// `SystemSeedKey.make` keys ("exercise.pull-up" vs
    /// "exercise.pull--up"), so a store that installed before the fix can
    /// already have both Exercise records, each with its own logged
    /// history. `ExerciseSeedData.templates()` no longer emits the losing
    /// spelling, so it drops out of `desired` on every install from here
    /// on -- but simply no longer seeding it would leave that record's
    /// SystemSeedRecord dangling and its history unreachable from any seed
    /// key. Retire it in place instead: archive the Exercise (it survives,
    /// keeps its history, and `!isArchived` picker/browser queries stop
    /// surfacing it) and mark its SystemSeedRecord deprecated with a
    /// pointer at the surviving key, using the
    /// deprecate/replacementSeedKey mechanism `SystemSeedRegistry` already
    /// exposes for exactly this.
    private static let retiredDuplicateExerciseSeedKeys: [(retired: String, survivor: String)] = [
        ("exercise.pull--up", "exercise.pull-up"),
        ("exercise.assisted-pull--up", "exercise.assisted-pull-up"),
    ]

    private static func retireDuplicateExercises(
        in context: ModelContext,
        registry: SystemSeedRegistry,
        existingByID: [UUID: Exercise],
        report: inout SystemSeedInstallReport
    ) throws {
        for pair in retiredDuplicateExerciseSeedKeys {
            // nil on any store that never installed the losing spelling in
            // the first place -- every fresh install post-fix, and every
            // store that's already been through this retirement once.
            guard let record = try registry.record(for: pair.retired, expectedKind: .exercise) else { continue }
            guard !record.isDeprecated else { continue }
            guard let entity = existingByID[record.entityID] else {
                throw SystemSeedError.danglingEntity(key: pair.retired, entityID: record.entityID)
            }
            entity.isArchived = true
            try registry.deprecate(key: pair.retired, replacementSeedKey: pair.survivor)
            report.deprecated += 1
        }
    }

    private static func applySystemFields(from source: Exercise, to destination: Exercise) {
        destination.name = source.name
        destination.primaryMuscles = source.primaryMuscles
        destination.secondaryMuscles = source.secondaryMuscles
        destination.category = source.category
        destination.trackingType = source.trackingType
        destination.equipmentType = source.equipmentType
        destination.resistanceType = source.resistanceType
        destination.movementPattern = source.movementPattern
        destination.forceType = source.forceType
        destination.mechanics = source.mechanics
        destination.gripStyle = source.gripStyle
        destination.stance = source.stance
        destination.rangeOfMotion = source.rangeOfMotion
        destination.setupAngleDegrees = source.setupAngleDegrees
        destination.variationFamilyID = source.variationFamilyID
        destination.difficulty = source.difficulty
        destination.tags = source.tags
        destination.frenchName = source.frenchName
        destination.searchAliases = source.searchAliases
        destination.isPlateLoaded = source.isPlateLoaded
        destination.laterality = source.laterality
        destination.repCountingStyle = source.repCountingStyle
        destination.weightEntryStyle = source.weightEntryStyle
        destination.loadUnitCount = source.loadUnitCount
        destination.sportDiscipline = source.sportDiscipline
        // isFavorite, isArchived, and isCustom are user-owned.
    }
}
