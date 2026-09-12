import Foundation

/// Installation-local record of the linked cloud file. The bookmark is not
/// user training data: a restored backup must not silently take over another
/// device's Files location, so this record is excluded from `BackupDTO`.
nonisolated struct CloudFileLinkRecord: Codable, Equatable, Sendable {
    var bookmarkData: Data
    var displayName: String
    var locationKind: CloudFileLocationKind
    var lastSyncedHash: String?
    var lastSyncedAt: Date?
}

nonisolated struct CloudFileLinkStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = DefaultsKey.cloudFileLinkRecord
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> CloudFileLinkRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CloudFileLinkRecord.self, from: data)
    }

    func save(_ record: CloudFileLinkRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    func updateLastSync(hash: String, at date: Date = .now) {
        guard var record = load() else { return }
        record.lastSyncedHash = hash
        record.lastSyncedAt = date
        save(record)
    }
}
