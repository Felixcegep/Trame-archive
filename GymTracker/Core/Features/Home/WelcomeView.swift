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
struct WelcomeView: View {
    let onChoosePlan: () -> Void
    let onChooseRotation: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Image(systemName: AppIcon.workout)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.gymPrimary)
                        .padding(.bottom, Spacing.s)

                    Text("Welcome to GymTracker")
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Choose how your next workout gets decided. You can switch at any time, and nothing you have already done ever changes.")
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
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.m) {
                Image(systemName: icon)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(isProminent ? Color.gymPrimary : Color.gymSubduedText)
                    .frame(width: 34, height: 34)
                    .background(
                        (isProminent ? Color.gymPrimary : Color.gymSubduedText).opacity(0.12),
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
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(
                        isProminent ? Color.gymPrimary.opacity(0.24) : Color.gymBorder,
                        lineWidth: isProminent ? 1.5 : 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier(identifier)
        .accessibilityElement(children: .combine)
    }
}
