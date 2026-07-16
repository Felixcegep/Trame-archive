import Foundation

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

enum PlanCalendarBuilder {
    static func displayState(
        status: PlanWorkoutStatus,
        scheduledDate: Date?,
        today: Date,
        calendar: Calendar
    ) -> PlanCalendarDisplayState {
        switch status {
        case .completed: return .completed
        case .skipped: return .skipped
        case .inProgress: return .inProgress
        case .available, .upcoming:
            guard let scheduledDate else { return status == .available ? .available : .upcoming }
            return calendar.startOfDay(for: scheduledDate) < calendar.startOfDay(for: today)
                ? .missed
                : (status == .available ? .available : .upcoming)
        }
    }

    static func weeks(
        for progress: [PlanWorkoutProgress],
        today: Date = .now,
        calendar: Calendar = .current
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
                    calendar: calendar
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
