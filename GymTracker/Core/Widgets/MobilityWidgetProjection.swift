import Foundation

/// Small, deterministic input for the widget snapshot. The extension never
/// sees SwiftData objects; the app maps its model into this value first.
struct MobilityWidgetSessionSnapshot: Equatable, Sendable {
    enum State: String, Sendable {
        case active
        case completed
        case stopped
    }

    let state: State
    let sessionID: UUID
    let title: String
    let currentEntryID: UUID?
    let currentMovementName: String?
    let currentEntryNeedsRepetitions: Bool?
    let completedEntryCount: Int
    let totalEntryCount: Int
    let startTime: Date
}

enum MobilityWidgetProjection {
    static func resolve(
        sessions: [MobilityWidgetSessionSnapshot],
        now: Date,
        calendar: Calendar
    ) -> MobilityWidgetData {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        let completedThisWeek = sessions.filter { session in
            session.state == .completed
                && (weekStart.map { session.startTime >= $0 } ?? true)
                && session.startTime <= now
        }.count

        if let active = sessions
            .filter({ $0.state == .active })
            .max(by: { ($0.startTime, $0.title) < ($1.startTime, $1.title) }) {
            return MobilityWidgetData(
                state: .activeSession,
                title: active.title,
                currentMovementName: active.currentMovementName,
                completedEntryCount: active.completedEntryCount,
                totalEntryCount: active.totalEntryCount,
                completedSessionCountThisWeek: completedThisWeek,
                sessionID: active.sessionID,
                currentEntryID: active.currentEntryID,
                currentEntryNeedsRepetitions: active.currentEntryNeedsRepetitions
            )
        }

        if let latest = sessions
            .filter({ $0.state == .completed })
            .max(by: { ($0.startTime, $0.title) < ($1.startTime, $1.title) }) {
            return MobilityWidgetData(
                state: .latestCompleted,
                title: latest.title,
                currentMovementName: nil,
                completedEntryCount: latest.completedEntryCount,
                totalEntryCount: latest.totalEntryCount,
                completedSessionCountThisWeek: completedThisWeek
            )
        }

        return .placeholder
    }
}
