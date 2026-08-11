import CryptoKit
import Foundation

#if !GYMTRACKER_EXTENSION

/// The user's package selection is intentionally value-only. SwiftData
/// objects are converted to sources before assembly, so the package builder
/// remains deterministic and cannot mutate local definitions or history.
struct PortableTrainingPackageSelection: Equatable {
    var componentIDs: Set<UUID>

    init(componentIDs: Set<UUID> = []) {
        self.componentIDs = componentIDs
    }
}

struct PortableTrainingAssemblySource: Equatable, Hashable {
    let componentID: UUID
    let contentID: UUID
    let kind: PortableTrainingComponentKind
    let name: String
    let contentVersion: Int
    let payload: Data
    let dependencies: [PortableTrainingDependencyDescriptor]

    init(
        componentID: UUID,
        contentID: UUID = UUID(),
        kind: PortableTrainingComponentKind,
        name: String,
        contentVersion: Int = 1,
        payload: Data,
        dependencies: [PortableTrainingDependencyDescriptor] = []
    ) {
        self.componentID = componentID
        self.contentID = contentID
        self.kind = kind
        self.name = name
        self.contentVersion = contentVersion
        self.payload = payload
        self.dependencies = dependencies
    }
}

enum PortableTrainingPackageAssemblyError: Error, Equatable {
    case noComponentsSelected
    case selectedComponentUnavailable(UUID)
    case duplicateDependency(UUID)
    case invalidSource(UUID)
}

