import Foundation

/// The semantic structure lanes are intentionally derived from chapter kind,
/// not from the chapter's position in an array. Free training and plan runs
/// therefore remain distinct even when their calendar intervals overlap.
enum TrainingJourneyTimelineLane: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case fixedPlan
    case repeatingPlan
    case freeTraining

    init(kind: TrainingJourneyChapter.Kind) {
        switch kind {
        case .fixedPlan: self = .fixedPlan
        case .repeatingPlan: self = .repeatingPlan
        case .freeTraining: self = .freeTraining
        }
    }
}

struct TrainingJourneyTimelineDomain: Equatable, Sendable {
    let start: Date
    let endExclusive: Date

    var duration: TimeInterval {
        endExclusive.timeIntervalSince(start)
    }
}

struct TrainingJourneyTimelineTick: Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Hashable, Sendable {
        case year
        case month
    }

    let id: String
    let kind: Kind
    let date: Date
    let position: Double
    let year: Int
    let month: Int?
}

struct TrainingJourneyTimelineSegment: Identifiable, Equatable, Sendable {
    let id: String
    let chapterID: String
    let lane: TrainingJourneyTimelineLane
    let sublane: Int
    let title: String
    let originalStart: Date
    let originalEnd: Date?
    let normalizedStart: Date
    let normalizedEndExclusive: Date
    let positionStart: Double
    let positionEnd: Double
    let isOpenEnded: Bool
    let statusText: String?
    let completedWorkouts: Int
    let personalRecords: Int
    let mobilitySessions: Int
    let assessments: Int

    var normalizedInterval: DateInterval {
        DateInterval(start: normalizedStart, end: normalizedEndExclusive)
    }
}

struct TrainingJourneyTimelineGap: Identifiable, Equatable, Sendable {
    let id: String
    let lane: TrainingJourneyTimelineLane
    let normalizedStart: Date
    let normalizedEndExclusive: Date
    let positionStart: Double
    let positionEnd: Double

    var normalizedInterval: DateInterval {
        DateInterval(start: normalizedStart, end: normalizedEndExclusive)
    }
}

struct TrainingJourneyTimelineLaneProjection: Identifiable, Equatable, Sendable {
    let lane: TrainingJourneyTimelineLane
    let segments: [TrainingJourneyTimelineSegment]
    let gaps: [TrainingJourneyTimelineGap]

    var id: String { lane.rawValue }
}

/// Evidence returned by a date hit. This is data for a caller to format; the
/// projection deliberately does not manufacture localized copy.
struct TrainingJourneyTimelineHit: Identifiable, Equatable, Sendable {
    let id: String
    let chapterID: String
    let lane: TrainingJourneyTimelineLane
    let sublane: Int
    let title: String
    let originalStart: Date
    let originalEnd: Date?
    let isOpenEnded: Bool
    let statusText: String?
    let completedWorkouts: Int
    let personalRecords: Int
    let mobilitySessions: Int
    let assessments: Int
}

struct TrainingJourneyTimelineSelection: Equatable, Sendable {
    let date: Date
    let normalizedDate: Date
    let hits: [TrainingJourneyTimelineHit]
    let gaps: [TrainingJourneyTimelineGap]
}

struct TrainingJourneyTimelineProjection: Equatable, Sendable {
    let domain: TrainingJourneyTimelineDomain
    let lanes: [TrainingJourneyTimelineLaneProjection]
    let ticks: [TrainingJourneyTimelineTick]

    /// Hit testing uses the same calendar-normalized intervals as rendering,
    /// so a selected date cannot drift from the visible segment.
    func selection(
        for date: Date,
        calendar: Calendar = .current
    ) -> TrainingJourneyTimelineSelection {
        let normalizedDate = calendar.startOfDay(for: date)
        let hits = lanes
            .flatMap(\.segments)
            .filter { segment in
                segment.normalizedStart <= normalizedDate
                    && normalizedDate < segment.normalizedEndExclusive
            }
            .sorted { lhs, rhs in
                if lhs.lane != rhs.lane {
                    return laneOrder(lhs.lane) < laneOrder(rhs.lane)
                }
                if lhs.sublane != rhs.sublane {
                    return lhs.sublane < rhs.sublane
                }
                return lhs.id < rhs.id
            }
            .map { segment in
                TrainingJourneyTimelineHit(
                    id: segment.id,
                    chapterID: segment.chapterID,
                    lane: segment.lane,
                    sublane: segment.sublane,
                    title: segment.title,
                    originalStart: segment.originalStart,
                    originalEnd: segment.originalEnd,
                    isOpenEnded: segment.isOpenEnded,
                    statusText: segment.statusText,
                    completedWorkouts: segment.completedWorkouts,
                    personalRecords: segment.personalRecords,
                    mobilitySessions: segment.mobilitySessions,
                    assessments: segment.assessments
                )
            }
        let gaps = lanes
            .flatMap(\.gaps)
            .filter { gap in
                gap.normalizedStart <= normalizedDate
                    && normalizedDate < gap.normalizedEndExclusive
            }
            .sorted { lhs, rhs in
                if lhs.lane != rhs.lane {
                    return laneOrder(lhs.lane) < laneOrder(rhs.lane)
                }
                return lhs.id < rhs.id
            }
        return TrainingJourneyTimelineSelection(
            date: date,
            normalizedDate: normalizedDate,
            hits: hits,
            gaps: gaps
        )
    }

