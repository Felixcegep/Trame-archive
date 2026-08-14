import Foundation
import OSLog
import SwiftData
import UserNotifications

@MainActor
final class CheckInNotificationScheduler {
    static let shared = CheckInNotificationScheduler()

    private static let categoryIdentifier = "GYMTRACKER_DAILY_CHECK_IN"
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "GymTracker", category: "CheckInNotifications")
    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.checkInRemindersEnabled)
    }

    var reminderHour: Int {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: DefaultsKey.checkInReminderHour) == nil
            ? 20
            : defaults.integer(forKey: DefaultsKey.checkInReminderHour)
    }

    var reminderMinute: Int {
        UserDefaults.standard.integer(forKey: DefaultsKey.checkInReminderMinute)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func enable() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            UserDefaults.standard.set(granted, forKey: DefaultsKey.checkInRemindersEnabled)
            return granted
        } catch {
            UserDefaults.standard.set(false, forKey: DefaultsKey.checkInRemindersEnabled)
            return false
        }
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: DefaultsKey.checkInRemindersEnabled)
        Task { await cancelAllCheckInReminders() }
    }

    func setReminderTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(components.hour ?? 20, forKey: DefaultsKey.checkInReminderHour)
        UserDefaults.standard.set(components.minute ?? 0, forKey: DefaultsKey.checkInReminderMinute)
    }

    func reconcile(using modelContext: ModelContext, now: Date = .now) async {
        guard isEnabled, await authorizationStatus() == .authorized else {
            await cancelAllCheckInReminders()
            return
        }

        let calendar = Calendar.current
        let days = [
            LocalDay(date: now, calendar: calendar),
            LocalDay(date: calendar.date(byAdding: .day, value: 1, to: now) ?? now, calendar: calendar)
        ]
        let todayKey = days[0].rawValue
        let tomorrowKey = days[1].rawValue
        let entries: [DailyLogEntry]
        do {
            entries = try modelContext.fetch(FetchDescriptor<DailyLogEntry>(
                predicate: #Predicate { $0.dayKey == todayKey || $0.dayKey == tomorrowKey }
            ))
        } catch {
            logger.error("Daily check-in reminder fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        let completedDays = Set(entries.map(\.dayKey))
        var requests: [UNNotificationRequest] = []

        for day in days where !completedDays.contains(day.rawValue) {
            guard let date = date(for: day, calendar: calendar), date > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Daily check-in"
            content.body = "How did your day feel?"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = ["dayKey": day.rawValue]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            requests.append(
                UNNotificationRequest(
                    identifier: ReminderIdentifier.checkIn(day: day),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
            )
            break
        }

        await cancelAllCheckInReminders()
        for request in requests {
            do {
                try await center.add(request)
            } catch {
                logger.error("Daily check-in reminder scheduling failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func date(for day: LocalDay, calendar: Calendar) -> Date? {
        let parts = day.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = reminderHour
        components.minute = reminderMinute
        return calendar.date(from: components)
    }

    private func cancelAllCheckInReminders() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter(ReminderIdentifier.matchesCheckIn)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
