import Foundation

/// How much comparable evidence a strength claim actually rests on.
///
/// An eight-week chart drawn from two sessions occupies the same width as one
/// drawn from twenty, and a sentence like "24% higher than the first recorded
/// value" reads identically in both cases. The number is true either way; the
/// *claim* it invites is not. This is the one place that decides which claims
/// the data can carry, so a chart, a takeaway line, and a section heading
/// cannot each answer that question differently.
///
/// Deliberately coarse and named, never a numeric confidence score: a
/// percentage of certainty would be a fabricated statistic, while "based on
/// two sessions" is simply what happened.
enum StrengthEvidenceLevel: Equatable {
    /// Nothing comparable recorded. Say nothing.
    case none
    /// One session. Report the value; never a direction — there is nothing to
    /// have moved *from*.
    case latestResult
    /// Two or three comparable sessions. A direction is visible but not yet a
    /// pattern, and must be labelled as early.
    case earlyComparison
    /// Four or more comparable sessions. A directional claim is warranted.
    case trend

    /// The threshold between `earlyComparison` and `trend`.
    ///
    /// Four is the smallest count where a single unusual session stops
    /// dominating the direction. It matches the four-session floor
    /// `StrengthInsightPresentationPolicy` already applies to weekly volume,
    /// so the two surfaces agree about when a pattern exists.
    static let trendSessionCount = 4

    static func resolve(comparableSessionCount count: Int) -> Self {
        switch count {
        case ..<1: .none
        case 1: .latestResult
        case 2..<trendSessionCount: .earlyComparison
        default: .trend
        }
    }

    /// Whether the data may be described as having moved in a direction.
    var allowsDirectionalClaim: Bool {
        switch self {
        case .none, .latestResult: false
        case .earlyComparison, .trend: true
        }
    }

    /// What to call this on screen. `nil` for `.none`, which gets no badge
    /// because it gets no claim.
    var title: String? {
        switch self {
        case .none: nil
        case .latestResult: String(localized: "Latest result")
        case .earlyComparison: String(localized: "Early comparison")
        case .trend: String(localized: "Trend")
        }
    }

    /// The evidence line under a chart: what the reading is based on, stated
    /// before any conclusion drawn from it.
    ///
    /// Counts are formatted as a number beside a fixed noun rather than
    /// interpolated into a sentence, so no plural agreement is required in any
    /// language.
    func evidenceText(comparableSessionCount count: Int) -> String {
        guard let title else {
            return String(localized: "No completed sessions to compare.")
        }
        let format = String(
            localized: "strength.evidence.basis",
            defaultValue: "%1$@ · completed sessions: %2$lld"
        )
        return String(format: format, title, Int64(count))
    }
}