/// Assembles selected local definitions and their declared dependencies into
/// the existing package/checksum contract. It never includes performed
/// workouts, active runs, progression receipts, or backup data.
enum PortableTrainingPackageAssemblyProjection {
    static func assemble(
        selection: PortableTrainingPackageSelection,
        sources: [PortableTrainingAssemblySource],
        author: PortableTrainingAuthor,
        provenance: PortableTrainingProvenance,
        compatibility: PortableTrainingCompatibility
    ) throws -> PortableTrainingPackage {
        guard selection.componentIDs.isEmpty == false else {
            throw PortableTrainingPackageAssemblyError.noComponentsSelected
        }

        let sourceByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.componentID, $0) })
        let selected = try selection.componentIDs
            .sorted { $0.uuidString < $1.uuidString }
            .enumerated()
            .map { order, id -> PortableTrainingComponentDescriptor in
                guard let source = sourceByID[id] else {
                    throw PortableTrainingPackageAssemblyError.selectedComponentUnavailable(id)
                }
                guard source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                      source.contentVersion > 0,
                      source.payload.isEmpty == false
                else {
                    throw PortableTrainingPackageAssemblyError.invalidSource(id)
                }
                return PortableTrainingComponentDescriptor(
                    componentID: source.componentID,
                    contentID: source.contentID,
                    kind: source.kind,
                    name: source.name,
                    contentVersion: source.contentVersion,
                    selectionOrder: order,
                    dependencyIDs: source.dependencies.map(\.dependencyID).sorted { $0.uuidString < $1.uuidString },
                    payload: source.payload
                )
            }

        var dependenciesByID: [UUID: PortableTrainingDependencyDescriptor] = [:]
        for source in selected.compactMap({ sourceByID[$0.componentID] }) {
            for dependency in source.dependencies {
                if let existing = dependenciesByID[dependency.dependencyID], existing != dependency {
                    throw PortableTrainingPackageAssemblyError.duplicateDependency(dependency.dependencyID)
                }
                dependenciesByID[dependency.dependencyID] = dependency
            }
        }

        let selectedIDs = Set(selected.map(\.componentID))
        let dependencies = dependenciesByID.values
            .filter { !selectedIDs.contains($0.dependencyID) }
            .sorted {
                if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.dependencyID.uuidString < $1.dependencyID.uuidString
            }

        let seed = selected
            .map { "\($0.componentID.uuidString)|\($0.contentID.uuidString)|\($0.payload.base64EncodedString())" }
            .joined(separator: "\n")
        return PortableTrainingPackage(
            packageID: stableUUID(seed: "package|\(seed)"),
            contentID: stableUUID(seed: "content|\(seed)"),
            author: author,
            provenance: provenance,
            compatibility: compatibility,
            components: selected,
            dependencies: dependencies
        )
    }

    static func source(
        record: ProgramDefinitionRecord,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> PortableTrainingAssemblySource {
        let payload = try record.payload(decoder: decoder)
        let data = try ProgramDefinitionCodec.encode(payload)
        let dependencyIDs = payload.blocks
            .flatMap(\.weeks)
            .flatMap(\.workouts)
            .flatMap(\.plannedExercises)
            .flatMap { exercise in
                [exercise.exerciseID] + exercise.alternativeExerciseIDs + (exercise.variationExerciseIDs ?? [])
            }
        return PortableTrainingAssemblySource(
            componentID: record.id,
            contentID: payload.id,
            kind: .planDefinition,
            name: record.name,
            contentVersion: max(record.templateVersion, payload.templateVersion),
            payload: data,
            dependencies: dependencyDescriptors(
                ids: dependencyIDs,
                kind: .exerciseDefinition,
                names: [:]
            )
        )
    }

    static func source(
        record: MobilityProgramDefinitionRecord,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> PortableTrainingAssemblySource {
        let payload = try record.payload(decoder: decoder)
        let data = try MobilityProgramDefinitionCodec.encode(payload)
        let dependencyIDs = payload.blocks
            .flatMap(\.weeks)
            .flatMap(\.sessions)
            .flatMap { $0.recipe.occurrences }
            .map(\.mobilityDefinitionID)
        return PortableTrainingAssemblySource(
            componentID: record.id,
            contentID: payload.id,
            kind: .mobilityProgram,
            name: record.name,
            contentVersion: max(record.templateVersion, payload.templateVersion),
            payload: data,
            dependencies: dependencyDescriptors(
                ids: dependencyIDs,
                kind: .mobilityRoutine,
                names: [:]
            )
        )
    }

    static func source(template: WorkoutTemplate) throws -> PortableTrainingAssemblySource {
        let payload = PortableWorkoutTemplateSnapshot(
            id: template.id,
            name: template.name,
            exercises: template.orderedTemplateExercises.map {
                .init(
                    id: $0.exercise.id,
                    name: $0.exercise.name,
                    progressionKey: $0.progressionKey,
                    orderIndex: $0.orderIndex,
                    targetSets: $0.targetSets,
                    repRangeMinimum: $0.repRangeMinimum,
                    repRangeMaximum: $0.repRangeMaximum,
                    restSeconds: $0.restSeconds,
                    targetRPE: $0.targetRPE,
                    targetRIR: $0.targetRIR,
                    notes: $0.notes,
                    trackingTypeOverrideRaw: $0.trackingTypeOverrideRaw,
                    stimulusRaw: $0.stimulusRaw,
                    progressionRule: $0.progressionRule,
                    supersetGroupID: $0.supersetGroupID,
                    executionBlockID: $0.executionBlockID,
                    executionBlockComponentOrder: $0.executionBlockComponentOrder
                )
            },
            executionBlocks: template.orderedExecutionBlocks.map {
                .init(
                    id: $0.id,
                    orderIndex: $0.orderIndex,
                    kind: $0.kind,
                    name: $0.name,
                    targetRounds: $0.targetRounds,
                    isSharedLoad: $0.isSharedLoad,
                    restSeconds: $0.restSeconds,
                    clockMode: $0.clockMode,
                    prescribedDurationSeconds: $0.prescribedDurationSeconds,
                    timeCapSeconds: $0.timeCapSeconds,
                    intervalSeconds: $0.intervalSeconds,
                    scoreKind: $0.scoreKind,
                    repetitionScheme: $0.repetitionScheme,
                    repetitionStart: $0.repetitionStart,
                    repetitionEnd: $0.repetitionEnd,
                    repetitionStep: $0.repetitionStep
                )
            },
            preWorkoutMobilityRoutineID: template.preWorkoutMobilityRoutine?.id,
            postWorkoutMobilityRoutineID: template.postWorkoutMobilityRoutine?.id
        )
        let data = try sortedJSONEncoder.encode(payload)
        let exerciseDependencies = template.orderedTemplateExercises.map {
            PortableTrainingDependencyDescriptor(
                dependencyID: $0.exercise.id,
                kind: .exerciseDefinition,
                name: $0.exercise.name,
                minimumContentVersion: 1,
                isRequired: true
            )
        }
        let mobilityDependencies = [template.preWorkoutMobilityRoutine, template.postWorkoutMobilityRoutine]
            .compactMap { $0 }
            .map {
                PortableTrainingDependencyDescriptor(
                    dependencyID: $0.id,
                    kind: .mobilityRoutine,
                    name: $0.name,
                    minimumContentVersion: 1,
                    isRequired: true
                )
            }
        return PortableTrainingAssemblySource(
            componentID: template.id,
            contentID: template.id,
            kind: .workoutTemplate,
            name: template.name,
            payload: data,
            dependencies: uniqueDependencies(exerciseDependencies + mobilityDependencies)
        )
    }

    static func source(repeatingPlan: RepeatingPlan) throws -> PortableTrainingAssemblySource {
        let payload = PortableRepeatingPlanSnapshot(
            id: repeatingPlan.id,
            name: repeatingPlan.name,
            goal: repeatingPlan.goal,
            experienceLevel: repeatingPlan.experienceLevel,
            requiredEquipment: repeatingPlan.requiredEquipment,
            notes: repeatingPlan.notes,
            slots: repeatingPlan.orderedSlots.map {
                .init(
                    id: $0.id,
                    orderIndex: $0.orderIndex,
                    templateID: $0.templateIDSnapshot,
                    templateName: $0.templateNameSnapshot,
                    preWorkoutMobilityRoutineID: $0.preWorkoutMobilityRoutineIDSnapshot,
                    preWorkoutMobilityRoutineName: $0.preWorkoutMobilityRoutineNameSnapshot,
                    postWorkoutMobilityRoutineID: $0.postWorkoutMobilityRoutineIDSnapshot,
                    postWorkoutMobilityRoutineName: $0.postWorkoutMobilityRoutineNameSnapshot
                )
            }
        )
        let data = try sortedJSONEncoder.encode(payload)
        var dependencies: [PortableTrainingDependencyDescriptor] = []
        for slot in repeatingPlan.orderedSlots {
            dependencies.append(.init(
                dependencyID: slot.templateIDSnapshot,
                kind: .workoutTemplate,
                name: slot.templateNameSnapshot,
                minimumContentVersion: 1,
                isRequired: true
            ))
            if let id = slot.preWorkoutMobilityRoutineIDSnapshot,
               let name = slot.preWorkoutMobilityRoutineNameSnapshot {
                dependencies.append(.init(dependencyID: id, kind: .mobilityRoutine, name: name, minimumContentVersion: 1, isRequired: true))
            }
            if let id = slot.postWorkoutMobilityRoutineIDSnapshot,
               let name = slot.postWorkoutMobilityRoutineNameSnapshot {
                dependencies.append(.init(dependencyID: id, kind: .mobilityRoutine, name: name, minimumContentVersion: 1, isRequired: true))
            }
        }
        return PortableTrainingAssemblySource(
            componentID: repeatingPlan.id,
            contentID: repeatingPlan.id,
            kind: .repeatingPlan,
            name: repeatingPlan.name,
            payload: data,
            dependencies: uniqueDependencies(dependencies)
        )
    }

    private static func dependencyDescriptors(
        ids: [UUID],
        kind: PortableTrainingComponentKind,
        names: [UUID: String]
    ) -> [PortableTrainingDependencyDescriptor] {
        uniqueDependencies(ids.map {
            PortableTrainingDependencyDescriptor(
                dependencyID: $0,
                kind: kind,
                name: names[$0] ?? $0.uuidString,
                minimumContentVersion: 1,
                isRequired: true
            )
        })
    }

    private static func uniqueDependencies(
        _ dependencies: [PortableTrainingDependencyDescriptor]
    ) -> [PortableTrainingDependencyDescriptor] {
        var byID: [UUID: PortableTrainingDependencyDescriptor] = [:]
        for dependency in dependencies {
            byID[dependency.dependencyID] = dependency
        }
        return byID.values.sorted { $0.dependencyID.uuidString < $1.dependencyID.uuidString }
    }

    private static let sortedJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static func stableUUID(seed: String) -> UUID {
        let hex = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        let value = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-4\(hex.dropFirst(13).prefix(3))-8\(hex.dropFirst(16).prefix(3))-\(hex.dropFirst(19).prefix(12))"
        return UUID(uuidString: value)!
    }
}

struct PortableWorkoutTemplateSnapshot: Codable, Hashable {
    struct Exercise: Codable, Hashable {
        let id: UUID
        let name: String
        let progressionKey: String
        let orderIndex: Int
        let targetSets: Int
        let repRangeMinimum: Int
        let repRangeMaximum: Int
        let restSeconds: Int
        let targetRPE: Double?
        let targetRIR: Int?
        let notes: String?
        let trackingTypeOverrideRaw: String?
        let stimulusRaw: String?
        let progressionRule: ProgressionRule
        let supersetGroupID: UUID?
        let executionBlockID: UUID?
        let executionBlockComponentOrder: Int?
    }

    struct Block: Codable, Hashable {
        let id: UUID
        let orderIndex: Int
        let kind: ExerciseBlockKind
        let name: String?
        let targetRounds: Int?
        let isSharedLoad: Bool
        let restSeconds: Int?
        let clockMode: BlockClockMode
        let prescribedDurationSeconds: Int?
        let timeCapSeconds: Int?
        let intervalSeconds: Int?
        let scoreKind: BlockScoreKind
        let repetitionScheme: BlockRepetitionScheme
        let repetitionStart: Int?
        let repetitionEnd: Int?
        let repetitionStep: Int?
    }

    let id: UUID
    let name: String
    let exercises: [Exercise]
    let executionBlocks: [Block]
    let preWorkoutMobilityRoutineID: UUID?
    let postWorkoutMobilityRoutineID: UUID?
}

struct PortableRepeatingPlanSnapshot: Codable, Hashable {
    struct Slot: Codable, Hashable {
        let id: UUID
        let orderIndex: Int
        let templateID: UUID
        let templateName: String
        let preWorkoutMobilityRoutineID: UUID?
        let preWorkoutMobilityRoutineName: String?
        let postWorkoutMobilityRoutineID: UUID?
        let postWorkoutMobilityRoutineName: String?
    }

    let id: UUID
    let name: String
    let goal: PlanGoal
    let experienceLevel: PlanExperienceLevel
    let requiredEquipment: [EquipmentType]
    let notes: String?
    let slots: [Slot]
}

#endif
