import Foundation
import SwiftData
import UIKit
import UserNotifications

extension Notification.Name {
    static let planScheduleDidChange = Notification.Name("planScheduleDidChange")
    static let planNotificationOpened = Notification.Name("planNotificationOpened")
}

struct PlanNotificationDestination: Sendable {
    let planID: UUID
    let runID: UUID
    let progressID: UUID
}

@MainActor
final class PlanNotificationScheduler {
    static let shared = PlanNotificationScheduler()

    private static let categoryIdentifier = "GYMTRACKER_PLAN_WORKOUT"

    private let center = UNUserNotificationCenter.current()
    private var reconciliationGeneration = 0
    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.planRemindersEnabled)
    }

    var reminderHour: Int {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: DefaultsKey.planReminderHour) == nil
            ? 9
            : defaults.integer(forKey: DefaultsKey.planReminderHour)
    }

    var reminderMinute: Int {
        UserDefaults.standard.integer(forKey: DefaultsKey.planReminderMinute)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func enable() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            UserDefaults.standard.set(granted, forKey: DefaultsKey.planRemindersEnabled)
            return granted
        } catch {
            UserDefaults.standard.set(false, forKey: DefaultsKey.planRemindersEnabled)
            return false
        }
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: DefaultsKey.planRemindersEnabled)
        Task { await cancelAllPlanReminders() }
    }

    func setReminderTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(components.hour ?? 9, forKey: DefaultsKey.planReminderHour)
        UserDefaults.standard.set(components.minute ?? 0, forKey: DefaultsKey.planReminderMinute)
        NotificationCenter.default.post(name: .planScheduleDidChange, object: nil)
    }

    func reconcile(using modelContext: ModelContext) async {
        reconciliationGeneration += 1
        let generation = reconciliationGeneration
        guard isEnabled, await authorizationStatus() == .authorized else {
            await cancelAllPlanReminders()
            return
        }

        let runs: [PlanRun]
        do {
            runs = try modelContext.fetch(FetchDescriptor<PlanRun>())
        } catch {
            return
        }

        let now = Date.now
        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []

        for run in runs where run.status == .active {
            for progress in run.orderedWorkoutProgress
            where progress.status == .available || progress.status == .upcoming {
                guard let scheduledDate = progress.scheduledDate,
                      let fireDate = calendar.date(
                        bySettingHour: reminderHour,
                        minute: reminderMinute,
                        second: 0,
                        of: scheduledDate
                      ),
                      fireDate > now
                else { continue }

                let content = UNMutableNotificationContent()
                content.title = progress.plannedWorkoutName
                content.body = "Your \(run.sourcePlanName) workout is scheduled for today."
                content.sound = .default
                content.categoryIdentifier = Self.categoryIdentifier
                content.userInfo = [
                    "planID": run.sourcePlanID.uuidString,
                    "runID": run.id.uuidString,
                    "progressID": progress.id.uuidString
                ]

                let dateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                requests.append(
                    UNNotificationRequest(
                        identifier: ReminderIdentifier.planWorkout(progressID: progress.id),
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                    )
                )
            }
        }

        await cancelAllPlanReminders()
        guard generation == reconciliationGeneration else { return }
        for request in requests {
            guard generation == reconciliationGeneration else { return }
            try? await center.add(request)
        }
    }

    private func cancelAllPlanReminders() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter(ReminderIdentifier.matchesPlanWorkout)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

final class GymTrackerNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let planString = info["planID"] as? String,
              let runString = info["runID"] as? String,
              let progressString = info["progressID"] as? String,
              let planID = UUID(uuidString: planString),
              let runID = UUID(uuidString: runString),
              let progressID = UUID(uuidString: progressString)
        else { return }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .planNotificationOpened,
                object: PlanNotificationDestination(planID: planID, runID: runID, progressID: progressID)
            )
        }
    }
}
