import Foundation

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
    let disciplineDistribution: TrainingJourneyDisciplineDistribution

    var isOngoing: Bool { end == nil }
}

struct TrainingJourneyYear: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let chapters: [TrainingJourneyChapter]
}

struct TrainingJourneySummary: Equatable, Sendable {
    let latestChapterTitle: String?
    let chapterCount: Int
    let yearCount: Int
}

/// Sorted timestamp index for repeated chapter-range counts. `DateInterval`
/// includes its start and excludes its end; two lower bounds preserve that
/// contract without rescanning every historical row for every chapter.
private struct TrainingJourneyDateCountIndex {
    let dates: [Date]

    init<S: Sequence>(_ dates: S) where S.Element == Date {
        self.dates = dates.sorted()
    }

    func count(in interval: DateInterval) -> Int {
        lowerBound(of: interval.end) - lowerBound(of: interval.start)
    }

    private func lowerBound(of value: Date) -> Int {
        var lower = 0
        var upper = dates.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if dates[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}

/// Projects the journey from records that already exist.
///
/// Deliberately not backed by persisted timeline rows: every fact here is
/// derivable from the runs, workouts and sessions already stored, and a
/// duplicate event table would be one more thing to keep true. Callers own
/// observation and invalidation; this builder never reaches back into the
/// store or creates a second persistence boundary.
@MainActor
struct TrainingJourneyBuilder {
    /// Projects from already-observed records so a dashboard can share one
    /// persistence read across consistency, records, series, and Journey.
    func journey(
        workouts: [Workout],
        fixedRuns: [PlanRun],
        repeatingRuns: [RepeatingPlanRun],
        mobilitySessions: [MobilitySession],
        assessments: [MobilityAssessmentSession],
        records suppliedRecords: [PersonalRecordItem]? = nil,
        calendar: Calendar = .current
    ) -> [TrainingJourneyYear] {
        let completedWorkouts = workouts.filter { $0.status == .completed }
        let completedMobilitySessions = mobilitySessions.filter { $0.status == .completed }
        let recordedAssessments = assessments.filter { $0.results.isEmpty == false }
        // Records are projected once and reused by every chapter. A caller
        // that already needs records can supply the same result directly.
        let records = suppliedRecords ?? PersonalRecordAnalyticsService.personalRecords(
            workouts: completedWorkouts,
            dateRange: .allTime
        )
        let fixedWorkoutsByRun = Dictionary(grouping: completedWorkouts.compactMap { workout in
            workout.sourcePlanRunID.map { ($0, workout) }
        }, by: \.0).mapValues { $0.map(\.1) }
        let repeatingWorkoutsByRun = Dictionary(grouping: completedWorkouts.compactMap { workout in
            workout.sourceRepeatingPlanRunID.map { ($0, workout) }
        }, by: \.0).mapValues { $0.map(\.1) }
        let recordDates = TrainingJourneyDateCountIndex(records.map(\.date))
        let mobilityDates = TrainingJourneyDateCountIndex(completedMobilitySessions.map(\.startTime))
        let assessmentDates = TrainingJourneyDateCountIndex(recordedAssessments.map(\.startedAt))

        var chapters: [TrainingJourneyChapter] = []

        for run in fixedRuns {
            let runWorkouts = fixedWorkoutsByRun[run.id, default: []]
            chapters.append(
                chapter(
                    id: "fixed-\(run.id)",
                    kind: .fixedPlan,
                    title: run.sourcePlanName,
                    start: run.startDate,
                    end: run.endDate,
                    statusText: fixedStatusText(run.status),
                    workouts: runWorkouts,
                    recordDates: recordDates,
                    mobilityDates: mobilityDates,
                    assessmentDates: assessmentDates,
                    calendar: calendar
                )
            )
        }

        for run in repeatingRuns {
            let runWorkouts = repeatingWorkoutsByRun[run.id, default: []]
            chapters.append(
                chapter(
                    id: "repeating-\(run.id)",
                    kind: .repeatingPlan,
                    title: run.sourcePlanName,
                    start: run.startedAt,
                    end: run.endedAt,
                    statusText: repeatingStatusText(run.status),
                    workouts: runWorkouts,
                    recordDates: recordDates,
                    mobilityDates: mobilityDates,
                    assessmentDates: assessmentDates,
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
                    recordDates: recordDates,
                    mobilityDates: mobilityDates,
                    assessmentDates: assessmentDates,
                    calendar: calendar
                )
            )
        }

        return group(chapters.sorted { $0.start > $1.start }, calendar: calendar)
    }

    /// The Progress hub needs chapter identity and counts, not per-chapter
    /// evidence or discipline distributions. Derive that compact answer from
    /// the same chapter roots without constructing the complete timeline.
    func summary(
        workouts: [Workout],
        fixedRuns: [PlanRun],
        repeatingRuns: [RepeatingPlanRun],
        calendar: Calendar = .current
    ) -> TrainingJourneySummary {
        var roots: [(start: Date, title: String)] = fixedRuns.map {
            ($0.startDate, $0.sourcePlanName)
        }
        roots.append(contentsOf: repeatingRuns.map {
            ($0.startedAt, $0.sourcePlanName)
        })

        let freeWorkouts = workouts.filter {
            $0.status == .completed
                && $0.sourcePlanRunID == nil
                && $0.sourceRepeatingPlanRunID == nil
        }
        let freeByMonth = Dictionary(grouping: freeWorkouts) {
            calendar.dateInterval(of: .month, for: $0.startTime)?.start
                ?? $0.startTime
        }
        roots.append(contentsOf: freeByMonth.values.compactMap { monthWorkouts in
            monthWorkouts.map(\.startTime).min().map {
                ($0, String(localized: "Free training"))
            }
        })

        let latest = roots.max {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let years = Set(roots.map { calendar.component(.year, from: $0.start) })
        return TrainingJourneySummary(
            latestChapterTitle: latest?.title,
            chapterCount: roots.count,
            yearCount: years.count
        )
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
        recordDates: TrainingJourneyDateCountIndex,
        mobilityDates: TrainingJourneyDateCountIndex,
        assessmentDates: TrainingJourneyDateCountIndex,
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
            personalRecords: recordDates.count(in: span),
            mobilitySessions: mobilityDates.count(in: span),
            assessments: assessmentDates.count(in: span),
            disciplineDistribution: TrainingJourneyDisciplineDistribution.project(workouts: workouts)
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
