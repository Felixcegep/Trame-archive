import SwiftUI

// MARK: - Scaffold

/// The one composition every question screen uses.
///
/// Written once rather than per question because the thing that makes a
/// multi-step form feel calm is that nothing moves between steps except the
/// answer: the title bar, the progress, and the committing action hold their
/// positions while only the middle changes. Twelve screens each laying
/// themselves out is twelve chances for the Continue button to shift by four
/// points and make the flow feel unsteady.
struct OnboardingScaffold<Content: View>: View {
    let step: OnboardingStep
    let progressDescription: String?
    let progressFraction: Double
    let stepIndex: Int
    let stepCount: Int
    let direction: OnboardingCoordinator.Direction
    let canGoBack: Bool
    let validationMessage: String?
    /// `nil` on steps where the selection itself commits, so no dead button
    /// sits at the bottom of a screen that does not need one.
    let primaryAction: (title: String, isEnabled: Bool, perform: () -> Void)?
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isQuestionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressHeader(
                progressDescription: progressDescription,
                progressFraction: progressFraction,
                stepIndex: stepIndex,
                stepCount: stepCount,
                canGoBack: canGoBack,
                onBack: onBack,
                onSkip: onSkip
            )

            // The question is pinned; only the answers scroll.
            //
            // It used to scroll with them, which broke down on exactly the
            // screen that needed it most: "What do you mainly train?" offers
            // eleven options, and by the time you have scrolled to Strongman
            // the question is gone. Choosing from a list whose prompt you can
            // no longer see is a memory test the flow has no business setting.
            //
            // Both the question and the answers travel together on a step
            // change, so the pin costs nothing at the transition.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(step.question)
                        .font(AppFont.displayMedium)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isQuestionFocused)
                        // Spoken once, on the heading, so VoiceOver hears
                        // the question and its position together instead of
                        // hunting for a progress label elsewhere.
                        .accessibilityLabel(accessibleQuestion)

                    if let explanation = step.explanation {
                        Text(explanation)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    content
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.xxxl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            // Chrome above and below is deliberately outside this transition.
            .transition(stepTransition)
            .id(step)

            OnboardingBottomAction(
                validationMessage: validationMessage,
                primaryAction: primaryAction
            )
        }
        .background(Color.gymBackground)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : AppMotion.layout, value: step)
        .onAppear { moveFocusToQuestion() }
        .onChange(of: step) { _, _ in moveFocusToQuestion() }
        .accessibilityIdentifier("onboarding-step-\(step.rawValue)")
    }

    private var accessibleQuestion: String {
        guard let progressDescription else { return step.question }
        return "\(step.question). \(progressDescription)"
    }

    /// Directional under normal settings, a crossfade under Reduce Motion.
    ///
    /// The direction is the lifter's own: forward leaves toward the leading
    /// edge and arrives from the trailing one, and Back reverses it, so the
    /// flow has a consistent sense of where the previous answer went.
    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let isForward = direction == .forward
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    /// VoiceOver reads from the top of a changed screen only if something asks
    /// it to; otherwise focus stays on the Continue button the lifter just
    /// activated, and the next question is never announced at all.
    private func moveFocusToQuestion() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        isQuestionFocused = true
    }
}

// MARK: - Progress header

/// Back, position, and Skip — the three controls that must never move.
struct OnboardingProgressHeader: View {
    let progressDescription: String?
    let progressFraction: Double
    let stepIndex: Int
    let stepCount: Int
    let canGoBack: Bool
    let onBack: () -> Void
    let onSkip: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onBack) {
                Image(systemName: AppIcon.chevronLeft)
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .frame(
                        width: ComponentSize.minimumTouchTarget,
                        height: ComponentSize.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.gymPress)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("onboarding-back")
            .accessibilityHidden(!canGoBack)

            segments
                .frame(maxWidth: .infinity)

            if let onSkip {
                Button("Skip", action: onSkip)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("onboarding-skip")
                    .accessibilityHint("Leaves this question unanswered.")
            } else {
                // Holds the Back button's counterweight so the progress bar
                // stays centred whether or not the step can be skipped.
                Color.clear
                    .frame(
                        width: ComponentSize.minimumTouchTarget,
                        height: ComponentSize.minimumTouchTarget
                    )
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.md)
        .background(Color.gymBackground)
    }

    /// One capsule per question rather than a continuous bar.
    ///
    /// A bar at 43% tells the lifter nothing they can act on. Segments say how
    /// many questions are left in a form they can count at a glance, and only
    /// the segment that changed animates — so moving between steps never reads
    /// as the whole indicator redrawing.
    private var segments: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(stepCount, 1), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= stepIndex ? Color.gymPrimary : Color.gymBorder)
                    .frame(height: 4)
                    .animation(reduceMotion ? nil : AppMotion.compact, value: stepIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressDescription ?? "")
        .accessibilityValue(Text(progressFraction, format: .percent.precision(.fractionLength(0))))
        .accessibilityIdentifier("onboarding-progress")
    }
}

// MARK: - Bottom action

