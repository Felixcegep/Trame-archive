import SwiftUI

/// First launch: one screen, three ways to train.
///
/// Deliberately not a tour. A walkthrough that has to explain how to start a
/// plan is a symptom of a flow that does not explain itself, so this only asks
/// the one question the app cannot infer — how do you want your next workout
/// decided?
///
/// It offers three answers rather than two because the app supports three, and
/// the old wording ("Follow a plan" / "Just track my workouts") hid one of
/// them entirely. Rotations are not a variant of a plan: a plan puts sessions
/// on dates across a fixed number of weeks, while a rotation just hands you
/// the next workout in an endless cycle whenever you show up. A lifter who
/// trains four times "most weeks" wants the second one and would never have
/// found it behind a button that says "Follow a plan".
///
/// Each option is phrased as something the lifter would say about themselves,
/// not as the name of a model type.
///
/// The choice commits on tap. There is no select-then-Continue pair here,
/// because on a routing screen the selection *is* the decision and a second
/// confirming tap confirms nothing — it only asks the lifter to agree with
/// themselves. What the brief pause before navigating buys is the one thing a
/// bare push does not: seeing which card you hit.
struct WelcomeView: View {
    let onChoosePlan: () -> Void
    let onChooseRotation: () -> Void
    let onSkip: () -> Void

    /// The card that has been chosen, held only long enough for its selected
    /// state to be visible before the screen changes underneath it.
    @State private var committedIdentifier: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Long enough to register as a state change on a 120 Hz display, short
    /// enough that no one experiences it as the app thinking.
    private static let commitDelay: Duration = .milliseconds(150)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(spacing: Spacing.m) {
                        TrameMarkView(height: 44)

                        Text("Welcome to Trame")
                            .font(AppFont.displayMedium)
                            .foregroundStyle(Color.gymText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Spacing.s)

                    Text("How do you want your next workout decided?")
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("You can change this at any time. Nothing you have already trained changes when you do.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Spacing.m) {
                    LibrarySectionTitle("Set up my training")

                    optionCard(
                        title: "Follow a plan",
                        detail: "My sessions are scheduled across a set number of weeks.",
                        icon: AppIcon.plan,
                        identifier: "welcome-follow-plan",
                        action: onChoosePlan
                    )

                    optionCard(
                        title: "Follow a rotation",
                        detail: "I always do the next workout in the cycle, whatever day it is.",
                        icon: AppIcon.routine,
                        identifier: "welcome-follow-rotation",
                        action: onChooseRotation
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.m) {
                    LibrarySectionTitle("Or start now")

                    optionCard(
                        title: "Free workout",
                        detail: "I decide what I am doing today.",
                        icon: AppIcon.play,
                        identifier: "welcome-skip",
                        isProminent: false,
                        action: onSkip
                    )
                }

                Text("Free workout asks you nothing. You can set up a plan whenever you want one.")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.gymBackground)
        .accessibilityIdentifier("welcome")
    }

    /// One option, as a full-width row rather than a capsule button.
    ///
    /// A capsule fits a verb and nothing else, and every one of these needs a
    /// sentence to be distinguishable from the others — which is the entire
    /// point of the screen.
    private func optionCard(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        icon: String,
        identifier: String,
        isProminent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let isCommitted = committedIdentifier == identifier

        return Button {
            commit(identifier, then: action)
        } label: {
            HStack(alignment: .top, spacing: Spacing.m) {
                // Becomes a checkmark on the chosen card. The glyph changes in
                // place rather than the card growing or bouncing: this row is
                // about to be replaced by the next screen, and a card that
                // celebrates on its way out reads as a delay.
                Image(systemName: isCommitted ? AppIcon.checkmark : icon)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(iconTint(isProminent: isProminent, isCommitted: isCommitted))
                    .frame(width: 34, height: 34)
                    .background(
                        iconTint(isProminent: isProminent, isCommitted: isCommitted).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Radius.medium)
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymText)

                    Text(detail)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubtleText)
                    .padding(.top, Spacing.md)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isCommitted ? Color.gymPrimarySurface : Color.gymCard,
                in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(
                        strokeTint(isProminent: isProminent, isCommitted: isCommitted),
                        lineWidth: isCommitted || isProminent ? 1.5 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : AppMotion.compact, value: isCommitted)
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCommitted ? .isSelected : [])
        // A second tap on a screen that is already leaving would run the
        // routing action twice.
        .disabled(committedIdentifier != nil)
    }

    private func iconTint(isProminent: Bool, isCommitted: Bool) -> Color {
        if isCommitted { return .gymPrimary }
        return isProminent ? .gymPrimary : .gymSubduedText
    }

    private func strokeTint(isProminent: Bool, isCommitted: Bool) -> Color {
        if isCommitted { return .gymPrimary }
        return isProminent ? Color.gymPrimary.opacity(0.24) : .gymBorder
    }

    private func commit(_ identifier: String, then action: @escaping () -> Void) {
        guard committedIdentifier == nil else { return }
        committedIdentifier = identifier
        Task {
            try? await Task.sleep(for: Self.commitDelay)
            action()
        }
    }
}
