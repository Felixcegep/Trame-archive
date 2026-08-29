import SwiftUI

/// The active-session decision surface for the one progression action that
/// must be resolved before the performed workout becomes immutable History.
/// The persisted recommendation remains the source of its action and evidence.
struct ActiveDailyMaximumRecommendationCard: View {
    let recommendation: PlanProgressionRecommendationRecord
    let exerciseName: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isShowingWhy = false

    private var action: (sets: Int, repetitions: Int, percentage: Double)? {
        guard let decoded = try? recommendation.action(),
              case let .endActiveDailyMaximumAndGenerateBackOffs(sets, repetitions, percentage) = decoded
        else { return nil }
        return (sets, repetitions, percentage)
    }

    private var missCount: Int {
        recommendation.performance()?.consecutiveMissedAttempts ?? 0
    }

    var body: some View {
        if let action {
            TrameColorField(
                fill: Color.trameCurrent,
                ink: Color.trameText,
                border: Color.trameActionOutline,
                radius: Radius.medium
            ) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Label("Daily maximum decision", systemImage: AppIcon.progression)
                        .font(AppFont.headlineSemibold)

                    Text(summaryText)
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(proposalText(action: action))
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)

                    WhyButton(identifier: "active-daily-maximum-why-\(recommendation.id.uuidString)") {
                        isShowingWhy = true
                    }

                    VStack(spacing: Spacing.s) {
                        Button("Stop and add back-offs", action: onAccept)
                            .buttonStyle(.tramePrimaryAction)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier(
                                "active-daily-maximum-accept-\(recommendation.id.uuidString)"
                            )

                        Button("Continue maximum attempts", action: onDecline)
                            .font(AppFont.subheadlineSemibold)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: ComponentSize.minimumTouchTarget
                            )
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.trameText)
                            .accessibilityIdentifier(
                                "active-daily-maximum-decline-\(recommendation.id.uuidString)"
                            )
                    }
                }
                .padding(Spacing.l)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                "active-daily-maximum-recommendation-\(recommendation.id.uuidString)"
            )
            .sheet(isPresented: $isShowingWhy) {
                WhyExplanationView(model: whyModel(action: action))
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...1)))
    }

    private var summaryText: String {
        String(
            format: String(
                localized: "active.dailyMaximum.summary",
                defaultValue: "%1$@ — %2$lld attempts missed in a row."
            ),
            exerciseName,
            Int64(missCount)
        )
    }

    private func proposalText(
        action: (sets: Int, repetitions: Int, percentage: Double)
    ) -> String {
        String(
            format: String(
                localized: "active.dailyMaximum.proposal",
                defaultValue: "Stop maximum attempts and add %1$lld × %2$lld back-off sets at %3$@ of your best successful attempt?"
            ),
            Int64(action.sets),
            Int64(action.repetitions),
            formattedPercentage(action.percentage)
        )
    }

    private func whyModel(
        action: (sets: Int, repetitions: Int, percentage: Double)
    ) -> WhyExplanationModel {
        var builder = WhyExplanationBuilder(
            title: String(localized: "Why?"),
            isDecision: true
        )
        builder.add(
            .whatChanged,
            body: String(
                format: String(
                    localized: "active.dailyMaximum.why.change",
                    defaultValue: "Stop further maximum attempts and add %1$lld × %2$lld back-off sets at %3$@."
                ),
                Int64(action.sets),
                Int64(action.repetitions),
                formattedPercentage(action.percentage)
            )
        )
        builder.add(
            .evidenceUsed,
            items: [
                String(
                    format: String(
                        localized: "active.dailyMaximum.why.misses",
                        defaultValue: "%lld consecutive parent attempts were recorded as missed."
                    ),
                    Int64(missCount)
                ),
                String(
                    localized: "active.dailyMaximum.why.bestAttempt",
                    defaultValue: "The best successful attempt in this exercise sets the back-off load."
                )
            ]
        )
        builder.add(
            .ifYouAccept,
            body: String(
                localized: "active.dailyMaximum.why.accept",
                defaultValue: "Completed attempts stay unchanged. Only unperformed maximum attempts are removed, and the back-off prescriptions are added to this active workout."
            )
        )
        builder.add(
            .ifYouDecline,
            body: String(
                localized: "active.dailyMaximum.why.decline",
                defaultValue: "Your maximum-attempt sequence remains available and no back-off sets are generated from this decision."
            )
        )
        return builder.build()
    }
}
