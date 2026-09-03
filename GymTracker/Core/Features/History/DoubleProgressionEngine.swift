import Foundation

struct ProgressionEvidence: Equatable, Sendable {
    let completedSets: Int
    let requiredSets: Int
    let repCeiling: Int
    let priorLoad: Float
    let unit: WeightType
    let workoutDate: Date
}

struct DoubleProgressionRecommendation: Equatable, Sendable {
    let decision: DoubleProgressionDecision
    let recommendedLoad: Float
    let unit: WeightType
    let evidence: ProgressionEvidence

    var explanation: String {
        let load = Formatters.formatFloat(evidence.priorLoad)
        let recommended = Formatters.formatFloat(recommendedLoad)
        switch decision {
        case .hold:
            return "Keep \(load) \(unit.rawValue): not every required set reached \(evidence.repCeiling) reps last time."
        case .increase:
            return "\(recommended) \(unit.rawValue) recommended because you completed \(evidence.requiredSets) sets at \(evidence.repCeiling)+ reps with \(load) \(unit.rawValue) last time."
        }
    }
}

/// Pure progression logic over completed historical truth. It intentionally
/// makes no persistence decisions, which keeps manual overrides explicit.
enum DoubleProgressionEngine {
    static func recommend(
        from performance: PreviousExercisePerformance,
        requiredSets: Int,
        repCeiling: Int,
        increment: Float
    ) -> DoubleProgressionRecommendation? {
        guard requiredSets > 0, increment > 0 else { return nil }
        let required = performance.sets.sorted { $0.orderIndex < $1.orderIndex }.prefix(requiredSets)
        guard required.count == requiredSets, let latest = required.last else { return nil }

        let unit = latest.weightType
        let priorLoad = UnitConversion.weight(latest.weight, from: latest.weightType, to: unit)
        let allRequiredSetsReachedCeiling = required.allSatisfy { $0.repetitions >= Float(repCeiling) }
        let decision: DoubleProgressionDecision = allRequiredSetsReachedCeiling ? .increase : .hold
        let recommendedLoad = decision == .increase ? priorLoad + increment : priorLoad

        return DoubleProgressionRecommendation(
            decision: decision,
            recommendedLoad: recommendedLoad,
            unit: unit,
            evidence: ProgressionEvidence(
                completedSets: performance.completedSetCount,
                requiredSets: requiredSets,
                repCeiling: repCeiling,
                priorLoad: priorLoad,
                unit: unit,
                workoutDate: performance.workoutDate
            )
        )
    }
}

/// Scores a proposed load against what is already on the bar today.
///
/// Double progression only knows last session. If today's working weight is
/// already far from that history, presenting last-session + increment as the
/// default is worse than holding the current reality.
enum LoadRecommendationRealism {
    static func maximumPlausibleJump(priorLoad: Float, increment: Float) -> Float {
        max(increment * 2, abs(priorLoad) * 0.15)
    }

    static func workingLoad(on entry: ExerciseEntry) -> (weight: Float, unit: WeightType)? {
        let sets = entry.orderedSets.filter { $0.setType != .warmup }
        let candidate = sets.first(where: { $0.done == false }) ?? sets.last
        guard let candidate, candidate.weight > 0 else { return nil }
        return (candidate.weight, candidate.weightType)
    }

    /// When today's working load already disagrees with the historical jump,
    /// hold the working load instead of recommending a value that far away.
    static func resolved(
        proposed: Float,
        decision: DoubleProgressionDecision,
        prior: Float,
        unit: WeightType,
        working: (weight: Float, unit: WeightType)?
    ) -> (decision: DoubleProgressionDecision, load: Float) {
        let increment = Constants.Progression.increment(for: unit)
        let limit = maximumPlausibleJump(priorLoad: prior, increment: increment)

        guard let working else {
            return (decision, proposed)
        }

        let workingInUnit = UnitConversion.weight(working.weight, from: working.unit, to: unit)
        guard workingInUnit > 0 else {
            return (decision, proposed)
        }

        let distanceFromWorking = abs(proposed - workingInUnit)
        let workingDriftFromPrior = abs(workingInUnit - prior)

        if distanceFromWorking > limit, workingDriftFromPrior > limit {
            return (.hold, workingInUnit)
        }

        return (decision, proposed)
    }
}
