import SwiftUI

/// One progression recommendation resolved during this week: which exercise,
/// what outcome, and the proposed/applied loads when the record supplies
/// them. Purely a report — this is history, not a live decision, so there is
/// no accept/decline control here.
struct WeeklyProgramReviewProgressionDecisionRow: View {
    let decision: WeeklyProgramReviewProjection.ProgressionDecision

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(WeeklyProgramReviewPresentation.decisionExerciseName(decision.exerciseName))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)

            Label(outcomeTitle, systemImage: outcomeIcon)
                .font(AppFont.captionBold)
                .foregroundStyle(outcomeTint)

            if let proposed = WeeklyProgramReviewPresentation.proposedLoadLine(decision.proposedLoad) {
                Text(proposed)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            if let applied = WeeklyProgramReviewPresentation.appliedLoadLine(decision.appliedLoad) {
                Text(applied)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Text(WeeklyProgramReviewPresentation.ruleLabel(version: decision.ruleVersion))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-review-progression-decision")
    }

    private var outcomeTitle: String {
        WeeklyProgramReviewPresentation.decisionOutcomeTitle(
            isResolved: decision.isResolved,
            outcome: decision.outcome
        )
    }

    private var outcomeIcon: String {
        WeeklyProgramReviewPresentation.decisionOutcomeIcon(
            isResolved: decision.isResolved,
            outcome: decision.outcome
        )
    }

    private var outcomeTint: Color {
        WeeklyProgramReviewPresentation.decisionOutcomeTint(
            isResolved: decision.isResolved,
            outcome: decision.outcome
        )
    }
}

/// One exercise substitution recorded in a completed workout this week.
///
/// Reuses `SubstitutionPresentation`'s existing titles, icons, and tints for
/// suitability, comparability, confidence, scope, and progression effect —
/// the same vocabulary the Active Workout substitution flow already renders
/// — rather than inventing a second copy of it here. Fields the underlying
/// entry never recorded (legacy evidence) are simply omitted, never shown as
/// a fabricated placeholder; `WeeklyProgramReviewProjection.Warning
/// .legacySubstitutionEvidence` already explains the gap in the warnings
/// section.
struct WeeklyProgramReviewSubstitutionRow: View {
    let substitution: WeeklyProgramReviewProjection.Substitution

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(WeeklyProgramReviewPresentation.substitutionOriginalName(substitution.originalExerciseName))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityHidden(true)
                Text(substitution.selectedExerciseName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
            }
            .fixedSize(horizontal: false, vertical: true)

            if let reason = substitution.reason {
                Text(SubstitutionPresentation.reasonTitle(reason))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            if let scope = substitution.scope {
                GymTagChip(
                    title: SubstitutionPresentation.scopeTitle(scope),
                    style: .outlined
                )
            }

            if let suitability = substitution.suitability {
                verdictLine(
                    icon: SubstitutionPresentation.suitabilityIcon(suitability),
                    text: SubstitutionPresentation.suitabilityTitle(suitability),
                    tint: SubstitutionPresentation.suitabilityColor(suitability)
                )
            }

            if let comparability = substitution.comparability {
                verdictLine(
                    icon: SubstitutionPresentation.comparabilityIcon(comparability),
                    text: SubstitutionPresentation.comparabilityTitle(comparability),
                    tint: SubstitutionPresentation.comparabilityColor(comparability)
                )
                Text(SubstitutionPresentation.comparabilityDetail(comparability))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let policy = substitution.progressionPolicy {
                Text(SubstitutionPresentation.progressionEffect(policy))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let confidence = substitution.confidence {
                Text(SubstitutionPresentation.confidenceTitle(confidence))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-review-substitution")
    }

    private func verdictLine(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(AppFont.caption)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(tint)
        }
    }
}
