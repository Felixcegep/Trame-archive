import SwiftUI

/// Date plus the plan you are following — nothing else.
///
/// This header used to repeat the workout name, plan name, and week that
/// `HomePrimaryWorkoutCard` states immediately below it, plus a fixed greeting
/// line that never changed. The hero card is the better place for all of that,
/// so the header keeps only what the card does not say: the date, and a tap
/// target into the plan itself.
struct HomeWelcomeHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activePlanRun: PlanRun?
    let activeRepeatingPlanRun: RepeatingPlanRun?
    let onOpenPlan: (UUID) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    dateLabel
                    planContext
                }
            } else {
                HStack(spacing: Spacing.m) {
                    dateLabel
                    Spacer(minLength: Spacing.s)
                    planContext
                }
            }
        }
    }

    private var dateLabel: some View {
        // Subdued ink keeps orientation available without spending a semantic
        // training color on information that never needs action.
        Text(todayLabel)
            .font(AppFont.eyebrow)
            .tracking(1.1)
            .foregroundStyle(Color.trameSubdued)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var planContext: some View {
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

    private var todayLabel: String {
        Date.now
            .formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .uppercased(with: .current)
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
                    .foregroundStyle(Color.trameStrength)

                Text(name)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(stage)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .background(Color.trameRow, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the plan.")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
