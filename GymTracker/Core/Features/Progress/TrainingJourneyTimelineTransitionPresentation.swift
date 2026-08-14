import Foundation

/// Value-only presentation data for timeline transition markers. The view owns
/// layout and colors; this contract owns stable ordering, collision rows, and
/// cautious evidence wording so VoiceOver and visual labels describe the same
/// marker without implying a cause.
enum TrainingJourneyTimelineTransitionPresentation {
    static func collisionRows(
        _ markers: [TrainingJourneyPracticeTransitionMarker]
    ) -> [[TrainingJourneyPracticeTransitionMarker]] {
        var rows: [[TrainingJourneyPracticeTransitionMarker]] = []
        for marker in markers.sorted(by: { order($0, $1) }) {
            if let lastIndex = rows.indices.last,
               let lastMarker = rows[lastIndex].last,
               lastMarker.normalizedDate == marker.normalizedDate {
                rows[lastIndex].append(marker)
            } else {
                rows.append([marker])
            }
        }
        return rows
    }

    static func order(
        _ lhs: TrainingJourneyPracticeTransitionMarker,
        _ rhs: TrainingJourneyPracticeTransitionMarker
    ) -> Bool {
        if lhs.normalizedDate != rhs.normalizedDate {
            return lhs.normalizedDate < rhs.normalizedDate
        }
        return lhs.id < rhs.id
    }

    static func title(_ marker: TrainingJourneyPracticeTransitionMarker) -> String {
        let qualifier = marker.kind.isDeclared ? "Declared structure transition" : "Practice transition"
        let evidence = marker.isObserved ? "Observed" : evidenceStateText(marker.state)
        return "\(qualifier) · \(evidence)"
    }

    static func shortLabel(_ marker: TrainingJourneyPracticeTransitionMarker) -> String {
        marker.kind.isDeclared ? "Declared" : (marker.isObserved ? "Observed" : "Review")
    }

    static func accessibilityLabel(_ marker: TrainingJourneyPracticeTransitionMarker) -> String {
        [
            title(marker),
            kindText(marker.kind),
            "from \(chapterEvidenceText(marker.from))",
            "to \(chapterEvidenceText(marker.to))",
            marker.normalizedDate.formatted(date: .abbreviated, time: .omitted),
            "Descriptive evidence only; no causality inferred"
        ].joined(separator: ", ")
    }

    static func evidenceSummary(_ marker: TrainingJourneyPracticeTransitionMarker) -> String {
        "\(kindText(marker.kind)). \(evidenceStateText(marker.state)). No reason or causal outcome is inferred."
    }

    private static func kindText(_ kind: TrainingJourneyPracticeTransitionKind) -> String {
        switch kind {
        case let .structureChange(from, to):
            return "structure changed from \(laneName(from)) to \(laneName(to))"
        case .dominantDisciplineChange:
            return "dominant discipline changed"
        case .returnToEarlierDiscipline:
            return "returned to an earlier discipline"
        }
    }

    private static func chapterEvidenceText(_ evidence: TrainingJourneyPracticeTransitionChapterEvidence) -> String {
        "\(evidence.chapterID), \(evidence.completedWorkouts) completed workouts"
    }

    private static func evidenceStateText(_ state: TrainingJourneyPracticeTransitionEvidenceState) -> String {
        switch state {
        case .observed: "Observed"
        case .insufficientCompletedEvidence: "Insufficient completed evidence"
        case .ambiguousDiscipline: "Ambiguous discipline evidence"
        case .unknownDiscipline: "Unknown discipline evidence"
        case .concurrentIntervals: "Concurrent intervals"
        }
    }

    private static func laneName(_ lane: TrainingJourneyTimelineLane) -> String {
        switch lane {
        case .fixedPlan: "fixed plan"
        case .repeatingPlan: "rotation"
        case .freeTraining: "free training"
        }
    }
}

extension TrainingJourneyPracticeTransitionKind {
    var isDeclared: Bool {
        if case .structureChange = self { return true }
        return false
    }
}
