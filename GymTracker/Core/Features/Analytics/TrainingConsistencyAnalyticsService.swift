import Foundation
import SwiftData

struct WeeklyFrequencyPoint: Equatable, Sendable, Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let workoutCount: Int
}

struct ConsistencyAnalytics: Equatable, Sendable {
    let weeklyFrequency: [WeeklyFrequencyPoint]
    let recentFourWeeksWorkoutCount: Int
    let previousFourWeeksWorkoutCount: Int
    let periodComparison: AnalyticsPeriodComparison<Int>
    let quality: AnalyticsDataQuality
    let takeawayText: String?
}

/// Pure service for computing training frequency and consistency metrics over time.
@MainActor
struct TrainingConsistencyAnalyticsService {
    let modelContext: ModelContext

    func analytics(
        referenceDate: Date = .now,
        weekCount: Int = 8,
        calendar: Calendar = .current
    ) throws -> ConsistencyAnalytics {
        guard weekCount > 0, let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return Self.emptyAnalytics
        }
        let earliestStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart
        let predicate = #Predicate<Workout> { workout in
            workout.startTime >= earliestStart && workout.startTime <= referenceDate
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Workout.startTime, order: .forward)]
        )
        return Self.analytics(
            workouts: try modelContext.fetch(descriptor),
            referenceDate: referenceDate,
            weekCount: weekCount,
            calendar: calendar
        )
    }

    /// Pure projection entry point for callers that specify an `AnalyticsDateRange`.
    /// Resolves the matching number of weekly buckets for that range.
    static func analytics(
        workouts: [Workout],
        range: AnalyticsDateRange,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> ConsistencyAnalytics {
        let weekCount: Int
        switch range {
        case .fourWeeks:
            weekCount = 4
        case .twelveWeeks:
            weekCount = 12
        case .sixMonths:
            weekCount = 26
        case .oneYear:
            weekCount = 52
        case .allTime:
            let completed = workouts.filter { $0.status == .completed }
            if let earliest = completed.map(\.startTime).min(),
               let earliestWeekStart = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start,
               let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start {
                let diff = calendar.dateComponents([.weekOfYear], from: earliestWeekStart, to: currentWeekStart).weekOfYear ?? 11
                weekCount = max(4, min(104, diff + 1))
            } else {
                weekCount = 12
            }
        }

        return analytics(
            workouts: workouts,
            referenceDate: referenceDate,
            weekCount: weekCount,
            calendar: calendar
        )
    }

    /// Pure projection entry point for callers that already observe workouts.
    /// This avoids issuing another SwiftData fetch for every overview card.
    static func analytics(
        workouts: [Workout],
        referenceDate: Date = .now,
        weekCount: Int = 8,
        calendar: Calendar = .current
    ) -> ConsistencyAnalytics {
        guard weekCount > 0, let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return emptyAnalytics
        }

        let earliestStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart
        let completed = workouts.filter {
            $0.status == .completed && $0.startTime >= earliestStart && $0.startTime <= referenceDate
        }
        let countByWeek = Dictionary(grouping: completed) {
            calendar.dateInterval(of: .weekOfYear, for: $0.startTime)?.start ?? $0.startTime
        }.mapValues(\.count)

        var frequencyPoints: [WeeklyFrequencyPoint] = []
        for offset in (0..<weekCount).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else { continue }
            frequencyPoints.append(WeeklyFrequencyPoint(weekStart: weekStart, workoutCount: countByWeek[weekStart, default: 0]))
        }

        let recentFour = frequencyPoints.suffix(4).reduce(0) { $0 + $1.workoutCount }
        let previousFour = frequencyPoints.prefix(max(0, frequencyPoints.count - 4)).suffix(4).reduce(0) { $0 + $1.workoutCount }
        let quality = AnalyticsDataQuality.evaluate(sampleCount: completed.count)

        let comparison = AnalyticsPeriodComparison(
            current: recentFour,
            previous: previousFour,
            quality: quality
        )

        let takeaway: String?
        if frequencyPoints.count >= 8 {
            if recentFour == previousFour {
                takeaway = "Training frequency was the same across the two four-week windows."
            } else {
                let diff = abs(recentFour - previousFour)
                let direction = recentFour > previousFour ? "more" : "fewer"
                takeaway = "You completed \(diff) \(direction) \(diff == 1 ? "workout" : "workouts") in the recent four weeks."
            }
        } else {
            takeaway = nil
        }

        return ConsistencyAnalytics(
            weeklyFrequency: frequencyPoints,
            recentFourWeeksWorkoutCount: recentFour,
            previousFourWeeksWorkoutCount: previousFour,
            periodComparison: comparison,
            quality: quality,
            takeawayText: takeaway
        )
    }

    private static var emptyAnalytics: ConsistencyAnalytics {
        ConsistencyAnalytics(
            weeklyFrequency: [],
            recentFourWeeksWorkoutCount: 0,
            previousFourWeeksWorkoutCount: 0,
            periodComparison: AnalyticsPeriodComparison(current: nil, previous: nil, quality: .insufficient),
            quality: .insufficient,
            takeawayText: nil
        )
    }
}
