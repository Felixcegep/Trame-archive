import Foundation

/// Shared vocabulary for progress, analytics, and training journey services.
///
/// Principles:
/// 1. Missing data is represented as `nil`, never `0`.
/// 2. Measured vs estimated values carry explicit provenance.
/// 3. Source references enable drill-down navigation from chart points and records.

/// Standard analytics date ranges for filtering progress metrics.
enum AnalyticsDateRange: String, CaseIterable, Codable, Sendable {
    case fourWeeks
    case twelveWeeks
    case sixMonths
    case oneYear
    case allTime

    var title: String {
        switch self {
        case .fourWeeks: "4 Weeks"
        case .twelveWeeks: "12 Weeks"
        case .sixMonths: "6 Months"
        case .oneYear: "1 Year"
        case .allTime: "All Time"
        }
    }

    /// Resolves the concrete date interval ending at `referenceDate`.
    func dateInterval(endingAt referenceDate: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .allTime:
            return nil
        case .fourWeeks:
            guard let start = calendar.date(byAdding: .day, value: -28, to: referenceDate) else { return nil }
            return DateInterval(start: start, end: referenceDate)
        case .twelveWeeks:
            guard let start = calendar.date(byAdding: .day, value: -84, to: referenceDate) else { return nil }
            return DateInterval(start: start, end: referenceDate)
        case .sixMonths:
            guard let start = calendar.date(byAdding: .month, value: -6, to: referenceDate) else { return nil }
            return DateInterval(start: start, end: referenceDate)
        case .oneYear:
            guard let start = calendar.date(byAdding: .year, value: -1, to: referenceDate) else { return nil }
            return DateInterval(start: start, end: referenceDate)
        }
    }
}

/// Optional filters for scoping analytics queries.
struct AnalyticsFilter: Equatable, Sendable {
    enum WorkoutKind: Equatable, Sendable {
        case all
        case free
        case planned
    }

    var planID: UUID?
    var workoutKind: WorkoutKind

    init(planID: UUID? = nil, workoutKind: WorkoutKind = .all) {
        self.planID = planID
        self.workoutKind = workoutKind
    }
}

/// Data quality classification for analytics aggregation.
enum AnalyticsDataQuality: String, Equatable, Sendable {
    /// 0-1 data points: insufficient to calculate trends or averages.
    case insufficient
    /// 2-3 data points: sparse, directional only, must use cautious messaging.
    case sparse
    /// 4+ data points: adequate for trend evaluation.
    case adequate

    static func evaluate(sampleCount: Int) -> AnalyticsDataQuality {
        switch sampleCount {
        case 0...1: .insufficient
        case 2...3: .sparse
        default: .adequate
        }
    }
}

/// Trend comparison between current and previous period.
struct AnalyticsPeriodComparison<Value: Comparable & Sendable>: Equatable, Sendable {
    let current: Value?
    let previous: Value?
    let quality: AnalyticsDataQuality

    var isComparable: Bool {
        current != nil && previous != nil && quality != .insufficient
    }

    var trend: SessionTrend? {
        guard let current, let previous, isComparable else { return nil }
        if current > previous { return .increased }
        if current < previous { return .decreased }
        return .same
    }
}

/// Direct reference to originating entities for tap-to-source navigation.
struct AnalyticsSourceReference: Hashable, Equatable, Sendable, Identifiable {
    var id: String {
        let entryStr = entryID?.uuidString ?? "none"
        let setStr = setID?.uuidString ?? "none"
        return "\(workoutID.uuidString):\(entryStr):\(setStr)"
    }

    let workoutID: UUID
    let entryID: UUID?
    let setID: UUID?

    init(workoutID: UUID, entryID: UUID? = nil, setID: UUID? = nil) {
        self.workoutID = workoutID
        self.entryID = entryID
        self.setID = setID
    }
}

/// Structured analytics insight containing evidence tier, metrics, and explanatory metadata.
struct AnalyticsInsight: Equatable, Sendable {
    /// The number of comparable sessions analyzed.
    let sessionCount: Int
    /// Wording tier title: "Latest result" (1 session), "Early comparison" (2–3 sessions), "Trend" (4+ sessions), or nil if 0.
    let wordingTier: String?
    /// Evidence level classification (.none, .latestResult, .earlyComparison, .trend).
    let evidenceLevel: StrengthEvidenceLevel
    /// Whether directional claims (e.g. % increase/decrease) are allowed.
    let allowsDirectionalClaim: Bool
    /// Description of conditions required for sessions to be comparable.
    let comparisonConditions: String
    /// Description of evidence excluded from analysis.
    let excludedEvidence: String
    /// Description of the mathematical calculation method used.
    let calculationMethod: String
    /// Human-readable takeaway summary statement, if applicable.
    let takeaway: String?
}

