import SwiftUI

/// The optional warm-up offered at the moment a workout starts.
///
/// This was a `confirmationDialog`, which is the wrong container for it twice
/// over. An action sheet is for choosing between actions you already
/// understand, so it gave the routine's *name* and nothing else — not how long
/// it takes, not how much of it there is — and asked the lifter to commit
/// anyway. And because it slid up over Today rather than over the workout being
/// started, it read as an interruption of the screen behind it instead of as
/// the first step of starting a session.
///
/// A sheet fixes both: there is room to say what the routine is, and the
/// workout remains the obvious destination — "Skip and start workout" is a
/// full-width action, not a row buried among alert buttons.
///
/// The facts are `LabeledContent` rows rather than a summary sentence. A
/// sentence with a movement count needs grammatical agreement in every
/// shipped language, and this catalogue already carries inflection markup that
/// resolves in only some of them; a labelled number is exact everywhere.
struct WorkoutPreparationSheet: View {
    let routine: MobilityRoutine?
    /// When a mobility session is already running, the only sensible forward
    /// action is to return to it — starting a second one would fork the record.
    let hasActiveMobilitySession: Bool
    let onStart: () -> Void
    let onResumeActive: () -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Only the descriptive half scrolls. The actions stay pinned, so
            // raising the text size can never push "Skip and start workout"
            // below the detent — a sheet whose only forward action is off
            // screen is a trap, and this one appears mid-flow between tapping
            // Start and the workout opening.
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    facts
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            actions
        }
        .padding(.horizontal, Spacing.xl)
        // Clearance for the drag indicator, which the presentation draws inside
        // the sheet's own top edge without reserving space for it.
        //
        // The padding alone was not what failed. The content — eyebrow, title,
        // explanation, three fact rows and three actions — was taller than the
        // `.medium` detent, and an unscrolled `VStack` has nothing to give, so
        // it overflowed past the top edge and took its own top padding off
        // screen with it. That is what put the grabber on the eyebrow and made
        // it render with a line struck through. The `ScrollView` above is the
        // actual fix; this is the clearance that should have been here anyway.
        .padding(.top, Spacing.xxxl + Spacing.s)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBackground)
        .tint(Color.gymPrimary)
        // Sized to the content rather than to half the screen.
        //
        // `.medium` was a half sheet holding an eyebrow, a title, two lines of
        // explanation, three fact rows and three buttons — roughly 340pt of
        // content in roughly 500pt of sheet, so the expanded state read as
        // two-thirds empty and the buttons floated far below the text that
        // justified them. A fixed height puts the actions directly under the
        // facts.
        //
        // `.large` stays in the set because at accessibility text sizes the
        // same content genuinely needs the room, and the `ScrollView` above
        // handles everything in between.
        .presentationDetents([.height(360), .large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-preparation-sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label("OPTIONAL PREPARATION", systemImage: AppIcon.mobilityPurposePreparation)
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymAccent)

            title
                .font(AppFont.titleMedium)
                .foregroundStyle(Color.gymText)
                .fixedSize(horizontal: false, vertical: true)

            Text(explanation)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var facts: some View {
        if let routine, !hasActiveMobilitySession {
            VStack(spacing: 0) {
                factRow("Movements", value: Text(routine.items.count, format: .number))

                LibraryGroupDivider()

                factRow(
                    "Estimated time",
                    value: Text(WorkoutMobilityPresentation.durationText(for: routine))
                )

                if let purpose = routine.purpose {
                    LibraryGroupDivider()
                    factRow("Purpose", value: Text(purpose.displayName))
                }
            }
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            if hasActiveMobilitySession {
                Button("Resume mobility", action: onResumeActive)
                    .buttonStyle(.gymPrimaryProminent)
                    .accessibilityIdentifier("resume-active-mobility-before-workout")
            } else if routine != nil {
                Button("Start preparation", action: onStart)
                    .buttonStyle(.gymPrimaryProminent)
                    .accessibilityIdentifier("start-linked-warmup")
                    .accessibilityHint("Starts the linked warm-up first. The workout begins after you leave mobility.")
            }

            // Outlined, not filled. It is still a full-width action — the sheet
            // exists so the workout stays the obvious destination — but drawn
            // in the same blue capsule as the button above it, the two read as
            // one choice offered twice. The recommended path is the one the
            // sheet was raised to offer; this is the alternative to it.
            Button("Skip and start workout", action: onSkip)
                .buttonStyle(.gymOutlineProminent)
                .accessibilityIdentifier("skip-linked-warmup")
                .accessibilityHint("Starts the workout without the optional warm-up.")

            // Kept as an explicit control rather than left to interactive
            // dismissal, which VoiceOver and UI automation cannot reach as
            // reliably as a button.
            Button("Cancel", role: .cancel, action: onCancel)
                .font(AppFont.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                .accessibilityIdentifier("cancel-workout-preparation")
        }
    }

    /// A `Text`, not a `LocalizedStringKey`: the routine name is user data,
    /// and returning it as a key would send "Hip Openers" through the string
    /// catalogue looking for a translation of it.
    private var title: Text {
        if hasActiveMobilitySession {
            return Text("A mobility session is already running")
        }
        if let routine {
            return Text(verbatim: routine.name)
        }
        return Text("Optional Warm-Up")
    }

    private var explanation: LocalizedStringKey {
        guard !hasActiveMobilitySession else {
            return "Finish or stop it before starting this linked warm-up, or start the workout without it."
        }
        return "It is recorded as its own mobility session, separate from the workout."
    }

    private func factRow(_ label: LocalizedStringKey, value: Text) -> some View {
        LabeledContent {
            value
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
                .monospacedDigit()
        } label: {
            Text(label)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: 44)
    }
}
