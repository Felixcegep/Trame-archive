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

/// The result of serializing a value-only backup archive. This crosses the
/// export task boundary; it deliberately contains no SwiftData model or model
/// context reference.
nonisolated struct BackupArchiveFile: Sendable {
    let fileURL: URL
    let data: Data
}

/// JSON encoding and file I/O can be substantial for a long training history.
/// Keep it independent from the `ModelContext` snapshot phase so it can run at
/// utility priority without ever touching a SwiftData graph off its actor.
nonisolated enum BackupArchiveFileWriter {
    static func write(_ backup: BackupDTO, in directory: URL) throws -> BackupArchiveFile {
        // An export is a recovery artifact, not merely JSON. Refuse to publish
        // or record success for a value graph the restore path would reject.
        try backup.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let fileURL = directory.appendingPathComponent("TrameBackup.json")
        try data.write(to: fileURL, options: .atomic)
        return BackupArchiveFile(fileURL: fileURL, data: data)
    }
}

/// Owns the read-side SwiftData context used by backup export. Creating a
/// separate context is important: the main UI context can remain responsive
/// while the complete relationship graph is materialized into value-only
/// DTOs. This actor never saves or mutates the store.
@ModelActor
private actor BackupSnapshotActor {
    func makeBackup(
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem
    ) throws -> BackupDTO {
        try BackupDTO.create(
            from: modelContext,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )
    }
}

/// Service exposing data-fetching logic for data safety metadata and backup export operations.
struct DataSafetyService {
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
        unitSystem: UnitSystem,
        selection: BackupExportSelection = .everything
    ) async throws -> DataSafetyExportResult {
        guard selection.isEmpty == false else {
            throw BackupExportError.nothingSelected
        }

        // A second context sees only committed data. Preserve the previous
        // export contract for a caller with pending edits by reading the
        // caller's context in that case; the normal saved-store path moves
        // the expensive graph traversal to the model actor.
        let snapshot: BackupDTO
        if context.hasChanges {
            snapshot = try BackupDTO.create(
                from: context,
                restTimer: restTimer,
                darkMode: darkMode,
                unitSystem: unitSystem
            )
        } else {
            let snapshotActor = BackupSnapshotActor(modelContainer: context.container)
            snapshot = try await snapshotActor.makeBackup(
                restTimer: restTimer,
                darkMode: darkMode,
                unitSystem: unitSystem
            )
        }
        let backup = try snapshot.applying(selection)

        let targetDirectory = fileManager.temporaryDirectory
        let archive = try await Task.detached(priority: .utility) {
            try BackupArchiveFileWriter.write(backup, in: targetDirectory)
        }.value

        let exportDate = Date.now
        recordExportSuccess(at: exportDate)

        return DataSafetyExportResult(
            backup: backup,
            fileURL: archive.fileURL,
            data: archive.data,
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
        selection: BackupExportSelection = .everything,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) async throws -> DataSafetyExportResult {
        try await DataSafetyService(defaults: defaults, fileManager: fileManager).exportData(
            from: context,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem,
            selection: selection
        )
    }
}

/// Convenience alias matching alternative naming convention.
typealias GymBackupService = DataSafetyService
