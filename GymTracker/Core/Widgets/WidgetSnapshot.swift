import Foundation

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

/// Reads/writes the shared snapshot file in the App Group container. Both the
/// app and the widget extension link this file; only the app ever calls
/// `write`.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.felix.GymTracker"
    private static let fileName = "widget-snapshot.json"

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
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
