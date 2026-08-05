import Foundation
import SwiftData

/// One chapter of a lifter's training history.
///
/// A chapter is a plan run — fixed or repeating — or a stretch of free
/// training between them. Workouts attribute to a run by their recorded
/// `sourcePlanRunID` / `sourceRepeatingPlanRunID`, not by falling inside its
/// date span: a workout logged during a paused run, or a free session slipped
/// into a plan week, belongs to what it actually says it belongs to.
struct TrainingJourneyChapter: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case fixedPlan
        case repeatingPlan
        case freeTraining
    }

    let id: String
    let kind: Kind
    let title: String
    let start: Date
    let end: Date?
    /// Nil for free training, which has no lifecycle to report.
    let statusText: String?
    let completedWorkouts: Int
    let personalRecords: Int
    let mobilitySessions: Int
    let assessments: Int

    var isOngoing: Bool { end == nil }
}

struct TrainingJourneyYear: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let chapters: [TrainingJourneyChapter]
}

/// Projects the journey from records that already exist.
///
/// Deliberately not backed by persisted timeline rows: every fact here is
/// derivable from the runs, workouts and sessions already stored, and a
/// duplicate event table would be one more thing to keep true. If profiling
/// ever shows the projection is too slow, that is the moment to cache it —
/// not before.
struct TrainingJourneyBuilder: Sendable {
    let modelContext: ModelContext

    func journey(calendar: Calendar = .current) throws -> [TrainingJourneyYear] {
        let completedWorkouts = try modelContext
            .fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startTime, order: .forward)]))
            .filter { $0.status == .completed }
        let fixedRuns = try modelContext.fetch(FetchDescriptor<PlanRun>())
        let repeatingRuns = try modelContext.fetch(FetchDescriptor<RepeatingPlanRun>())
        let mobilitySessions = try modelContext
            .fetch(FetchDescriptor<MobilitySession>())
            .filter { $0.status == .completed }
        let assessments = try modelContext
            .fetch(FetchDescriptor<MobilityAssessmentSession>())
            .filter { $0.results.isEmpty == false }

        // Records are read once and bucketed by date rather than recomputed per
        // chapter, which would refetch the whole history for every run.
        let records = try PersonalRecordAnalyticsService(modelContext: modelContext)
            .personalRecords(dateRange: .allTime)

        var chapters: [TrainingJourneyChapter] = []

        for run in fixedRuns {
            let runWorkouts = completedWorkouts.filter { $0.sourcePlanRunID == run.id }
            chapters.append(
                chapter(
                    id: "fixed-\(run.id)",
                    kind: .fixedPlan,
                    title: run.sourcePlanName,
                    start: run.startDate,
                    end: run.endDate,
                    statusText: fixedStatusText(run.status),
                    workouts: runWorkouts,
                    records: records,
                    mobilitySessions: mobilitySessions,
                    assessments: assessments,
                    calendar: calendar
                )
            )
        }

        for run in repeatingRuns {
            let runWorkouts = completedWorkouts.filter { $0.sourceRepeatingPlanRunID == run.id }
            chapters.append(
                chapter(
                    id: "repeating-\(run.id)",
                    kind: .repeatingPlan,
                    title: run.sourcePlanName,
                    start: run.startedAt,
                    end: run.endedAt,
                    statusText: repeatingStatusText(run.status),
                    workouts: runWorkouts,
                    records: records,
                    mobilitySessions: mobilitySessions,
                    assessments: assessments,
                    calendar: calendar
                )
            )
        }

        // Everything not claimed by a run is free training, grouped by month so
        // a long unplanned stretch reads as a period rather than one row per
        // session.
        let unclaimed = completedWorkouts.filter {
            $0.sourcePlanRunID == nil && $0.sourceRepeatingPlanRunID == nil
        }
        let byMonth = Dictionary(grouping: unclaimed) { workout in
            calendar.dateInterval(of: .month, for: workout.startTime)?.start ?? workout.startTime
        }
        for (monthStart, monthWorkouts) in byMonth {
            // A free-training stretch in the month still underway has not
            // ended. Reporting the month boundary — or today — as its end
            // would close a chapter the lifter is still writing.
            let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
            let isOngoing = monthInterval.map { $0.contains(Date.now) } ?? false
            let end = isOngoing ? nil : monthInterval?.end
            chapters.append(
                chapter(
                    id: "free-\(monthStart.timeIntervalSince1970)",
                    kind: .freeTraining,
                    title: "Free training",
                    start: monthWorkouts.map(\.startTime).min() ?? monthStart,
                    end: end,
                    statusText: nil,
                    workouts: monthWorkouts,
                    records: records,
                    mobilitySessions: mobilitySessions,
                    assessments: assessments,
                    calendar: calendar
                )
            )
        }

        return group(chapters.sorted { $0.start > $1.start }, calendar: calendar)
    }

    // MARK: - Assembly

    private func chapter(
        id: String,
        kind: TrainingJourneyChapter.Kind,
        title: String,
        start: Date,
        end: Date?,
        statusText: String?,
        workouts: [Workout],
        records: [PersonalRecordItem],
        mobilitySessions: [MobilitySession],
        assessments: [MobilityAssessmentSession],
        calendar: Calendar
    ) -> TrainingJourneyChapter {
        // Mobility and assessments carry no plan-run link, so they are the one
        // thing attributed by date span. Stated here so the difference from
        // workout attribution is not mistaken for an oversight.
        let span = DateInterval(start: start, end: end ?? .now)
        return TrainingJourneyChapter(
            id: id,
            kind: kind,
            title: title,
            start: start,
            end: end,
            statusText: statusText,
            completedWorkouts: workouts.count,
            personalRecords: records.filter { span.contains($0.date) }.count,
            mobilitySessions: mobilitySessions.filter { span.contains($0.startTime) }.count,
            assessments: assessments.filter { span.contains($0.startedAt) }.count
        )
    }

    private func group(_ chapters: [TrainingJourneyChapter], calendar: Calendar) -> [TrainingJourneyYear] {
        let byYear = Dictionary(grouping: chapters) { calendar.component(.year, from: $0.start) }
        return byYear
            .map { TrainingJourneyYear(year: $0.key, chapters: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.year > $1.year }
    }

    private func fixedStatusText(_ status: PlanRunStatus) -> String {
        switch status {
        case .active: "In progress"
        case .paused: "Paused"
        case .testDayAvailable: "Test day available"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }

    private func repeatingStatusText(_ status: RepeatingPlanRunStatus) -> String {
        switch status {
        case .active: "In progress"
        case .paused: "Paused"
        case .ended: "Ended"
        case .archived: "Archived"
        }
    }
}
