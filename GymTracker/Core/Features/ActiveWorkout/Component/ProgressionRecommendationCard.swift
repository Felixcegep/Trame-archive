import SwiftUI

/// The single progression recommendation surface. It renders inside the
/// exercise it belongs to, so it names the decision and its evidence but not
/// the exercise — the card that contains it already does.
struct ProgressionRecommendationCard: View {
    let exerciseName: String
    let state: RecommendationPresentationState
    let onAction: (RecommendationAction) -> Void

    // The sheet is the expansion of the card's inline one-liner, not a
    // replacement for it — `explanation` keeps rendering below unchanged.
    @State private var isShowingWhy = false

    var body: some View {
        TrameColorField(
            fill: Color.trameCurrent,
            ink: Color.trameText,
            border: Color.trameActionOutline,
            radius: Radius.medium
        ) {
            VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Label("Progression recommendation", systemImage: AppIcon.progression)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameText)

                Spacer()

                WhyButton(identifier: "progression-recommendation-why") {
                    isShowingWhy = true
                }
            }

            switch state {
            case .recommendation(let presentation):
                recommendationContent(presentation)
            case .insufficientHistory:
                insufficientHistoryContent
            }
            }
            .padding(Spacing.l)
        }
        // Keep the card addressable as a screenshot state without hiding its
        // action buttons from VoiceOver and UI tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progression-recommendation-card-\(exerciseName)")
        .sheet(isPresented: $isShowingWhy) {
            WhyExplanationView(model: whyModel)
        }
    }

    private var whyModel: WhyExplanationModel {
        switch state {
        case .recommendation(let presentation):
            return presentation.whyModel
        case .insufficientHistory:
            return RecommendationPresentationState.insufficientHistoryWhyModel()
        }
    }

    private func recommendationContent(_ presentation: RecommendationPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(presentation.explanation)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)

            if presentation.decision == .increase {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.s) {
                        increaseButtons(presentation)
                    }
                    VStack(spacing: Spacing.s) {
                        increaseButtons(presentation)
                    }
                }
            } else {
                Button {
                    onAction(.keepLast)
                } label: {
                    Text("Keep \(presentation.priorLoadText)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tramePrimaryAction)
                .accessibilityIdentifier("keep-last-recommendation-\(exerciseName)")
            }

            Button("Edit manually") {
                onAction(.edit)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .accessibilityIdentifier("edit-recommendation-\(exerciseName)")
        }
    }

    @ViewBuilder
    private func increaseButtons(_ presentation: RecommendationPresentation) -> some View {
        Button {
            onAction(.accept)
        } label: {
            Text("Accept \(presentation.appliedLoadText)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.tramePrimaryAction)
        .accessibilityIdentifier("accept-recommendation-\(exerciseName)")

        Button {
            onAction(.keepLast)
        } label: {
            Text("Keep \(presentation.priorLoadText)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier("keep-last-recommendation-\(exerciseName)")
    }

    private var insufficientHistoryContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("No recommendation yet. Complete this workout to establish your progression history.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onAction(.edit)
            } label: {
                Text("Enter starting weight")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tramePrimaryAction)
            .accessibilityIdentifier("enter-starting-weight-\(exerciseName)")
        }
    }
}
