import CryptoKit
import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

enum PortableImportResolution: String, CaseIterable, Codable, Equatable, Sendable {
    case keepExisting
    case importSeparateCopy
    case updateExisting
}

struct PortableImportDecision: Equatable, Sendable {
    let componentID: UUID
    let resolution: PortableImportResolution
}

struct PortableImportApplicationResult: Equatable, Sendable {
    let insertedComponentIDs: [UUID]
    let updatedComponentIDs: [UUID]
    let skippedComponentIDs: [UUID]
}

enum PortableTrainingPackageImportError: LocalizedError, Equatable {
    case invalidPackage
    case unresolvedComponent(UUID)
    case unsupportedComponent(UUID, PortableTrainingComponentKind)
    case invalidPayload(UUID)
    case missingDependency(UUID, UUID)
    case dependencyCycle
    case identityConflict(UUID)
    case unsafeUpdate(UUID)
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalidPackage: "The package failed integrity or compatibility validation."
        case .unresolvedComponent: "Every package conflict must have an explicit decision."
        case .unsupportedComponent(_, let kind): "This build cannot import a \(kind.rawValue) component."
        case .invalidPayload: "A package component contains an invalid payload."
        case .missingDependency: "A required package dependency is unavailable."
        case .dependencyCycle: "The package contains a circular dependency."
        case .identityConflict: "A stable identity already belongs to different local content."
        case .unsafeUpdate: "This definition is not eligible for a safe in-place update."
        case .persistenceFailed: "The package could not be saved. No import was applied."
        }
    }
}

/// Builds preview identity from real local definition records. Display names
/// are deliberately descriptive only and never participate in ownership.
@MainActor
enum PortableLocalComponentInventory {
    static func build(using context: ModelContext) throws -> [PortableLocalComponent] {
        var result: [PortableLocalComponent] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for record in try context.fetch(FetchDescriptor<ProgramDefinitionRecord>()) {
            let source = try PortableTrainingPackageAssemblyProjection.source(record: record)
            result.append(component(id: source.componentID, contentID: source.contentID, kind: source.kind,
                                    name: source.name, version: source.contentVersion, payload: source.payload))
        }
        for record in try context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>()) {
            let source = try PortableTrainingPackageAssemblyProjection.source(record: record)
            result.append(component(id: source.componentID, contentID: source.contentID, kind: source.kind,
                                    name: source.name, version: source.contentVersion, payload: source.payload))
        }
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) {
            let source = try PortableTrainingPackageAssemblyProjection.source(template: template)
            result.append(component(id: source.componentID, contentID: source.contentID, kind: source.kind,
                                    name: source.name, version: source.contentVersion, payload: source.payload))
        }
        for plan in try context.fetch(FetchDescriptor<RepeatingPlan>()) {
            let source = try PortableTrainingPackageAssemblyProjection.source(repeatingPlan: plan)
            result.append(component(id: source.componentID, contentID: source.contentID, kind: source.kind,
                                    name: source.name, version: source.contentVersion, payload: source.payload))
        }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            result.append(component(id: exercise.id, kind: .exerciseDefinition, name: exercise.name,
                                    version: 1, payload: try encoder.encode(exercise.id)))
        }
        for routine in try context.fetch(FetchDescriptor<MobilityRoutine>()) {
            result.append(component(id: routine.id, kind: .mobilityRoutine, name: routine.name,
                                    version: 1, payload: try encoder.encode(routine.id)))
        }
        return result.sorted { $0.componentID.uuidString < $1.componentID.uuidString }
    }

    private static func component(
        id: UUID,
        contentID: UUID? = nil,
        kind: PortableTrainingComponentKind,
        name: String,
        version: Int,
        payload: Data
    ) -> PortableLocalComponent {
        PortableLocalComponent(
            componentID: id,
            contentID: contentID ?? id,
            kind: kind,
            name: name,
            contentVersion: max(1, version),
            checksum: SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        )
    }
}

