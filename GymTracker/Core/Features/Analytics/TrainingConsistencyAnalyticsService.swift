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
struct TrainingConsistencyAnalyticsService: Sendable {
    let modelContext: ModelContext

    func analytics(
        referenceDate: Date = .now,
        weekCount: Int = 8,
        calendar: Calendar = .current
    ) throws -> ConsistencyAnalytics {
        guard weekCount > 0, let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return ConsistencyAnalytics(
                weeklyFrequency: [],
                recentFourWeeksWorkoutCount: 0,
                previousFourWeeksWorkoutCount: 0,
                periodComparison: AnalyticsPeriodComparison(current: nil, previous: nil, quality: .insufficient),
                quality: .insufficient,
                takeawayText: nil
            )
        }

        let earliestStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart
        let predicate = #Predicate<Workout> { workout in
            workout.startTime >= earliestStart && workout.startTime <= referenceDate
        }
        let descriptor = FetchDescriptor<Workout>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Workout.startTime, order: .forward)]
        )
        let workouts = try modelContext.fetch(descriptor).filter { $0.status == .completed }

        var frequencyPoints: [WeeklyFrequencyPoint] = []
        for offset in (0..<weekCount).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            let count = workouts.filter { interval.contains($0.startTime) }.count
            frequencyPoints.append(WeeklyFrequencyPoint(weekStart: weekStart, workoutCount: count))
        }

        let recentFour = frequencyPoints.suffix(4).reduce(0) { $0 + $1.workoutCount }
        let previousFour = frequencyPoints.prefix(max(0, frequencyPoints.count - 4)).suffix(4).reduce(0) { $0 + $1.workoutCount }
        let quality = AnalyticsDataQuality.evaluate(sampleCount: workouts.count)

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
}
