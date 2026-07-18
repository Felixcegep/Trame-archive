import Foundation
import SwiftData
import CryptoKit

#if !GYMTRACKER_EXTENSION

nonisolated enum ProgramLibraryImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decodingFailed
    case invalidSetGroup(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return "Program library schema version \(found) is newer than supported version \(supported)."
        case .decodingFailed:
            return "The program library could not be decoded."
        case .invalidSetGroup(let path):
            return "The set group at \(path) must define exactly one repetition prescription."
        }
    }
}

nonisolated struct AuthoringLoadDefinition: Codable, Hashable {
    var reference: LoadReferenceKind?
    var of: String?
    var fixed: Double?
    var percent: Double?
    var offset: Double?
    var percentOffset: Double?
    var min: Double?
    var max: Double?
    var round: Double?

    init(
        reference: LoadReferenceKind? = nil,
        of: String? = nil,
        fixed: Double? = nil,
        percent: Double? = nil,
        offset: Double? = nil,
        percentOffset: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        round: Double? = nil
    ) {
        self.reference = reference
        self.of = of
        self.fixed = fixed
        self.percent = percent
        self.offset = offset
        self.percentOffset = percentOffset
        self.min = min
        self.max = max
        self.round = round
    }

    func expand() -> LoadPrescription {
        let kind: LoadReferenceKind
        if fixed != nil {
            kind = .fixedLoad
        } else {
            kind = reference ?? .manual
        }
        return LoadPrescription(
            reference: LoadReference(kind: kind, exposureKey: of),
            fixedValue: fixed,
            percentage: percent,
            absoluteOffset: offset ?? 0,
            percentageOffset: percentOffset,
            minimum: min,
            maximum: max,
            rounding: round.map(LoadRoundingRule.nearestIncrement) ?? .none
        )
    }
}

nonisolated struct AuthoringSetGroupDefinition: Codable, Hashable {
    var count: Int
    var reps: Int?
    var repRange: [Int]?
    var amrap: [Int?]?
    var durationSeconds: Double?
    var load: AuthoringLoadDefinition?
    var role: ProgramSetRole?
    var targetRPE: Double?
    var targetRIR: Int?
    var tempo: String?
    var progressionEligible: Bool?

    init(
        count: Int,
        reps: Int? = nil,
        repRange: [Int]? = nil,
        amrap: [Int?]? = nil,
        durationSeconds: Double? = nil,
        load: AuthoringLoadDefinition? = nil,
        role: ProgramSetRole? = nil,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        tempo: String? = nil,
        progressionEligible: Bool? = nil
    ) {
        self.count = count
        self.reps = reps
        self.repRange = repRange
        self.amrap = amrap
        self.durationSeconds = durationSeconds
        self.load = load
        self.role = role
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.tempo = tempo
        self.progressionEligible = progressionEligible
    }

    func expand(path: String, startingAt orderIndex: Int) throws -> [SetPrescriptionDefinition] {
        let options = [reps != nil, repRange != nil, amrap != nil, durationSeconds != nil]
        guard options.filter({ $0 }).count == 1 else {
            throw ProgramLibraryImportError.invalidSetGroup(path)
        }

        let repetitionPrescription: RepPrescription
        if let reps {
            repetitionPrescription = .fixed(reps)
        } else if let repRange, repRange.count == 2 {
            repetitionPrescription = .range(minimum: repRange[0], maximum: repRange[1])
        } else if let amrap, amrap.count == 2 {
            repetitionPrescription = .amrap(minimum: amrap[0], maximum: amrap[1])
        } else if let durationSeconds {
            repetitionPrescription = .duration(seconds: durationSeconds)
        } else {
            throw ProgramLibraryImportError.invalidSetGroup(path)
        }

        return (0..<max(0, count)).map { offset in
            let setPath = "\(path)/s\(offset)"
            return SetPrescriptionDefinition(
                id: ProgramLibraryDeterministicID.uuid(for: setPath),
                orderIndex: orderIndex + offset,
                role: role ?? (amrap != nil ? .amrap : .working),
                repetitions: repetitionPrescription,
                load: load?.expand() ?? LoadPrescription(),
                targetRPE: targetRPE,
                targetRIR: targetRIR,
                tempo: tempo,
                progressionEligible: progressionEligible ?? true
            )
        }
    }
}

nonisolated enum ProgramLibraryDeterministicID {
    static func uuid(for path: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(path.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
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