/// Applies only definition graphs. It never fetches or mutates Workout,
/// PlanRun, RepeatingPlanRun, MobilitySession, or progression receipt records.
/// All payloads and decisions are validated before the first insertion and the
/// graph is committed with one save; any thrown error rolls the context back.
@MainActor
enum PortableTrainingPackageImportService {
    static func apply(
        package: PortableTrainingPackage,
        decisions: [PortableImportDecision],
        supportedCapabilityIDs: Set<String> = EngineCapabilities.current,
        minimumSchemaVersion: Int = 1,
        beforeCommit: (() throws -> Void)? = nil,
        using context: ModelContext
    ) throws -> PortableImportApplicationResult {
        let inventory: [PortableLocalComponent]
        do {
            inventory = try PortableLocalComponentInventory.build(using: context)
        } catch {
            throw PortableTrainingPackageImportError.persistenceFailed
        }
        let preview = PortableImportPreviewPolicy.preview(
            package: package,
            localComponents: inventory,
            supportedCapabilityIDs: supportedCapabilityIDs,
            minimumSchemaVersion: minimumSchemaVersion
        )
        guard preview.validationFailures.isEmpty, preview.compatibilityFailures.isEmpty else {
            throw PortableTrainingPackageImportError.invalidPackage
        }

        let decisionsByID = Dictionary(uniqueKeysWithValues: decisions.map { ($0.componentID, $0.resolution) })
        let localIDs = Set(inventory.map(\.componentID))
        let packageIDs = Set(package.components.map(\.componentID))
        for item in preview.items {
            switch item.classification {
            case .addition, .exactMatch:
                break
            default:
                guard decisionsByID[item.component.componentID] != nil else {
                    throw PortableTrainingPackageImportError.unresolvedComponent(item.component.componentID)
                }
            }
        }
        for component in package.components {
            for dependencyID in component.dependencyIDs {
                guard localIDs.contains(dependencyID) || packageIDs.contains(dependencyID) else {
                    throw PortableTrainingPackageImportError.missingDependency(component.componentID, dependencyID)
                }
            }
            try validatePayload(component)
        }

        let orderedItems = try dependencyOrdered(preview.items)
        var inserted: [UUID] = []
        var updated: [UUID] = []
        var skipped: [UUID] = []
        var copiedIDs: [UUID: UUID] = [:]
        for item in orderedItems {
            let resolution = decisionsByID[item.component.componentID] ?? defaultResolution(for: item.classification)
            guard resolution == .importSeparateCopy else { continue }
            let targetID: UUID
            if case .addition = item.classification {
                targetID = item.component.contentID
            } else {
                targetID = UUID()
            }
            copiedIDs[item.component.componentID] = targetID
            copiedIDs[item.component.contentID] = targetID
        }

        do {
            for item in orderedItems {
                let component = item.component
                let resolution = decisionsByID[component.componentID] ?? defaultResolution(for: item.classification)
                switch resolution {
                case .keepExisting:
                    skipped.append(component.componentID)
                case .importSeparateCopy:
                    let newID = copiedIDs[component.contentID] ?? UUID()
                    try materialize(component, targetID: newID, updateExisting: false, copiedIDs: copiedIDs, using: context)
                    inserted.append(newID)
                case .updateExisting:
                    guard try canSafelyUpdate(
                        component: component,
                        classification: item.classification,
                        packageProvenance: package.provenance,
                        using: context
                    ) else {
                        throw PortableTrainingPackageImportError.unsafeUpdate(component.componentID)
                    }
                    try materialize(component, targetID: component.contentID, updateExisting: true, copiedIDs: copiedIDs, using: context)
                    updated.append(component.componentID)
                }
            }
            try beforeCommit?()
            try context.save()
        } catch let error as PortableTrainingPackageImportError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw PortableTrainingPackageImportError.persistenceFailed
        }

