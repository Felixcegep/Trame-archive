import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

nonisolated enum ProgramLibraryImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return "Program library schema version \(found) is newer than supported version \(supported)."
        case .decodingFailed:
            return "The program library could not be decoded."
        }
    }
}

nonisolated struct ProgramLibraryDocument: Codable, Hashable {
    var schemaVersion: Int
    var libraryVersion: Int
    var programDefinitions: [ProgramDefinitionPayload]

    init(
        schemaVersion: Int = ProgramLibraryImporter.supportedSchemaVersion,
        libraryVersion: Int,
        programDefinitions: [ProgramDefinitionPayload]
    ) {
        self.schemaVersion = schemaVersion
        self.libraryVersion = libraryVersion
        self.programDefinitions = programDefinitions
    }
}

nonisolated struct ProgramLibraryImportResult: Equatable {
    var importedProgramKeys: [String]
    var skippedPrograms: [SkippedProgram]

    nonisolated struct SkippedProgram: Equatable {
        var programKey: String
        var missingCapabilities: Set<String>
    }
}

enum ProgramLibraryImporter {
    nonisolated static let supportedSchemaVersion = 1

    nonisolated static func decode(
        _ data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> ProgramLibraryDocument {
        guard let document = try? decoder.decode(ProgramLibraryDocument.self, from: data) else {
            throw ProgramLibraryImportError.decodingFailed
        }
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }
        return document
    }

    @MainActor
    static func importDocument(
        _ document: ProgramLibraryDocument,
        into context: ModelContext
    ) throws -> ProgramLibraryImportResult {
        guard document.schemaVersion <= supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        var importedProgramKeys: [String] = []
        var skippedPrograms: [ProgramLibraryImportResult.SkippedProgram] = []

        for payload in document.programDefinitions {
            let missingCapabilities = EngineCapabilities.missing(from: payload.requiredCapabilities)
            guard missingCapabilities.isEmpty else {
                skippedPrograms.append(.init(
                    programKey: payload.programKey,
                    missingCapabilities: missingCapabilities
                ))
                continue
            }

            _ = try ProgramDefinitionRepository.save(payload, isBuiltIn: true, in: context)
            importedProgramKeys.append(payload.programKey)
        }

        try context.save()
        return ProgramLibraryImportResult(
            importedProgramKeys: importedProgramKeys,
            skippedPrograms: skippedPrograms
        )
    }

    @MainActor
    static func importData(
        _ data: Data,
        into context: ModelContext,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> ProgramLibraryImportResult {
        try importDocument(decode(data, decoder: decoder), into: context)
    }
}

#endif
