import Foundation

enum PerformanceComparisonStatus: String, Equatable {
    case below
    case met
    case above
    case noTarget

    var title: String {
        switch self {
        case .below: return String(localized: "Below")
        case .met: return String(localized: "Met")
        case .above: return String(localized: "Above")
        case .noTarget: return String(localized: "No target")
        }
    }
}

struct PerformanceDimension: Equatable, Identifiable {
    let name: String
    let status: PerformanceComparisonStatus

    var id: String { name }
}

struct WorkoutPerformanceComparison {
    let sets: PerformanceComparisonStatus
    let reps: PerformanceComparisonStatus
    let load: PerformanceComparisonStatus
    let effort: PerformanceComparisonStatus
    let recommendation: PerformanceComparisonStatus
    let plannedSummary: String
    let performedSummary: String
    let recommendationSummary: String?

    init(exercise: ExerciseEntry) {
        let completedSets = exercise.orderedSets.filter(\.done)

        sets = Self.compareCount(
            completedSets.count,
            target: exercise.prescribedSets
        )
        reps = Self.compareReps(
            completedSets,
            minimum: exercise.prescribedRepRangeMinimum,
            maximum: exercise.prescribedRepRangeMaximum
        )
        load = Self.compareLoad(
            completedSets,
            target: exercise.prescribedSuggestedLoad.map(Float.init),
            unit: exercise.prescribedSuggestedLoadType
        )
        effort = Self.compareEffort(
            completedSets,
            targetRPE: exercise.prescribedRPE
        )
        recommendation = Self.compareLoad(
            completedSets,
            target: exercise.recommendedLoad,
            unit: exercise.recommendedUnit
        )
        plannedSummary = Self.plannedSummary(for: exercise)
        performedSummary = Self.performedSummary(for: exercise, completedSets: completedSets)
        recommendationSummary = Self.recommendationSummary(for: exercise)
    }

    var dimensions: [PerformanceDimension] {
        [
            PerformanceDimension(name: String(localized: "Sets"), status: sets),
            PerformanceDimension(name: String(localized: "Reps"), status: reps),
            PerformanceDimension(name: String(localized: "Load"), status: load),
            PerformanceDimension(name: String(localized: "Effort"), status: effort),
            PerformanceDimension(name: String(localized: "Recommendation"), status: recommendation)
        ]
        .filter { $0.status != .noTarget }
    }

    var overall: PerformanceComparisonStatus {
        let statuses = dimensions.map(\.status)
        guard !statuses.isEmpty else { return .noTarget }
        if statuses.contains(.below) { return .below }
        if statuses.contains(.above) { return .above }
        return .met
    }

    var hasTargets: Bool {
        overall != .noTarget
    }

    private static func compareCount(_ value: Int, target: Int?) -> PerformanceComparisonStatus {
        guard let target, target > 0 else { return .noTarget }
        if value < target { return .below }
        if value > target { return .above }
        return .met
    }

    private static func compareReps(
        _ sets: [ExerciseSet],
        minimum: Int?,
        maximum: Int?
    ) -> PerformanceComparisonStatus {
        guard let minimum, let maximum, !sets.isEmpty else { return .noTarget }
        let repetitions = sets.map { Int($0.repetitions.rounded()) }
        if repetitions.contains(where: { $0 < minimum }) { return .below }
        if repetitions.contains(where: { $0 > maximum }) { return .above }
        return .met
    }

    private static func compareLoad(
        _ sets: [ExerciseSet],
        target: Float?,
        unit: WeightType?
    ) -> PerformanceComparisonStatus {
        guard let target, let unit, target > 0, !sets.isEmpty else { return .noTarget }
        let loads = sets.map { set in
            UnitConversion.weight(set.weight, from: set.weightType, to: unit)
        }
        let tolerance: Float = 0.0001
        if loads.contains(where: { $0 < target - tolerance }) { return .below }
        if loads.contains(where: { $0 > target + tolerance }) { return .above }
        return .met
    }

