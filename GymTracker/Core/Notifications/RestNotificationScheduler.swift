import Foundation
import OSLog
import UserNotifications

/// Tells a lifter their rest is over when the app is not on screen.
///
/// Rest is the one interval where the phone is most likely to be pocketed or
/// face-down on a bench, and it was the app's largest silent gap: the deadline
/// was known to the millisecond and nothing announced it. The in-app haptic and
/// announcement cover the foreground case; this covers the other one.
///
/// **It never asks for permission.** The app already requests notification
/// authorization for plan and check-in reminders, and interrupting a first
/// workout with a system prompt would cost more than this feature is worth.
/// When authorization has not already been granted, rest notifications simply
/// do not happen — the visible, spoken, and tactile channels still do.
///
/// Scheduled on backgrounding and cancelled on foregrounding, which is also
/// what keeps it from duplicating anything: a notification can only fire while
/// the app is away, so it can never arrive alongside the in-app feedback, and
/// the Live Activity is a passive display that does not alert.
@MainActor
final class RestNotificationScheduler {
    static let shared = RestNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "GymTracker", category: "RestNotifications")
    private init() {}

    /// Schedules the reminder for `restEndDate`, replacing any pending one.
    ///
    /// Silently does nothing when authorization was never granted, when the
    /// deadline has already passed, or when there is no rest running.
    func schedule(restEndDate: Date?, nextSetDescription: String?, now: Date = .now) async {
        await cancel()

        guard let restEndDate else { return }
        let remaining = restEndDate.timeIntervalSince(now)
        // Under a second there is nothing useful left to schedule, and
        // UNTimeIntervalNotificationTrigger rejects a non-positive interval.
        guard remaining >= 1 else { return }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Rest complete")
        content.body = nextSetDescription ?? String(localized: "Time for your next set.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: ReminderIdentifier.restComplete,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Rest notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Removes the pending reminder. Safe to call when none exists, which is
    /// why every path that ends or changes a rest period can call it blindly:
    /// returning to the app, skipping, pausing, extending, completing the
    /// workout, or discarding it.
    func cancel() async {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderIdentifier.restComplete])
        center.removeDeliveredNotifications(withIdentifiers: [ReminderIdentifier.restComplete])
    }
}
