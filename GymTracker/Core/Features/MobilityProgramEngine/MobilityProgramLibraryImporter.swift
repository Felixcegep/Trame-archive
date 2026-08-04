import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

nonisolated struct MobilityProgramLibraryDocument: Codable, Hashable {
    var schemaVersion: Int
    var libraryVersion: Int
    var programDefinitions: [MobilityProgramDefinitionPayload]

    init(
        schemaVersion: Int = MobilityProgramLibraryImporter.supportedSchemaVersion,
        libraryVersion: Int,
        programDefinitions: [MobilityProgramDefinitionPayload]
    ) {
        self.schemaVersion = schemaVersion
        self.libraryVersion = libraryVersion
        self.programDefinitions = programDefinitions
    }
}

nonisolated struct MobilityProgramLibraryImportResult: Equatable {
    var importedProgramKeys: [String]
    var skippedPrograms: [SkippedProgram]

    nonisolated struct SkippedProgram: Equatable {
        var programKey: String
        var missingCapabilities: Set<String>
    }
}

nonisolated enum MobilityProgramLibraryImportError: Error, Equatable {
    case decodingFailed
    case unsupportedSchemaVersion(found: Int, supported: Int)
}

/// Bundled mobility program catalogue import, mirroring
/// `ProgramLibraryImporter` exactly so the two library formats behave the
/// same way for authors and for the system seed coordinator.
enum MobilityProgramLibraryImporter {
    nonisolated static let supportedSchemaVersion = 1

    nonisolated static func decode(
        _ data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> MobilityProgramLibraryDocument {
        guard let document = try? decoder.decode(MobilityProgramLibraryDocument.self, from: data) else {
            throw MobilityProgramLibraryImportError.decodingFailed
        }
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw MobilityProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }
        return document
    }

    @MainActor
    static func importDocument(
        _ document: MobilityProgramLibraryDocument,
        into context: ModelContext,
        saveChanges: Bool = true
    ) throws -> MobilityProgramLibraryImportResult {
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw MobilityProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        var importedProgramKeys: [String] = []
        var skippedPrograms: [MobilityProgramLibraryImportResult.SkippedProgram] = []

        for payload in document.programDefinitions {
            let missingCapabilities = MobilityEngineCapabilities.missing(from: payload.requiredCapabilities)
            guard missingCapabilities.isEmpty else {
                skippedPrograms.append(.init(programKey: payload.programKey, missingCapabilities: missingCapabilities))
                continue
            }
            _ = try MobilityProgramDefinitionRepository.save(payload, isBuiltIn: true, in: context)
            importedProgramKeys.append(payload.programKey)
        }

        if saveChanges { try context.save() }
        return MobilityProgramLibraryImportResult(
            importedProgramKeys: importedProgramKeys,
            skippedPrograms: skippedPrograms
        )
    }

    @MainActor
    static func importData(
        _ data: Data,
        into context: ModelContext,
        decoder: JSONDecoder = JSONDecoder(),
        saveChanges: Bool = true
    ) throws -> MobilityProgramLibraryImportResult {
        try importDocument(decode(data, decoder: decoder), into: context, saveChanges: saveChanges)
    }
}

nonisolated enum MobilityProgramLibrarySeedError: Error, Equatable {
    /// A program in `MobilityProgramLibraryData` references a movement name
    /// that does not (yet) exist in the live `MobilityDefinition` catalogue.
    /// This can only mean the authored catalogue and the authored program
    /// content have drifted apart; it must never be silently skipped.
    case missingMovement(String)
}

@MainActor
enum MobilityProgramLibrarySeedData {
    /// Bundled mobility program catalogue, mirroring `ProgramLibrarySeedData`
    /// — except a mobility program has no bundled-JSON authoring layer of its
    /// own (unlike `AuthoringProgramDefinition.expand(exerciseIDsByName:)` on
    /// the workout side). `MobilityMovementOccurrenceDefinition
    /// .mobilityDefinitionID` is resolved by `MobilityProgramCompiler` with a
    /// strict dictionary lookup against whatever UUID a device's own
    /// `MobilityDefinition` rows actually carry — and those rows are
    /// per-install (each first-ever seed on a device mints its own random
    /// `id` unless a `SystemSeedRecord` already pins an older one). A static
    /// bundled JSON with hand-written UUID literals can only ever match a
    /// brand-new install; it would silently fail catalogue resolution for
    /// any device that already has these movements seeded from an earlier
    /// build. Building the payloads here in Swift and resolving
    /// `mobilityDefinitionID` by movement *name* against the catalogue this
    /// same transaction just staged (see the call ordering in
    /// `SystemSeedCatalogCoordinator.stageBundledCatalog`) sidesteps that
    /// entirely — exactly the same problem `ProgramLibrarySeedData.seed`
    /// solves for exercises via `exerciseIDsByName`.
    static func seedBundledCatalog(
        in context: ModelContext,
        bundle: Bundle = .main,
        saveChanges: Bool = true
    ) throws -> MobilityProgramLibraryImportResult {
        let definitions = try context.fetch(FetchDescriptor<MobilityDefinition>())
        let movementIDsByName = Dictionary(
            definitions.map { ($0.name, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        let payloads = try MobilityProgramLibraryData.payloads(movementIDsByName: movementIDsByName)
        for payload in payloads {
            let issues = MobilityProgramDefinitionValidator.validate(payload, isBuiltIn: true)
            guard issues.isEmpty else { throw MobilityProgramDefinitionStoreError.invalid(issues) }
        }
        return try MobilityProgramLibraryImporter.importDocument(
            MobilityProgramLibraryDocument(libraryVersion: 1, programDefinitions: payloads),
            into: context,
            saveChanges: saveChanges
        )
    }
}

#endif
