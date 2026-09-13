import Foundation
import SwiftData

nonisolated struct CatalogMetadataInstallReport: Equatable, Sendable {
    var inserted = 0
    var updated = 0
    var unchanged = 0
    var unmatchedExerciseKeys: [String] = []
    var unmatchedMobilityKeys: [String] = []
    var unmatchedProgramKeys: [String] = []
    /// Recovered rows persisted as discovery-only listings; they never become
    /// executable program definitions.
    var discoveryOnlyProgramKeys: [String] = []
}

nonisolated enum CatalogMetadataInstallError: Error, Equatable, Sendable {
    case duplicateTarget(kind: CatalogDefinitionKind, definitionID: UUID)
    case ambiguousLegacyName(kind: CatalogDefinitionKind, name: String)
    case encodingFailed(kind: CatalogDefinitionKind, definitionID: UUID)
}

/// Installs descriptive recovered-catalogue fields after the canonical system
/// definitions have been staged. The explicit movement-seed entry point may
/// add missing bundled Exercise/MobilityDefinition rows, but never creates a
/// runnable program or reads `routinesSummary` as an executable prescription.
@MainActor
enum CatalogMetadataInstaller {
    /// Seeds the complete recovered movement catalog into the existing
    /// definition entities. This method never creates programs and never
    /// touches performed-workout rows; it only stages Exercise and
    /// MobilityDefinition records in the caller's transaction.
    static func seedBundledDefinitions(
        in context: ModelContext,
        bundle: Bundle = .main,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let catalog = try CatalogResourceDecoder.decodeBundled(bundle: bundle)
        return try seedDefinitions(catalog, in: context, registry: registry)
    }

