import Foundation

struct ProgressionEvidence: Equatable, Sendable {
    let completedSets: Int
    let requiredSets: Int
    let repCeiling: Int
    let priorLoad: Float
    let unit: WeightType
    let workoutDate: Date
}

enum DoubleProgressionDecision: Equatable, Sendable {
    case hold
    case increase
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
