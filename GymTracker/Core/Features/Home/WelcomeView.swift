import SwiftUI

/// First launch: one screen, two ways forward.
///
/// Deliberately not a tour. A walkthrough that has to explain how to start a
/// plan is a symptom of a flow that does not explain itself, so this only asks
/// the one question the app cannot infer — do you want to be told what to
/// train, or do you want to log what you already do?
struct WelcomeView: View {
    let onChoosePlan: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Spacing.m) {
                Image(systemName: AppIcon.workout)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.gymPrimary)
                    .padding(.bottom, Spacing.s)

                Text("Welcome to GymTracker")
                    .font(AppFont.displayMedium)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You can follow a plan and be told what to train each day, or just log your own workouts. You can switch at any time.")
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: Spacing.m) {
                Button(action: onChoosePlan) {
                    Text("Follow a plan")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.l)
                        .background(Color.gymPrimary, in: Capsule())
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("welcome-follow-plan")

                Button(action: onSkip) {
                    Text("Just track my workouts")
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(Color.gymPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.l)
                        .background(Color.gymCard, in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.gymBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("welcome-skip")
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gymBackground)
        .accessibilityIdentifier("welcome")
    }
}
