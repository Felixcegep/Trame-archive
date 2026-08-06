import SwiftUI

/// Moving a planned session, with its consequence stated before it happens.
///
/// The sheet used to be one `DatePicker` in an otherwise empty form. That is
/// enough to *perform* a reschedule and not nearly enough to decide on one:
/// it never showed the date being moved from, and it gave no way to express —
/// or even to notice — the difference between moving one session and pushing
/// the rest of the plan along with it.
///
/// The redesign replaces the `Form` with a custom `ScrollView` layout that
/// uses the app's design tokens throughout. Two date "pills" — old (subdued)
/// and new (primary-tinted) — sit side by side with a directional arrow, so
/// the change is legible at a glance. The graphical date picker follows,
/// then a card with the shift toggle, affected count, and consequence text.
struct RescheduleWorkoutSheet: View {
    let progress: PlanWorkoutProgress
    let run: PlanRun?
    @Binding var date: Date
    @Binding var shiftsRemaining: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var preview: PlanCoordinator.ReschedulePreview? {
        run.map { PlanCoordinator.reschedulePreview(for: progress, to: date, in: $0) }
    }

    private var isUnchanged: Bool {
        progress.scheduledDate.map {
            Calendar.current.isDate($0, inSameDayAs: date)
        } ?? false
    }

    private var canShiftRemaining: Bool {
        preview?.canShiftRemaining ?? false
    }

    /// The selected session plus everything a shifting save would carry.
    private var movingSessionCount: Int {
        (preview?.followingSessionCount ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // MARK: – Header
                    headerSection

                    // MARK: – Date pills
                    datePillsSection

                    // MARK: – Graphical date picker
                    datePickerSection

                    // MARK: – Shift toggle & consequence
                    if canShiftRemaining {
                        shiftSection
                    }

                    // MARK: – Hint
                    hintFooter
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color.gymBackground.ignoresSafeArea())
            .navigationTitle("Reschedule workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        // Saving the date it already has is a no-op that still
                        // reported "Moved to …", which is a confirmation of
                        // nothing.
                        .disabled(isUnchanged)
                        .accessibilityIdentifier("today-confirm-reschedule")
                }
            }
        }
    }

    // MARK: - Sections

    /// Workout name displayed prominently at the top.
    private var headerSection: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.reschedule)
                .foregroundStyle(Color.gymPrimary)
                .font(AppFont.body)

            Text(progress.plannedWorkoutName)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(Color.gymText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rescheduling \(progress.plannedWorkoutName)")
    }

    /// Two date pills side by side: old date (subdued, read-only) →  new date
    /// (primary-tinted, reflecting the picker).
    private var datePillsSection: some View {
        HStack(spacing: Spacing.m) {
            if let scheduledDate = progress.scheduledDate {
                datePill(
                    label: "Current",
                    date: scheduledDate,
                    foreground: Color.gymSubduedText,
                    background: Color.gymRowSurface
                )
                .accessibilityIdentifier("today-reschedule-current-date")

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .accessibilityHidden(true)
            }

            datePill(
                label: "New",
                date: date,
                foreground: Color.gymPrimary,
                background: Color.gymPrimarySurface
            )
            .accessibilityIdentifier("today-reschedule-date")
        }
    }

    /// A single date pill: a rounded capsule showing a label and a formatted date.
    private func datePill(
        label: String,
        date: Date,
        foreground: Color,
        background: Color
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(AppFont.caption2Bold)
                .foregroundStyle(foreground.opacity(0.7))

            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(AppFont.subheadlineBold)
                .foregroundStyle(foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(background)
        )
        .accessibilityElement(children: .combine)
    }

    /// Graphical calendar picker in a card.
    private var datePickerSection: some View {
        GymCard {
            DatePicker(
                "New date",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.gymPrimary)
            .labelsHidden()
            .accessibilityIdentifier("today-reschedule-date")
        }
    }

    /// Shift-remaining toggle, affected count, and consequence copy.
    private var shiftSection: some View {
        GymCard {
            Toggle(isOn: $shiftsRemaining) {
                Label {
                    Text("Shift remaining workouts")
                        .font(AppFont.body)
                        .foregroundStyle(Color.gymText)
                } icon: {
                    Image(systemName: AppIcon.fastForward)
                        .foregroundStyle(Color.gymPrimary)
                }
            }
            .tint(Color.gymPrimary)
            .accessibilityIdentifier("today-reschedule-shift-remaining")

            if shiftsRemaining, !isUnchanged, movingSessionCount > 1 {
                Divider()

                HStack {
                    Text("Workouts that move")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)

                    Spacer()

                    Text(movingSessionCount, format: .number)
                        .font(AppFont.subheadlineBold)
                        .monospacedDigit()
                        .foregroundStyle(Color.gymDataEmphasis)
                }
                .accessibilityIdentifier("today-reschedule-affected-count")
            }

            Text(consequence)
                .font(AppFont.footnote)
                .foregroundStyle(Color.gymSubduedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// An explanatory footnote that previously lived in the form section footer.
    private var hintFooter: some View {
        Text("Any date is allowed. A date in the past is recorded as missed, and one outside the plan's range still keeps the plan's order.")
            .font(AppFont.footnote)
            .foregroundStyle(Color.gymSubduedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Consequence

    /// Deliberately free of numbers: the rows above carry the exact dates and
    /// the exact count, and this says what kind of change it is.
    private var consequence: LocalizedStringKey {
        guard !isUnchanged else {
            return "This workout keeps its current date."
        }
        guard shiftsRemaining else {
            return "Only this workout moves. Later workouts keep their dates."
        }
        guard movingSessionCount > 1 else {
            return "No later workouts are scheduled, so only this workout moves."
        }
        return "This workout and every later workout move by the same number of days. Completed workouts never move."
    }
}