    private static func compareEffort(
        _ sets: [ExerciseSet],
        targetRPE: Double?
    ) -> PerformanceComparisonStatus {
        guard let targetRPE else { return .noTarget }
        let recorded = sets.compactMap(\.rpe)
        guard !recorded.isEmpty else { return .noTarget }
        let average = Double(recorded.reduce(0, +)) / Double(recorded.count)
        if average < targetRPE { return .below }
        if average > targetRPE { return .above }
        return .met
    }

    private static func plannedSummary(for exercise: ExerciseEntry) -> String {
        var components: [String] = []
        if let sets = exercise.prescribedSets,
           let minimum = exercise.prescribedRepRangeMinimum,
           let maximum = exercise.prescribedRepRangeMaximum {
            components.append("\(sets) × \(minimum)–\(maximum)")
        }
        if let load = exercise.prescribedSuggestedLoad,
           let unit = exercise.prescribedSuggestedLoadType,
           load > 0 {
            components.append("\(Formatters.formatFloat(Float(load))) \(unit.rawValue)")
        }
        if let rpe = exercise.prescribedRPE {
            components.append("RPE \(Formatters.formatFloat(Float(rpe)))")
        }
        if let seconds = exercise.orderedSets.first?.prescribedDurationSecondsSnapshot {
            components.append("\(Formatters.formatFloat(Float(seconds))) sec")
        }
        if let meters = exercise.orderedSets.first?.prescribedDistanceMetersSnapshot {
            components.append("\(Formatters.formatFloat(Float(meters))) m")
        }
        if let calories = exercise.orderedSets.first?.prescribedCaloriesSnapshot {
            components.append("\(Formatters.formatFloat(Float(calories))) cal")
        }
        return components.isEmpty ? String(localized: "No prescription target") : components.joined(separator: " · ")
    }

    private static func performedSummary(
        for exercise: ExerciseEntry,
        completedSets: [ExerciseSet]
    ) -> String {
        guard !completedSets.isEmpty else { return String(localized: "No completed sets") }
        var components = [String(localized: "\(completedSets.count) sets")]
        if exercise.trackingTypeSnapshot.usesReps {
            let reps = completedSets.map { Int($0.repetitions.rounded()) }
            let range = reps.min() == reps.max() ? "\(reps.first ?? 0) reps" : "\(reps.min() ?? 0)–\(reps.max() ?? 0) reps"
            components.append(range)
        }
        if exercise.trackingTypeSnapshot.usesWeight,
           let first = completedSets.first {
            let loads = completedSets.map {
                UnitConversion.weight($0.weight, from: $0.weightType, to: first.weightType)
            }
            let minimum = loads.min() ?? 0
            let maximum = loads.max() ?? 0
            let range = abs(minimum - maximum) < 0.0001
                ? Formatters.formatFloat(minimum)
                : "\(Formatters.formatFloat(minimum))–\(Formatters.formatFloat(maximum))"
            components.append("\(range) \(first.weightType.rawValue)")
        }
        if exercise.trackingTypeSnapshot.usesDuration {
            let durations = completedSets.compactMap(\.duration)
            if !durations.isEmpty {
                components.append("\(Int(durations.reduce(0, +))) sec")
            }
        }
        if exercise.trackingTypeSnapshot.usesDistance {
            let meters = completedSets.reduce(Float(0)) { $0 + (WorkoutDistancePolicy.meters(of: $1) ?? 0) }
            if meters > 0 { components.append("\(Formatters.formatFloat(meters)) m") }
        }
        if exercise.trackingTypeSnapshot.usesCalories {
            let calories = completedSets.compactMap(\.calories).reduce(0, +)
            if calories > 0 { components.append("\(Formatters.formatFloat(Float(calories))) cal") }
        }
        return components.joined(separator: " · ")
    }

    private static func recommendationSummary(for exercise: ExerciseEntry) -> String? {
        guard let load = exercise.recommendedLoad, let unit = exercise.recommendedUnit else { return nil }
        return "\(Formatters.formatFloat(load)) \(unit.rawValue)"
    }
}
