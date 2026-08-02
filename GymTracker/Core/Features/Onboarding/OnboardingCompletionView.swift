import SwiftData
import SwiftUI

/// The one confirmation that setup worked, and what happens next.
///
/// It does not dismiss itself. A screen that appears and vanishes before it is
/// read has told the lifter nothing, and the whole point of arriving here is to
/// answer "what am I doing next, and when" without having to go looking. The
/// flow leaves only when the lifter says so.
struct OnboardingCompletionView: View {
    let summary: OnboardingActivationSummary
    let onOpenToday: () -> Void
    let onReviewPlan: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isHeadingFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.xl) {
                // The app's existing branded completion beat, played once.
                // Reusing it rather than authoring a new celebration keeps the
                // one moment of overshoot in the product on the mark it was
                // written for — and `TrameLiftAndLock` already resolves to its
                // exact final frame under Reduce Motion.
                TrameLiftAndLock(variant: .signature, markHeight: 72, showsWordmark: false)
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.s) {
                    Text(headline)
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isHeadingFocused)

                    Text(subheadline)
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymSubduedText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let detail = firstSessionDetail {
                    firstSessionCard(detail)
                }
            }
            .padding(.horizontal, Spacing.xl)

            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.s) {
                Button("View today’s training", action: onOpenToday)
                    .buttonStyle(.gymPrimaryProminent)
                    .accessibilityIdentifier("onboarding-open-today")

                if let onReviewPlan {
                    Button("Review plan", action: onReviewPlan)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymSubduedText)
                        .frame(minHeight: ComponentSize.minimumTouchTarget)
                        .buttonStyle(.gymPress)
                        .accessibilityIdentifier("onboarding-review-plan")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gymBackground)
        .accessibilityIdentifier("onboarding-completion")
        .onAppear {
            guard UIAccessibility.isVoiceOverRunning else { return }
            isHeadingFocused = true
        }
    }

    private var headline: String {
        switch summary {
        case .plan, .rotation: String(localized: "Your training is ready")
        case .freeWorkout: String(localized: "You’re ready to train")
        }
    }

    private var subheadline: String {
        switch summary {
        case .plan(let name, _, _):
            String(localized: "\(name) is now the plan you’re following.")
        case .rotation(let name, _):
            String(localized: "\(name) is now the rotation you’re following.")
        case .freeWorkout:
            String(localized: "Start a workout whenever you like. You can set up a plan later from Train.")
        }
    }

    /// What the lifter actually needs: the next session, named and dated.
    private var firstSessionDetail: (title: String, value: String)? {
        switch summary {
        case .plan(_, let date, let sessionCount):
            guard let date else {
                return (String(localized: "Sessions"), String(localized: "\(CountPhrase.sessions(sessionCount)) scheduled"))
            }
            return (
                String(localized: "First session"),
                date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            )
        case .rotation(_, let nextWorkoutName):
            guard let nextWorkoutName else { return nil }
            return (String(localized: "Next in rotation"), nextWorkoutName)
        case .freeWorkout:
            return nil
        }
    }

    private func firstSessionCard(_ detail: (title: String, value: String)) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(detail.title.uppercased())
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)
            Text(detail.value)
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding-first-session")
    }
}

extension OnboardingActivationSummary {
    /// Reads back what activation actually committed, rather than assuming the
    /// program the lifter tapped is the one that ended up active. A setup sheet
    /// can be cancelled, and a conflict can pause one source in favour of
    /// another; the completion screen has to report the store, not the intent.
    @MainActor
    static func current(using context: ModelContext) -> OnboardingActivationSummary? {
        if let run = PlanLifecycleService.activeFixedRuns(using: context)
            .max(by: { $0.createdAt < $1.createdAt }) {
            let upcoming = run.orderedWorkoutProgress.first { $0.status != .completed && $0.status != .skipped }
            return .plan(
                name: run.sourcePlanName,
                firstSessionDate: upcoming?.scheduledDate,
                sessionCount: run.workoutProgress.count
            )
        }
        if let run = PlanLifecycleService.activeRepeatingRuns(using: context)
            .max(by: { $0.startedAt < $1.startedAt }) {
            let slots = run.orderedSlots
            let next = slots.indices.contains(run.currentSlotIndex) ? slots[run.currentSlotIndex] : slots.first
            return .rotation(name: run.sourcePlanName, nextWorkoutName: next?.templateNameSnapshot)
        }
        return nil
    }
}
