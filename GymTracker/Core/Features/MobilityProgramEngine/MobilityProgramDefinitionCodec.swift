import Foundation

#if !GYMTRACKER_EXTENSION

enum MobilityProgramDefinitionCodecError: Error, Equatable {
    case validation([MobilityProgramValidationIssue])
    case malformed
}

/// Safe, versioned JSON interchange for one mobility program definition. The
/// payload is typed Codable data; it never evaluates executable code or
/// closures. Mirrors `ProgramDefinitionCodec` exactly so the two definition
/// graphs decode/encode the same way.
enum MobilityProgramDefinitionCodec {
    static func encode(_ definition: MobilityProgramDefinitionPayload) throws -> Data {
        let issues = MobilityProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw MobilityProgramDefinitionCodecError.validation(issues) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(definition)
    }

    static func decode(_ data: Data) throws -> MobilityProgramDefinitionPayload {
        guard let definition = try? JSONDecoder().decode(MobilityProgramDefinitionPayload.self, from: data) else {
            throw MobilityProgramDefinitionCodecError.malformed
        }
        let issues = MobilityProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw MobilityProgramDefinitionCodecError.validation(issues) }
        return definition
    }
}

#endif
