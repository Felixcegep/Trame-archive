import Foundation
import SwiftData

enum ExerciseDetailInsightsBuilder {
    static func make(
        for exercise: Exercise,
        using context: ModelContext,
        referenceDate: Date = .now
    ) throws -> ExerciseDetailInsightsModel {
        let analytics = try ExerciseDetailAnalyticsService(modelContext: context)
            .analytics(for: exercise, referenceDate: referenceDate)

        let latestSession = analytics.latestSession.map { makeSession($0, id: "latest") }
        let previousSession = analytics.sessionComparison.map { comparison in
            ExerciseDetailSession(
                id: "previous",
                date: comparison.previousDate.formatted(date: .abbreviated, time: .omitted),
                summary: "\(Formatters.formatFloat(comparison.previousBestLoad)) \(comparison.unit.rawValue) best · \(Formatters.formatFloat(comparison.previousVolume)) volume",
                sets: []
            )
        }

        var bestResults: [ExerciseDetailBestResult] = []
        if let bestLoadSet = analytics.bestLoadSet {
            bestResults.append(
                ExerciseDetailBestResult(
                    id: "best-load",
                    title: "Best load",
                    value: "\(Formatters.formatFloat(bestLoadSet.weight)) \(bestLoadSet.unit.rawValue) × \(Formatters.formatFloat(bestLoadSet.repetitions))",
                    detail: bestLoadSet.workoutDate.formatted(date: .abbreviated, time: .omitted)
                )
            )
        }
        if let bestRepetitionSet = analytics.bestRepetitionSet {
            bestResults.append(
                ExerciseDetailBestResult(
                    id: "best-reps",
                    title: "Most reps in one working set",
                    value: "\(Formatters.formatFloat(bestRepetitionSet.weight)) \(bestRepetitionSet.unit.rawValue) × \(Formatters.formatFloat(bestRepetitionSet.repetitions))",
                    detail: bestRepetitionSet.workoutDate.formatted(date: .abbreviated, time: .omitted)
                )
            )
        }
        bestResults.append(contentsOf: analytics.bestSetsByRepRange.map { result in
            ExerciseDetailBestResult(
                id: "rep-range-\(result.rangeName)",
                title: "Best \(result.rangeName) rep set",
                value: "\(Formatters.formatFloat(result.bestSet.weight)) \(result.bestSet.unit.rawValue) × \(Formatters.formatFloat(result.bestSet.repetitions))",
                detail: result.bestSet.workoutDate.formatted(date: .abbreviated, time: .omitted)
            )
        })

        let volumePoints = analytics.weeklyVolume.map { week in
            ExerciseDetailVolumePoint(
                id: week.weekStart.formatted(.iso8601),
                date: week.weekStart,
                label: week.weekStart.formatted(.dateTime.month(.abbreviated).day()),
                value: Double(week.totalVolume),
                unit: analytics.unit?.rawValue ?? "",
                workingSetCount: week.workingSetCount,
                sessionCount: week.sessionCount,
                accessibilityValue: "\(Formatters.formatGroupedMetric(week.totalVolume)) \(analytics.unit?.rawValue ?? "volume units"), \(week.workingSetCount) working sets, \(week.sessionCount) \(week.sessionCount == 1 ? "session" : "sessions")"
            )
        }

        let historyCount = analytics.sessionCount

        return ExerciseDetailInsightsModel(
            exerciseName: exercise.name,
            subtitle: exercise.subtitle,
            latestSession: latestSession,
            previousSession: previousSession,
            bestResults: bestResults,
            estimatedOneRepMax: analytics.estimatedOneRepMax.map {
                ExerciseDetailMetric(
                    value: Formatters.formatEstimatedLoad($0.estimatedLoad),
                    unit: $0.unit.rawValue,
                    context: "From \(Formatters.formatFloat($0.sourceWeight)) \($0.unit.rawValue) × \(Formatters.formatFloat($0.sourceRepetitions)) on \($0.workoutDate.formatted(date: .abbreviated, time: .omitted))"
                )
            },
            volumePoints: volumePoints,
            changeSummary: StrengthInsightPresentationPolicy.changeSummary(for: analytics),
            volumeTakeaway: StrengthInsightPresentationPolicy.volumeTakeaway(
                sessionCount: analytics.sessionCount,
                weeklyVolumes: analytics.weeklyVolume.map(\.totalVolume)
            ),
            notes: Array(analytics.notes.map {
                ExerciseDetailNote(
                    id: "note-\($0.workoutDate.timeIntervalSince1970)-\($0.text)",
                    date: $0.workoutDate.formatted(date: .abbreviated, time: .omitted),
                    text: $0.text
                )
            }.reversed()),
            progression: activeProgression(for: exercise, using: context),
            historyCount: historyCount
        )
    }

    private static func makeSession(_ session: ExerciseSession, id: String) -> ExerciseDetailSession {
        let unit = session.workingSets.last?.weightType ?? session.sets.last?.weightType
        let bestLoad = session.workingSets
            .map { set in UnitConversion.weight(set.weight, from: set.weightType, to: unit ?? .kg) }
            .max() ?? 0

        return ExerciseDetailSession(
            id: id,
            workoutID: session.workoutID,
            date: session.workoutDate.formatted(date: .abbreviated, time: .omitted),
            summary: "\(session.sets.count) sets · \(Formatters.formatFloat(bestLoad)) \(unit?.rawValue ?? "kg") best",
            sets: session.sets.map {
                ExerciseDetailSet(
                    id: "\(id)-\($0.orderIndex)",
                    label: "Set \($0.orderIndex + 1)",
                    value: "\(Formatters.formatFloat($0.weight)) \($0.weightType.rawValue) × \(Formatters.formatFloat($0.repetitions))",
                    detail: $0.setType == .warmup ? "Warm-up" : nil
                )
            }
        )
    }

    private static func activeProgression(
        for exercise: Exercise,
        using context: ModelContext
    ) -> ExerciseDetailProgression? {
        guard
            let workout = try? context.fetch(FetchDescriptor<Workout>()).first(where: { $0.status == .active }),
            let entry = workout.orderedExercises.first(where: { $0.exercise.persistentModelID == exercise.persistentModelID }),
            let decision = entry.recommendedDecision,
            let recommendedLoad = entry.recommendedLoad,
            let unit = entry.recommendedUnit
        else { return nil }

        switch decision {
        case .increase:
            return ExerciseDetailProgression(
                title: "Increase to \(Formatters.formatFloat(recommendedLoad)) \(unit.rawValue)",
                explanation: "You reached the rep ceiling on every required set last time.",
                actionLabel: "Review in Active Workout"
            )
        case .hold:
            return ExerciseDetailProgression(
                title: "Keep \(Formatters.formatFloat(recommendedLoad)) \(unit.rawValue)",
                explanation: "Not every required set reached the rep ceiling last time.",
                actionLabel: "Review in Active Workout"
            )
        }
    }
}
