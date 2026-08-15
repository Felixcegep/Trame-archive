import Foundation

/// A value-only handoff from the CE6.1 analytics projection to the dashboard.
/// This layer deliberately performs no workout or component calculations.
enum WeightliftingDashboardAvailability: Equatable {
    case empty
    case sparse
    case populated
}

enum WeightliftingEvidenceCount: Equatable {
    case observed(Int)
    case unavailable

    var displayText: String {
        switch self {
        case let .observed(value): "\(value)"
        case .unavailable: String(localized: "Not recorded")
        }
    }
}

struct WeightliftingDashboardMetric: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String?
    let detail: String?
    let evidenceAvailable: Bool
}

struct WeightliftingComponentOutcomeSummary: Equatable, Identifiable {
    let id: String
    let title: String
    let made: WeightliftingEvidenceCount
    let partial: WeightliftingEvidenceCount
    let missed: WeightliftingEvidenceCount
    let skipped: WeightliftingEvidenceCount
    let notStarted: WeightliftingEvidenceCount
}

struct WeightliftingRecentAttempt: Equatable, Identifiable {
    let id: UUID
    let date: Date
    let load: String
    let outcome: OlympicAttemptOutcome
    let components: [ComplexComponentOutcome]
    var componentLabels: [String] = []
}

struct WeightliftingAttemptOutcomeSummary: Equatable {
    let made: Int
    let partial: Int
    let missed: Int
    let skipped: Int
    let notStarted: Int
}

/// Presentation state for the specialist dashboard. CE6.1 supplies these
/// facts from completed snapshots; CE6.2 only decides hierarchy and wording.
struct WeightliftingDashboardPresentation: Equatable {
    let availability: WeightliftingDashboardAvailability
    let fullLiftBest: WeightliftingDashboardMetric?
    let cleanBest: WeightliftingDashboardMetric?
    let jerkAfterCleanBest: WeightliftingDashboardMetric?
    let attemptSummary: String?
    let componentOutcomes: [WeightliftingComponentOutcomeSummary]
    let qualityTrend: String?
    let evidenceNote: String?
    var fullLiftBests: [WeightliftingDashboardMetric] = []
    var attemptOutcomes: WeightliftingAttemptOutcomeSummary?
    var recentAttempts: [WeightliftingRecentAttempt] = []

    init(
        availability: WeightliftingDashboardAvailability,
        fullLiftBest: WeightliftingDashboardMetric?,
        cleanBest: WeightliftingDashboardMetric?,
        jerkAfterCleanBest: WeightliftingDashboardMetric?,
        attemptSummary: String?,
        componentOutcomes: [WeightliftingComponentOutcomeSummary],
        qualityTrend: String?,
        evidenceNote: String?,
        fullLiftBests: [WeightliftingDashboardMetric] = [],
        attemptOutcomes: WeightliftingAttemptOutcomeSummary? = nil,
        recentAttempts: [WeightliftingRecentAttempt] = []
    ) {
        self.availability = availability
        self.fullLiftBest = fullLiftBest
        self.cleanBest = cleanBest
        self.jerkAfterCleanBest = jerkAfterCleanBest
        self.attemptSummary = attemptSummary
        self.componentOutcomes = componentOutcomes
        self.qualityTrend = qualityTrend
        self.evidenceNote = evidenceNote
        self.fullLiftBests = fullLiftBests
        self.attemptOutcomes = attemptOutcomes
        self.recentAttempts = recentAttempts
    }

    static let empty = Self(
        availability: .empty,
        fullLiftBest: nil,
        cleanBest: nil,
        jerkAfterCleanBest: nil,
        attemptSummary: nil,
        componentOutcomes: [],
        qualityTrend: nil,
        evidenceNote: nil,
        fullLiftBests: [],
        attemptOutcomes: nil,
        recentAttempts: []
    )

    var hasFullLiftEvidence: Bool {
        fullLiftBest?.evidenceAvailable == true
            || fullLiftBests.contains(where: \.evidenceAvailable)
    }

    var hasComponentEvidence: Bool {
        componentOutcomes.isEmpty == false
            || cleanBest?.evidenceAvailable == true
            || jerkAfterCleanBest?.evidenceAvailable == true
    }

