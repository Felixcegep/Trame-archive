import SwiftUI

/// Date plus the plan you are following — nothing else.
///
/// This header used to repeat the workout name, plan name, and week that
/// `HomePrimaryWorkoutCard` states immediately below it, plus a fixed greeting
/// line that never changed. The hero card is the better place for all of that,
/// so the header keeps only what the card does not say: the date, and a tap
/// target into the plan itself.
struct HomeWelcomeHeader: View {
    let activePlanRun: PlanRun?
    let activeRepeatingPlanRun: RepeatingPlanRun?
    let onOpenPlan: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.subheadlineMediumMonospaced)
                .foregroundStyle(Color.gymAccent)

            if let activePlanRun {
                planChip(
                    planID: activePlanRun.sourcePlanID,
                    icon: AppIcon.plan,
                    name: activePlanRun.sourcePlanName,
                    stage: "Week \(activePlanRun.currentWeekIndex + 1)",
                    accessibilityLabel: "Active plan: \(activePlanRun.sourcePlanName), week \(activePlanRun.currentWeekIndex + 1)",
                    accessibilityIdentifier: "active-plan-badge"
                )
            } else if let activeRepeatingPlanRun {
                planChip(
                    planID: activeRepeatingPlanRun.sourcePlanID,
                    icon: AppIcon.routine,
                    name: activeRepeatingPlanRun.sourcePlanName,
                    stage: "Cycle \(activeRepeatingPlanRun.completedCycleCount + 1)",
                    accessibilityLabel: "Active rotation: \(activeRepeatingPlanRun.sourcePlanName), cycle \(activeRepeatingPlanRun.completedCycleCount + 1)",
                    accessibilityIdentifier: "active-repeating-plan-badge"
                )
            }
        }
    }

    private func planChip(
        planID: UUID,
        icon: String,
        name: String,
        stage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            onOpenPlan(planID)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(AppFont.captionBold)

                Text(name)
                    .font(AppFont.captionBold)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Spacing.s)

                Text(stage)
                    .font(AppFont.captionBold)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.gymBackground, in: Capsule())

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
            }
            .foregroundStyle(Color.gymAccent)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the plan.")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
