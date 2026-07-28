import SwiftUI

/// What comes after the reviewed week: its position, block/phase, ordered
/// sessions with dates, and a deload callout when the block ahead reduces
/// volume or intensity.
struct WeeklyProgramReviewNextWeekView: View {
    let nextWeek: WeeklyProgramReviewProjection.NextWeek

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(WeeklyProgramReviewPresentation.nextWeekPositionTitle(nextWeek))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)

                if nextWeek.blockName != nil || nextWeek.phaseType != nil {
                    ChipFlowLayout(spacing: Spacing.s) {
                        if let blockName = nextWeek.blockName {
                            GymTagChip(title: blockName, tint: .gymAccent, style: .outlined)
                        }
                        if let phaseType = nextWeek.phaseType {
                            GymTagChip(
                                title: ProgramPathPresentation.phaseTitle(phaseType),
                                systemImage: phaseType == .deload ? AppIcon.pause : AppIcon.progression,
                                tint: phaseType == .deload ? .gymAccent : .gymPrimary
                            )
                        }
                    }
                }
            }

            ForEach(nextWeek.sessions) { session in
                HStack(spacing: Spacing.m) {
                    GymIconChip(systemImage: AppIcon.routine, tint: .gymPrimary)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(session.name)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        Text(WeeklyProgramReviewPresentation.scheduledDateTitle(session.scheduledDate))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }

            if nextWeek.isDeload {
                ProgramPathDeloadView(
                    title: WeeklyProgramReviewPresentation.nextWeekDeloadTitle,
                    detail: WeeklyProgramReviewPresentation.nextWeekDeloadReductions(
                        volumeReductionPercent: nextWeek.deloadVolumeReductionPercent,
                        intensityReductionPercent: nextWeek.deloadIntensityReductionPercent
                    )
                )
                .accessibilityIdentifier("weekly-review-next-week-deload")
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityIdentifier("weekly-review-next-week")
    }
}

/// The reviewed week is the last one the run has scheduled.
struct WeeklyProgramReviewFinalWeekView: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(WeeklyProgramReviewPresentation.finalWeekTitle)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(WeeklyProgramReviewPresentation.finalWeekDetail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: AppIcon.checkmarkCircle)
                .foregroundStyle(Color.gymSuccess)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekly-review-next-week")
    }
}
