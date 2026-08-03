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

@MainActor
enum MobilityProgramLibrarySeedData {
    /// Bundled mobility program catalogue, mirroring `ProgramLibrarySeedData`.
    /// No mobility programs are authored yet — the bundled JSON resource is
    /// intentionally absent until a later slice ships the first one. An
    /// absent resource is not a failure: it seeds zero programs, exactly like
    /// decoding an empty catalogue, which keeps this path idempotent from day
    /// one and requires no change when the first program is added, only a
    /// new bundled `MobilityProgramLibrary.json`.
    static func seedBundledCatalog(
        in context: ModelContext,
        bundle: Bundle = .main,
        saveChanges: Bool = true
    ) throws -> MobilityProgramLibraryImportResult {
        guard let url = bundle.url(forResource: "MobilityProgramLibrary", withExtension: "json") else {
            return MobilityProgramLibraryImportResult(importedProgramKeys: [], skippedPrograms: [])
        }
        let data = try Data(contentsOf: url)
        return try MobilityProgramLibraryImporter.importDocument(
            try MobilityProgramLibraryImporter.decode(data),
            into: context,
            saveChanges: saveChanges
        )
    }
}

#endif