        return PortableImportApplicationResult(
            insertedComponentIDs: inserted,
            updatedComponentIDs: updated,
            skippedComponentIDs: skipped
        )
    }

    private static func dependencyOrdered(
        _ items: [PortableImportItemPreview]
    ) throws -> [PortableImportItemPreview] {
        let ids = Set(items.map(\.component.componentID))
        var remaining = items
        var resolved = Set<UUID>()
        var result: [PortableImportItemPreview] = []
        while !remaining.isEmpty {
            let ready = remaining.filter { item in
                Set(item.component.dependencyIDs.filter(ids.contains)).isSubset(of: resolved)
            }.sorted { $0.component.selectionOrder < $1.component.selectionOrder }
            guard !ready.isEmpty else { throw PortableTrainingPackageImportError.dependencyCycle }
            let readyIDs = Set(ready.map(\.component.componentID))
            result.append(contentsOf: ready)
            resolved.formUnion(readyIDs)
            remaining.removeAll { readyIDs.contains($0.component.componentID) }
        }
        return result
    }

    private static func defaultResolution(for classification: PortableImportClassification) -> PortableImportResolution {
        switch classification {
        case .addition: .importSeparateCopy
        case .exactMatch: .keepExisting
        default: .keepExisting
        }
    }

    private static func validatePayload(_ component: PortableTrainingComponentDescriptor) throws {
        do {
            switch component.kind {
            case .planDefinition:
                _ = try ProgramDefinitionCodec.decode(component.payload)
            case .mobilityProgram:
                _ = try MobilityProgramDefinitionCodec.decode(component.payload)
            case .workoutTemplate:
                _ = try JSONDecoder().decode(PortableWorkoutTemplateSnapshot.self, from: component.payload)
            case .repeatingPlan:
                _ = try JSONDecoder().decode(PortableRepeatingPlanSnapshot.self, from: component.payload)
            case .exerciseDefinition, .mobilityRoutine:
                throw PortableTrainingPackageImportError.unsupportedComponent(component.componentID, component.kind)
            }
        } catch let error as PortableTrainingPackageImportError {
            throw error
        } catch {
            throw PortableTrainingPackageImportError.invalidPayload(component.componentID)
        }
    }

    private static func canSafelyUpdate(
        component: PortableTrainingComponentDescriptor,
        classification: PortableImportClassification,
        packageProvenance: PortableTrainingProvenance,
        using context: ModelContext
    ) throws -> Bool {
        guard case .safeUpdate = classification,
              packageProvenance.kind == .bundled,
              packageProvenance.sourceIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else { return false }
        let contentID = component.contentID
        switch component.kind {
        case .planDefinition:
            return try context.fetch(FetchDescriptor<ProgramDefinitionRecord>(
                predicate: #Predicate { $0.id == contentID }
            )).first?.isBuiltIn == true
        case .mobilityProgram:
            return try context.fetch(FetchDescriptor<MobilityProgramDefinitionRecord>(
                predicate: #Predicate { $0.id == contentID }
            )).first?.isBuiltIn == true
        case .workoutTemplate:
            return try context.fetch(FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate { $0.id == contentID }
            )).first?.isBuiltIn == true
        case .repeatingPlan:
            return try context.fetch(FetchDescriptor<RepeatingPlan>(
                predicate: #Predicate { $0.id == contentID }
            )).first?.isBuiltIn == true
        case .exerciseDefinition, .mobilityRoutine:
            return false
        }
    }

    private static func materialize(
        _ component: PortableTrainingComponentDescriptor,
        targetID: UUID,
        updateExisting: Bool,
        copiedIDs: [UUID: UUID],
        using context: ModelContext
    ) throws {
        switch component.kind {
        case .planDefinition:
            var payload = try ProgramDefinitionCodec.decode(component.payload)
            if targetID != payload.id { payload = try remapped(payload, to: targetID) }
            let preservesTrustedOwnership: Bool
            if updateExisting {
                preservesTrustedOwnership = try context.fetch(
                    FetchDescriptor<ProgramDefinitionRecord>(predicate: #Predicate { $0.id == targetID })
                ).first?.isBuiltIn == true
            } else {
                preservesTrustedOwnership = false
            }
            _ = try ProgramDefinitionRepository.save(payload, isBuiltIn: preservesTrustedOwnership, in: context)
        case .mobilityProgram:
            var payload = try MobilityProgramDefinitionCodec.decode(component.payload)
            if targetID != payload.id { payload = try remapped(payload, to: targetID) }
            let preservesTrustedOwnership: Bool
            if updateExisting {
                preservesTrustedOwnership = try context.fetch(
                    FetchDescriptor<MobilityProgramDefinitionRecord>(predicate: #Predicate { $0.id == targetID })
                ).first?.isBuiltIn == true
            } else {
                preservesTrustedOwnership = false
            }
            _ = try MobilityProgramDefinitionRepository.save(payload, isBuiltIn: preservesTrustedOwnership, in: context)
        case .workoutTemplate:
            let snapshot = try JSONDecoder().decode(PortableWorkoutTemplateSnapshot.self, from: component.payload)
            try materializeTemplate(snapshot, targetID: targetID, updateExisting: updateExisting, copiedIDs: copiedIDs, using: context)
        case .repeatingPlan:
            let snapshot = try JSONDecoder().decode(PortableRepeatingPlanSnapshot.self, from: component.payload)
            try materializeRepeatingPlan(snapshot, targetID: targetID, updateExisting: updateExisting, copiedIDs: copiedIDs, using: context)
        case .exerciseDefinition, .mobilityRoutine:
            throw PortableTrainingPackageImportError.unsupportedComponent(component.componentID, component.kind)
        }
    }

    private static func materializeTemplate(
        _ snapshot: PortableWorkoutTemplateSnapshot,
        targetID: UUID,
        updateExisting: Bool,
        copiedIDs: [UUID: UUID],
        using context: ModelContext
    ) throws {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exerciseByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        let routineByID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let blockIDMap = Dictionary(uniqueKeysWithValues: snapshot.executionBlocks.map { row in
            (row.id, updateExisting ? row.id : UUID())
        })
        var supersetIDMap: [UUID: UUID] = [:]
        let rows = try snapshot.exercises.map { row -> TemplateExercise in
            guard let exercise = exerciseByID[copiedIDs[row.id] ?? row.id] else {
                throw PortableTrainingPackageImportError.missingDependency(snapshot.id, row.id)
            }
            let supersetID = row.supersetGroupID.map { sourceID in
                if updateExisting { return sourceID }
                if let mapped = supersetIDMap[sourceID] { return mapped }
                let mapped = UUID()
                supersetIDMap[sourceID] = mapped
                return mapped
            }
            let entry = TemplateExercise(
                exercise: exercise, order: row.orderIndex, targetSets: row.targetSets,
                repRangeMinimum: row.repRangeMinimum, repRangeMaximum: row.repRangeMaximum,
                restSeconds: row.restSeconds, targetRPE: row.targetRPE, targetRIR: row.targetRIR,
                notes: row.notes, progressionRule: row.progressionRule,
                trackingTypeOverride: row.trackingTypeOverrideRaw.flatMap(TrackingType.init(rawValue:)),
                stimulus: row.stimulusRaw.flatMap(TrainingStimulus.init(rawValue:)),
                supersetGroupID: supersetID, progressionKey: row.progressionKey
            )
            entry.executionBlockID = row.executionBlockID.flatMap { blockIDMap[$0] }
            entry.executionBlockComponentOrder = row.executionBlockComponentOrder
            return entry
        }
        let blocks = snapshot.executionBlocks.map { row -> TemplateExerciseBlock in
            let block = TemplateExerciseBlock(
                orderIndex: row.orderIndex, kind: row.kind, name: row.name, targetRounds: row.targetRounds,
                isSharedLoad: row.isSharedLoad, restSeconds: row.restSeconds, clockMode: row.clockMode,
                prescribedDurationSeconds: row.prescribedDurationSeconds, timeCapSeconds: row.timeCapSeconds,
                intervalSeconds: row.intervalSeconds, scoreKind: row.scoreKind, repetitionScheme: row.repetitionScheme,
                repetitionStart: row.repetitionStart, repetitionEnd: row.repetitionEnd, repetitionStep: row.repetitionStep
            )
            block.id = blockIDMap[row.id] ?? row.id
            return block
        }
        let preID = snapshot.preWorkoutMobilityRoutineID.map { copiedIDs[$0] ?? $0 }
        let postID = snapshot.postWorkoutMobilityRoutineID.map { copiedIDs[$0] ?? $0 }
        let existingTemplate = try context.fetch(FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == targetID }
        )).first
        if updateExisting, let existing = existingTemplate {
            existing.name = snapshot.name
            existing.templateExercises = rows
            existing.executionBlocks = blocks
            existing.preWorkoutMobilityRoutine = preID.flatMap { routineByID[$0] }
            existing.postWorkoutMobilityRoutine = postID.flatMap { routineByID[$0] }
            existing.isArchived = false
        } else {
            let template = WorkoutTemplate(
                name: snapshot.name, exercises: [], templateExercises: rows,
                preWorkoutMobilityRoutine: preID.flatMap { routineByID[$0] },
                postWorkoutMobilityRoutine: postID.flatMap { routineByID[$0] }
            )
            template.id = targetID
            template.executionBlocks = blocks
            context.insert(template)
        }
    }

    private static func materializeRepeatingPlan(
        _ snapshot: PortableRepeatingPlanSnapshot,
        targetID: UUID,
        updateExisting: Bool,
        copiedIDs: [UUID: UUID],
        using context: ModelContext
    ) throws {
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let templateByID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        let routines = try context.fetch(FetchDescriptor<MobilityRoutine>())
        let routineByID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let slots = try snapshot.slots.map { row -> RepeatingPlanSlot in
            let templateID = copiedIDs[row.templateID] ?? row.templateID
            guard let template = templateByID[templateID] else {
                throw PortableTrainingPackageImportError.missingDependency(snapshot.id, row.templateID)
            }
            let preID = row.preWorkoutMobilityRoutineID.map { copiedIDs[$0] ?? $0 }
            let postID = row.postWorkoutMobilityRoutineID.map { copiedIDs[$0] ?? $0 }
            let slot = RepeatingPlanSlot(
                orderIndex: row.orderIndex, workoutTemplate: template,
                preWorkoutMobilityRoutine: preID.flatMap { routineByID[$0] },
                postWorkoutMobilityRoutine: postID.flatMap { routineByID[$0] }
            )
            slot.id = updateExisting ? row.id : UUID()
            return slot
        }
        let existingPlan = try context.fetch(FetchDescriptor<RepeatingPlan>(
            predicate: #Predicate { $0.id == targetID }
        )).first
        if updateExisting, let existing = existingPlan {
            existing.name = snapshot.name
            existing.goal = snapshot.goal
            existing.experienceLevel = snapshot.experienceLevel
            existing.requiredEquipment = snapshot.requiredEquipment
            existing.notes = snapshot.notes
            existing.slots = slots
            existing.isArchived = false
            existing.updatedAt = .now
        } else {
            let plan = RepeatingPlan(
                name: snapshot.name, goal: snapshot.goal, experienceLevel: snapshot.experienceLevel,
                requiredEquipment: snapshot.requiredEquipment, notes: snapshot.notes, slots: slots
            )
            plan.id = targetID
            context.insert(plan)
        }
    }

    private static func remapped<T: Codable>(_ value: T, to id: UUID) throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        var object = try JSONSerialization.jsonObject(with: data)
        guard var dictionary = object as? [String: Any] else { throw PortableTrainingPackageImportError.invalidPackage }
        dictionary["id"] = id.uuidString
        object = dictionary
        let remappedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try JSONDecoder().decode(T.self, from: remappedData)
    }
}

#endif
