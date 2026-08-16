import SwiftUI

/// Date plus the training context — active plan, active rotation, or personalization offer.
///
/// This header provides orientation (the date) and trailing training context.
/// When a plan or rotation is active, it presents the plan badge and week/cycle.
/// When no plan is active and the lifter is eligible, it presents a compact,
/// solid Trame competition color block offering personalization.
struct HomeWelcomeHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activePlanRun: PlanRun?
    let activeRepeatingPlanRun: RepeatingPlanRun?
    var showsPersonalizationOffer: Bool = false
    let onOpenPlan: (UUID) -> Void
    var onPersonalize: () -> Void = {}
    var onDeferPersonalization: () -> Void = {}

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    dateLabel
                    trainingContext
                }
            } else {
                HStack(spacing: Spacing.m) {
                    dateLabel
                    Spacer(minLength: Spacing.s)
                    trainingContext
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
    private var trainingContext: some View {
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
        } else if showsPersonalizationOffer {
            personalizationControl
        }
    }

    private var personalizationControl: some View {
        HStack(spacing: 0) {
            Button(action: onPersonalize) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: AppIcon.siri)
                        .font(AppFont.captionBold)

                    Text("PERSONALISE")
                        .font(AppFont.metadata)
                        .tracking(0.5)
                        .lineLimit(1)

                    Image(systemName: AppIcon.chevronRight)
                        .font(AppFont.micro)
                }
                .foregroundStyle(Color.trameSemanticFieldInk)
                .padding(.leading, Spacing.m)
                .padding(.trailing, Spacing.s)
                .frame(minHeight: ComponentSize.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("personalization-accept")
            .accessibilityLabel("Personalise training")
            .accessibilityHint("Opens training setup and plan recommendations.")

            Button(action: onDeferPersonalization) {
                Image(systemName: AppIcon.remove)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSemanticFieldInk)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("personalization-defer")
            .accessibilityLabel("Dismiss personalisation prompt")
            .accessibilityHint("Postpones training setup.")
        }
        .background(Color.trameCompetition, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
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
