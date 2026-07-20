import Foundation

/// Stable notification identities prevent a completed, skipped, or rescheduled
/// occurrence from leaving a stale local notification behind.
enum ReminderIdentifier {
    private static let prefix = "gymtracker."

    static func planWorkout(progressID: UUID) -> String {
        prefix + "plan." + progressID.uuidString
    }

    static func checkIn(day: LocalDay) -> String {
        prefix + "check-in." + day.rawValue
    }

    static func matchesPlanWorkout(_ identifier: String) -> Bool {
        identifier.hasPrefix(prefix + "plan.")
    }

    static func matchesCheckIn(_ identifier: String) -> Bool {
        identifier.hasPrefix(prefix + "check-in.")
    }
}