    private func laneOrder(_ lane: TrainingJourneyTimelineLane) -> Int {
        TrainingJourneyTimelineLane.allCases.firstIndex(of: lane) ?? Int.max
    }
}

/// Calendar-normalized, value-only projection for a visual training history.
///
/// Chapter end dates are calendar-inclusive: a chapter ending on 2025-03-10
/// occupies that day and its normalized interval ends at the start of
/// 2025-03-11. This makes exact-date selection deterministic while preserving
/// half-open interval math for overlap and gap detection. Open chapters use
/// the supplied reference date as their visible inclusive end and remain
/// marked `isOpenEnded`.
enum TrainingJourneyTimelineProjectionService {
    static func project(
        chapters: [TrainingJourneyChapter],
        calendar inputCalendar: Calendar,
        referenceDate: Date
    ) -> TrainingJourneyTimelineProjection {
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let normalized = chapters.compactMap {
            normalize($0, calendar: calendar, referenceDate: referenceDate)
        }
        guard let minimumStart = normalized.map(\.normalizedStart).min() else {
            let day = calendar.startOfDay(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            let domain = TrainingJourneyTimelineDomain(start: day, endExclusive: end)
            return TrainingJourneyTimelineProjection(domain: domain, lanes: emptyLanes(), ticks: [])
        }

        let maximumEnd = normalized.map(\.normalizedEndExclusive).max() ?? minimumStart
        let domain = TrainingJourneyTimelineDomain(start: minimumStart, endExclusive: maximumEnd)
        let lanes = TrainingJourneyTimelineLane.allCases.map { lane in
            makeLane(
                lane,
                normalized: normalized.filter { $0.lane == lane },
                domain: domain
            )
        }
        return TrainingJourneyTimelineProjection(
            domain: domain,
            lanes: lanes,
            ticks: makeTicks(domain: domain, calendar: calendar)
        )
    }

    private struct NormalizedChapter {
        let chapter: TrainingJourneyChapter
        let lane: TrainingJourneyTimelineLane
        let normalizedStart: Date
        let normalizedEndExclusive: Date
    }

    private static func normalize(
        _ chapter: TrainingJourneyChapter,
        calendar: Calendar,
        referenceDate: Date
    ) -> NormalizedChapter? {
        let start = calendar.startOfDay(for: chapter.start)
        let visibleEnd = chapter.end.map(calendar.startOfDay(for:)) ??
            max(calendar.startOfDay(for: referenceDate), start)
        guard visibleEnd >= start else { return nil }
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)
        return NormalizedChapter(
            chapter: chapter,
            lane: TrainingJourneyTimelineLane(kind: chapter.kind),
            normalizedStart: start,
            normalizedEndExclusive: endExclusive
        )
    }

    private static func makeLane(
        _ lane: TrainingJourneyTimelineLane,
        normalized: [NormalizedChapter],
        domain: TrainingJourneyTimelineDomain
    ) -> TrainingJourneyTimelineLaneProjection {
        let sorted = normalized.sorted { lhs, rhs in
            if lhs.normalizedStart != rhs.normalizedStart {
                return lhs.normalizedStart < rhs.normalizedStart
            }
            if lhs.normalizedEndExclusive != rhs.normalizedEndExclusive {
                return lhs.normalizedEndExclusive < rhs.normalizedEndExclusive
            }
            return lhs.chapter.id < rhs.chapter.id
        }
        var sublaneEnds: [Date] = []
        var segments: [TrainingJourneyTimelineSegment] = []
        for item in sorted {
            let sublane = sublaneEnds.firstIndex(where: { $0 <= item.normalizedStart }) ?? sublaneEnds.count
            if sublane == sublaneEnds.count {
                sublaneEnds.append(item.normalizedEndExclusive)
            } else {
                sublaneEnds[sublane] = item.normalizedEndExclusive
            }
            segments.append(makeSegment(item, lane: lane, sublane: sublane, domain: domain))
        }
        let orderedSegments = segments.sorted { lhs, rhs in
            if lhs.sublane != rhs.sublane { return lhs.sublane < rhs.sublane }
            if lhs.normalizedStart != rhs.normalizedStart { return lhs.normalizedStart < rhs.normalizedStart }
            return lhs.id < rhs.id
        }
        return TrainingJourneyTimelineLaneProjection(
            lane: lane,
            segments: orderedSegments,
            gaps: makeGaps(segments: segments, lane: lane, domain: domain)
        )
    }

