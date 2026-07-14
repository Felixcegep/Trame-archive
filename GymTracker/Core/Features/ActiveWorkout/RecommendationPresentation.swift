import Foundation

struct RecommendationPresentation {
    let decision: DoubleProgressionDecision
    let recommendedLoad: Float
    let unit: WeightType
    let priorLoad: Float
    let requiredSets: Int
    let repCeiling: Int

    init?(entry: ExerciceEntry) {
        guard
            let decision = entry.recommendedDecision,
            let recommendedLoad = entry.recommendedLoad,
            let unit = entry.recommendedUnit,
            let priorLoad = entry.recommendationPriorLoad,
            let requiredSets = entry.recommendationRequiredSets,
            let repCeiling = entry.recommendationRepCeiling,
            entry.recommendationCompletedSets != nil,
            entry.recommendationPriorWorkoutDate != nil
        else {
            return nil
        }

        self.decision = decision
        self.recommendedLoad = recommendedLoad
        self.unit = unit
        self.priorLoad = priorLoad
        self.requiredSets = requiredSets
        self.repCeiling = repCeiling
    }

    var explanation: String {
        switch decision {
        case .hold:
            let format = String(
                localized: "progression.recommendation.hold",
                defaultValue: "Keep %1$@ %2$@ — not every set reached %3$lld reps last time."
            )
            return String(
                format: format,
                Formatters.formatFloat(priorLoad),
                unit.rawValue,
                Int64(repCeiling)
            )
        case .increase:
            let format = String(
                localized: "progression.recommendation.increase",
                defaultValue: "%1$@ %2$@ recommended — you completed %3$lld×%4$lld at %5$@ %2$@ last time."
            )
            return String(
                format: format,
                Formatters.formatFloat(recommendedLoad),
                unit.rawValue,
                Int64(requiredSets),
                Int64(repCeiling),
                Formatters.formatFloat(priorLoad)
            )
        }
    }

    var appliedLoadText: String {
        "\(Formatters.formatFloat(recommendedLoad)) \(unit.rawValue)"
    }
}
