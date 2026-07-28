import Foundation

enum RecommendationAction {
    case accept
    case keepLast
    case edit
}

enum RecommendationPresentationState {
    case recommendation(RecommendationPresentation)
    case insufficientHistory

    init?(entry: ExerciseEntry) {
        if let presentation = RecommendationPresentation(entry: entry) {
            self = .recommendation(presentation)
            return
        }

        guard
            let rule = entry.prescribedProgressionRule,
            let requiredSets = entry.prescribedSets,
            let repCeiling = entry.prescribedRepRangeMaximum,
            ProgressionSnapshotService.isEligible(
                exercise: entry.exercise,
                rule: rule,
                requiredSets: requiredSets,
                repCeiling: repCeiling
            )
        else {
            return nil
        }

        self = .insufficientHistory
    }

    /// The "Why?" model for `.insufficientHistory`. This is a real limitation,
    /// not an error and not an empty sheet: no comparable prior performance is
    /// recorded yet, so no load can be recommended. `noteMissingEvidence` is
    /// the only path that can express that, which is why this doesn't just add
    /// a plain body to `.confidence` directly.
    static func insufficientHistoryWhyModel() -> WhyExplanationModel {
        var builder = WhyExplanationBuilder(
            title: String(localized: "progression.why.title", defaultValue: "Why?"),
            isDecision: false
        )

        builder.noteMissingEvidence(
            qualifier: String(
                localized: "progression.why.insufficientHistory.qualifier",
                defaultValue: "No load is recommended yet because there's no comparable prior performance recorded."
            ),
            missing: [
                String(
                    localized: "progression.why.insufficientHistory.missing",
                    defaultValue: "A completed workout for this exercise that reached your set and rep target"
                )
            ]
        )

        return builder.build()
    }
}

struct RecommendationPresentation: WhyExplainable {
    let decision: DoubleProgressionDecision
    let recommendedLoad: Float
    let unit: WeightType
    let priorLoad: Float
    let requiredSets: Int
    let repCeiling: Int
    let completedSets: Int
    let priorWorkoutDate: Date

    init?(entry: ExerciseEntry) {
        guard
            let decision = entry.recommendedDecision,
            let recommendedLoad = entry.recommendedLoad,
            let unit = entry.recommendedUnit,
            let priorLoad = entry.recommendationPriorLoad,
            let requiredSets = entry.recommendationRequiredSets,
            let repCeiling = entry.recommendationRepCeiling,
            let completedSets = entry.recommendationCompletedSets,
            let priorWorkoutDate = entry.recommendationPriorWorkoutDate
        else {
            return nil
        }

        self.decision = decision
        self.recommendedLoad = recommendedLoad
        self.unit = unit
        self.priorLoad = priorLoad
        self.requiredSets = requiredSets
        self.repCeiling = repCeiling
        self.completedSets = completedSets
        self.priorWorkoutDate = priorWorkoutDate
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

    var priorLoadText: String {
        "\(Formatters.formatFloat(priorLoad)) \(unit.rawValue)"
    }

    /// Structured expansion of `explanation`. `explanation` stays the card's
    /// fast-path one-liner; this is what the "Why?" sheet renders — one
    /// section per evidence field actually captured on the entry, never a
    /// re-derivation of the recommendation itself.
    var whyModel: WhyExplanationModel {
        var builder = WhyExplanationBuilder(
            title: String(localized: "progression.why.title", defaultValue: "Why?"),
            isDecision: true
        )

        switch decision {
        case .hold:
            let format = String(
                localized: "progression.why.whatChanged.hold",
                defaultValue: "Hold at %1$@ %2$@."
            )
            builder.add(.whatChanged, body: String(format: format, Formatters.formatFloat(priorLoad), unit.rawValue))
        case .increase:
            let format = String(
                localized: "progression.why.whatChanged.increase",
                defaultValue: "Increase to %1$@ %2$@."
            )
            builder.add(.whatChanged, body: String(format: format, Formatters.formatFloat(recommendedLoad), unit.rawValue))
        }

        let priorLoadLine = String(
            format: String(
                localized: "progression.why.evidence.priorLoad",
                defaultValue: "Prior load: %1$@ %2$@"
            ),
            Formatters.formatFloat(priorLoad),
            unit.rawValue
        )
        let targetLine = String(
            format: String(
                localized: "progression.why.evidence.target",
                defaultValue: "Target: %1$lld sets \u{00d7} %2$lld reps"
            ),
            Int64(requiredSets),
            Int64(repCeiling)
        )
        let completedSetsLine = String(
            format: String(
                localized: "progression.why.evidence.completedSets",
                defaultValue: "%1$lld sets completed last time"
            ),
            Int64(completedSets)
        )
        let priorWorkoutDateLine = String(
            format: String(
                localized: "progression.why.evidence.priorWorkoutDate",
                defaultValue: "Last recorded: %@"
            ),
            priorWorkoutDate.formatted(date: .abbreviated, time: .omitted)
        )
        builder.add(.evidenceUsed, items: [priorLoadLine, targetLine, completedSetsLine, priorWorkoutDateLine])

        builder.add(
            .ifYouAccept,
            body: String(
                format: String(
                    localized: "progression.why.ifYouAccept",
                    defaultValue: "Applies %1$@ %2$@ to this exercise's remaining sets today."
                ),
                Formatters.formatFloat(recommendedLoad),
                unit.rawValue
            )
        )
        builder.add(
            .ifYouDecline,
            body: String(
                format: String(
                    localized: "progression.why.ifYouDecline",
                    defaultValue: "Keeps %1$@ %2$@ for this exercise's remaining sets today. That's an ordinary choice, not a setback."
                ),
                Formatters.formatFloat(priorLoad),
                unit.rawValue
            )
        )

        return builder.build()
    }
}
