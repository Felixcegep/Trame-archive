import SwiftUI

/// One refinement question, over the results it is about to reorder.
///
/// The questions in here used to be asked before the lifter had seen a single
/// plan. That ordering was the flow's central mistake: "how long should most
/// workouts take?" is an abstraction when nothing is on screen, and a visible,
/// reversible filter when the list is right behind the sheet. Same question,
/// same control, entirely different thing to answer.
///
/// A sheet rather than a push, because this is a temporary task the lifter
/// returns from — and because the list staying visible behind it is the whole
/// argument for asking here at all.
struct OnboardingRefinementSheet: View {
    @Bindable var coordinator: OnboardingCoordinator
    let step: OnboardingStep

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if let explanation = step.explanation {
                        Text(explanation)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    OnboardingAnswerContent(coordinator: coordinator, step: step) { answered in
                        // A single-answer question is finished the moment it is
                        // answered, and a sheet that stays open after that is
                        // asking the lifter to dismiss a decision they already
                        // made. Multi-select keeps the sheet: there is no way
                        // to know the third tick was the last one.
                        guard answered.advancesOnSelection else { return }
                        dismiss()
                    }

                    if coordinator.hasAnswer(for: step) {
                        clearButton
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.gymBackground)
            .navigationTitle(step.refinementTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("onboarding-refinement-done")
                }
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("onboarding-refinement-\(step.rawValue)")
    }

    /// Unanswering, as a first-class action.
    ///
    /// The linear flow had a Skip button on every question, and dropping it
    /// without a replacement would have made these the only answers in the app
    /// that cannot be taken back — a lifter who tapped "Advanced" by mistake
    /// could reach every value except the one they started with. A cleared
    /// answer stores nothing and simply stops contributing to the ranking,
    /// which is the same thing Skip always meant.
    private var clearButton: some View {
        Button("Clear answer") {
            coordinator.clearAnswer(for: step)
        }
        .font(AppFont.subheadlineSemibold)
        .foregroundStyle(Color.gymSubduedText)
        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("onboarding-refinement-clear")
    }

    /// Sized to the question. A four-option list at `.large` is a screen of
    /// empty space between the answers and the plan the lifter is refining;
    /// the equipment grid and the competition form genuinely need the height.
    private var detents: Set<PresentationDetent> {
        switch step {
        case .equipment, .specializedEquipment, .competition:
            [.large]
        default:
            [.medium, .large]
        }
    }
}

/// The mobility intake, taken only by someone who asked for it.
///
/// These three questions used to sit at the end of the main flow, behind a
/// feature flag, charged to every lifter who had just spent ten screens setting
/// up a training plan. Mobility is a separate track — a lifter can want either,
/// both or neither — so it now has a separate door, and the door says what is
/// behind it before anyone opens it.
///
/// All three on one sheet rather than three in sequence: they are one decision
/// about one thing, and a lifter who has explicitly opted in does not need to
/// be walked through them one at a time.
struct OnboardingMobilityIntakeSheet: View {
    @Bindable var coordinator: OnboardingCoordinator

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    question(.mobilityGoal)

                    // The two follow-ups appear only once there is a goal, the
                    // same rule the linear flow used: someone who has not said
                    // they want a mobility plan is never asked two more
                    // questions about one.
                    if coordinator.draft.mobilityGoal != nil {
                        question(.mobilityExperience)
                        question(.mobilityFrequency)
                        clearButton
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.gymBackground)
            .navigationTitle("Mobility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("onboarding-mobility-intake-done")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("onboarding-mobility-intake")
    }

    private func question(_ step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(step.question)
                .font(AppFont.headlineSemibold)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            // No auto-advance and no dismissal on tap: this sheet holds three
            // questions, so an answer to the first is not the end of anything.
            OnboardingAnswerContent(coordinator: coordinator, step: step)
        }
    }

    /// Backing all the way out of mobility, in one action.
    ///
    /// Clearing the goal alone would leave an experience level and a frequency
    /// behind for a plan track the lifter just said they did not want — answers
    /// that no screen would show them again and that the ranking would still
    /// read the next time they opened the door.
    private var clearButton: some View {
        Button("I don’t want a mobility plan") {
            coordinator.clearAnswer(for: .mobilityFrequency)
            coordinator.clearAnswer(for: .mobilityExperience)
            coordinator.clearAnswer(for: .mobilityGoal)
        }
        .font(AppFont.subheadlineSemibold)
        .foregroundStyle(Color.gymSubduedText)
        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("onboarding-mobility-intake-clear")
    }
}
