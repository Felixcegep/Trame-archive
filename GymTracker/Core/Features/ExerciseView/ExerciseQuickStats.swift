import Foundation
import SwiftData

/// Compact performance summary shown on the exercise detail screen, above the
/// full insights destination. Values come from completed history only.
struct ExerciseQuickStats: Equatable {
    enum Accent: Equatable {
        case primary
        case secondary
        case accent
        case neutral
    }

    enum Direction: Equatable {
        case up
        case down
        case flat
    }

    struct Metric: Identifiable, Equatable {
        let id: String
        /// Headline number, e.g. `120 kg × 8`.
        let value: String
        /// What the number is, e.g. `best set`.
        let label: String
        /// Supporting context, e.g. `Jul 12` or `vs previous session`.
        let detail: String?
        var direction: Direction = .flat
        let accent: Accent
    }

    let metrics: [Metric]
    let sessionCount: Int

    var hasHistory: Bool { sessionCount > 0 }

    static let empty = ExerciseQuickStats(metrics: [], sessionCount: 0)
}

enum ExerciseQuickStatsBuilder {
    static func make(
        for exercise: Exercise,
        using context: ModelContext,
        referenceDate: Date = .now
    ) throws -> ExerciseQuickStats {
        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        guard analytics.sessionCount > 0 else { return .empty }

        var metrics: [ExerciseQuickStats.Metric] = []

        metrics.append(
            ExerciseQuickStats.Metric(
                id: "sessions",
                value: "\(analytics.sessionCount)",
                label: analytics.sessionCount == 1 ? "session" : "sessions",
                detail: "completed",
                accent: .primary
            )
        )

        if let latest = analytics.latestSession {
            metrics.append(
                ExerciseQuickStats.Metric(
                    id: "last-trained",
                    value: latest.workoutDate.formatted(.dateTime.month(.abbreviated).day()),
                    label: "last trained",
                    detail: relativeDescription(for: latest.workoutDate, referenceDate: referenceDate),
                    accent: .neutral
                )
            )
        }

        if let best = analytics.bestLoadSet {
            metrics.append(
                ExerciseQuickStats.Metric(
                    id: "best-set",
                    value: "\(Formatters.formatFloat(best.weight)) \(best.unit.rawValue) × \(Formatters.formatFloat(best.repetitions))",
                    label: "best set",
                    detail: loadComparison(analytics.sessionComparison)?.text
                        ?? best.workoutDate.formatted(.dateTime.month(.abbreviated).day()),
                    direction: loadComparison(analytics.sessionComparison)?.direction ?? .flat,
                    accent: .accent
                )
            )
        }

        if let estimate = analytics.estimatedOneRepMax {
            metrics.append(
                ExerciseQuickStats.Metric(
                    id: "estimated-1rm",
                    value: "≈\(Formatters.formatEstimatedLoad(estimate.estimatedLoad)) \(estimate.unit.rawValue)",
                    label: "est. 1RM",
                    detail: "from \(Formatters.formatFloat(estimate.sourceWeight)) × \(Formatters.formatFloat(estimate.sourceRepetitions))",
                    accent: .secondary
                )
            )
        } else if let comparison = analytics.sessionComparison {
            metrics.append(
                ExerciseQuickStats.Metric(
                    id: "volume",
                    value: Formatters.formatGroupedMetric(comparison.latestVolume),
                    label: "last volume",
                    detail: volumeComparison(comparison).text,
                    direction: volumeComparison(comparison).direction,
                    accent: .secondary
                )
            )
        }

        return ExerciseQuickStats(metrics: metrics, sessionCount: analytics.sessionCount)
    }

    private static func relativeDescription(for date: Date, referenceDate: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0

        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2...13: return "\(days) days ago"
        default:
            let weeks = days / 7
            return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
        }
    }

    private static func loadComparison(
        _ comparison: SessionComparison?
    ) -> (text: String, direction: ExerciseQuickStats.Direction)? {
        guard let comparison else { return nil }
        let delta = comparison.latestBestLoad - comparison.previousBestLoad
        switch comparison.bestLoadTrend {
        case .increased:
            return ("+\(Formatters.formatFloat(delta)) \(comparison.unit.rawValue) vs previous", .up)
        case .decreased:
            return ("\(Formatters.formatFloat(delta)) \(comparison.unit.rawValue) vs previous", .down)
        case .same:
            return ("same as previous", .flat)
        }
    }

    private static func volumeComparison(
        _ comparison: SessionComparison
    ) -> (text: String, direction: ExerciseQuickStats.Direction) {
        guard comparison.previousVolume > 0 else {
            return ("no comparable previous session", .flat)
        }
        let change = comparison.latestVolume - comparison.previousVolume
        let percentage = Int((abs(change / comparison.previousVolume) * 100).rounded())
        switch comparison.volumeTrend {
        case .increased:
            return ("\(percentage)% above previous", .up)
        case .decreased:
            return ("\(percentage)% below previous", .down)
        case .same:
            return ("same as previous", .flat)
        }
    }
}