    private static func makeSegment(
        _ item: NormalizedChapter,
        lane: TrainingJourneyTimelineLane,
        sublane: Int,
        domain: TrainingJourneyTimelineDomain
    ) -> TrainingJourneyTimelineSegment {
        let chapter = item.chapter
        return TrainingJourneyTimelineSegment(
            id: "segment|\(chapter.id)|\(lane.rawValue)|\(sublane)",
            chapterID: chapter.id,
            lane: lane,
            sublane: sublane,
            title: chapter.title,
            originalStart: chapter.start,
            originalEnd: chapter.end,
            normalizedStart: item.normalizedStart,
            normalizedEndExclusive: item.normalizedEndExclusive,
            positionStart: position(item.normalizedStart, domain: domain),
            positionEnd: position(item.normalizedEndExclusive, domain: domain),
            isOpenEnded: chapter.isOngoing,
            statusText: chapter.statusText,
            completedWorkouts: chapter.completedWorkouts,
            personalRecords: chapter.personalRecords,
            mobilitySessions: chapter.mobilitySessions,
            assessments: chapter.assessments
        )
    }

    private static func makeGaps(
        segments: [TrainingJourneyTimelineSegment],
        lane: TrainingJourneyTimelineLane,
        domain: TrainingJourneyTimelineDomain
    ) -> [TrainingJourneyTimelineGap] {
        let intervals = segments
            .map(\.normalizedInterval)
            .sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in intervals {
            guard let previous = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= previous.end {
                merged[merged.count - 1] = DateInterval(
                    start: previous.start,
                    end: max(previous.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }
        var gaps: [DateInterval] = []
        var cursor = domain.start
        for interval in merged {
            if cursor < interval.start {
                gaps.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < domain.endExclusive {
            gaps.append(DateInterval(start: cursor, end: domain.endExclusive))
        }
        return gaps.map { gap in
            let start = gap.start.timeIntervalSince1970
            let end = gap.end.timeIntervalSince1970
            return TrainingJourneyTimelineGap(
                id: "gap|\(lane.rawValue)|\(start)|\(end)",
                lane: lane,
                normalizedStart: gap.start,
                normalizedEndExclusive: gap.end,
                positionStart: position(gap.start, domain: domain),
                positionEnd: position(gap.end, domain: domain)
            )
        }
    }

    private static func makeTicks(
        domain: TrainingJourneyTimelineDomain,
        calendar: Calendar
    ) -> [TrainingJourneyTimelineTick] {
        var ticks: [TrainingJourneyTimelineTick] = []
        var cursor = calendar.dateInterval(of: .year, for: domain.start)?.start ?? domain.start
        while cursor < domain.endExclusive {
            let year = calendar.component(.year, from: cursor)
            ticks.append(
                TrainingJourneyTimelineTick(
                    id: "year|\(year)",
                    kind: .year,
                    date: cursor,
                    position: position(cursor, domain: domain),
                    year: year,
                    month: nil
                )
            )
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: cursor) ?? domain.endExclusive
            var monthCursor = cursor
            while monthCursor < yearEnd && monthCursor < domain.endExclusive {
                let month = calendar.component(.month, from: monthCursor)
                ticks.append(
                    TrainingJourneyTimelineTick(
                        id: "month|\(year)-\(month)",
                        kind: .month,
                        date: monthCursor,
                        position: position(monthCursor, domain: domain),
                        year: year,
                        month: month
                    )
                )
                monthCursor = calendar.date(byAdding: .month, value: 1, to: monthCursor) ?? domain.endExclusive
            }
            cursor = yearEnd
        }
        return ticks.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.kind != $1.kind { return $0.kind == .year }
            return $0.id < $1.id
        }
    }

    private static func position(_ date: Date, domain: TrainingJourneyTimelineDomain) -> Double {
        guard domain.duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(domain.start) / domain.duration))
    }

    private static func emptyLanes() -> [TrainingJourneyTimelineLaneProjection] {
        TrainingJourneyTimelineLane.allCases.map {
            TrainingJourneyTimelineLaneProjection(lane: $0, segments: [], gaps: [])
        }
    }
}
