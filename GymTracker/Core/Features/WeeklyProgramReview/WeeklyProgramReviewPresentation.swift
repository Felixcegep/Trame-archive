import SwiftUI

/// Copy and status styling for Weekly Review.
///
/// Visible vocabulary is "Weekly review". Skipped, missed, declined, or
/// incomplete evidence is described factually — never as failure, poor
/// performance, or noncompliance. Everything here is a pure function of
/// projection values, so wording can be exercised without a live view
/// hierarchy, and nothing here recomputes a rule the projection already owns.
enum WeeklyProgramReviewPresentation {
    static var screenTitle: String { String(localized: "Weekly review") }
    static var entryTitle: String { String(localized: "Weekly review") }
    static var entryDetail: String {
        String(localized: "See what this week planned, completed, and changed.")
    }

    // MARK: - Header

    static func weekPositionTitle(_ week: WeeklyProgramReviewProjection.Week) -> String {
        if let name = week.name, !name.isEmpty {
            return String(localized: "Week \(week.runWeekIndex + 1) · \(name)")
        }
        return String(localized: "Week \(week.runWeekIndex + 1)")
    }

    static func dateRangeTitle(_ range: DateInterval) -> String {
        if Calendar.current.isDate(range.start, inSameDayAs: range.end) {
            return range.start.formatted(date: .abbreviated, time: .omitted)
        }
        let format = String(localized: "%1$@ – %2$@")
        return String(
            format: format,
            range.start.formatted(.dateTime.month(.abbreviated).day()),
            range.end.formatted(.dateTime.month(.abbreviated).day())
        )
    }

    static func runStatusNote(_ status: PlanRunStatus) -> String? {
        switch status {
        case .paused:
            String(localized: "This plan is currently paused.")
        case .archived:
            String(localized: "You've stopped following this plan. Its history stays available here.")
        case .completed:
            String(localized: "This plan run is complete.")
        case .active, .testDayAvailable:
            nil
        }
    }

    // MARK: - Session summary

    static var plannedSummaryTitle: String { String(localized: "Planned") }
    static var completedSummaryTitle: String { String(localized: "Completed") }
    static var inProgressSummaryTitle: String { String(localized: "In progress") }
    static var skippedSummaryTitle: String { String(localized: "Skipped") }
    static var missedSummaryTitle: String { String(localized: "Missed") }
    /// Sessions the projection reports as `available` or `upcoming` — resolved
    /// neither to a completion nor to skipped/missed. This sums two already
    /// final projection counts; it does not infer or recompute lifecycle state.
    static var remainingSummaryTitle: String { String(localized: "Remaining") }
    static func unscheduledSummaryTitle(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 session is unscheduled")
            : String(localized: "\(count) sessions are unscheduled")
    }

    // MARK: - Session detail

    /// Reuses `ProgramPathPresentation.style(for:)` — both surfaces render the
    /// same `PlanCalendarDisplayState`, and the state vocabulary (icon, tint,
    /// title) must read identically wherever it appears.
    static func sessionStateStyle(_ state: PlanCalendarDisplayState) -> ProgramPathPresentation.StateStyle {
        ProgramPathPresentation.style(for: state)
    }

    /// Distinct identifiers from `ProgramPathPresentation.style(for:)`'s
    /// `program-path-state-*` family — Weekly Review is a separate screen with
    /// its own required `weekly-review-session-*` contract.
    static func sessionStateIdentifier(_ state: PlanCalendarDisplayState) -> String {
        switch state {
        case .completed: "weekly-review-session-completed"
        case .inProgress: "weekly-review-session-in-progress"
        case .skipped: "weekly-review-session-skipped"
        case .missed: "weekly-review-session-missed"
        case .available: "weekly-review-session-available"
        case .upcoming: "weekly-review-session-upcoming"
        }
    }

    static var unscheduledTitle: String { String(localized: "Unscheduled") }

