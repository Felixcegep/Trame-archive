import Foundation

/// The current training week as Today needs to state it: which days carried a
/// session, and what the week adds up to so far.
///
/// Today used to fill the space below the workout card with adjacent domains —
/// food, supplements, a daily questionnaire. This is the same space answering
/// the question the screen is actually for: am I training this week.
struct TrainingWeekSummary: Equatable, Sendable {
    /// A session the schedule expects, reduced to the two facts the strip can
    /// state: which day, and what it is called.
    struct ScheduledDay: Equatable, Sendable {
        let date: Date
        let title: String
    }

    struct Day: Equatable, Sendable, Identifiable {
        let date: Date
        /// One locale-aware letter, e.g. "M". Reinforcement for the marks; the
        /// accessible summary never depends on it.
        let initial: String
        let workoutCount: Int
        let isToday: Bool
        let isFuture: Bool
        /// Whether the schedule expects a session here and it has not happened.
        ///
        /// Only ever true for today or a future day. A past day that was
        /// scheduled and not trained is deliberately *not* marked: calling it
        /// "missed" is a judgement `PlanCoordinator` already owns — it can be
        /// rescheduled, skipped, or simply late — and a strip on Today is not
        /// the place to assert it.
        let isScheduled: Bool

        var isTrained: Bool { workoutCount > 0 }
        var id: Date { date }
    }

    let days: [Day]
    let workoutCount: Int
    let setCount: Int
    /// The next expected session from today onward, if the schedule names one.
    let nextScheduled: ScheduledDay?

    var hasTraining: Bool { workoutCount > 0 }
}

extension TrainingWeekSummary {
    /// - Parameter recentWorkoutsNewestFirst: workouts sorted by `startTime`
    ///   descending — the order every `@Query` in the app already asks for. The
    ///   order is a requirement rather than an assumption because it lets this
    ///   stop at the week boundary instead of walking a lifetime of history on
    ///   every render.
    /// - Parameter scheduled: sessions the plan expects, in any order. Days
    ///   already trained still render as trained — a schedule entry is an
    ///   expectation, and a completed session outranks one.
    static func make(
        recentWorkoutsNewestFirst workouts: [Workout],
        scheduled: [ScheduledDay] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TrainingWeekSummary {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let dayStarts = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }

        // Completed only. An in-progress session is not yet part of the week's
        // record, and counting it would make the totals move backwards if the
        // lifter discards it.
        let weekWorkouts = workouts
            .prefix { $0.startTime >= weekStart }
            .filter { $0.status == .completed }

        // Bucketed by when the session started, not when it was saved: a
        // late-night session belongs to the day it was trained.
        var countsByDay: [Date: Int] = [:]
        var setCount = 0
        for workout in weekWorkouts {
            countsByDay[calendar.startOfDay(for: workout.startTime), default: 0] += 1
            setCount += workout.completedSetCount
        }

        // Earliest expectation per day. Two sessions on one date collapse to one
        // mark, because the strip has one mark per day to give.
        var scheduledByDay: [Date: ScheduledDay] = [:]
        for entry in scheduled {
            let dayStart = calendar.startOfDay(for: entry.date)
            if scheduledByDay[dayStart] == nil {
                scheduledByDay[dayStart] = ScheduledDay(date: dayStart, title: entry.title)
            }
        }

        let days = dayStarts.map { dayStart in
            let workoutCount = countsByDay[dayStart] ?? 0
            return Day(
                date: dayStart,
                initial: dayStart.formatted(.dateTime.weekday(.narrow)),
                workoutCount: workoutCount,
                isToday: dayStart == today,
                isFuture: dayStart > today,
                // Trained beats scheduled: once the session exists, what was
                // expected is no longer the news. Past days are never marked —
                // see `Day.isScheduled`.
                isScheduled: workoutCount == 0
                    && dayStart >= today
                    && scheduledByDay[dayStart] != nil
            )
        }

        // Read from the whole schedule rather than from `days`, so a session
        // later this month still answers "what's next" in a week with nothing
        // left in it.
        let nextScheduled = scheduled
            .map { ScheduledDay(date: calendar.startOfDay(for: $0.date), title: $0.title) }
            .filter { $0.date >= today }
            .min { $0.date < $1.date }

        return TrainingWeekSummary(
            days: days,
            workoutCount: weekWorkouts.count,
            setCount: setCount,
            nextScheduled: nextScheduled
        )
    }

    /// "2 workouts · 24 sets", or the invitation when the week is still empty.
    var detailText: String {
        guard hasTraining else {
            return String(localized: "No sessions logged yet this week")
        }
        let workouts = workoutCount == 1
            ? String(localized: "1 workout")
            : String(localized: "\(workoutCount) workouts")
        let sets = setCount == 1
            ? String(localized: "1 set")
            : String(localized: "\(setCount) sets")
        return "\(workouts) · \(sets)"
    }
}
