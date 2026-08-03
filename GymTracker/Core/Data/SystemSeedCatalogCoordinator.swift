import Foundation
import SwiftData

@MainActor
enum SystemSeedCatalogCoordinator {
    static let seedVersion = 1
    static let contentVersion = 13

    /// The catalogue is immutable between bundled content versions. Avoid a
    /// full graph scan and save on every launch once this version is present.
    static func needsInstallation(in context: ModelContext) throws -> Bool {
        let records = try context.fetch(FetchDescriptor<SystemSeedRecord>())
        return records.isEmpty || records.contains {
            $0.seedVersion < seedVersion || $0.contentVersion < contentVersion
        }
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
        let registry = try SystemSeedRegistry(context: context)
        var report = try ExerciseSystemSeedInstaller.install(
            in: context,
            registry: registry,
            seedVersion: seedVersion,
            contentVersion: contentVersion
        )

        _ = try ExerciseRelationshipSeedData.seed(in: context, saveChanges: false)
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
#endif

        report += try MobilityAssessmentSeedData.stage(using: context, registry: registry)
        report += try WorkoutTemplateMobilitySeedLinker.apply(in: context, registry: registry)
        try NutritionSeedData.stage(using: context, registry: registry)

        return report
    }

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
        var report = SystemSeedInstallReport()
        var installedTemplatesByKey: [String: WorkoutTemplate] = [:]

        for desired in desiredTemplates {
            let key = desired.seedKey
            let entity: WorkoutTemplate
            if let record = try registry.record(for: key, expectedKind: .workoutTemplate) {
                guard let matched = existingTemplates.first(where: { $0.id == record.entityID }) else {
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
        for collectionDef in WorkoutTemplateSeedData.collections {
            let collectionKey = collectionDef.seedKey
            let collectionTemplates = try collectionDef.templateSeedKeys.map { templateKey in
                guard let template = installedTemplatesByKey[templateKey] else {
                    throw SystemSeedError.unresolvedDependency(key: collectionKey, dependency: templateKey)
                }
                return template
            }

            if let record = try registry.record(for: collectionKey, expectedKind: .workoutCollection) {
                guard let matched = existingCollections.first(where: { $0.id == record.entityID }) else {
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
        let records = try context.fetch(FetchDescriptor<ProgramDefinitionRecord>()).filter(\.isBuiltIn)
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
        let records = try context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>()).filter(\.isBuiltIn)
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
