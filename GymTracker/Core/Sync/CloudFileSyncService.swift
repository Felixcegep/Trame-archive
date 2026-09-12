import Foundation
import Observation
import SwiftData

/// KeePass-style sync of one portable backup file. SwiftData on this iPhone
/// remains the working copy; the linked file is the copy other devices open.
@Observable
@MainActor
final class CloudFileSyncService {
    static let shared = CloudFileSyncService()

    enum Outcome: Equatable, Sendable {
        case unlinked
        case inSync
        case pushed
        case pulled
        case conflict
        case skippedActiveWorkout
        case failed(String)
    }

    enum Request: Equatable, Sendable {
        /// Push or pull when unambiguous. Never overwrite either side on conflict.
        case automatic
        /// Same as automatic, but a conflict is reported to Settings.
        case manual
        case keepThisIPhone
        case useCloudFile
    }

    private let defaults: UserDefaults
    private let linkStore: CloudFileLinkStore
    private let dataSafety: DataSafetyService
    private let fileManager: FileManager

    private(set) var isSyncing = false
    private(set) var lastOutcome: Outcome = .unlinked
    private(set) var lastErrorMessage: String?
    private(set) var linkedRecord: CloudFileLinkRecord?

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.linkStore = CloudFileLinkStore(defaults: defaults)
        self.dataSafety = DataSafetyService(defaults: defaults, fileManager: fileManager)
        self.fileManager = fileManager
        linkedRecord = linkStore.load()
        if linkedRecord == nil {
            lastOutcome = .unlinked
        }
    }

    var isLinked: Bool { linkedRecord != nil }

    func unlink() {
        linkStore.clear()
        linkedRecord = nil
        lastOutcome = .unlinked
        lastErrorMessage = nil
        isSyncing = false
    }

    /// Remembers the Files location. Does not read or write the file yet.
    func link(url: URL) throws {
        let bookmark = try CloudFileBookmark.makeBookmark(for: url)
        let record = CloudFileLinkRecord(
            bookmarkData: bookmark,
            displayName: url.lastPathComponent,
            locationKind: .classify(url: url),
            lastSyncedHash: nil,
            lastSyncedAt: nil
        )
        linkStore.save(record)
        linkedRecord = record
        lastErrorMessage = nil
    }

    func sync(
        from context: ModelContext,
        hasActiveWorkout: Bool,
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem,
        request: Request
    ) async -> Outcome {
        guard isSyncing == false else { return lastOutcome }
        guard linkStore.load() != nil else {
            lastOutcome = .unlinked
            return .unlinked
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let outcome = try await performSync(
                from: context,
                hasActiveWorkout: hasActiveWorkout,
                restTimer: restTimer,
                darkMode: darkMode,
                unitSystem: unitSystem,
                request: request
            )
            lastOutcome = outcome
            if outcome != .failed("") {
                lastErrorMessage = nil
            }
            return outcome
        } catch {
            let message = error.localizedDescription
            lastErrorMessage = message
            lastOutcome = .failed(message)
            return lastOutcome
        }
    }

    private func performSync(
        from context: ModelContext,
        hasActiveWorkout: Bool,
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem,
        request: Request
    ) async throws -> Outcome {
        guard var record = linkStore.load() else { return .unlinked }
        let url = try CloudFileBookmark.resolve(record.bookmarkData)

        let snapshot = try await makeSnapshot(
            from: context,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )
        let localData = try BackupArchiveFileWriter.encode(snapshot)
        let localHash = CloudFileContentHash.sha256Hex(localData)

        let remoteData: Data?
        if CloudFileIO.fileExists(url) {
            let data = try CloudFileIO.read(from: url)
            remoteData = data.isEmpty ? nil : data
        } else {
            remoteData = nil
        }
        let remoteHash = remoteData.map(CloudFileContentHash.sha256Hex)

        var decision = CloudFileReconciler.decide(
            localHash: localHash,
            remoteHash: remoteHash,
            lastSyncedHash: record.lastSyncedHash
        )

        switch request {
        case .keepThisIPhone:
            decision = .push
        case .useCloudFile:
            decision = .pull
        case .automatic, .manual:
            break
        }

        switch decision {
        case .inSync:
            record.lastSyncedHash = localHash
            record.lastSyncedAt = .now
            persist(record)
            return .inSync
        case .push:
            try CloudFileIO.write(localData, to: url)
            dataSafety.recordExportSuccess()
            record.lastSyncedHash = localHash
            record.lastSyncedAt = .now
            persist(record)
            return .pushed
        case .pull:
            guard let remoteData else {
                try CloudFileIO.write(localData, to: url)
                record.lastSyncedHash = localHash
                record.lastSyncedAt = .now
                persist(record)
                return .pushed
            }
            if hasActiveWorkout, request == .automatic || request == .manual {
                return .skippedActiveWorkout
            }
            return try pull(
                remoteData,
                hash: CloudFileContentHash.sha256Hex(remoteData),
                into: context,
                record: record
            )
        case .conflict:
            return .conflict
        }
    }

    private func pull(
        _ remoteData: Data,
        hash: String,
        into context: ModelContext,
        record: CloudFileLinkRecord
    ) throws -> Outcome {
        let backup = try BackupImportService.decodeAndValidate(remoteData)
        try writeRecoveryCopy(of: context)
        let preferences = try BackupImportService.restore(backup, to: context)
        apply(preferences)
        dataSafety.recordRestoreSuccess()
        var updated = record
        updated.lastSyncedHash = hash
        updated.lastSyncedAt = .now
        persist(updated)
        NotificationCenter.default.post(name: .gymDataRestored, object: nil)
        return .pulled
    }

    private func persist(_ record: CloudFileLinkRecord) {
        linkStore.save(record)
        linkedRecord = record
    }

    private func makeSnapshot(
        from context: ModelContext,
        restTimer: Int,
        darkMode: Bool,
        unitSystem: UnitSystem
    ) async throws -> BackupDTO {
        if context.hasChanges {
            return try BackupDTO.create(
                from: context,
                restTimer: restTimer,
                darkMode: darkMode,
                unitSystem: unitSystem
            )
        }
        let snapshotActor = CloudFileBackupSnapshotActor(modelContainer: context.container)
        return try await snapshotActor.makeBackup(
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )
    }

    private func writeRecoveryCopy(of context: ModelContext) throws {
        // Best-effort: a failed recovery write must not block pull, but we try
        // to keep the previous local graph as a file beside the linked copy.
        let restTimer = defaults.integer(forKey: DefaultsKey.restTimer)
        let appearance = AppAppearance(
            rawValue: defaults.string(forKey: DefaultsKey.appearance) ?? ""
        ) ?? .dark
        let darkMode = AppAppearance.resolved(
            stored: appearance,
            legacyDarkMode: defaults.bool(forKey: DefaultsKey.darkMode),
            defaults: defaults
        ) == .dark
        let unitSystem = defaults.unitSystem
        let snapshot = try BackupDTO.create(
            from: context,
            restTimer: restTimer,
            darkMode: darkMode,
            unitSystem: unitSystem
        )
        let data = try BackupArchiveFileWriter.encode(snapshot)
        let directory = try recoveryDirectory()
        let name = "TrameBackup-before-pull.json"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    private func recoveryDirectory() throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("CloudFileRecovery", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func apply(_ preferences: PreferencesDTO) {
        defaults.set(preferences.darkMode, forKey: DefaultsKey.darkMode)
        defaults.set(
            (preferences.darkMode ? AppAppearance.dark : AppAppearance.system).rawValue,
            forKey: DefaultsKey.appearance
        )
        defaults.set(preferences.restTimer, forKey: DefaultsKey.restTimer)
        defaults.setUnitSystem(UnitSystem(rawValue: preferences.unitSystem) ?? .metric)
        if let cadence = preferences.bodyWeightPromptCadence {
            defaults.set(cadence, forKey: DefaultsKey.bodyWeightPromptCadence)
        }
        if let timestamp = preferences.birthdateTimestamp {
            defaults.set(timestamp, forKey: DefaultsKey.caffeineBirthdateTimestamp)
        }
    }

    func applyLaunchFixtureIfNeeded() {
        let arguments = AppLaunchArguments.current
        let wantsLinked = arguments.contains("-ui-testing-cloud-file-linked")
        let wantsConflict = arguments.contains("-ui-testing-cloud-file-conflict")
        guard wantsLinked || wantsConflict else { return }
        guard isLinked == false else {
            lastOutcome = wantsConflict ? .conflict : .inSync
            return
        }

        let url = fileManager.temporaryDirectory.appendingPathComponent("TrameBackup.json")
        let backup = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(
                darkMode: false,
                restTimer: 90,
                unitSystem: UnitSystem.metric.rawValue
            ),
            exercises: [],
            templates: [],
            collections: [],
            workouts: []
        )
        do {
            let data = try BackupArchiveFileWriter.encode(backup)
            try data.write(to: url, options: .atomic)
            try link(url: url)
            let hash = CloudFileContentHash.sha256Hex(data)
            linkStore.updateLastSync(
                hash: hash,
                at: Date(timeIntervalSince1970: 1_750_000_000)
            )
            linkedRecord = linkStore.load()
            lastOutcome = wantsConflict ? .conflict : .inSync
        } catch {
            lastErrorMessage = error.localizedDescription
            lastOutcome = .failed(error.localizedDescription)
        }
    }
}

@ModelActor
private actor CloudFileBackupSnapshotActor {
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
