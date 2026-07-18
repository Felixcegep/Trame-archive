import Foundation

#if !GYMTRACKER_EXTENSION

enum ProgramDefinitionCodecError: Error, Equatable {
    case validation([ProgramValidationIssue])
    case malformed
}

/// Safe, versioned JSON interchange for one program definition. The payload is
/// typed Codable data; it never evaluates executable code or closures.
enum ProgramDefinitionCodec {
    static func encode(_ definition: ProgramDefinitionPayload) throws -> Data {
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionCodecError.validation(issues) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(definition)
    }

    static func decode(_ data: Data) throws -> ProgramDefinitionPayload {
        guard let definition = try? JSONDecoder().decode(ProgramDefinitionPayload.self, from: data) else {
            throw ProgramDefinitionCodecError.malformed
        }
        let issues = ProgramDefinitionValidator.validate(definition)
        guard issues.isEmpty else { throw ProgramDefinitionCodecError.validation(issues) }
        return definition
    }
}

#endif
