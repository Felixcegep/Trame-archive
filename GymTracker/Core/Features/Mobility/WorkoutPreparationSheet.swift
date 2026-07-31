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

                Button("Skip and start workout", action: onSkip)
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("skip-linked-warmup")
                    .accessibilityHint("Starts the workout without the optional warm-up.")

                // Kept as an explicit control rather than left to interactive
                // dismissal, which VoiceOver and UI automation cannot reach as
                // reliably as a button.
                Button("Cancel", role: .cancel, action: onCancel)
                    .font(AppFont.subheadlineSemibold)
                    .frame(minHeight: ComponentSize.minimumTouchTarget)
                    .accessibilityIdentifier("cancel-workout-preparation")
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymBackground)
        .tint(Color.gymPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// A `Text`, not a `LocalizedStringKey`: the routine name is user data,
    /// and returning it as a key would send "Hip Openers" through the string
    /// catalogue looking for a translation of it.
    private var title: Text {
        guard !hasActiveMobilitySession else {
            return Text("A mobility session is already running")
        }
        guard let routine else {
            return Text("This workout has a linked warm-up")
        }
        return Text(verbatim: routine.name)
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
