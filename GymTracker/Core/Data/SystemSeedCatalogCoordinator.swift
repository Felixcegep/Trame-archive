import Foundation
import SwiftData

@MainActor
enum SystemSeedCatalogCoordinator {
    static let seedVersion = 1
    static let contentVersion = 2

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
        var report = try ExerciseSystemSeedInstaller.install(in: context, registry: registry)

        _ = try ExerciseRelationshipSeedData.seed(in: context, saveChanges: false)
        report += try registerExerciseRelationships(in: context, registry: registry)

        report += try installWorkoutTemplatesAndCollection(in: context, registry: registry)
        report += try installWorkoutPlan(in: context, registry: registry)

#if !GYMTRACKER_EXTENSION
        _ = try ProgramLibrarySeedData.seedBundledCatalog(
            in: context,
            bundle: bundle,
            saveChanges: false
        )
        report += try registerPrograms(in: context, registry: registry)
#endif

        try MobilitySeedData.stage(using: context, registry: registry)
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
        let desiredTemplates = WorkoutTemplateSeedData.templates(using: exercises)
        guard desiredTemplates.count == WorkoutTemplateSeedData.seededTemplateNames.count else {
            throw SystemSeedError.unresolvedDependency(
                key: "workout-template.upper-lower-four-day",
                dependency: "seeded exercises"
            )
        }
        var existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        var report = SystemSeedInstallReport()
        var installedTemplates: [WorkoutTemplate] = []

        for desired in desiredTemplates {
            let key = SystemSeedKey.make(namespace: "workout-template", legacyName: desired.name)
            let entity: WorkoutTemplate
            if let record = try registry.record(for: key, expectedKind: .workoutTemplate) {
                guard let matched = existingTemplates.first(where: { $0.id == record.entityID }) else {
                    throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
                }
                entity = matched
                entity.isBuiltIn = true
                report.unchanged += 1
            } else {
                let candidates = existingTemplates.filter { isLegacyTemplate($0, equivalentTo: desired) }
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
                    entity = desired
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
            installedTemplates.append(entity)
        }

        let collectionKey = "workout-collection.upper-lower-four-day"
        let collections = try context.fetch(FetchDescriptor<WorkoutCollection>())
        if let record = try registry.record(for: collectionKey, expectedKind: .workoutCollection) {
            guard let matched = collections.first(where: { $0.id == record.entityID }) else {
                throw SystemSeedError.danglingEntity(key: collectionKey, entityID: record.entityID)
            }
            matched.isBuiltIn = true
            report.unchanged += 1
        } else {
            let candidates = collections.filter {
                $0.name == WorkoutTemplateSeedData.collectionName
                    && Set($0.workoutTemplates.map(\.id)) == Set(installedTemplates.map(\.id))
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
                    name: WorkoutTemplateSeedData.collectionName,
                    workoutTemplates: installedTemplates,
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
        let key = "workout-plan.sacroiliac-rehabilitation"
        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        if let record = try registry.record(for: key, expectedKind: .workoutPlan) {
            guard plans.contains(where: { $0.id == record.entityID }) else {
                throw SystemSeedError.danglingEntity(key: key, entityID: record.entityID)
            }
            return .init(unchanged: 1)
        }
        let candidates = plans.filter { $0.name == SacroiliacRehabPlanSeedData.planName }
        guard candidates.count <= 1 else {
            throw SystemSeedError.ambiguousLegacyMatch(key: key, count: candidates.count)
        }
        let plan: WorkoutPlan
        let source: SystemSeedSourceKind
        var report = SystemSeedInstallReport()
        if let adopted = candidates.first {
            plan = adopted
            source = .migratedLegacy
            report.adopted = 1
        } else {
            let exercises = try context.fetch(FetchDescriptor<Exercise>())
            guard let created = SacroiliacRehabPlanSeedData.makePlan(using: exercises) else {
                throw SystemSeedError.unresolvedDependency(key: key, dependency: "seeded exercises")
            }
            plan = created
            context.insert(plan)
            source = .bundled
            report.inserted = 1
        }
        try registry.register(
            key: key,
            kind: .workoutPlan,
            entityID: plan.id,
            seedVersion: seedVersion,
            contentVersion: contentVersion,
            sourceKind: source
        )
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
                contentVersion: payload.templateVersion,
                sourceKind: existed ? .bundled : .migratedLegacy
            )
            if existed { report.updated += 1 } else { report.adopted += 1 }
        }
        return report
    }
#endif
}
