import Foundation
import SwiftData

enum MuscleBalanceGroup: String, CaseIterable, Identifiable {
    case chest
    case back
    case deltoids
    case arms
    case core
    case glutes
    case quadriceps
    case hamstrings
    case calves
    case hips

    var id: Self { self }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .deltoids: "Deltoids"
        case .arms: "Arms"
        case .core: "Core"
        case .glutes: "Glutes"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Hamstrings"
        case .calves: "Calves"
        case .hips: "Hips"
        }
    }

    var muscles: Set<Muscle> {
        switch self {
        case .chest:
            [.upperChest, .middleChest, .lowerChest]
        case .back:
            [.latissimusDorsi, .trapezius, .rhomboids, .teresMajor, .erectorSpinae]
        case .deltoids:
            [.frontDeltoid, .lateralDeltoid, .rearDeltoid]
        case .arms:
            [.bicep, .brachialis, .brachioradialis, .tricepLongHead, .tricepLateralHead, .tricepMedialHead, .forearms]
        case .core:
            [.rectusAbdominis, .obliques, .transverseAbdominis]
        case .glutes:
            [.gluteMaximus, .gluteMedius, .gluteMinimus]
        case .quadriceps:
            [.quadriceps]
        case .hamstrings:
            [.hamstrings]
        case .calves:
            [.calves, .tibialisAnterior]
        case .hips:
            [.adductors, .abductors]
        }
    }

    static func containing(_ muscle: Muscle) -> Self? {
        allCases.first { $0.muscles.contains(muscle) }
    }
}

struct MuscleBalanceWeek: Equatable, Identifiable {
    let weekStart: Date
    let counts: [MuscleBalanceGroup: Double]

    var id: Date { weekStart }

    func count(for group: MuscleBalanceGroup) -> Double {
        counts[group, default: 0]
    }
}

struct MuscleBalanceSummary: Equatable, Identifiable {
    let group: MuscleBalanceGroup
    let recentAverage: Double
    let previousAverage: Double

    var id: MuscleBalanceGroup { group }

    var change: Double {
        recentAverage - previousAverage
    }

    var changeRatio: Double? {
        guard previousAverage > 0 else { return nil }
        return change / previousAverage
    }
}

struct MuscleBalanceCallout: Equatable, Identifiable {
    let group: MuscleBalanceGroup
    let message: String

    var id: MuscleBalanceGroup { group }
}

struct MuscleBalanceAnalytics: Equatable {
    let weeks: [MuscleBalanceWeek]
    let summaries: [MuscleBalanceSummary]
    let callouts: [MuscleBalanceCallout]

    var hasHistory: Bool {
        weeks.contains { week in
            week.counts.values.contains { $0 > 0 }
        }
    }
}

struct MuscleBalanceAnalyticsService {
    let modelContext: ModelContext

    func analytics(
        referenceDate: Date = .now,
        weekCount: Int = 8
    ) throws -> MuscleBalanceAnalytics {
        let weeks = makeWeeks(endingAt: referenceDate, count: weekCount)
        guard !weeks.isEmpty else {
            return MuscleBalanceAnalytics(weeks: [], summaries: [], callouts: [])
        }

        let workouts = try modelContext.fetch(
            FetchDescriptor<Workout>(
                sortBy: [SortDescriptor(\Workout.startTime, order: .forward)]
            )
        )
        let completedWorkouts = workouts.filter {
            $0.status == .completed && $0.startTime <= referenceDate
        }

        var counts = weeks.map { _ in [MuscleBalanceGroup: Double]() }
        for workout in completedWorkouts {
            guard let weekIndex = weeks.firstIndex(where: { week in
                guard let interval = weekInterval(containing: week.weekStart) else { return false }
                return interval.contains(workout.startTime)
            }) else {
                continue
            }

            for entry in workout.orderedExercises {
                let weights = groupWeights(for: entry.exercise)
                let workingSetCount = entry.orderedSets.filter { $0.done && $0.setType != .warmup }.count
                for (group, weight) in weights {
                    counts[weekIndex][group, default: 0] += Double(workingSetCount) * weight
                }
            }
        }

        let weeksWithCounts = zip(weeks, counts).map { week, weekCounts in
            MuscleBalanceWeek(weekStart: week.weekStart, counts: weekCounts)
        }
        let splitIndex = max(0, weeksWithCounts.count - 4)
        let previousWeeks = Array(weeksWithCounts.prefix(splitIndex))
        let recentWeeks = Array(weeksWithCounts.suffix(min(4, weeksWithCounts.count)))
        let summaries = MuscleBalanceGroup.allCases.compactMap { group -> MuscleBalanceSummary? in
            let recentAverage = average(group, in: recentWeeks)
            let previousAverage = average(group, in: previousWeeks)
            guard recentAverage > 0 || previousAverage > 0 else { return nil }
            return MuscleBalanceSummary(
                group: group,
                recentAverage: recentAverage,
                previousAverage: previousAverage
            )
        }
        .sorted {
            if $0.recentAverage == $1.recentAverage {
                return $0.group.displayName < $1.group.displayName
            }
            return $0.recentAverage > $1.recentAverage
        }

        let callouts = summaries.compactMap { summary -> MuscleBalanceCallout? in
            guard
                summary.previousAverage >= 2,
                summary.recentAverage < summary.previousAverage * 0.75
            else { return nil }
            return MuscleBalanceCallout(
                group: summary.group,
                message: "\(summary.group.displayName) averaged \(Formatters.formatFloat(Float(summary.recentAverage))) estimated sets per week, down from \(Formatters.formatFloat(Float(summary.previousAverage))) in the previous four weeks."
            )
        }

        return MuscleBalanceAnalytics(
            weeks: weeksWithCounts,
            summaries: summaries,
            callouts: callouts
        )
    }

    private func makeWeeks(endingAt date: Date, count: Int) -> [MuscleBalanceWeek] {
        guard count > 0, let currentWeekStart = weekInterval(containing: date)?.start else {
            return []
        }
        return (0..<count).reversed().compactMap { offset in
            guard let start = Calendar.current.date(
                byAdding: .weekOfYear,
                value: -offset,
                to: currentWeekStart
            ) else { return nil }
            return MuscleBalanceWeek(weekStart: start, counts: [:])
        }
    }

    private func weekInterval(containing date: Date) -> DateInterval? {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)
    }

    private func average(
        _ group: MuscleBalanceGroup,
        in weeks: [MuscleBalanceWeek]
    ) -> Double {
        guard !weeks.isEmpty else { return 0 }
        return weeks.reduce(0) { $0 + $1.count(for: group) } / Double(weeks.count)
    }

    private func groupWeights(for exercise: Exercise) -> [MuscleBalanceGroup: Double] {
        var weights: [MuscleBalanceGroup: Double] = [:]
        for muscle in exercise.primaryMuscles {
            if let group = MuscleBalanceGroup.containing(muscle) {
                weights[group] = max(weights[group, default: 0], 1)
            }
        }
        for muscle in exercise.secondaryMuscles ?? [] {
            if let group = MuscleBalanceGroup.containing(muscle) {
                weights[group] = max(weights[group, default: 0], 0.5)
            }
        }
        return weights
    }
}
