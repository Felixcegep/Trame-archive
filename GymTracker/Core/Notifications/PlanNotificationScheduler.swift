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
    let action: PlanNotificationAction

    init(
        planID: UUID,
        runID: UUID,
        progressID: UUID,
        action: PlanNotificationAction = .openPlan
    ) {
        self.planID = planID
        self.runID = runID
        self.progressID = progressID
        self.action = action
    }

    init?(userInfo: [AnyHashable: Any], action: PlanNotificationAction = .openPlan) {
        guard let planString = userInfo["planID"] as? String,
              let runString = userInfo["runID"] as? String,
              let progressString = userInfo["progressID"] as? String,
              let planID = UUID(uuidString: planString),
              let runID = UUID(uuidString: runString),
              let progressID = UUID(uuidString: progressString)
        else {
            return nil
        }
        self.init(planID: planID, runID: runID, progressID: progressID, action: action)
    }
}

enum PlanNotificationAction: Sendable, Equatable {
    case openPlan
    case reschedule
}

enum PlanNotificationActionIdentifier {
    static let snooze = "GYMTRACKER_PLAN_SNOOZE"
    static let skipToday = "GYMTRACKER_PLAN_SKIP_TODAY"
    static let reschedule = "GYMTRACKER_PLAN_RESCHEDULE"
}

@MainActor
final class PlanNotificationScheduler {
    static let shared = PlanNotificationScheduler()

    static let categoryIdentifier = "GYMTRACKER_PLAN_WORKOUT"

    private let center = UNUserNotificationCenter.current()
    private var reconciliationGeneration = 0
    private init() {}

    static func registerNotificationCategory() {
        let snooze = UNNotificationAction(
            identifier: PlanNotificationActionIdentifier.snooze,
            title: "Snooze 1 Hour"
        )
        let skipToday = UNNotificationAction(
            identifier: PlanNotificationActionIdentifier.skipToday,
            title: "Skip Today",
            options: [.destructive]
        )
        let reschedule = UNNotificationAction(
            identifier: PlanNotificationActionIdentifier.reschedule,
            title: "Reschedule",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [snooze, skipToday, reschedule],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

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
            where PlanReminderEligibility.canSchedule(progress, in: run) {
                guard let scheduledDate = progress.scheduledDate,
                      let fireDate = calendar.date(
                        bySettingHour: reminderHour,
                        minute: reminderMinute,
                        second: 0,
                        of: scheduledDate
                      ),
                      fireDate > now
                else { continue }

                let dateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                requests.append(
                    UNNotificationRequest(
                        identifier: ReminderIdentifier.planWorkout(progressID: progress.id),
                        content: notificationContent(for: progress, in: run),
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

    /// Snooze is derived notification state. It does not reschedule the plan
    /// occurrence and never writes to SwiftData.
    func snooze(
        _ destination: PlanNotificationDestination,
        in run: PlanRun,
        progress: PlanWorkoutProgress,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> Bool {
        guard isEnabled,
              await authorizationStatus() == .authorized,
              destination.runID == run.id,
              destination.progressID == progress.id,
              destination.planID == run.sourcePlanID,
              PlanReminderEligibility.isActionableToday(progress, in: run, now: now, calendar: calendar),
              let fireDate = calendar.date(byAdding: .hour, value: 1, to: now),
              calendar.isDate(fireDate, inSameDayAs: now)
        else {
            return false
        }

        let identifiers = [
            ReminderIdentifier.planWorkout(progressID: progress.id),
            ReminderIdentifier.snoozedPlanWorkout(progressID: progress.id)
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: ReminderIdentifier.snoozedPlanWorkout(progressID: progress.id),
            content: notificationContent(for: progress, in: run),
            trigger: trigger
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    private func notificationContent(
        for progress: PlanWorkoutProgress,
        in run: PlanRun
    ) -> UNMutableNotificationContent {
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
        return content
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
        PlanNotificationScheduler.registerNotificationCategory()
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
        let action: PlanNotificationAction
        switch response.actionIdentifier {
        case PlanNotificationActionIdentifier.reschedule:
            action = .reschedule
        default:
            action = .openPlan
        }
        guard let destination = PlanNotificationDestination(
            userInfo: response.notification.request.content.userInfo,
            action: action
        ) else { return }

        switch response.actionIdentifier {
        case PlanNotificationActionIdentifier.snooze:
            await MainActor.run {
                guard let modelContext = GymTrackerModelContainer.shared?.mainContext else { return }
                guard let resolved = PlanReminderActionService.resolve(destination, using: modelContext) else { return }
                Task {
                    _ = await PlanNotificationScheduler.shared.snooze(
                        destination,
                        in: resolved.run,
                        progress: resolved.progress
                    )
                }
            }
        case PlanNotificationActionIdentifier.skipToday:
            await MainActor.run {
                guard let modelContext = GymTrackerModelContainer.shared?.mainContext else { return }
                guard PlanReminderActionService.skipToday(destination, using: modelContext) else { return }
                Task { await PlanNotificationScheduler.shared.reconcile(using: modelContext) }
            }
        case UNNotificationDefaultActionIdentifier, PlanNotificationActionIdentifier.reschedule:
            await MainActor.run {
                PlanNotificationRouter.shared.submit(destination)
            }
        default:
            break
        }
    }
}
