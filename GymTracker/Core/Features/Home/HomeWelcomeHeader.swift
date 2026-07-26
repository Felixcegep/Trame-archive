import SwiftUI

struct HomeWelcomeHeader: View {
    let activePlanRun: PlanRun?
    let activeRepeatingPlanRun: RepeatingPlanRun?
    let summaryTitle: String
    let hasActiveWorkout: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.subheadlineMediumMonospaced)
                .foregroundStyle(Color.gymAccent)

            if let activePlanRun {
                activePlanContext(for: activePlanRun)
                    .padding(.bottom, Spacing.xs)
            } else if let activeRepeatingPlanRun {
                repeatingPlanContext(for: activeRepeatingPlanRun)
                    .padding(.bottom, Spacing.xs)
            }

            Text(summaryTitle)
                .font(AppFont.displayMedium)

            Text(hasActiveWorkout
                 ? "Your session is still running."
                 : "Train, reflect, and keep the day simple.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func activePlanContext(for run: PlanRun) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: AppIcon.plan)
                .font(AppFont.captionBold)

            Text(run.sourcePlanName)
                .font(AppFont.captionBold)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Spacing.s)

            Text("Week \(run.currentWeekIndex + 1)")
                .font(AppFont.caption2Bold)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background(Color.gymCard.opacity(0.72), in: Capsule())
        }
        .foregroundStyle(Color.gymAccent)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active plan: \(run.sourcePlanName), week \(run.currentWeekIndex + 1)")
        .accessibilityIdentifier("active-plan-badge")
    }

    private func repeatingPlanContext(for run: RepeatingPlanRun) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: AppIcon.routine)
                .font(AppFont.captionBold)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(run.sourcePlanName)
                    .font(AppFont.captionBold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cycle \(run.completedCycleCount + 1)")
                    .font(AppFont.caption2Bold)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.gymCard.opacity(0.72), in: Capsule())
            }
        }
        .foregroundStyle(Color.gymAccent)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active rotation: \(run.sourcePlanName), cycle \(run.completedCycleCount + 1)")
        .accessibilityIdentifier("active-repeating-plan-badge")
    }
}
