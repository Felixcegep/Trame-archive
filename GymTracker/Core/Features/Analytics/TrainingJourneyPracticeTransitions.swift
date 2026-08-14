import Foundation

enum TrainingJourneyPracticeTransitionKind: Equatable, Hashable, Sendable {
    case structureChange(
        from: TrainingJourneyTimelineLane,
        to: TrainingJourneyTimelineLane
    )
    case dominantDisciplineChange
    case returnToEarlierDiscipline

    fileprivate var stableKey: String {
        switch self {
        case let .structureChange(from, to):
            return "structure|\(from.rawValue)|\(to.rawValue)"
        case .dominantDisciplineChange:
            return "discipline-change"
        case .returnToEarlierDiscipline:
            return "discipline-return"
        }
    }
}

enum TrainingJourneyPracticeTransitionEvidenceState: String, Codable, Equatable, Hashable, Sendable {
    case observed
    case insufficientCompletedEvidence
    case ambiguousDiscipline
    case unknownDiscipline
    case concurrentIntervals
}

enum TrainingJourneyDisciplineObservation: Equatable, Hashable, Sendable {
    case noCompletedEvidence
    case unknown
    case ambiguous([SportDiscipline])
    case dominant(SportDiscipline)
}

struct TrainingJourneyPracticeTransitionChapterEvidence: Equatable, Sendable {
    let chapterID: String
    let completedWorkouts: Int
    let discipline: TrainingJourneyDisciplineObservation
    let sourceEvidence: [AnalyticsSourceReference]
}

struct TrainingJourneyPracticeTransitionMarker: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let normalizedDate: Date
    let position: Double
    let kind: TrainingJourneyPracticeTransitionKind
    let state: TrainingJourneyPracticeTransitionEvidenceState
    let from: TrainingJourneyPracticeTransitionChapterEvidence
    let to: TrainingJourneyPracticeTransitionChapterEvidence

    var isObserved: Bool { state == .observed }
}

struct TrainingJourneyPracticeTransitionProjection: Equatable, Sendable {
    let markers: [TrainingJourneyPracticeTransitionMarker]

    var observedMarkers: [TrainingJourneyPracticeTransitionMarker] {
        markers.filter(\.isObserved)
    }

    var uncertainMarkers: [TrainingJourneyPracticeTransitionMarker] {
        markers.filter { $0.isObserved == false }
    }
}

/// Derives descriptive practice-transition markers from completed historical
/// evidence. It does not infer a reason, outcome, fitness change, or causal
/// relationship. A marker can be retained with an explicit uncertainty state
/// when a candidate boundary is concurrent or lacks completed evidence.
enum TrainingJourneyPracticeTransitionProjectionService {
    static func project(
        chapters: [TrainingJourneyChapter],
        timeline: TrainingJourneyTimelineProjection
    ) -> TrainingJourneyPracticeTransitionProjection {
        let segmentsByChapterID = Dictionary(
            uniqueKeysWithValues: timeline.lanes
                .flatMap(\.segments)
                .map { ($0.chapterID, $0) }
        )
        let ordered = chapters
            .compactMap { chapter -> (TrainingJourneyChapter, TrainingJourneyTimelineSegment)? in
                guard let segment = segmentsByChapterID[chapter.id] else { return nil }
                return (chapter, segment)
            }
            .sorted {
                if $0.1.normalizedStart != $1.1.normalizedStart {
                    return $0.1.normalizedStart < $1.1.normalizedStart
                }
                if $0.1.normalizedEndExclusive != $1.1.normalizedEndExclusive {
                    return $0.1.normalizedEndExclusive < $1.1.normalizedEndExclusive
                }
                return $0.0.id < $1.0.id
            }
            .map { chapter, segment in
                (
                    chapter: chapter,
                    segment: segment,
                    evidence: chapterEvidence(chapter)
                )
            }

        var markers: [TrainingJourneyPracticeTransitionMarker] = []
        var seenDominantDisciplines = Set<SportDiscipline>()
        for index in ordered.indices.dropFirst() {
            let previous = ordered[index - 1]
            let current = ordered[index]
            let previousChapter = previous.chapter
            let currentChapter = current.chapter
            let previousEvidence = previous.evidence
            let currentEvidence = current.evidence
            if let previousDominant = dominantDiscipline(previousEvidence.discipline) {
                seenDominantDisciplines.insert(previousDominant)
            }
            let overlaps = current.segment.normalizedStart < previous.segment.normalizedEndExclusive
            let state: TrainingJourneyPracticeTransitionEvidenceState = overlaps
                ? .concurrentIntervals
                : evidenceState(from: previousEvidence, to: currentEvidence)

            if previous.segment.lane != current.segment.lane {
                markers.append(
                    makeMarker(
                        kind: .structureChange(from: previous.segment.lane, to: current.segment.lane),
                        state: state,
                        from: previousChapter,
                        to: currentChapter,
                        fromEvidence: previousEvidence,
                        toEvidence: currentEvidence,
                        toSegment: current.segment,
                        timelineDomain: timeline.domain
                    )
                )
            }

            guard overlaps == false else { continue }
            switch (previousEvidence.discipline, currentEvidence.discipline) {
            case let (.dominant(previousDiscipline), .dominant(currentDiscipline))
                where previousDiscipline != currentDiscipline:
                let kind: TrainingJourneyPracticeTransitionKind = seenDominantDisciplines.contains(currentDiscipline)
                    ? .returnToEarlierDiscipline
                    : .dominantDisciplineChange
                markers.append(
                    makeMarker(
                        kind: kind,
                        state: .observed,
                        from: previousChapter,
                        to: currentChapter,
                        fromEvidence: previousEvidence,
                        toEvidence: currentEvidence,
                        toSegment: current.segment,
                        timelineDomain: timeline.domain
                    )
                )
            case (.ambiguous, _), (_, .ambiguous):
                markers.append(
                    makeMarker(
                        kind: .dominantDisciplineChange,
                        state: .ambiguousDiscipline,
                        from: previousChapter,
                        to: currentChapter,
                        fromEvidence: previousEvidence,
                        toEvidence: currentEvidence,
                        toSegment: current.segment,
                        timelineDomain: timeline.domain
                    )
                )
            case (.unknown, _), (_, .unknown):
                markers.append(
                    makeMarker(
                        kind: .dominantDisciplineChange,
                        state: .unknownDiscipline,
                        from: previousChapter,
                        to: currentChapter,
                        fromEvidence: previousEvidence,
                        toEvidence: currentEvidence,
                        toSegment: current.segment,
                        timelineDomain: timeline.domain
                    )
                )
            case (.noCompletedEvidence, _), (_, .noCompletedEvidence):
                break
            default:
                break
            }
        }

        return TrainingJourneyPracticeTransitionProjection(
            markers: markers.sorted {
                if $0.normalizedDate != $1.normalizedDate {
                    return $0.normalizedDate < $1.normalizedDate
                }
                return $0.id < $1.id
            }
        )
    }

