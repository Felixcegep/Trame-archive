import Foundation

enum BackupEnvelopeValidator {
    static func validate(_ backup: BackupDTO) throws {
        guard backup.version >= BackupDTO.legacyVersion && backup.version <= BackupDTO.currentVersion else {
            throw BackupValidationError.unsupportedVersion(backup.version)
        }
        guard UnitSystem(rawValue: backup.preferences.unitSystem) != nil,
              backup.preferences.restTimer >= 0
        else {
            throw BackupValidationError.invalidIdentifier("preferences configuration")
        }

        if let issue = TrackingProfileValidator.validate(backup: backup).first {
            throw BackupValidationError.invalidTrackingProfile(issue.message)
        }
    }
}