    static func seedDefinitions(
        _ catalog: CatalogResourceCatalog,
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        var report = SystemSeedInstallReport()
        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        var exercisesByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var exerciseByKey = Dictionary(
            exercises.compactMap { exercise in exercise.catalogueKey.map { (normalizedKey($0), exercise) } },
            uniquingKeysWith: { first, _ in first }
        )
        for resource in catalog.exercises.sorted(by: { $0.stableKey < $1.stableKey }) {
            let key = normalizedKey(resource.stableKey)
            let target = try resolveExercise(
                key: key,
                name: resource.name,
                existing: exercises,
                byKey: exerciseByKey,
                byID: exercisesByID,
                registry: registry
            )
            let exercise: Exercise
            let sourceKind: SystemSeedSourceKind
            if let target {
                exercise = target.entity
                sourceKind = target.sourceKind
            } else {
                exercise = makeExercise(from: resource)
                context.insert(exercise)
                exercises.append(exercise)
                exercisesByID[exercise.id] = exercise
                sourceKind = .bundled
                report.inserted += 1
            }
            let changed = apply(resource: resource, key: key, to: exercise)
            exerciseByKey[key] = exercise
            if target != nil {
                if changed { report.updated += 1 } else { report.unchanged += 1 }
            }
            let manifestKey = key
            if try registry.record(for: manifestKey, expectedKind: .exercise) == nil {
                try registry.register(
                    key: manifestKey,
                    kind: .exercise,
                    entityID: exercise.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: sourceKind
                )
            } else {
                _ = try registry.register(
                    key: manifestKey,
                    kind: .exercise,
                    entityID: exercise.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
            }
        }

        var mobilityDefinitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
        var mobilityByID = Dictionary(mobilityDefinitions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var mobilityByKey = Dictionary(
            mobilityDefinitions.compactMap { definition in definition.catalogueKey.map { (normalizedKey($0), definition) } },
            uniquingKeysWith: { first, _ in first }
        )
        var families = Dictionary(
            (try context.fetch(FetchDescriptor<MobilityFamily>())).map { (normalizedKey($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for resource in catalog.mobilityDefinitions.sorted(by: { $0.stableKey < $1.stableKey }) {
            let key = normalizedKey(resource.stableKey)
            let target = try resolveMobility(
                key: key,
                name: resource.name,
                existing: mobilityDefinitions,
                byKey: mobilityByKey,
                byID: mobilityByID,
                registry: registry
            )
            let definition: MobilityDefinition
            let sourceKind: SystemSeedSourceKind
            if let target {
                definition = target.entity
                sourceKind = target.sourceKind
            } else {
                definition = MobilityDefinition(name: resource.name, isCustom: false)
                context.insert(definition)
                mobilityDefinitions.append(definition)
                mobilityByID[definition.id] = definition
                sourceKind = .bundled
                report.inserted += 1
            }
            let family = try mobilityFamily(resource.familyName, in: context, families: &families)
            let changed = apply(resource: resource, key: key, family: family, to: definition)
            mobilityByKey[key] = definition
            if target != nil {
                if changed { report.updated += 1 } else { report.unchanged += 1 }
            }
            if try registry.record(for: key, expectedKind: .mobilityDefinition) == nil {
                try registry.register(
                    key: key,
                    kind: .mobilityDefinition,
                    entityID: definition.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: sourceKind
                )
            } else {
                _ = try registry.register(
                    key: key,
                    kind: .mobilityDefinition,
                    entityID: definition.id,
                    seedVersion: SystemSeedCatalogCoordinator.seedVersion,
                    contentVersion: SystemSeedCatalogCoordinator.contentVersion,
                    sourceKind: .bundled
                )
            }
        }
        return report
    }

    static func stageBundled(
        in context: ModelContext,
        bundle: Bundle = .main
    ) throws -> CatalogMetadataInstallReport {
        try stage(try CatalogResourceDecoder.decodeBundled(bundle: bundle), in: context)
    }

    static func stage(
        _ catalog: CatalogResourceCatalog,
        in context: ModelContext
    ) throws -> CatalogMetadataInstallReport {
        var report = CatalogMetadataInstallReport()
        var metadata = try context.fetch(FetchDescriptor<CatalogDefinitionMetadata>())
        var metadataByTarget: [Target: CatalogDefinitionMetadata] = [:]
        for row in metadata {
            let target = Target(kind: row.definitionKind, id: row.definitionID)
            guard metadataByTarget[target] == nil else {
                throw CatalogMetadataInstallError.duplicateTarget(
                    kind: target.kind,
                    definitionID: target.id
                )
            }
            metadataByTarget[target] = row
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let systemExercises = exercises.filter { !$0.isCustom }
        let exercisesByKey = Dictionary(
            systemExercises.compactMap { exercise in
                exercise.catalogueKey.map { ($0.lowercased(), exercise) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let exercisesByName = groupedByNormalizedName(systemExercises, name: \Exercise.name)

        for resource in catalog.exercises {
            guard let definition = try resolve(
                key: resource.stableKey,
                name: resource.name,
                exact: exercisesByKey,
                byName: exercisesByName,
                kind: .exercise
            ) else {
                report.unmatchedExerciseKeys.append(resource.stableKey)
                continue
            }
            let (row, isNew) = metadataRow(
                for: definition.id,
                kind: .exercise,
                catalogueKey: resource.stableKey,
                context: context,
                metadata: &metadata,
                metadataByTarget: &metadataByTarget,
                report: &report
            )
            let sources = sourceReferences(resource.sources, primaryURL: resource.liftosaurURL)
            let steps = resource.instructions.map {
                $0.title.isEmpty ? $0.text : "\($0.title): \($0.text)"
            }
            let changed = row.catalogueKey != resource.stableKey
                || row.sourceReferences != sources
                || row.muscleGroups != resource.muscleGroups
                || row.anatomicalTargetMuscles != resource.anatomicalTargetMuscles
                || row.anatomicalSynergistMuscles != resource.anatomicalSynergistMuscles
                || row.descriptionText != nilIfEmpty(resource.description)
                || row.instructionSteps != steps
                || row.videoURLString != nilIfEmpty(resource.videoURL)
                || row.videoEmbedURLString != nilIfEmpty(resource.videoEmbedURL)
                || row.thumbnailURLString != nilIfEmpty(resource.videoThumbnail)
                || row.imageURLString != nilIfEmpty(resource.imageURL)
                || row.liftosaurURLString != nilIfEmpty(resource.liftosaurURL)
                || row.liftosaurSlug != nilIfEmpty(resource.liftosaurSlug)
            row.catalogueKey = resource.stableKey
            row.sourceReferences = sources
            row.muscleGroups = resource.muscleGroups
            row.anatomicalTargetMuscles = resource.anatomicalTargetMuscles
            row.anatomicalSynergistMuscles = resource.anatomicalSynergistMuscles
            row.descriptionText = nilIfEmpty(resource.description)
            row.instructionSteps = steps
            row.videoURLString = nilIfEmpty(resource.videoURL)
            row.videoEmbedURLString = nilIfEmpty(resource.videoEmbedURL)
            row.thumbnailURLString = nilIfEmpty(resource.videoThumbnail)
            row.imageURLString = nilIfEmpty(resource.imageURL)
            row.liftosaurURLString = nilIfEmpty(resource.liftosaurURL)
            row.liftosaurSlug = nilIfEmpty(resource.liftosaurSlug)
            finish(changed: changed, isNew: isNew, row: row, report: &report)
        }

        let mobility = try context.fetch(FetchDescriptor<MobilityDefinition>())
        let systemMobility = mobility.filter { !$0.isCustom }
        let mobilityByKey = Dictionary(
            systemMobility.compactMap { definition in
                definition.catalogueKey.map { ($0.lowercased(), definition) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let mobilityByName = groupedByNormalizedName(systemMobility, name: \MobilityDefinition.name)

        for resource in catalog.mobilityDefinitions {
            guard let definition = try resolve(
                key: resource.stableKey,
                name: resource.name,
                exact: mobilityByKey,
                byName: mobilityByName,
                kind: .mobilityDefinition
            ) else {
                report.unmatchedMobilityKeys.append(resource.stableKey)
                continue
            }
            let (row, isNew) = metadataRow(
                for: definition.id,
                kind: .mobilityDefinition,
                catalogueKey: resource.stableKey,
                context: context,
                metadata: &metadata,
                metadataByTarget: &metadataByTarget,
                report: &report
            )
            let sources = sourceReferences(resource.sources)
            let equipment = nilIfEmpty(resource.equipment).map { [$0] } ?? []
            let changed = row.catalogueKey != resource.stableKey
                || row.sourceReferences != sources
                || row.categoryRaw != nilIfEmpty(resource.category)
                || row.difficultyRaw != nilIfEmpty(resource.difficulty)
                || row.equipmentLabels != equipment
                || row.primaryMuscleLabels != resource.primaryMuscles
                || row.secondaryMuscleLabels != resource.secondaryMuscles
                || row.sanskritName != nilIfEmpty(resource.sanskritName)
                || row.metValue != resource.met
                || row.benefitsText != nilIfEmpty(resource.benefits)
                || row.imageURLString != nilIfEmpty(resource.imageURL)
                || row.svgURLString != nilIfEmpty(resource.svgURL)
            row.catalogueKey = resource.stableKey
            row.sourceReferences = sources
            row.categoryRaw = nilIfEmpty(resource.category)
            row.difficultyRaw = nilIfEmpty(resource.difficulty)
            row.equipmentLabels = equipment
            row.primaryMuscleLabels = resource.primaryMuscles
            row.secondaryMuscleLabels = resource.secondaryMuscles
            row.sanskritName = nilIfEmpty(resource.sanskritName)
            row.metValue = resource.met
            row.benefitsText = nilIfEmpty(resource.benefits)
            row.imageURLString = nilIfEmpty(resource.imageURL)
            row.svgURLString = nilIfEmpty(resource.svgURL)
            finish(changed: changed, isNew: isNew, row: row, report: &report)
        }

#if !GYMTRACKER_EXTENSION
        try stageProgramMetadata(
            catalog.programs,
            context: context,
            metadata: &metadata,
            metadataByTarget: &metadataByTarget,
            report: &report
        )
#else
        report.unmatchedProgramKeys = catalog.programs.map(\.stableKey).sorted()
#endif

        report.unmatchedExerciseKeys.sort()
        report.unmatchedMobilityKeys.sort()
        report.unmatchedProgramKeys.sort()
        return report
    }

    private struct ResolvedTarget<Entity: AnyObject> {
        let entity: Entity
        let sourceKind: SystemSeedSourceKind
    }

    private static func resolveExercise(
        key: String,
        name: String,
        existing: [Exercise],
        byKey: [String: Exercise],
        byID: [UUID: Exercise],
        registry: SystemSeedRegistry
    ) throws -> ResolvedTarget<Exercise>? {
        if let exercise = byKey[key] { return ResolvedTarget(entity: exercise, sourceKind: .bundled) }
        if let record = try registry.record(for: key, expectedKind: .exercise), let exercise = byID[record.entityID] {
            exercise.catalogueKey = key
            return ResolvedTarget(entity: exercise, sourceKind: .bundled)
        }
        let candidates = existing.filter {
            !$0.isCustom && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard candidates.count <= 1 else {
            throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
        }
        return candidates.first.map { ResolvedTarget(entity: $0, sourceKind: .migratedLegacy) }
    }

    private static func resolveMobility(
        key: String,
        name: String,
        existing: [MobilityDefinition],
        byKey: [String: MobilityDefinition],
        byID: [UUID: MobilityDefinition],
        registry: SystemSeedRegistry
    ) throws -> ResolvedTarget<MobilityDefinition>? {
        if let definition = byKey[key] { return ResolvedTarget(entity: definition, sourceKind: .bundled) }
        if let record = try registry.record(for: key, expectedKind: .mobilityDefinition), let definition = byID[record.entityID] {
            definition.catalogueKey = key
            return ResolvedTarget(entity: definition, sourceKind: .bundled)
        }
        let candidates = existing.filter {
            !$0.isCustom && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard candidates.count <= 1 else {
            throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
        }
        return candidates.first.map { ResolvedTarget(entity: $0, sourceKind: .migratedLegacy) }
    }

    private static func makeExercise(from resource: ExerciseCatalogResource) -> Exercise {
        let force = resource.forceType.flatMap(ForceType.init(rawValue:))
        let patterns = resource.movementPatterns.map { enumValue(MovementPattern.self, raw: $0, fallback: .other) }
        let exercise = Exercise(
            name: resource.name,
            primaryMuscles: resource.primaryMuscles.compactMap(Muscle.init(rawValue:)),
            secondaryMuscles: resource.secondaryMuscles.compactMap(Muscle.init(rawValue:)),
            category: enumValue(ExerciseCategory.self, raw: resource.category, fallback: .other),
            trackingType: enumValue(TrackingType.self, raw: resource.trackingType, fallback: .weightAndReps),
            equipmentType: enumValue(EquipmentType.self, raw: resource.equipment, fallback: .other),
            resistanceType: enumValue(ResistanceType.self, raw: resource.resistanceType, fallback: .other),
            movementPattern: enumValue(MovementPattern.self, raw: resource.movementPattern, fallback: .other),
            movementPatterns: patterns,
            forceType: force,
            difficulty: enumValue(Difficulty.self, raw: resource.difficulty, fallback: .beginner),
            tags: resource.tags
        )
        exercise.sportDiscipline = resolvedSportDiscipline(for: resource)
        return exercise
    }

    @discardableResult
    private static func apply(resource: ExerciseCatalogResource, key: String, to exercise: Exercise) -> Bool {
        guard !exercise.isCustom else {
            if exercise.catalogueKey != key { exercise.catalogueKey = key; return true }
            return false
        }
        let primary = resource.primaryMuscles.compactMap(Muscle.init(rawValue:))
        let secondary: [Muscle]? = resource.secondaryMuscles.isEmpty
            ? nil
            : resource.secondaryMuscles.compactMap(Muscle.init(rawValue:))
        let category = enumValue(ExerciseCategory.self, raw: resource.category, fallback: .other)
        let tracking = enumValue(TrackingType.self, raw: resource.trackingType, fallback: .weightAndReps)
        let equipment = enumValue(EquipmentType.self, raw: resource.equipment, fallback: .other)
        let resistance = enumValue(ResistanceType.self, raw: resource.resistanceType, fallback: .other)
        let movement = enumValue(MovementPattern.self, raw: resource.movementPattern, fallback: .other)
        let patterns = resource.movementPatterns.map { enumValue(MovementPattern.self, raw: $0, fallback: .other) }
        let force = resource.forceType.flatMap(ForceType.init(rawValue:))
        let difficulty = enumValue(Difficulty.self, raw: resource.difficulty, fallback: .beginner)

        var changed = exercise.catalogueKey != key || exercise.name != resource.name
        exercise.catalogueKey = key
        exercise.name = resource.name

        if !primary.isEmpty && exercise.primaryMuscles != primary {
            exercise.primaryMuscles = primary
            changed = true
        }
        if exercise.secondaryMuscles != secondary {
            exercise.secondaryMuscles = secondary
            changed = true
        }
        if exercise.category != category && category != .other {
            exercise.category = category
            changed = true
        }
        if exercise.trackingType != tracking {
            exercise.trackingType = tracking
            changed = true
        }
        if exercise.equipmentType != equipment && equipment != .other {
            exercise.equipmentType = equipment
            changed = true
        }
        if exercise.resistanceType != resistance && resistance != .other {
            exercise.resistanceType = resistance
            changed = true
        }
        if !patterns.isEmpty && exercise.movementPatterns != patterns {
            exercise.movementPatterns = patterns
            exercise.movementPattern = patterns.first
            changed = true
        } else if movement != .other || exercise.movementPattern == nil || exercise.movementPattern == .other {
            if exercise.movementPattern != movement {
                exercise.movementPattern = movement
                exercise.movementPatterns = [movement]
                changed = true
            }
        }
        if let force, exercise.forceType != force {
            exercise.forceType = force
            changed = true
        }
        if exercise.difficulty != difficulty {
            exercise.difficulty = difficulty
            changed = true
        }
        if exercise.tags != resource.tags {
            exercise.tags = resource.tags
            changed = true
        }
        if let discipline = resolvedSportDiscipline(for: resource),
           exercise.sportDiscipline != discipline {
            exercise.sportDiscipline = discipline
            changed = true
        }
        return changed
    }

    /// Authored JSON discipline wins. Olympic-tagged lifts without that field
    /// still resolve to weightlifting so logging can ask made/missed/quality.
    private static func resolvedSportDiscipline(for resource: ExerciseCatalogResource) -> SportDiscipline? {
        if let raw = resource.sportDiscipline?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let discipline = SportDiscipline(rawValue: raw) {
            return discipline
        }
        if resource.tags.contains(where: { $0.caseInsensitiveCompare("olympic-weightlifting") == .orderedSame }) {
            return .olympicWeightlifting
        }
        return nil
    }

    private static func mobilityFamily(
        _ name: String?,
        in context: ModelContext,
        families: inout [String: MobilityFamily]
    ) throws -> MobilityFamily? {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let key = normalizedKey(name)
        if let family = families[key] { return family }
        let family = MobilityFamily(name: name)
        context.insert(family)
        families[key] = family
        return family
    }

    @discardableResult
    private static func apply(
        resource: MobilityCatalogResource,
        key: String,
        family: MobilityFamily?,
        to definition: MobilityDefinition
    ) -> Bool {
        guard !definition.isCustom else {
            if definition.catalogueKey != key { definition.catalogueKey = key; return true }
            return false
        }
        let tracking = enumValue(MobilityTrackingType.self, raw: resource.trackingType, fallback: .duration)
        let changed = definition.catalogueKey != key || definition.name != resource.name
            || definition.instructions != resource.instructions || definition.trackingType != tracking
            || definition.defaultDurationSeconds != resource.defaultDurationSeconds
            || definition.defaultRepetitions != resource.defaultRepetitions || definition.family?.id != family?.id
        definition.catalogueKey = key
        definition.name = resource.name
        definition.instructions = resource.instructions
        definition.trackingType = tracking
        definition.defaultDurationSeconds = resource.defaultDurationSeconds
        definition.defaultRepetitions = resource.defaultRepetitions
        definition.family = family
        return changed
    }

    private static func enumValue<T: RawRepresentable & CaseIterable>(
        _ type: T.Type,
        raw: String?,
        fallback: T
    ) -> T where T.RawValue == String {
        guard let raw else { return fallback }
        let normalized = enumComparisonKey(raw)
        return type.allCases.first { enumComparisonKey($0.rawValue) == normalized } ?? fallback
    }

    /// Recovered resources contain both enum spellings (`weightAndReps`) and
    /// display spellings (`Weight & Reps`, `Medicine Ball`). Compare their
    /// semantic tokens so valid values do not silently fall back to `.other`
    /// or the default tracking mode.
    private static func enumComparisonKey(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "and")
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map { String($0).lowercased() }
            .joined()
    }

    private struct Target: Hashable {
        let kind: CatalogDefinitionKind
        let id: UUID
    }

    private static func metadataRow(
        for definitionID: UUID,
        kind: CatalogDefinitionKind,
        catalogueKey: String,
        context: ModelContext,
        metadata: inout [CatalogDefinitionMetadata],
        metadataByTarget: inout [Target: CatalogDefinitionMetadata],
        report: inout CatalogMetadataInstallReport
    ) -> (CatalogDefinitionMetadata, Bool) {
        let target = Target(kind: kind, id: definitionID)
        if let existing = metadataByTarget[target] { return (existing, false) }
        let row = CatalogDefinitionMetadata(
            definitionID: definitionID,
            definitionKind: kind,
            catalogueKey: catalogueKey
        )
        context.insert(row)
        metadata.append(row)
        metadataByTarget[target] = row
        report.inserted += 1
        return (row, true)
    }

    private static func finish(
        changed: Bool,
        isNew: Bool,
        row: CatalogDefinitionMetadata,
        report: inout CatalogMetadataInstallReport
    ) {
        if isNew {
            row.updatedAt = .now
            return
        }
        if changed {
            row.updatedAt = .now
            report.updated += 1
        } else {
            report.unchanged += 1
        }
    }

    private static func groupedByNormalizedName<Value>(
        _ values: [Value],
        name: KeyPath<Value, String>
    ) -> [String: [Value]] {
        Dictionary(grouping: values) {
            SystemSeedKey.normalizedComparisonKey($0[keyPath: name])
        }
    }

    private static func groupedByNormalizedName<Value>(
        _ values: [Value],
        _ name: (Value) -> String
    ) -> [String: [Value]] {
        Dictionary(grouping: values) {
            SystemSeedKey.normalizedComparisonKey(name($0))
        }
    }

    private static func resolve<Value>(
        key: String,
        name: String,
        exact: [String: Value],
        byName: [String: [Value]],
        kind: CatalogDefinitionKind
    ) throws -> Value? {
        if let exact = exact[key.lowercased()] { return exact }
        let candidates = byName[SystemSeedKey.normalizedComparisonKey(name)] ?? []
        guard candidates.count <= 1 else {
            throw CatalogMetadataInstallError.ambiguousLegacyName(kind: kind, name: name)
        }
        return candidates.first
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func sourceReferences(
        _ values: [String],
        primaryURL: String? = nil
    ) -> [CatalogSourceReference] {
        values.enumerated().map { index, source in
            CatalogSourceReference(
                sourceID: source,
                label: source,
                url: index == 0 ? nilIfEmpty(primaryURL) : nil
            )
        }
    }

#if !GYMTRACKER_EXTENSION
    private static func stageProgramMetadata(
        _ resources: [ProgramCatalogResource],
        context: ModelContext,
        metadata: inout [CatalogDefinitionMetadata],
        metadataByTarget: inout [Target: CatalogDefinitionMetadata],
        report: inout CatalogMetadataInstallReport
    ) throws {
        // Only independently authored bundled definitions may be linked to a
        // recovered row. User programs can share names or keys and remain
        // entirely user-owned.
        let strengthRecords = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
            .filter(\.isBuiltIn)
        let strengthByKey = Dictionary(
            try strengthRecords.map { (try $0.payload().programKey.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // The recovered Liftosaur export contains a few lossy slug rewrites
        // (for example `foundation-barbell-5-ud7-5` for the canonical
        // `foundation-barbell-5x5`). The display name is the only defensible
        // fallback: it lets us attach descriptive metadata without treating a
        // scraped routine summary as an executable program definition.
        let strengthByName = groupedByNormalizedName(strengthRecords) { record in
            (try? record.payload().name) ?? record.name
        }
        // `liftosaur_programs_all` is the recovered strength/program export.
        // Mobility programs have their own bundled library and must not be
        // accidentally counted as executable matches here; the recovered
        // rows remain discovery-only until a source-backed mapping exists.
        let mobilityByKey: [String: MobilityProgramDefinitionRecord] = [:]
        let encoder = JSONEncoder()
        let existingDiscoverySeeds = try context.fetch(FetchDescriptor<ProgramDiscoverySeed>())
        var discoverySeedsByKey = Dictionary(
            existingDiscoverySeeds.map { ($0.programKey.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for resource in resources {
            let key = resource.stableKey.lowercased()
            let discovery = ProgramDiscoveryMetadata(
                authorOrOrigin: nilIfEmpty(resource.author),
                categoryOrDisciplineLabel: nilIfEmpty(resource.category),
                progressionModelLabel: nilIfEmpty(resource.progressionModel),
                tags: resource.tags,
                sourceProgramURL: nilIfEmpty(resource.url),
                imageURL: nilIfEmpty(resource.imageURL)
            )
            if let record = try resolve(
                key: key,
                name: resource.name,
                exact: strengthByKey,
                byName: strengthByName,
                kind: .workoutProgram
            ) {
                var payload = try record.payload()
                let payloadChanged = payload.discoveryMetadata != discovery
                if payloadChanged {
                    payload.discoveryMetadata = discovery
                    guard let data = try? encoder.encode(payload) else {
                        throw CatalogMetadataInstallError.encodingFailed(kind: .workoutProgram, definitionID: record.id)
                    }
                    record.definitionData = data
                    record.updatedAt = .now
                }
                let (row, isNew) = metadataRow(
                    for: record.id,
                    kind: .workoutProgram,
                    catalogueKey: resource.stableKey,
                    context: context,
                    metadata: &metadata,
                    metadataByTarget: &metadataByTarget,
                    report: &report
                )
                applyProgramPresentation(resource, to: row, isNew: isNew, payloadChanged: payloadChanged, report: &report)
            } else if let record = mobilityByKey[key] {
                var payload = try record.payload()
                let payloadChanged = payload.discoveryMetadata != discovery
                if payloadChanged {
                    payload.discoveryMetadata = discovery
                    guard let data = try? encoder.encode(payload) else {
                        throw CatalogMetadataInstallError.encodingFailed(kind: .mobilityProgram, definitionID: record.id)
                    }
                    record.definitionData = data
                    record.updatedAt = .now
                }
                let (row, isNew) = metadataRow(
                    for: record.id,
                    kind: .mobilityProgram,
                    catalogueKey: resource.stableKey,
                    context: context,
                    metadata: &metadata,
                    metadataByTarget: &metadataByTarget,
                    report: &report
                )
                applyProgramPresentation(resource, to: row, isNew: isNew, payloadChanged: payloadChanged, report: &report)
            } else {
                report.unmatchedProgramKeys.append(resource.stableKey)
                let normalizedKey = resource.stableKey.lowercased()
                let seed: ProgramDiscoverySeed
                let isNew: Bool
                if let existing = discoverySeedsByKey[normalizedKey] {
                    seed = existing
                    isNew = false
                } else {
                    seed = ProgramDiscoverySeed(programKey: resource.stableKey, name: resource.name)
                    context.insert(seed)
                    discoverySeedsByKey[normalizedKey] = seed
                    isNew = true
                }
                let changed = applyDiscoverySeed(resource, to: seed)
                if isNew {
                    report.inserted += 1
                } else if changed {
                    seed.updatedAt = .now
                    report.updated += 1
                } else {
                    report.unchanged += 1
                }
                report.discoveryOnlyProgramKeys.append(resource.stableKey)
            }
        }
        report.discoveryOnlyProgramKeys.sort()
    }

    private static func applyProgramPresentation(
        _ resource: ProgramCatalogResource,
        to row: CatalogDefinitionMetadata,
        isNew: Bool,
        payloadChanged: Bool,
        report: inout CatalogMetadataInstallReport
    ) {
        let sources = sourceReferences(resource.sources, primaryURL: resource.url)
        let equipment = resource.equipment
            .map { $0.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            ?? []
        let changed = payloadChanged
            || row.catalogueKey != resource.stableKey
            || row.sourceReferences != sources
            || row.descriptionText != nilIfEmpty(resource.description)
            || row.imageURLString != nilIfEmpty(resource.imageURL)
            || row.categoryRaw != nilIfEmpty(resource.category)
            || row.difficultyRaw != nilIfEmpty(resource.difficulty)
            || row.equipmentLabels != equipment
        row.catalogueKey = resource.stableKey
        row.sourceReferences = sources
        row.descriptionText = nilIfEmpty(resource.description)
        row.imageURLString = nilIfEmpty(resource.imageURL)
        row.categoryRaw = nilIfEmpty(resource.category)
        row.difficultyRaw = nilIfEmpty(resource.difficulty)
        row.equipmentLabels = equipment
        finish(changed: changed, isNew: isNew, row: row, report: &report)
    }

    @discardableResult
    private static func applyDiscoverySeed(
        _ resource: ProgramCatalogResource,
        to seed: ProgramDiscoverySeed
    ) -> Bool {
        let summary = nilIfEmpty(resource.description)
        let author = nilIfEmpty(resource.author)
        let category = nilIfEmpty(resource.category)
        let days = nilIfEmpty(resource.daysPerWeek)
        let duration = nilIfEmpty(resource.durationWeeks)
        let difficulty = nilIfEmpty(resource.difficulty)
        let progression = nilIfEmpty(resource.progressionModel)
        let equipment = nilIfEmpty(resource.equipment)
        let sourceURL = nilIfEmpty(resource.url)
        let imageURL = nilIfEmpty(resource.imageURL)
        let changed = seed.name != resource.name
            || seed.summary != summary
            || seed.authorOrOrigin != author
            || seed.categoryOrDisciplineLabel != category
            || seed.daysPerWeekText != days
            || seed.durationWeeksText != duration
            || seed.difficultyLabel != difficulty
            || seed.progressionModelLabel != progression
            || seed.equipmentText != equipment
            || seed.tags != resource.tags
            || seed.sourceURLString != sourceURL
            || seed.imageURLString != imageURL
            || seed.availabilityReason != .structuredPrescriptionUnavailable
            || seed.compatibilityStatus != .incompleteRecovery
            || seed.compatibilityReason != Self.incompleteRecoveryReason
            || seed.isRunnable
        seed.name = resource.name
        seed.summary = summary
        seed.authorOrOrigin = author
        seed.categoryOrDisciplineLabel = category
        seed.daysPerWeekText = days
        seed.durationWeeksText = duration
        seed.difficultyLabel = difficulty
        seed.progressionModelLabel = progression
        seed.equipmentText = equipment
        seed.tags = resource.tags
        seed.sourceURLString = sourceURL
        seed.imageURLString = imageURL
        seed.availabilityReason = .structuredPrescriptionUnavailable
        seed.compatibilityStatus = .incompleteRecovery
        seed.compatibilityReason = Self.incompleteRecoveryReason
        seed.isRunnable = false
        return changed
    }

    private static let incompleteRecoveryReason =
        "Recovered metadata does not include a trustworthy structured day/set/rep prescription."
#endif
}
