import Foundation
import SwiftData

/// One movement occurrence's performed history, pre-gathered by the caller
/// from `MobilitySession`/`MobilityEntry`/`MobilityResult`/
/// `MobilityResultEvidence` — mirroring `MobilityProgressionEvaluator`'s
/// "pure kernel, caller gathers evidence" split (spec §5.3). Nothing in
/// `MobilityAnalyticsService` fetches or joins these itself.
struct MobilityAnalyticsOccurrence {
    let session: MobilitySession
    let entry: MobilityEntry
    let result: MobilityResult
    let evidence: MobilityResultEvidence?

    init(session: MobilitySession, entry: MobilityEntry, result: MobilityResult, evidence: MobilityResultEvidence?) {
        self.session = session
        self.entry = entry
        self.result = result
        self.evidence = evidence
    }
}

/// Computes every mobility history/progress surface `MobilityAnalyticsPolicy`
/// is responsible for gating, deliberately as separate typed results rather
/// than one merged figure — there is no `MobilityAnalyticsSummary` type and
/// none of these functions feed into each other. That absence is the
/// enforcement mechanism for "do not create one universal mobility score":
/// a caller that wanted a single number would have to invent it outside
/// this file, in full view of a reviewer, rather than finding one already
/// offered here.
///
/// Every function reads only what the caller already gathered from snapshot
/// evidence; nothing here queries a live `MobilityDefinition`/
/// `MobilityRoutineItem`/`MobilityMovementOccurrenceDefinition`.
enum MobilityAnalyticsService {
    // MARK: 1. Session duration history

