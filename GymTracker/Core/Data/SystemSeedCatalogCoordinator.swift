import Foundation
import SwiftData

@MainActor
enum SystemSeedCatalogCoordinator {
    static let seedVersion = 1
    // 16: fixed the ExerciseSeedData/ExerciseCatalogSeedData dedupe filter
    // (exact-string match let "Pull Up" and "Pull-Up" both ship as separate
    // exercises) and retired the resulting shipped duplicates; corrected
    // Tibialis Raise, Assisted Push-Up, Assisted Dip, and Scapular Pull-Up
    // off `.weightAndReps` onto `.repsOnly` to match their bodyweight
    // resistanceType. Existing installs below this version still have the
    // stale duplicate/misclassified records and need `needsInstallation`
    // to trigger a reinstall so `ExerciseSystemSeedInstaller` can apply
    // both the corrected fields and the duplicate retirement.
    // 18: withheld bundled programs whose current payload does not establish
    // the advertised training schedule. Existing installs need this version
    // so those records are archived rather than continuing to surface an
    // incomplete Program Path.
    // 19: installs the additive recovered-catalogue metadata after all
    // canonical definition targets exist. Unmatched recovered rows remain
    // report-only and never become runnable content.
    // 20: materializes the complete recovered exercise/mobility catalogue and
    // all program discovery listings. This forces internal v19 stores to run
    // the finalized seed pass rather than incorrectly treating it as current.
    // 21: audit and correct Push/Pull/Legs/Core movement patterns, force types, and
    // focus filtering accuracy across all system catalog exercises.
    // 22: align bundled recipe ingredient names with the food catalog, add whey
    // protein powder, and repair incomplete v1 seeded recipes that skipped
    // unmatched ingredients.
    static let contentVersion = 22

    private static let retiredBundledProgramKeys: Set<String> = [
        "powerlifting-volume-intensity",
        "powerlifting-meet-preparation",
        "weightlifting-technical-foundations",
        "strongman-event-foundations",
        "hybrid-race-foundations",
        "couch-to-continuous-running",
        "rowerg-2000m-builder",
        "kettlebell-foundations"
    ]

    // Keep this separate from the current retirement set so a future content
    // version can intentionally reintroduce a repaired definition and
    // unarchive only that known key. Other built-in records must retain their
    // archive state when they are refreshed.
    private static let previouslyRetiredBundledProgramKeys: Set<String> = [
        "powerlifting-volume-intensity",
        "powerlifting-meet-preparation",
        "weightlifting-technical-foundations",
        "strongman-event-foundations",
        "hybrid-race-foundations",
        "couch-to-continuous-running",
        "rowerg-2000m-builder",
        "kettlebell-foundations"
    ]

