import Foundation

/// WidgetKit's extension target intentionally links only the small shared
/// snapshot surface. These values keep widget layouts on named tokens without
/// requiring the app's SwiftUI component graph in the extension.
enum WidgetLayout {
    static let compactSpacing: CGFloat = 2
    static let contentSpacing: CGFloat = 4
}

/// A Codable display projection written by the app process and read by the
/// widget extension process. Mirrors the existing Live Activity pattern
/// (`LiveActivityProjection`/`LiveActivityManager`): the app owns SwiftData
/// and pushes a small rendered snapshot; the extension never opens the store.
struct WidgetSnapshot: Codable, Sendable {
    var generatedAt: Date
    var today: TodayWidgetData
    var weeklyVolume: WeeklyVolumeWidgetData
    var caffeine: CaffeineWidgetData
    var creatine: CreatineWidgetData
    /// Optional so snapshots written before the mobility widget was shipped
    /// remain readable by an already-installed extension.
    var mobility: MobilityWidgetData?
}

struct TodayWidgetData: Codable, Sendable {
    enum State: String, Codable, Sendable {
        case activeWorkout
        case scheduledWorkout
        case noWorkout
    }

    var state: State
    var title: String
    var completedSetCount: Int
    var totalSetCount: Int
    var currentExerciseName: String?
}

struct WeeklyVolumeWidgetData: Codable, Sendable {
    var completedWorkoutCount: Int
    var workingSetCount: Int
    var loadVolume: Double?
    /// Plain unit symbol ("kg"/"lbs"), deliberately decoupled from
    /// `WeightType`'s own Codable shape so this snapshot never breaks if that
    /// enum changes.
    var unitSymbol: String?
}

struct CaffeineWidgetData: Codable, Sendable {
    var loggedMilligrams: Double
    /// Nil when `CaffeineGuidance` can't produce a flat reference (e.g. needs
    /// body weight, or not recommended under 14) — never coerced to zero.
    var referenceMilligrams: Double?
}

struct CreatineWidgetData: Codable, Sendable {
    var isConfirmed: Bool
}

struct MobilityWidgetData: Codable, Sendable, Equatable {
    enum State: String, Codable, Sendable {
        case activeSession
        case latestCompleted
        case noSession
    }

    var state: State
    var title: String
    var currentMovementName: String?
    var completedEntryCount: Int
    var totalEntryCount: Int
    var completedSessionCountThisWeek: Int
    /// Exact action identity. Optional for backward compatibility and absent
    /// whenever the projection is not an actionable active node.
    var sessionID: UUID? = nil
    var currentEntryID: UUID? = nil
    var currentEntryNeedsRepetitions: Bool? = nil

    static let placeholder = MobilityWidgetData(
        state: .noSession,
        title: "",
        currentMovementName: nil,
        completedEntryCount: 0,
        totalEntryCount: 0,
        completedSessionCountThisWeek: 0
    )
}

struct MobilityWidgetCommand: Codable, Equatable, Sendable {
    let commandID: UUID
    let sessionID: UUID
    let entryID: UUID
    let createdAt: Date
}

enum MobilityWidgetCommandStore {
    private static let fileName = "mobility-widget-command.json"

    static func submit(_ command: MobilityWidgetCommand) throws {
        guard let url = commandURL else { throw WidgetSharedStoreError.containerUnavailable }
        let data = try JSONEncoder().encode(command)
        try data.write(to: url, options: .atomic)
    }

    static func pending() -> MobilityWidgetCommand? {
        guard let url = commandURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MobilityWidgetCommand.self, from: data)
    }

    static func acknowledge(commandID: UUID) throws {
        guard pending()?.commandID == commandID, let url = commandURL else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static var commandURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}

enum MobilityWidgetActionPolicy {
    /// Matches the app-side command-consumption window so the widget never
    /// advertises an action that the authoritative mutation path will refuse.
    static let freshnessInterval: TimeInterval = 5 * 60

    static func canOfferCompletion(data: MobilityWidgetData, generatedAt: Date, now: Date) -> Bool {
        data.state == .activeSession
            && data.sessionID != nil
            && data.currentEntryID != nil
            && data.currentEntryNeedsRepetitions != true
            && generatedAt <= now
            && now.timeIntervalSince(generatedAt) <= freshnessInterval
    }
}

/// Reads/writes the shared snapshot file in the App Group container. Both the
/// app and the widget extension link this file; only the app ever calls
/// `write`.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.felix.GymTracker"
    private static let fileName = "widget-snapshot.json"

    static func write(_ snapshot: WidgetSnapshot) throws {
        guard let url = snapshotURL else { throw WidgetSharedStoreError.containerUnavailable }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static func read() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}

private enum WidgetSharedStoreError: Error {
    case containerUnavailable
}