    static func project(
        chapters: [TrainingJourneyChapter],
        calendar: Calendar,
        referenceDate: Date
    ) -> TrainingJourneyPracticeTransitionProjection {
        let timeline = TrainingJourneyTimelineProjectionService.project(
            chapters: chapters,
            calendar: calendar,
            referenceDate: referenceDate
        )
        return project(chapters: chapters, timeline: timeline)
    }

    private static func chapterEvidence(
        _ chapter: TrainingJourneyChapter
    ) -> TrainingJourneyPracticeTransitionChapterEvidence {
        let sourceEvidence = chapter.disciplineDistribution.slices
            .flatMap(\.evidence)
            .sorted { $0.id < $1.id }
        return TrainingJourneyPracticeTransitionChapterEvidence(
            chapterID: chapter.id,
            completedWorkouts: chapter.completedWorkouts,
            discipline: dominantObservation(for: chapter),
            sourceEvidence: sourceEvidence
        )
    }

    private static func dominantObservation(
        for chapter: TrainingJourneyChapter
    ) -> TrainingJourneyDisciplineObservation {
        guard chapter.completedWorkouts > 0,
              chapter.disciplineDistribution.totalEntryCount > 0
        else { return .noCompletedEvidence }

        let classified = chapter.disciplineDistribution.slices.filter { $0.discipline != nil }
        guard classified.isEmpty == false else { return .unknown }
        let highestCount = classified.map(\.entryCount).max() ?? 0
        let leaders = classified
            .filter { $0.entryCount == highestCount }
            .compactMap(\.discipline)
            .sorted { $0.rawValue < $1.rawValue }
        guard leaders.count == 1, let leader = leaders.first else {
            return .ambiguous(leaders)
        }
        return .dominant(leader)
    }

    private static func dominantDiscipline(
        _ observation: TrainingJourneyDisciplineObservation
    ) -> SportDiscipline? {
        guard case let .dominant(discipline) = observation else { return nil }
        return discipline
    }

    private static func evidenceState(
        from: TrainingJourneyPracticeTransitionChapterEvidence,
        to: TrainingJourneyPracticeTransitionChapterEvidence
    ) -> TrainingJourneyPracticeTransitionEvidenceState {
        switch (from.discipline, to.discipline) {
        case (.noCompletedEvidence, _), (_, .noCompletedEvidence):
            return .insufficientCompletedEvidence
        case (.ambiguous, _), (_, .ambiguous):
            return .ambiguousDiscipline
        case (.unknown, _), (_, .unknown):
            return .unknownDiscipline
        default:
            return .observed
        }
    }

    private static func makeMarker(
        kind: TrainingJourneyPracticeTransitionKind,
        state: TrainingJourneyPracticeTransitionEvidenceState,
        from: TrainingJourneyChapter,
        to: TrainingJourneyChapter,
        fromEvidence: TrainingJourneyPracticeTransitionChapterEvidence,
        toEvidence: TrainingJourneyPracticeTransitionChapterEvidence,
        toSegment: TrainingJourneyTimelineSegment,
        timelineDomain: TrainingJourneyTimelineDomain
    ) -> TrainingJourneyPracticeTransitionMarker {
        let date = toSegment.normalizedStart
        let position: Double
        if timelineDomain.duration > 0 {
            position = min(1, max(0, date.timeIntervalSince(timelineDomain.start) / timelineDomain.duration))
        } else {
            position = 0
        }
        let normalizedDate = toSegment.normalizedStart
        let id = [
            "transition",
            kind.stableKey,
            from.id,
            to.id,
            String(normalizedDate.timeIntervalSince1970)
        ].joined(separator: "|")
        return TrainingJourneyPracticeTransitionMarker(
            id: id,
            date: date,
            normalizedDate: normalizedDate,
            position: position,
            kind: kind,
            state: state,
            from: fromEvidence,
            to: toEvidence
        )
    }
}