    /// The catalogue is immutable between bundled content versions. Avoid a
    /// full graph scan and save on every launch once this version is present.
    static func needsInstallation(in context: ModelContext) throws -> Bool {
        if try context.fetchCount(FetchDescriptor<SystemSeedRecord>()) == 0 {
            return true
        }

        let requiredSeedVersion = seedVersion
        let requiredContentVersion = contentVersion
        var outdatedRecord = FetchDescriptor<SystemSeedRecord>(
            predicate: #Predicate {
                $0.seedVersion < requiredSeedVersion
                    || $0.contentVersion < requiredContentVersion
            }
        )
        outdatedRecord.fetchLimit = 1
        return try context.fetch(outdatedRecord).isEmpty == false
    }

    static func installBundledCatalog(
        in context: ModelContext,
        bundle: Bundle = .main
    ) throws -> SystemSeedInstallReport {
        do {
            let report = try stageBundledCatalog(in: context, bundle: bundle)
            try context.save()
            return report
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Stages the complete bundled catalogue without saving. Callers that
    /// already own a larger persistence transaction, such as backup restore,
    /// use this so the catalogue and its manifest commit or roll back together.
    static func stageBundledCatalog(
        in context: ModelContext,
        bundle: Bundle = .main
    ) throws -> SystemSeedInstallReport {
        let recoveredCatalog = try CatalogResourceDecoder.decodeBundled(bundle: bundle)
        let registry = try SystemSeedRegistry(context: context)
        var report = try ExerciseSystemSeedInstaller.install(
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )

        // Stage the complete recovered movement catalogue before relationships
        // and templates resolve their exercise references. Existing entities
        // are matched by stable key/legacy identity, so IDs and history stay
        // intact while missing bundled rows are added transactionally.
        report += try CatalogMetadataInstaller.seedDefinitions(
            recoveredCatalog,
            in: context,
            registry: registry
        )

        // ExerciseRelationshipSeedData.seed only asserts on an unresolved
        // exercise name, which is stripped in Release builds; without this
        // guard a Release install would silently skip relationships instead
        // of failing, the same class of gap installWorkoutTemplatesAndCollection
        // closes below with its `guard desiredTemplates.count == ...` check.
        let relationshipSeedResult = try ExerciseRelationshipSeedData.seed(in: context, saveChanges: false)
        guard relationshipSeedResult.unresolvedNames.isEmpty else {
            throw SystemSeedError.unresolvedDependency(
                key: "exercise-relationship-seed-data",
                dependency: relationshipSeedResult.unresolvedNames.sorted().joined(separator: ", ")
            )
        }
        report += try registerExerciseRelationships(in: context, registry: registry)

        report += try installWorkoutTemplatesAndCollection(in: context, registry: registry)
        report += try RepeatingPlanSystemSeedInstaller.install(
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )
        report += try installWorkoutPlan(in: context, registry: registry)

#if !GYMTRACKER_EXTENSION
        _ = try ProgramLibrarySeedData.seedBundledCatalog(
            in: context,
            bundle: bundle,
            saveChanges: false
        )
        report += try reconcileUnderSpecifiedBundledPrograms(in: context)
        report += try registerPrograms(in: context, registry: registry)
#endif

        // The mobility movement catalog must exist before mobility programs
        // are seeded: each program's occurrences resolve their
        // `mobilityDefinitionID` by looking up the just-staged
        // `MobilityDefinition` catalog by name (see
        // `MobilityProgramLibrarySeedData.seedBundledCatalog`), exactly like
        // `ProgramLibrarySeedData.seed` above resolves exercise references
        // against `Exercise` staged earlier in this same transaction.
        try MobilitySeedData.stage(using: context, registry: registry)

#if !GYMTRACKER_EXTENSION
        // Mirrors the workout program library seeding above, now that the
        // first three mobility programs ship.
        _ = try MobilityProgramLibrarySeedData.seedBundledCatalog(
            in: context,
            bundle: bundle,
            saveChanges: false
        )
        report += try registerMobilityPrograms(in: context, registry: registry)

        // Descriptive recovered data is attached last, after every possible
        // target exists, and remains inside this coordinator's one-save
        // transaction. The installer intentionally does not create runnable
        // programs from `routines_summary` or `days_structure` prose.
        _ = try CatalogMetadataInstaller.stageBundled(in: context, bundle: bundle)
#endif

        report += try MobilityAssessmentSeedData.stage(using: context, registry: registry)
        report += try WorkoutTemplateMobilitySeedLinker.apply(in: context, registry: registry)
        try NutritionSeedData.stage(using: context, registry: registry)

        return report
    }

#if !GYMTRACKER_EXTENSION
    /// Keeps incomplete bundled definitions recoverable without presenting
    /// them as real programs. A repaired definition may be reintroduced by
    /// removing its stable key from `retiredBundledProgramKeys`; only keys in
    /// `previouslyRetiredBundledProgramKeys` are then eligible for unarchiving.
    private static func reconcileUnderSpecifiedBundledPrograms(
        in context: ModelContext
    ) throws -> SystemSeedInstallReport {
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>())
        var report = SystemSeedInstallReport()
        for record in records where record.isBuiltIn {
            let payload = try record.payload()
            if retiredBundledProgramKeys.contains(payload.programKey) {
                guard !record.isArchived else { continue }
                record.isArchived = true
                record.updatedAt = .now
                report.updated += 1
            } else if previouslyRetiredBundledProgramKeys.contains(payload.programKey), record.isArchived {
                record.isArchived = false
                record.updatedAt = .now
                report.updated += 1
            }
        }
        return report
    }
#endif

    private static func registerExerciseRelationships(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let relationships = try context.fetch(FetchDescriptor<ExerciseRelationship>())
        var report = SystemSeedInstallReport()
        for definition in ExerciseRelationshipSeedData.definitions {
            guard let relationship = relationships.first(where: {
                $0.sourceExercise?.name == definition.source
                    && $0.targetExercise?.name == definition.target
                    && $0.type == definition.type
            }) else {
                throw SystemSeedError.unresolvedDependency(
                    key: relationshipKey(definition),
                    dependency: "\(definition.source) -> \(definition.target)"
                )
            }
            let key = relationshipKey(definition)
            let wasExisting = try registry.record(for: key, expectedKind: .exerciseRelationship) != nil
            try registry.register(
                key: key,
                kind: .exerciseRelationship,
                entityID: relationship.id,
                seedVersion: seedVersion,
                contentVersion: contentVersion,
                sourceKind: wasExisting ? .bundled : .migratedLegacy
            )
            if wasExisting { report.updated += 1 } else { report.adopted += 1 }
        }
        return report
    }

    private static func relationshipKey(_ definition: ExerciseRelationshipSeedData.Definition) -> String {
        let source = SystemSeedKey.make(namespace: "", legacyName: definition.source).dropFirst()
        let target = SystemSeedKey.make(namespace: "", legacyName: definition.target).dropFirst()
        return "exercise-relationship.\(source).\(definition.type.rawValue.lowercased()).\(target)"
    }

    private static func installWorkoutTemplatesAndCollection(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let desiredTemplates = WorkoutTemplateSeedData.seededTemplates(using: exercises)
        try registry.validateUniqueKeys(desiredTemplates.map(\.seedKey))
        guard desiredTemplates.count == WorkoutTemplateSeedData.seededTemplateNames.count else {
            throw SystemSeedError.unresolvedDependency(
                key: "workout-template.upper-lower-four-day",
                dependency: "seeded exercises"
            )
        }
        var existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        var existingTemplatesByID = Dictionary(
            existingTemplates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var report = SystemSeedInstallReport()
        var installedTemplatesByKey: [String: WorkoutTemplate] = [:]

        for desired in desiredTemplates {
            let key = desired.seedKey
            let entity: WorkoutTemplate
            if let record = try registry.record(for: key, expectedKind: .workoutTemplate) {
                guard let matched = existingTemplatesByID[record.entityID] else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                entity = matched
                entity.isBuiltIn = true
                report.unchanged += 1
            } else {
                let candidates = existingTemplates.filter { isLegacyTemplate($0, equivalentTo: desired.template) }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
                }
                if let adopted = candidates.first {
                    entity = adopted
                    entity.isBuiltIn = true
                    try registry.register(
                        key: key,
                        kind: .workoutTemplate,
                        entityID: entity.id,
                        seedVersion: seedVersion,
                        contentVersion: contentVersion,
                        sourceKind: .migratedLegacy
                    )
                    report.adopted += 1
                } else {
                    entity = desired.template
                    entity.isBuiltIn = true
                    context.insert(entity)
                    existingTemplates.append(entity)
                    existingTemplatesByID[entity.id] = entity
                    try registry.register(
                        key: key,
                        kind: .workoutTemplate,
                        entityID: entity.id,
                        seedVersion: seedVersion,
                        contentVersion: contentVersion,
                        sourceKind: .bundled
                    )
                    report.inserted += 1
                }
            }
            installedTemplatesByKey[key] = entity
        }

        let existingCollections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        let existingCollectionsByID = Dictionary(
            existingCollections.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for collectionDef in WorkoutTemplateSeedData.collections {
            let collectionKey = collectionDef.seedKey
            let collectionTemplates = try collectionDef.templateSeedKeys.map { templateKey in
                guard let template = installedTemplatesByKey[templateKey] else {
                    throw SystemSeedError.unresolvedDependency(key: collectionKey, dependency: templateKey)
                }
                return template
            }

            if let record = try registry.record(for: collectionKey, expectedKind: .workoutCollection) {
                guard let matched = existingCollectionsByID[record.entityID] else {
                    throw SystemSeedError.danglingEntity(key: collectionKey, entityID: record.entityID)
                }
                matched.isBuiltIn = true
                report.unchanged += 1
            } else {
                let candidates = existingCollections.filter {
                    $0.name == collectionDef.name
                        && Set($0.workoutTemplates.map(\.id)) == Set(collectionTemplates.map(\.id))
                }
                guard candidates.count <= 1 else {
                    throw SystemSeedError.ambiguousLegacyMatch(key: collectionKey, count: candidates.count)
                }
                let collection: WorkoutCollection
                let source: SystemSeedSourceKind
                if let adopted = candidates.first {
                    collection = adopted
                    collection.isBuiltIn = true
                    source = .migratedLegacy
                    report.adopted += 1
                } else {
                    collection = WorkoutCollection(
                        name: collectionDef.name,
                        workoutTemplates: collectionTemplates,
                        isBuiltIn: true
                    )
                    context.insert(collection)
                    source = .bundled
                    report.inserted += 1
                }
                try registry.register(
                    key: collectionKey,
                    kind: .workoutCollection,
                    entityID: collection.id,
                    seedVersion: seedVersion,
                    contentVersion: contentVersion,
                    sourceKind: source
                )
            }
        }
        return report
    }

    private static func isLegacyTemplate(_ existing: WorkoutTemplate, equivalentTo desired: WorkoutTemplate) -> Bool {
        existing.name == desired.name
            && existing.orderedTemplateExercises.map { $0.exercise.name }
                == desired.orderedTemplateExercises.map { $0.exercise.name }
    }

    private static func installWorkoutPlan(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let seededPlans = WorkoutPlanSeedData.plans(using: exercises)
        let existingPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        var report = SystemSeedInstallReport()

        for (key, desiredPlan) in seededPlans {
            if let record = try registry.record(for: key, expectedKind: .workoutPlan) {
                guard existingPlans.contains(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                report.unchanged += 1
                continue
            }
            let candidates = existingPlans.filter { $0.name == desiredPlan.name }
            guard candidates.count <= 1 else {
                throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
            }
            let plan: WorkoutPlan
            let source: SystemSeedSourceKind
            if let adopted = candidates.first {
                plan = adopted
                source = .migratedLegacy
                report.adopted += 1
            } else {
                plan = desiredPlan
                context.insert(plan)
                source = .bundled
                report.inserted += 1
            }
            try registry.register(
                key: key,
                kind: .workoutPlan,
                entityID: plan.id,
                seedVersion: seedVersion,
                contentVersion: contentVersion,
                sourceKind: source
            )
        }
        return report
    }

#if !GYMTRACKER_EXTENSION
    private static func registerPrograms(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>(
            predicate: #Predicate { $0.isBuiltIn }
        ))
        var report = SystemSeedInstallReport()
        for definition in records {
            let payload = try definition.payload()
            let key = "program.\(payload.programKey.lowercased())"
            let existed = try registry.record(for: key, expectedKind: .programDefinition) != nil
            try registry.register(
                key: key,
                kind: .programDefinition,
                entityID: definition.id,
                seedVersion: seedVersion,
                // Manifest content version tracks the bundled catalogue as a
                // whole. The program's own template version remains on its
                // definition record and is not a manifest version.
                contentVersion: contentVersion,
                sourceKind: existed ? .bundled : .migratedLegacy
            )
            if existed { report.updated += 1 } else { report.adopted += 1 }
        }
        return report
    }

    private static func registerMobilityPrograms(
        in context: ModelContext,
        registry: SystemSeedRegistry
    ) throws -> SystemSeedInstallReport {
        let records = try context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>(
            predicate: #Predicate { $0.isBuiltIn }
        ))
        var report = SystemSeedInstallReport()
        for definition in records {
            let key = "mobility-program.\(definition.programKey.lowercased())"
            let existed = try registry.record(for: key, expectedKind: .mobilityProgramDefinition) != nil
            try registry.register(
                key: key,
                kind: .mobilityProgramDefinition,
                entityID: definition.id,
                seedVersion: seedVersion,
                // Manifest content version tracks the bundled catalogue as a
                // whole. The program's own template version remains on its
                // definition record and is not a manifest version.
                contentVersion: contentVersion,
                sourceKind: existed ? .bundled : .migratedLegacy
            )
            if existed { report.updated += 1 } else { report.adopted += 1 }
        }
        return report
    }
#endif
}
