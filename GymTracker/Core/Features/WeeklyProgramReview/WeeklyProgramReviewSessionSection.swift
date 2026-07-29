import SwiftUI

/// Planned/completed/in-progress/skipped/missed/remaining tally for the
/// reviewed week, plus an unscheduled note when any session has no date.
struct WeeklyProgramReviewSessionSummary: View {
    let summary: WeeklyProgramReviewProjection.SessionSummary

    var body: some View {
        ChipFlowLayout(spacing: Spacing.s) {
            tile(WeeklyProgramReviewPresentation.plannedSummaryTitle, count: summary.plannedCount, tint: .gymText)
            tile(WeeklyProgramReviewPresentation.completedSummaryTitle, count: summary.completedCount, tint: .gymSuccess)
            tile(WeeklyProgramReviewPresentation.inProgressSummaryTitle, count: summary.inProgressCount, tint: .gymPrimary)
            tile(WeeklyProgramReviewPresentation.skippedSummaryTitle, count: summary.skippedCount, tint: .gymSubduedText)
            tile(WeeklyProgramReviewPresentation.missedSummaryTitle, count: summary.missedCount, tint: .gymDestructive)
            tile(WeeklyProgramReviewPresentation.remainingSummaryTitle, count: remainingCount, tint: .gymSubduedText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("weekly-review-session-summary")
        .accessibilityLabel(accessibilityLabel)

        if summary.unscheduledCount > 0 {
            Label(
                WeeklyProgramReviewPresentation.unscheduledSummaryTitle(summary.unscheduledCount),
                systemImage: AppIcon.circleDashed
            )
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
            .accessibilityIdentifier("weekly-review-session-unscheduled")
        }
    }

    /// Sessions the projection places in `available` or `upcoming` — neither
    /// resolved to a completion nor to skipped/missed. This adds two counts
    /// the projection already finalized; it derives no new lifecycle rule.
    private var remainingCount: Int {
        summary.availableCount + summary.upcomingCount
    }

    private func tile(_ title: String, count: Int, tint: Color) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(count.formatted())
                .font(AppFont.headlineMonospaced)
                .foregroundStyle(tint)
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .frame(minWidth: 64)
        .padding(.vertical, Spacing.s)
        .padding(.horizontal, Spacing.m)
        .background(Color.gymRowSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private var accessibilityLabel: String {
        [
            "\(summary.plannedCount) \(WeeklyProgramReviewPresentation.plannedSummaryTitle)",
            "\(summary.completedCount) \(WeeklyProgramReviewPresentation.completedSummaryTitle)",
            "\(summary.inProgressCount) \(WeeklyProgramReviewPresentation.inProgressSummaryTitle)",
            "\(summary.skippedCount) \(WeeklyProgramReviewPresentation.skippedSummaryTitle)",
            "\(summary.missedCount) \(WeeklyProgramReviewPresentation.missedSummaryTitle)",
            "\(remainingCount) \(WeeklyProgramReviewPresentation.remainingSummaryTitle)"
        ].joined(separator: ", ")
    }
}

/// One session in authored order: name, lifecycle state, current schedule,
/// and reschedule provenance. Opens the completed workout when the projection
/// links one; otherwise the row stays read-only.
///
/// State, unscheduled, and rescheduled markers are each their own leaf
/// accessibility element rather than being folded into one row-level combine
/// — collapsing them would make their required identifiers unreachable to a
/// query, which is exactly the failure mode this feature's accessibility
/// contract calls out.
struct WeeklyProgramReviewSessionRow: View {
    let session: WeeklyProgramReviewProjection.Session

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            stateBadge
                .frame(width: Spacing.xxl, alignment: .center)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(session.workoutName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                if session.scheduledDate == nil {
                    Text(WeeklyProgramReviewPresentation.unscheduledTitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("weekly-review-session-unscheduled")
                } else {
                    Text(WeeklyProgramReviewPresentation.scheduledDateTitle(session.scheduledDate))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }

                if let rescheduled = WeeklyProgramReviewPresentation.rescheduledDetail(session) {
                    Label(rescheduled, systemImage: AppIcon.reschedule)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymAccent)
                        .accessibilityIdentifier("weekly-review-session-rescheduled")
                }
            }

            Spacer(minLength: Spacing.s)

            if session.completedWorkoutID != nil {
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubtleText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
    }

    private var stateBadge: some View {
        let style = WeeklyProgramReviewPresentation.sessionStateStyle(session.displayState)
        return Image(systemName: style.systemImage)
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(style.tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.title)
            .accessibilityIdentifier(WeeklyProgramReviewPresentation.sessionStateIdentifier(session.displayState))
    }
}

/// Wraps `WeeklyProgramReviewSessionRow` in a `NavigationLink` when a
/// completed workout is available, matching how `FixedProgramPathTimeline`
/// opens the same destination from Plan Path. Kept read-only otherwise.
///
/// Only a `.completed` session ever carries `completedWorkoutID`, so this is
/// the one row shape where the row becomes a `NavigationLink`. iOS typically
/// synthesizes one combined accessibility element for a link's label content,
/// which is why an explicit combined label is supplied here — but it also
/// means `weekly-review-session-completed`, set inside
/// `WeeklyProgramReviewSessionRow.stateBadge`, may not remain independently
/// queryable on this specific row shape. Flagged for Codex to verify with a
/// live accessibility inspection; every other state identifier sits on a
/// plain, non-link row and is not affected.
struct WeeklyProgramReviewSessionLink: View {
    let session: WeeklyProgramReviewProjection.Session

    var body: some View {
        if let workoutID = session.completedWorkoutID {
            NavigationLink {
                ProgramPathCompletedWorkoutDestination(workoutID: workoutID)
            } label: {
                WeeklyProgramReviewSessionRow(session: session)
            }
            .accessibilityLabel(combinedAccessibilityLabel)
            .accessibilityHint(Text("Opens the completed workout."))
        } else {
            WeeklyProgramReviewSessionRow(session: session)
        }
    }

    private var combinedAccessibilityLabel: String {
        var parts = [
            session.workoutName,
            WeeklyProgramReviewPresentation.sessionStateStyle(session.displayState).title,
            WeeklyProgramReviewPresentation.scheduledDateTitle(session.scheduledDate)
        ]
        if let rescheduled = WeeklyProgramReviewPresentation.rescheduledDetail(session) {
            parts.append(rescheduled)
        }
        return parts.joined(separator: ", ")
    }
}

/// Prescribed versus performed sets, shown only when the projection reports
/// complete evidence. Performed sets are always real — never fabricated — so
/// they still show even when the prescribed side is unavailable.
struct WeeklyProgramReviewSetSummary: View {
    let summary: WeeklyProgramReviewProjection.SetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if summary.comparisonIsComplete, let prescribed = summary.prescribedCount {
                HStack(spacing: Spacing.l) {
                    GymMetricValue(
                        value: prescribed.formatted(),
                        unit: WeeklyProgramReviewPresentation.prescribedSetsUnit
                    )
                    GymMetricValue(
                        value: summary.performedCount.formatted(),
                        unit: WeeklyProgramReviewPresentation.performedSetsUnit
                    )
                }
            } else {
                GymMetricValue(
                    value: summary.performedCount.formatted(),
                    unit: WeeklyProgramReviewPresentation.performedSetsUnit
                )
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(WeeklyProgramReviewPresentation.setComparisonUnavailableTitle)
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.gymSubduedText)
                        Text(WeeklyProgramReviewPresentation.setComparisonUnavailableDetail)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: AppIcon.info)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-review-set-summary")
    }
}