    static func make(projection: WeightliftingAnalyticsProjection) -> Self {
        let attemptCount = projection.complexOutcomes.count
        let bests = projection.bestCompleteSuccessfulLiftsByUnit.map { lift in
            WeightliftingDashboardMetric(
                id: "full-lift-best-\(lift.weightType.rawValue)",
                title: String(localized: "Best complete parent lift"),
                value: String(format: String(localized: "%.1f %@"), Double(lift.weight), lift.weightType.rawValue),
                detail: lift.date.formatted(date: .abbreviated, time: .omitted),
                evidenceAvailable: true
            )
        }
        let best = bests.count == 1 ? bests.first : nil
        let clean = successMetric(
            projection.cleanSuccess,
            id: "clean-success",
            title: String(localized: "Clean success")
        )
        let jerk = successMetric(
            projection.jerkAfterCleanSuccess,
            id: "jerk-after-clean-success",
            title: String(localized: "Jerk after successful clean")
        )
        let outcomes = projection.componentFailureDistribution.map { distribution in
            WeightliftingComponentOutcomeSummary(
                id: distribution.role.rawValue,
                title: componentTitle(distribution.role),
                made: .observed(distribution.completed),
                partial: .observed(distribution.partial),
                missed: .observed(distribution.missed),
                skipped: .observed(distribution.skipped),
                notStarted: .observed(distribution.notStarted)
            )
        }
        let quality = projection.qualityTrend.last.map { point in
            String(
                format: String(localized: "%@ · %lld observed attempts: %lld excellent, %lld acceptable, %lld technically poor, %lld missed."),
                point.date.formatted(date: .abbreviated, time: .omitted),
                Int64(point.sampleCount),
                Int64(point.excellent),
                Int64(point.acceptable),
                Int64(point.technicallyPoor),
                Int64(point.missed)
            )
        }
        let hasEvidence = attemptCount > 0
        let attemptOutcomes = hasEvidence ? WeightliftingAttemptOutcomeSummary(
            made: projection.complexOutcomes.filter { $0.outcome == .made }.count,
            partial: projection.complexOutcomes.filter { $0.outcome == .partial }.count,
            missed: projection.complexOutcomes.filter { $0.outcome == .missed }.count,
            skipped: projection.complexOutcomes.filter { $0.outcome == .skipped }.count,
            notStarted: projection.complexOutcomes.filter { $0.outcome == .notStarted }.count
        ) : nil
        return Self(
            availability: hasEvidence ? (bests.isEmpty ? .sparse : .populated) : .empty,
            fullLiftBest: best,
            cleanBest: clean,
            jerkAfterCleanBest: jerk,
            attemptSummary: hasEvidence
                ? (attemptCount == 1
                    ? String(localized: "1 recorded complex attempt")
                    : String(format: String(localized: "%lld recorded complex attempts"), Int64(attemptCount)))
                : nil,
            componentOutcomes: outcomes,
            qualityTrend: quality,
            evidenceNote: projection.bestCompleteSuccessfulLiftsByUnit.count > 1
                ? String(localized: "Best complete parent lifts are kept separate by weight unit and are not ranked against each other. Component outcomes remain evidence inside a lift.")
                : String(localized: "Component outcomes are evidence inside a lift; they are never labelled as full-lift records. Lift quality is recorded observation, never inferred from load."),
            fullLiftBests: bests,
            attemptOutcomes: attemptOutcomes,
            recentAttempts: projection.complexOutcomes.suffix(5).reversed().map { attempt in
                WeightliftingRecentAttempt(
                    id: attempt.setID,
                    date: attempt.date,
                    load: String(format: String(localized: "%.1f %@"), Double(attempt.weight), attempt.weightType.rawValue),
                    outcome: attempt.outcome,
                    components: attempt.components.map(\.outcome),
                    componentLabels: attempt.components.map { component in
                        component.role == .unknown
                            ? component.exerciseNameSnapshot
                            : componentTitle(component.role)
                    }
                )
            }
        )
    }

    private static func successMetric(
        _ summary: WeightliftingComponentSuccessSummary?,
        id: String,
        title: String
    ) -> WeightliftingDashboardMetric? {
        guard let summary else { return nil }
        let percent = Int((summary.successRate ?? 0) * 100)
        return WeightliftingDashboardMetric(
            id: id,
            title: title,
            value: String(format: String(localized: "%lld of %lld"), Int64(summary.successes), Int64(summary.attempts)),
            detail: String(format: String(localized: "%lld%% of observed attempts"), Int64(percent)),
            evidenceAvailable: true
        )
    }

    private static func componentTitle(_ role: WeightliftingComponentRole) -> String {
        switch role {
        case .clean: String(localized: "Clean")
        case .jerk: String(localized: "Jerk")
        case .snatch: String(localized: "Snatch")
        case .other: String(localized: "Other component")
        case .unknown: String(localized: "Unclassified component")
        }
    }
}
