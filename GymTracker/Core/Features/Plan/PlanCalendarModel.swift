import Foundation
import SwiftUI

enum PlanCalendarDisplayState: String, CaseIterable {
    case upcoming
    case available
    case inProgress
    case completed
    case skipped
    case missed

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .available: "Ready"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .skipped: "Skipped"
        case .missed: "Missed"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .inProgress: "plan-calendar-state-in-progress"
        default: "plan-calendar-state-\(rawValue)"
        }
    }

    /// One icon per state, owned here so the plan calendar, the training
    /// calendar, and the program path cannot drift apart.
    ///
    /// They had. `PlanCalendarStateBadge` drew `skipped` with the same dashed
    /// circle as `upcoming`, making a session you chose to skip
    /// indistinguishable from one that has not happened yet; the program path
    /// used a distinct skip glyph. The distinct glyph wins, because those are
    /// different states with different consequences.
    var icon: String {
        switch self {
        case .completed: AppIcon.checkmarkCircle
        case .available: AppIcon.circleFill
        case .inProgress: AppIcon.workout
        case .missed: AppIcon.warning
        case .upcoming: AppIcon.circleDashed
        case .skipped: AppIcon.skip
        }
    }

    /// Never the only carrier of meaning — every surface pairs it with
    /// `title` — but it must mean the same thing everywhere.
    ///
    /// `PlanCalendarStateBadge` was the one place in the app that tinted with
    /// the system `.secondary` instead of a design token, so quiet states
    /// rendered a different grey here than on the program path.
    var tint: Color {
        switch self {
        case .completed: .gymSuccess
        case .available, .inProgress: .trameStrength
        case .missed: .gymDestructive
        case .upcoming, .skipped: .gymSubduedText
        }
    }
}

struct PlanCalendarEntry: Identifiable {
    let id: UUID
    let workoutName: String
    let weekIndex: Int
    let workoutIndex: Int
    let scheduledDate: Date?
    let displayState: PlanCalendarDisplayState

    var isReschedulable: Bool {
        switch displayState {
        case .upcoming, .available, .missed:
            true
        case .inProgress, .completed, .skipped:
            false
        }
    }
}

struct PlanCalendarDay: Identifiable {
    let date: Date
    let entries: [PlanCalendarEntry]

    var id: Date { date }
}

struct PlanCalendarWeek: Identifiable {
    let weekIndex: Int
    let days: [PlanCalendarDay]
    let unscheduledEntries: [PlanCalendarEntry]

    var id: Int { weekIndex }
}

/// Plan-week window used by flexible-week schedules. Week 0 starts on the
/// run's local start day and lasts seven days; later weeks follow the same
/// stride. This is not a weekday pin.
enum PlanWeekWindow {
    static func deadline(
        weekIndex: Int,
        runStart: Date,
        calendar: Calendar
    ) -> Date? {
        let start = calendar.startOfDay(for: runStart)
        return calendar.date(byAdding: .day, value: (weekIndex * 7) + 6, to: start)
    }

    static func contains(
        _ date: Date,
        weekIndex: Int,
        runStart: Date,
        calendar: Calendar
    ) -> Bool {
        let start = calendar.startOfDay(for: runStart)
        guard
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: start),
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)
        else {
            return false
        }
        let day = calendar.startOfDay(for: date)
        return day >= weekStart && day <= weekEnd
    }
}

enum PlanCalendarBuilder {
    static func displayState(
        status: PlanWorkoutStatus,
        scheduledDate: Date?,
        today: Date,
        calendar: Calendar,
        weekDeadline: Date? = nil
    ) -> PlanCalendarDisplayState {
        switch status {
        case .completed: return .completed
        case .skipped: return .skipped
        case .inProgress: return .inProgress
        case .available, .upcoming:
            if let scheduledDate {
                return calendar.startOfDay(for: scheduledDate) < calendar.startOfDay(for: today)
                    ? .missed
                    : (status == .available ? .available : .upcoming)
            }
            if let weekDeadline, calendar.startOfDay(for: weekDeadline) < calendar.startOfDay(for: today) {
                return .missed
            }
            return status == .available ? .available : .upcoming
        }
    }

    static func weekDeadline(
        for progress: PlanWorkoutProgress,
        in run: PlanRun,
        calendar: Calendar
    ) -> Date? {
        guard run.plan?.scheduleMode.usesFlexibleWeekWindow == true else { return nil }
        return PlanWeekWindow.deadline(
            weekIndex: progress.weekIndex,
            runStart: run.startDate,
            calendar: calendar
        )
    }

    static func displayState(
        for progress: PlanWorkoutProgress,
        in run: PlanRun,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> PlanCalendarDisplayState {
        displayState(
            status: progress.status,
            scheduledDate: progress.scheduledDate,
            today: today,
            calendar: calendar,
            weekDeadline: weekDeadline(for: progress, in: run, calendar: calendar)
        )
    }

    static func weeks(
        for run: PlanRun,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [PlanCalendarWeek] {
        weeks(
            for: run.orderedWorkoutProgress,
            today: today,
            calendar: calendar,
            weekDeadlineFor: { weekDeadline(for: $0, in: run, calendar: calendar) }
        )
    }

    static func weeks(
        for progress: [PlanWorkoutProgress],
        today: Date = .now,
        calendar: Calendar = .current,
        weekDeadlineFor: (PlanWorkoutProgress) -> Date? = { _ in nil }
    ) -> [PlanCalendarWeek] {
        let entries = progress.map { item in
            PlanCalendarEntry(
                id: item.id,
                workoutName: item.plannedWorkoutName,
                weekIndex: item.weekIndex,
                workoutIndex: item.workoutIndex,
                scheduledDate: item.scheduledDate.map(calendar.startOfDay(for:)),
                displayState: displayState(
                    status: item.status,
                    scheduledDate: item.scheduledDate,
                    today: today,
                    calendar: calendar,
                    weekDeadline: weekDeadlineFor(item)
                )
            )
        }

        return Dictionary(grouping: entries, by: \.weekIndex)
            .map { weekIndex, entries in
                let scheduled = entries.compactMap { entry -> (Date, PlanCalendarEntry)? in
                    entry.scheduledDate.map { ($0, entry) }
                }
                let days = Dictionary(grouping: scheduled, by: \.0)
                    .map { date, pairs in
                        PlanCalendarDay(
                            date: date,
                            entries: pairs.map(\.1).sorted(by: isOrdered)
                        )
                    }
                    .sorted { $0.date < $1.date }

                return PlanCalendarWeek(
                    weekIndex: weekIndex,
                    days: days,
                    unscheduledEntries: entries.filter { $0.scheduledDate == nil }.sorted(by: isOrdered)
                )
            }
            .sorted { $0.weekIndex < $1.weekIndex }
    }

    nonisolated private static func isOrdered(_ lhs: PlanCalendarEntry, _ rhs: PlanCalendarEntry) -> Bool {
        if lhs.weekIndex != rhs.weekIndex { return lhs.weekIndex < rhs.weekIndex }
        if lhs.workoutIndex != rhs.workoutIndex { return lhs.workoutIndex < rhs.workoutIndex }
        return lhs.workoutName.localizedStandardCompare(rhs.workoutName) == .orderedAscending
    }
}
