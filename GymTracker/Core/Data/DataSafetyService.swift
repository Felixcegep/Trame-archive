//
//  DataSafetyService.swift
//  GymTracker
//

import Foundation
import SwiftData

/// Confidence metadata describing local data safety and backup status.
struct DataSafetyMetadata: Equatable, Sendable, Codable {
    /// Human-readable storage location description (e.g., "This iPhone").
    let storageLocationDescription: String

    /// Whether data is stored locally on device without mandatory cloud sync.
    let isStoredLocally: Bool

    /// Timestamp of when a backup file was last exported, if ever.
    let lastExportDate: Date?

    /// Timestamp of when a backup was last successfully restored on this device, if ever.
    let lastRestoreDate: Date?

    /// Portable backup schema format string (e.g. "v27").
    let backupFormatVersion: String

    /// Portable backup format schema version integer (e.g. 27).
    let formatVersionNumber: Int

    /// Whether restore execution has been tested/proven on this device.
    var hasRestoredBeenTested: Bool {
        lastRestoreDate != nil
    }

    /// Whether a backup export has been performed at least once.
    var hasExported: Bool {
        lastExportDate != nil
    }

    init(
        storageLocationDescription: String = String(localized: "This iPhone"),
        isStoredLocally: Bool = true,
        lastExportDate: Date? = nil,
        lastRestoreDate: Date? = nil,
        backupFormatVersion: String = "v\(BackupDTO.currentVersion)",
        formatVersionNumber: Int = BackupDTO.currentVersion
    ) {
        self.storageLocationDescription = storageLocationDescription
        self.isStoredLocally = isStoredLocally
        self.lastExportDate = lastExportDate
        self.lastRestoreDate = lastRestoreDate
        self.backupFormatVersion = backupFormatVersion
        self.formatVersionNumber = formatVersionNumber
    }

    /// Returns a human-readable string for the last export date.
    func formattedLastExportDate(formatter: DateFormatter? = nil) -> String {
        guard let lastExportDate else { return String(localized: "Never") }
        if let formatter {
            return formatter.string(from: lastExportDate)
        }
        return lastExportDate.formatted(.dateTime.year().month(.abbreviated).day())
    }

    /// Returns a human-readable string for restore verification status.
    func restoreTestedDescription(formatter: DateFormatter? = nil) -> String {
        guard let lastRestoreDate else { return String(localized: "Not yet") }
        if let formatter {
            return formatter.string(from: lastRestoreDate)
        }
        return lastRestoreDate.formatted(.dateTime.year().month(.abbreviated).day())
    }
}

/// Result payload returned from completing a data backup export action.
struct DataSafetyExportResult: Sendable {
    let backup: BackupDTO
    let fileURL: URL
    let data: Data
    let exportDate: Date

    init(backup: BackupDTO, fileURL: URL, data: Data, exportDate: Date) {
        self.backup = backup
        self.fileURL = fileURL
        self.data = data
        self.exportDate = exportDate
    }
}

/// Service exposing data-fetching logic for data safety metadata and backup export operations.
struct DataSafetyService: Sendable {
    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    /// Fetches the current data safety and backup confidence metadata.
    func fetchMetadata() -> DataSafetyMetadata {
        let exportTimestamp = defaults.object(forKey: DefaultsKey.lastBackupExportTimestamp) as? Double
        let restoreTimestamp = defaults.object(forKey: DefaultsKey.lastBackupRestoreTimestamp) as? Double

        let lastExportDate = exportTimestamp.map { Date(timeIntervalSince1970: $0) }
        let lastRestoreDate = restoreTimestamp.map { Date(timeIntervalSince1970: $0) }

        return DataSafetyMetadata(
            storageLocationDescription: String(localized: "This iPhone"),
            isStoredLocally: true,
            lastExportDate: lastExportDate,
            lastRestoreDate: lastRestoreDate,
            backupFormatVersion: "v\(BackupDTO.currentVersion)",
            formatVersionNumber: BackupDTO.currentVersion
        )
    }

    /// Static convenience accessor to fetch data safety metadata.
    static func fetchMetadata(defaults: UserDefaults = .standard) -> DataSafetyMetadata {
        DataSafetyService(defaults: defaults).fetchMetadata()
    }

    /// Records a successful export timestamp in user defaults.
    func recordExportSuccess(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: DefaultsKey.lastBackupExportTimestamp)
    }

    /// Static convenience accessor to record export success.
    static func recordExportSuccess(at date: Date = .now, defaults: UserDefaults = .standard) {
        DataSafetyService(defaults: defaults).recordExportSuccess(at: date)
    }

    /// Records a successful restore timestamp in user defaults.
    func recordRestoreSuccess(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: DefaultsKey.lastBackupRestoreTimestamp)
    }

    /// Static convenience accessor to record restore success.
    static func recordRestoreSuccess(at date: Date = .now, defaults: UserDefaults = .standard) {
        DataSafetyService(defaults: defaults).recordRestoreSuccess(at: date)
    }

    /// Performs a data export operation, serializing the database graph into a JSON backup payload,
    /// saving it atomically to a temporary file, and recording the export timestamp.
    @MainActor
    func exportData(
        from context: ModelContext,
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem
    ) async throws -> DataSafetyExportResult {
        let backup = try BackupDTO.create(
            from: context,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )

        let targetDir = fileManager.temporaryDirectory
        let (fileURL, data) = try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(backup)
            let outputURL = targetDir.appendingPathComponent("TrameBackup.json")
            try encodedData.write(to: outputURL, options: .atomic)
            return (outputURL, encodedData)
        }.value

        let exportDate = Date.now
        recordExportSuccess(at: exportDate)

        return DataSafetyExportResult(
            backup: backup,
            fileURL: fileURL,
            data: data,
            exportDate: exportDate
        )
    }

    /// Static convenience accessor to execute export action.
    @MainActor
    static func exportData(
        from context: ModelContext,
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) async throws -> DataSafetyExportResult {
        try await DataSafetyService(defaults: defaults, fileManager: fileManager).exportData(
            from: context,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )
    }
}

/// Convenience alias matching alternative naming convention.
typealias GymBackupService = DataSafetyService
