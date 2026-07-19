import Foundation
import CryptoKit

#if !GYMTRACKER_EXTENSION

nonisolated enum ProgramLibraryImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decodingFailed
    case invalidSetGroup(String)
    case missingExercise(String)
    case missingRuleSet(String)
    case unsupportedRuleConstruct(String)
    case catalogFailures([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return "Program library schema version \(found) is newer than supported version \(supported)."
        case .decodingFailed:
            return "The program library could not be decoded."
        case .invalidSetGroup(let path):
            return "The set group at \(path) must define exactly one repetition prescription."
        case .missingExercise(let name):
            return "The program library references missing exercise \(name)."
        case .missingRuleSet(let name):
            return "The program library references missing rule set \(name)."
        case .unsupportedRuleConstruct(let construct):
            return "The program rule construct \(construct) is not supported by this engine."
        case .catalogFailures(let keys):
            return "The program catalog contains invalid definitions: \(keys.joined(separator: ", "))."
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

#endif
