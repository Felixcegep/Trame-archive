import Foundation
import SwiftData

/// Render-ready projections for the Mobility Progress surface.
///
/// These are presentation values, not persisted truth. The loader gathers
/// the immutable session/entry/result/evidence graph once, then delegates all
/// metric rules to `MobilityAnalyticsService` and `MobilityAnalyticsPolicy`.
struct MobilityProgressAnalytics: Equatable, Sendable {
    struct WeeklyFrequencyPoint: Identifiable, Equatable, Sendable {
        var id: Date { weekStart }
        let weekStart: Date
        let sessionCount: Int
    }

    struct HoldTimePoint: Identifiable, Equatable, Sendable {
        var id: UUID { sessionID }
        let sessionID: UUID
        let date: Date
        let totalSeconds: Int
    }

    struct SideSymmetryPoint: Identifiable, Equatable, Sendable {
        var id: UUID { entryID }
        let entryID: UUID
        let date: Date
        let trackingType: MobilityTrackingType
        let leftValue: Int
        let rightValue: Int
        let absoluteDifference: Int
    }

    struct StopSignalCountPoint: Identifiable, Equatable, Sendable {
        var id: Date { weekStart }
        let weekStart: Date
        let count: Int
    }

    let weeklyFrequency: [WeeklyFrequencyPoint]
    let holdTimeTrend: [HoldTimePoint]
    let sideSymmetry: [SideSymmetryPoint]
    let stopSignalCounts: [StopSignalCountPoint]

    static let empty = MobilityProgressAnalytics(
        weeklyFrequency: [],
        holdTimeTrend: [],
        sideSymmetry: [],
        stopSignalCounts: []
    )
}

/// SwiftData boundary for mobility progress. Like `ActiveWorkoutViewModel`,
/// this type owns the context-dependent loading side and leaves metric rules
/// in pure services. It is main-actor isolated because `ModelContext` is not
/// safe to move between actors.
@MainActor
struct MobilityProgressAnalyticsService {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func analytics(
        referenceDate: Date = .now,
        weekCount: Int = 12,
        calendar: Calendar = .current
    ) throws -> MobilityProgressAnalytics {
        guard weekCount > 0 else { return .empty }

        let weekStarts = weekStarts(
            referenceDate: referenceDate,
            weekCount: weekCount,
            calendar: calendar
        )
        guard let firstWeekStart = weekStarts.first else { return .empty }

        // Fetch entries/results explicitly rather than relying on relationship
        // faults. This keeps this boundary correct after another context has
        // committed a session. Evidence is then resolved only for results in
        // the requested window instead of retaining the complete sidecar table.
        let entries = try modelContext.fetch(FetchDescriptor<MobilityEntry>())
        let results = try modelContext.fetch(FetchDescriptor<MobilityResult>())
        let entryByResultID = Dictionary(
            entries.flatMap { entry in entry.results.map { ($0.id, entry) } },
            uniquingKeysWith: { first, _ in first }
        )

        let occurrenceRoots = results.compactMap { result -> (MobilitySession, MobilityEntry, MobilityResult)? in
            guard let entry = result.entry ?? entryByResultID[result.id],
                  let session = entry.session,
                  session.startTime >= firstWeekStart,
                  session.startTime <= referenceDate else { return nil }
            return (session, entry, result)
        }
        let relevantResultIDs = Set(occurrenceRoots.map { $0.2.id })
        let evidence = try modelContext.fetch(FetchDescriptor<MobilityResultEvidence>(
            predicate: #Predicate { $0.recordedAt >= firstWeekStart }
        ))
        let evidenceByResultID = Dictionary(
            evidence.lazy
                .filter { relevantResultIDs.contains($0.resultID) }
                .map { ($0.resultID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let occurrences = occurrenceRoots.map { session, entry, result in
            MobilityAnalyticsOccurrence(
                session: session,
                entry: entry,
                result: result,
                evidence: evidenceByResultID[result.id]
            )
        }

        let policy = StandardMobilityAnalyticsPolicy(evidenceByResultID: evidenceByResultID)
        let frequency = MobilityAnalyticsService.weeklyFrequency(occurrences, calendar: calendar)
        let holdTime = MobilityAnalyticsService.developmentHoldTimeHistory(occurrences, policy: policy)
        let symmetry = MobilityAnalyticsService.sideSymmetryHistory(occurrences)
        let stopSignals = MobilityAnalyticsService.stopSignalHistory(occurrences)

        let weeklyFrequency = weekStarts.map {
            MobilityProgressAnalytics.WeeklyFrequencyPoint(
                weekStart: $0,
                sessionCount: frequency[$0, default: 0]
            )
        }
        let stopSignalCountsByWeek = Dictionary(
            grouping: stopSignals,
            by: { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start }
        )
        let stopSignalCounts = weekStarts.map { weekStart in
            MobilityProgressAnalytics.StopSignalCountPoint(
                weekStart: weekStart,
                count: stopSignalCountsByWeek[weekStart]?.count ?? 0
            )
        }

        return MobilityProgressAnalytics(
            weeklyFrequency: weeklyFrequency,
            holdTimeTrend: holdTime.map {
                MobilityProgressAnalytics.HoldTimePoint(
                    sessionID: $0.id,
                    date: $0.date,
                    totalSeconds: $0.value
                )
            },
            sideSymmetry: symmetry.map {
                MobilityProgressAnalytics.SideSymmetryPoint(
                    entryID: $0.id,
                    date: $0.date,
                    trackingType: $0.trackingType,
                    leftValue: $0.leftValue,
                    rightValue: $0.rightValue,
                    absoluteDifference: $0.absoluteDifference
                )
            },
            stopSignalCounts: stopSignalCounts
        )
    }

    private func weekStarts(
        referenceDate: Date,
        weekCount: Int,
        calendar: Calendar
    ) -> [Date] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }
        return (0..<weekCount).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1 - offset), to: currentWeek)
        }
    }
}
