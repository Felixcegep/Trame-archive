import Foundation
import SwiftData

#if !GYMTRACKER_EXTENSION

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

nonisolated struct AuthoringCatalogDecodeResult {
    var schemaVersion: Int
    var definitions: [AuthoringProgramDefinition]
    var failures: [Failure]

    nonisolated struct Failure: Equatable {
        var programKey: String
        var message: String
    }
}

nonisolated enum AuthoringProgramCatalogDecoder {
    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> AuthoringCatalogDecodeResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaVersion = root["schemaVersion"] as? Int,
              let programs = root["programDefinitions"] as? [[String: Any]] else {
            throw ProgramLibraryImportError.decodingFailed
        }
        guard schemaVersion <= ProgramLibraryImporter.supportedSchemaVersion else {
            throw ProgramLibraryImportError.unsupportedSchemaVersion(
                found: schemaVersion,
                supported: ProgramLibraryImporter.supportedSchemaVersion
            )
        }

        var definitions: [AuthoringProgramDefinition] = []
        var failures: [AuthoringCatalogDecodeResult.Failure] = []
        for program in programs {
            let programKey = program["programKey"] as? String ?? "<missing-program-key>"
            do {
                let programData = try JSONSerialization.data(withJSONObject: program)
                definitions.append(try decoder.decode(AuthoringProgramDefinition.self, from: programData))
            } catch {
                failures.append(.init(programKey: programKey, message: String(describing: error)))
            }
        }
        return AuthoringCatalogDecodeResult(
            schemaVersion: schemaVersion,
            definitions: definitions,
            failures: failures
        )
    }

    static func bundledData(bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(forResource: "ProgramLibrary", withExtension: "json") else {
            throw ProgramLibraryImportError.decodingFailed
        }
        return try Data(contentsOf: url)
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
        into context: ModelContext,
        saveChanges: Bool = true
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

        if saveChanges { try context.save() }
        return ProgramLibraryImportResult(
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
    ) throws -> ProgramLibraryImportResult {
        try importDocument(decode(data, decoder: decoder), into: context, saveChanges: saveChanges)
    }
}

@MainActor
enum ProgramLibrarySeedData {
    static func seedBundledCatalog(
        in context: ModelContext,
        bundle: Bundle = .main,
        saveChanges: Bool = true
    ) throws -> ProgramLibraryImportResult {
        try seed(AuthoringProgramCatalogDecoder.bundledData(bundle: bundle), in: context, saveChanges: saveChanges)
    }

    static func seed(
        _ data: Data,
        in context: ModelContext,
        saveChanges: Bool = true
    ) throws -> ProgramLibraryImportResult {
        let catalog = try AuthoringProgramCatalogDecoder.decode(data)
        guard catalog.failures.isEmpty else {
            for failure in catalog.failures {
                print("Program catalog decode failed for \(failure.programKey): \(failure.message)")
            }
            throw ProgramLibraryImportError.catalogFailures(catalog.failures.map(\.programKey))
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let exerciseIDsByName = Dictionary(
            exercises.uniquedByNamePreferringSystem().map { ($0.name, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        let payloads = try catalog.definitions.map { try $0.expand(exerciseIDsByName: exerciseIDsByName) }
        for payload in payloads {
            let issues = ProgramDefinitionValidator.validate(payload, isBuiltIn: true)
            guard issues.isEmpty else {
                throw ProgramDefinitionStoreError.invalid(issues)
            }
        }
        return try ProgramLibraryImporter.importDocument(
            ProgramLibraryDocument(libraryVersion: 1, programDefinitions: payloads),
            into: context,
            saveChanges: saveChanges
        )
    }
}

#endif
