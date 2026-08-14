import Foundation

/// Validates mobility domain entities within a backup archive:
/// mobility definitions, routines, items, sessions, entries, results, evidence, and mobility program definitions.
nonisolated enum MobilityBackupValidator {
    static func validate(_ dto: BackupDTO) throws {
        let names = dto.mobilityRoutines.compactMap(\.name)
        let mobilityRoutineNames = Set(names)
        
        if dto.version >= BackupDTO.mobilityLinkageVersion {
            guard mobilityRoutineNames.count == dto.mobilityRoutines.count else {
                let duplicateName = Dictionary(grouping: names, by: \.self)
                    .first(where: { $0.value.count > 1 })?.key ?? "Unknown"
                throw BackupValidationError.duplicateTemplateName(duplicateName)
            }
        }
    }
}