    struct SessionDurationPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var duration: TimeInterval
    }

    static func sessionDurationHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [SessionDurationPoint] {
        var seenSessionIDs = Set<UUID>()
        var points: [SessionDurationPoint] = []
        for occurrence in occurrences.sorted(by: { $0.session.startTime < $1.session.startTime }) {
            let session = occurrence.session
            guard seenSessionIDs.insert(session.id).inserted, let endTime = session.endTime else { continue }
            points.append(SessionDurationPoint(id: session.id, date: session.startTime, duration: endTime.timeIntervalSince(session.startTime)))
        }
        return points
    }

    // MARK: 2. Development hold time

    struct SessionMetricPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var value: Int
    }

    /// Total performed duration, seconds, per completed session — counting
    /// only occurrences `policy.contributesToDevelopmentVolume` accepts.
    /// A preparation-purpose occurrence's held seconds never appear here.
    static func developmentHoldTimeHistory(
        _ occurrences: [MobilityAnalyticsOccurrence],
        policy: MobilityAnalyticsPolicy
    ) -> [SessionMetricPoint] {
        sessionMetricHistory(occurrences) { group in
            group
                .filter { policy.contributesToDevelopmentVolume(entry: $0.entry) }
                .compactMap { $0.result.performedDurationSeconds }
                .reduce(0, +)
        }
    }

    // MARK: 3. Controlled repetitions

    /// Total performed repetitions, per completed session — counting only
    /// development-volume-eligible occurrences whose recorded movement
    /// quality was `.controlled`/`.mostlyControlled` (an occurrence with no
    /// recorded quality is not excluded by a gate it was never asked to
    /// clear).
    static func controlledRepetitionHistory(
        _ occurrences: [MobilityAnalyticsOccurrence],
        policy: MobilityAnalyticsPolicy
    ) -> [SessionMetricPoint] {
        sessionMetricHistory(occurrences) { group in
            group
                .filter { policy.contributesToDevelopmentVolume(entry: $0.entry) }
                .filter { occurrence in
                    switch occurrence.evidence?.movementQuality {
                    case .none: return true
                    case .controlled, .mostlyControlled: return true
                    case .compensationObserved, .unableToAssess: return false
                    }
                }
                .compactMap { $0.result.performedRepetitions }
                .reduce(0, +)
        }
    }

    // MARK: 4. Completed vs. prescribed

    struct CompletionPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var completedCount: Int
        var prescribedCount: Int
    }

    static func completionHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [CompletionPoint] {
        groupedBySession(occurrences).map { session, group in
            CompletionPoint(
                id: session.id,
                date: session.startTime,
                completedCount: group.filter { $0.result.status == .completed }.count,
                prescribedCount: group.count
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: 5. Side history

    static func sideHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [MobilitySide: Int] {
        Dictionary(grouping: occurrences, by: { $0.result.side }).mapValues(\.count)
    }

    // MARK: 6. Side symmetry

    /// A paired left/right observation for one movement occurrence.
    ///
    /// This deliberately keeps the two sides separate. `absoluteDifference`
    /// is a descriptive distance between the recorded values, not a score or
    /// a diagnosis. An entry with only one side, or with a missing performed
    /// value on either side, does not produce a point: missing evidence stays
    /// missing rather than becoming zero.
    struct SideSymmetryPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var trackingType: MobilityTrackingType
        var leftValue: Int
        var rightValue: Int
        var absoluteDifference: Int
    }

    static func sideSymmetryHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [SideSymmetryPoint] {
        struct Pair {
            var session: MobilitySession
            var entry: MobilityEntry
            var left: MobilityAnalyticsOccurrence?
            var right: MobilityAnalyticsOccurrence?
        }

        var pairs: [UUID: Pair] = [:]
        for occurrence in occurrences where occurrence.session.status == .completed {
            guard occurrence.result.status == .completed,
                  occurrence.result.side == .left || occurrence.result.side == .right else { continue }
            var pair = pairs[occurrence.entry.id] ?? Pair(
                session: occurrence.session,
                entry: occurrence.entry,
                left: nil,
                right: nil
            )
            if occurrence.result.side == .left {
                pair.left = occurrence
            } else {
                pair.right = occurrence
            }
            pairs[occurrence.entry.id] = pair
        }

        return pairs.values.compactMap { pair in
            guard let left = pair.left,
                  let right = pair.right else { return nil }
            let values: (Int?, Int?)
            switch pair.entry.trackingType {
            case .duration:
                values = (left.result.performedDurationSeconds, right.result.performedDurationSeconds)
            case .repetitions:
                values = (left.result.performedRepetitions, right.result.performedRepetitions)
            }
            guard let leftValue = values.0, let rightValue = values.1 else { return nil }
            return SideSymmetryPoint(
                id: pair.entry.id,
                date: pair.session.startTime,
                trackingType: pair.entry.trackingType,
                leftValue: leftValue,
                rightValue: rightValue,
                absoluteDifference: abs(leftValue - rightValue)
            )
        }
        .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }

    // MARK: 7. Weekly frequency

    /// Completed sessions per calendar week, keyed by each week's start
    /// date. A session that contains more than one occurrence in the input
    /// still counts once.
    static func weeklyFrequency(
        _ occurrences: [MobilityAnalyticsOccurrence],
        calendar: Calendar = .current
    ) -> [Date: Int] {
        var sessionStartDates: [UUID: Date] = [:]
        for occurrence in occurrences where occurrence.session.status == .completed {
            sessionStartDates[occurrence.session.id] = occurrence.session.startTime
        }
        var counts: [Date: Int] = [:]
        for startTime in sessionStartDates.values {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: startTime)?.start else { continue }
            counts[weekStart, default: 0] += 1
        }
        return counts
    }

    // MARK: 8. Support history

    struct SupportPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var level: MobilitySupportLevel
    }

    /// Effective support level (performed, falling back to prescribed) per
    /// result, matching the same "effective support" resolution
    /// `MobilityResultEvidence.isComparable(to:)`/
    /// `StandardMobilityAnalyticsPolicy` use for comparison eligibility.
    static func supportHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [SupportPoint] {
        occurrences
            .compactMap { occurrence -> SupportPoint? in
                guard let level = occurrence.evidence?.performedSupportLevel ?? occurrence.evidence?.supportLevelSnapshot else {
                    return nil
                }
                return SupportPoint(id: occurrence.result.id, date: occurrence.session.startTime, level: level)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: 9. Assistance history

    struct AssistancePoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var assistanceType: MobilityAssistanceType?
        var level: Int?
    }

    static func assistanceHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [AssistancePoint] {
        occurrences
            .compactMap { occurrence -> AssistancePoint? in
                guard let prescription = occurrence.evidence?.assistancePrescriptionSnapshot else { return nil }
                let level = occurrence.evidence?.performedAssistanceLevel ?? prescription.level
                return AssistancePoint(
                    id: occurrence.result.id,
                    date: occurrence.session.startTime,
                    assistanceType: prescription.assistanceType,
                    level: level
                )
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: 10. Load history

    struct LoadPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var value: Double
        var unit: MobilityLoadUnit?
    }

    static func loadHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [LoadPoint] {
        occurrences
            .compactMap { occurrence -> LoadPoint? in
                guard let value = occurrence.result.performedLoadValue else { return nil }
                return LoadPoint(id: occurrence.result.id, date: occurrence.session.startTime, value: value, unit: occurrence.result.performedLoadUnit)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: 11. Comparable range history (assessment bridge)

    /// Read-only bridge into assessment history for informational display —
    /// never training evidence, never mutated by anything here. Reuses
    /// `MobilityAssessmentComparisonService`/`MobilityAssessmentHistoryQuery`
    /// verbatim (`MobilityAssessmentServices.swift`), the same rules the
    /// progression bridge (`MobilityProgressionRecommendationService
    /// .comparableAssessmentReached`) and the assessment history screen use.
    ///
    /// Callers pass the assessment catalogue key explicitly (from
    /// `MobilityMovementOccurrenceDefinition.linkedAssessmentCatalogueKey`
    /// for a program-run occurrence, or any other definite source) — there
    /// is no field on `MobilityEntry`/`MobilityResultEvidence` today that
    /// auto-resolves a training occurrence back to its assessment
    /// definition, so this is not wired to discover the key on its own. See
    /// the handoff report for why that auto-discovery was deliberately left
    /// out of this slice.
    @MainActor
    static func comparableRangeHistory(
        assessmentCatalogueKey: String,
        side: MobilityAssessmentSide,
        using modelContext: ModelContext
    ) -> [MobilityAssessmentComparison] {
        guard let history = try? MobilityAssessmentHistoryQuery.results(
            definitionCatalogueKey: assessmentCatalogueKey,
            side: side,
            using: modelContext
        ), history.isEmpty == false else {
            return []
        }
        return history
            .sorted { $0.createdAt < $1.createdAt }
            .map { MobilityAssessmentComparisonService.latestComparison(for: $0, among: history) }
    }

    // MARK: 12. Movement quality observations

    struct QualityPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var quality: MobilityMovementQuality
    }

    static func movementQualityHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [QualityPoint] {
        occurrences
            .compactMap { occurrence -> QualityPoint? in
                guard let quality = occurrence.evidence?.movementQuality else { return nil }
                return QualityPoint(id: occurrence.result.id, date: occurrence.session.startTime, quality: quality)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: 13. Stop-signal history

    struct StopSignalPoint: Identifiable, Equatable {
        var id: UUID
        var date: Date
        var sensation: MobilitySensation
    }

    /// Pain/numbness/tingling occurrences, surfaced as history even though
    /// `MobilityResultEvidence.isProgressionEligible` (and therefore
    /// `MobilityProgressionEvaluator`) excludes every one of them from
    /// progression evidence. Exclusion from progression is not exclusion
    /// from the historical record.
    static func stopSignalHistory(_ occurrences: [MobilityAnalyticsOccurrence]) -> [StopSignalPoint] {
        occurrences
            .compactMap { occurrence -> StopSignalPoint? in
                guard let sensation = occurrence.evidence?.sensation, sensation.isStopSignal else { return nil }
                return StopSignalPoint(id: occurrence.result.id, date: occurrence.session.startTime, sensation: sensation)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Shared grouping helpers

    private static func groupedBySession(
        _ occurrences: [MobilityAnalyticsOccurrence]
    ) -> [(MobilitySession, [MobilityAnalyticsOccurrence])] {
        Dictionary(grouping: occurrences, by: { $0.session.id })
            .compactMap { _, group -> (MobilitySession, [MobilityAnalyticsOccurrence])? in
                guard let session = group.first?.session, session.status == .completed else { return nil }
                return (session, group)
            }
    }

    private static func sessionMetricHistory(
        _ occurrences: [MobilityAnalyticsOccurrence],
        reducing: ([MobilityAnalyticsOccurrence]) -> Int
    ) -> [SessionMetricPoint] {
        groupedBySession(occurrences)
            .map { session, group in
                SessionMetricPoint(id: session.id, date: session.startTime, value: reducing(group))
            }
            .sorted { $0.date < $1.date }
    }
}