/// The committing action and the reason it is refusing, in a container whose
/// height does not depend on whether either is present.
///
/// Validation appears directly above the button that refused, not at the top of
/// a screen the lifter has scrolled away from.
struct OnboardingBottomAction: View {
    let validationMessage: String?
    let primaryAction: (title: String, isEnabled: Bool, perform: () -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isMessageFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.s) {
            if let validationMessage {
                OnboardingValidationMessage(text: validationMessage)
                    .accessibilityFocused($isMessageFocused)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }

            if let primaryAction {
                Button(primaryAction.title, action: primaryAction.perform)
                    .buttonStyle(.gymPrimaryProminent)
                    .disabled(!primaryAction.isEnabled)
                    .accessibilityIdentifier("onboarding-continue")
            } else {
                // The band keeps its height on steps that commit themselves.
                //
                // Without this the bar collapsed to its padding, the answer
                // area above it grew by a button's worth, and every move
                // between a self-advancing question and one with a Continue
                // button resized the list mid-transition. The cost is a strip
                // of empty space; what it buys is that the button is always in
                // the place the eye already learned, and that the options never
                // shift under a finger reaching for them.
                //
                // The real button, hidden — not a hardcoded height. A fixed 54
                // matched `.gymPrimaryProminent` at default type only; at
                // accessibility sizes the button grows and the placeholder did
                // not, which brought back the exact jump it exists to prevent.
                Button("Continue") {}
                    .buttonStyle(.gymPrimaryProminent)
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color.gymBackground)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : AppMotion.compact, value: validationMessage)
        .onChange(of: validationMessage) { _, newValue in
            guard newValue != nil, UIAccessibility.isVoiceOverRunning else { return }
            isMessageFocused = true
        }
    }
}

struct OnboardingValidationMessage: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: AppIcon.warningCircle)
                .font(AppFont.footnoteMedium)
                .foregroundStyle(Color.gymDestructive)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(
            Color.gymDestructive.opacity(0.10),
            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding-validation")
    }
}

// MARK: - Choice card

/// One answer, as a full-width row.
///
/// Full width rather than a two-column grid because most of these answers need
/// a sentence to be distinguishable from their neighbours — "General strength"
/// and "General fitness" are the same four syllables until you read what they
/// mean. Selection is carried by three independent channels (surface, border,
/// glyph) so it survives grayscale and Increase Contrast.
struct OnboardingChoiceCard: View {
    let title: String
    var detail: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.m) {
                // The icon is the first thing to go at accessibility sizes.
                //
                // A 34-point badge, a selection glyph and text that now wraps to
                // four or five lines leave the title column too narrow to read.
                // The icon is decorative — it is already hidden from VoiceOver
                // and never distinguishes two answers on its own — while the
                // glyph is the only non-color carrier of selection, so the icon
                // is what the row can afford to lose.
                if let icon, !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: icon)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymSubduedText)
                        .frame(width: 34, height: 34)
                        .background(
                            (isSelected ? Color.gymPrimary : Color.gymSubduedText).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: Radius.medium)
                        )
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.headlineSemibold)
                        .foregroundStyle(Color.gymText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail {
                        Text(detail)
                            .font(AppFont.subheadline)
                            .foregroundStyle(Color.gymSubduedText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Spacing.s)

                // Occupies its slot whether or not it is selected, so choosing
                // an answer never reflows the row it is in.
                Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                    .font(AppFont.headline)
                    .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymBorder)
                    .padding(.top, Spacing.xxs)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.gymPrimarySurface : Color.gymCard,
                in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .stroke(isSelected ? Color.gymPrimary : Color.gymBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : AppMotion.compact, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Multi-select tile

/// A member of a checklist. Distinguished from `OnboardingChoiceCard` by the
/// square indicator, which is the standard signal that more than one answer is
/// allowed — the flow should never need a sentence explaining that.
struct OnboardingMultiChoiceTile: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppFont.subheadline)
                        .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymSubduedText)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: Spacing.xs)

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(AppFont.subheadline)
                    .foregroundStyle(isSelected ? Color.gymPrimary : Color.gymBorder)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.m)
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .background(
                isSelected ? Color.gymPrimarySurface : Color.gymCard,
                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .stroke(isSelected ? Color.gymPrimary : Color.gymBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : AppMotion.compact, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Two columns normally, one at accessibility text sizes — where a two-column
/// grid stops being a grid and starts being two columns of truncation.
struct OnboardingTileGrid<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.s) {
            content
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: count)
    }
}

// MARK: - Compact chip

/// A single short token: a day count, a weekday initial. Only used where the
/// answer is one or two characters and a full-width row would be absurd.
struct OnboardingChip: View {
    let title: String
    var accessibilityTitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(isSelected ? Color.white : Color.gymText)
                // The token is one or two characters, so it must never wrap —
                // a weekday initial broken across two lines is not a label. The
                // frame is a *minimum*, so the chip grows with the type size
                // instead of clipping, and the scale factor only absorbs the
                // last few points where a wide glyph would still overrun.
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: ComponentSize.minimumTouchTarget, minHeight: ComponentSize.minimumTouchTarget)
                .padding(.horizontal, Spacing.s)
                .background(
                    isSelected ? Color.gymPrimaryDeep : Color.gymCard,
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .stroke(isSelected ? Color.gymPrimaryDeep : Color.gymBorder, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : AppMotion.compact, value: isSelected)
        .accessibilityLabel(accessibilityTitle ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