    static func scheduledDateTitle(_ date: Date?) -> String {
        guard let date else { return unscheduledTitle }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func rescheduledDetail(_ session: WeeklyProgramReviewProjection.Session) -> String? {
        guard session.isRescheduled, let original = session.originalScheduledDate else {
            return nil
        }
        return String(localized: "Moved from \(original.formatted(date: .abbreviated, time: .omitted))")
    }

    // MARK: - Set summary

    static var prescribedSetsUnit: String { String(localized: "prescribed sets") }
    static var performedSetsUnit: String { String(localized: "performed sets") }

    static var setComparisonUnavailableTitle: String {
        String(localized: "Set comparison unavailable")
    }

    static var setComparisonUnavailableDetail: String {
        String(
            localized: "Not every session this week has reliable prescribed-set evidence, so prescribed and performed sets aren't compared. Sets actually performed are still shown."
        )
    }

    // MARK: - Progression decisions

    /// Mirrors `ProgressionReceiptPresentation.resolutionSummary`'s vocabulary:
    /// a `nil` outcome on a resolved record is a legacy row or an
    /// automatic-mode application, and it must read as "resolved without a
    /// recorded outcome" rather than being guessed at as an accept or decline.
    static func decisionOutcomeTitle(
        isResolved: Bool,
        outcome: ProgressionDecisionOutcome?
    ) -> String {
        guard isResolved else {
            return String(localized: "Unresolved")
        }
        switch outcome {
        case .accepted:
            return String(localized: "Accepted")
        case .acceptedWithModifiedValue:
            return String(localized: "Accepted with a different value")
        case .declined:
            return String(localized: "Declined")
        case nil:
            return String(localized: "Resolved without a recorded outcome")
        }
    }

    static func decisionOutcomeIcon(isResolved: Bool, outcome: ProgressionDecisionOutcome?) -> String {
        guard isResolved else { return AppIcon.circleDashed }
        switch outcome {
        case .accepted, .acceptedWithModifiedValue: AppIcon.checkmarkCircle
        case .declined: AppIcon.circle
        case nil: AppIcon.circleDashed
        }
    }

    static func decisionOutcomeTint(isResolved: Bool, outcome: ProgressionDecisionOutcome?) -> Color {
        guard isResolved else { return .gymSubduedText }
        switch outcome {
        case .accepted, .acceptedWithModifiedValue: .gymSuccess
        case .declined, nil: .gymSubduedText
        }
    }

    /// Reuses `ProgressionReceiptPresentation.ruleLabel`'s exact keys and
    /// wording — both surfaces name a progression rule from the same
    /// optional `ruleVersion`, so the label must read identically rather than
    /// duplicating the string under a second key.
    static func ruleLabel(version: Int?) -> String {
        if let version {
            let format = String(
                localized: "progression.receipt.rule.versioned",
                defaultValue: "Progression rule v%lld"
            )
            return String(format: format, Int64(version))
        }
        return String(
            localized: "progression.receipt.rule.unversioned",
            defaultValue: "Progression rule"
        )
    }

    /// Loads are shown without a unit: the projection carries only raw
    /// doubles, not a `WeightType`. See the Claude handoff for why a unit was
    /// not derived here.
    static func loadTitle(_ value: Double?) -> String? {
        guard let value else { return nil }
        return Formatters.formatFloat(Float(value))
    }

    static func proposedLoadLine(_ value: Double?) -> String? {
        guard let text = loadTitle(value) else { return nil }
        return String(localized: "Proposed: \(text)")
    }

    static func appliedLoadLine(_ value: Double?) -> String? {
        guard let text = loadTitle(value) else { return nil }
        return String(localized: "Applied: \(text)")
    }

    static func decisionExerciseName(_ name: String?) -> String {
        name ?? String(localized: "Unknown exercise")
    }

    // MARK: - Substitutions

    static func substitutionOriginalName(_ name: String?) -> String {
        name ?? String(localized: "Unknown exercise")
    }

    // MARK: - Next week

    static func nextWeekPositionTitle(_ nextWeek: WeeklyProgramReviewProjection.NextWeek) -> String {
        if let name = nextWeek.name, !name.isEmpty {
            return String(localized: "Week \(nextWeek.runWeekIndex + 1) · \(name)")
        }
        return String(localized: "Week \(nextWeek.runWeekIndex + 1)")
    }

    static var finalWeekTitle: String { String(localized: "This is the final week of the plan") }
    static var finalWeekDetail: String {
        String(localized: "There is no scheduled week after this one.")
    }

    static var nextWeekDeloadTitle: String { String(localized: "Next week is a deload") }

    /// "Volume −30% · Intensity −10%". Matches the phrasing established by
    /// `ProgramPathPresentation.deloadReductions(_:)`, taking loose optional
    /// percentages directly since `NextWeek` has no `Block` to read from.
    static func nextWeekDeloadReductions(
        volumeReductionPercent: Int?,
        intensityReductionPercent: Int?
    ) -> String? {
        var parts: [String] = []
        if let volume = volumeReductionPercent {
            let value = volume.formatted() + "%"
            parts.append(String(localized: "Volume −\(value)"))
        }
        if let intensity = intensityReductionPercent {
            let value = intensity.formatted() + "%"
            parts.append(String(localized: "Intensity −\(value)"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Warnings

    static func warningMessage(_ warning: WeeklyProgramReviewProjection.Warning) -> String {
        switch warning {
        case .reviewedWeekUnavailable:
            String(localized: "No sessions were found for this week.")
        case .sourcePlanUnavailable:
            String(localized: "The plan behind this review is unavailable. Completed sessions still show what you did.")
        case .sourceWeekUnavailable(let sourceWeekIndex):
            String(localized: "Week \(sourceWeekIndex + 1) of the plan is unavailable, so its name and block are missing.")
        case .completedSessionMissingWorkout:
            String(localized: "A completed session in this week is missing its workout record.")
        case .linkedWorkoutNotCompleted:
            String(localized: "A session's linked workout wasn't marked completed, so it's left out of this week's evidence.")
        case .incompleteSetPrescription:
            String(localized: "Prescribed sets aren't fully recorded for at least one session this week.")
        case .legacySubstitutionEvidence:
            String(localized: "A substitution this week is missing some evidence fields recorded by newer versions.")
        }
    }
}
