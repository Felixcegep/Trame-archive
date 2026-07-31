import SwiftUI

/// Moving a planned session, with its consequence stated before it happens.
///
/// The sheet used to be one `DatePicker` in an otherwise empty form. That is
/// enough to *perform* a reschedule and not nearly enough to decide on one:
/// it never showed the date being moved from, and it gave no way to express —
/// or even to notice — the difference between moving one session and pushing
/// the rest of the plan along with it.
///
/// The count of affected sessions is a `LabeledContent` row rather than a
/// number folded into the footer sentence. Prose with an embedded count needs
/// grammatical agreement in every language the app ships, and this catalogue
/// has already shipped a visible inflection artifact once; a labelled row is
/// exact, translatable, and reads correctly at every content size.
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
            Form {
                Section {
                    if let scheduledDate = progress.scheduledDate {
                        LabeledContent("Current date") {
                            Text(scheduledDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        }
                        .accessibilityIdentifier("today-reschedule-current-date")
                    }

                    DatePicker("New date", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("today-reschedule-date")
                } footer: {
                    // A past date is allowed and becomes a missed session. That
                    // is deliberate, but nothing said so, and a date picker with
                    // no stated bounds invites the assumption that it is
                    // constrained.
                    Text("Any date is allowed. A date in the past is recorded as missed, and one outside the plan's range still keeps the plan's order.")
                }

                if canShiftRemaining {
                    Section {
                        Toggle("Shift remaining workouts", isOn: $shiftsRemaining)
                            .accessibilityIdentifier("today-reschedule-shift-remaining")

                        if shiftsRemaining, !isUnchanged, movingSessionCount > 1 {
                            LabeledContent("Workouts that move") {
                                Text(movingSessionCount, format: .number)
                                    .monospacedDigit()
                            }
                            .accessibilityIdentifier("today-reschedule-affected-count")
                        }
                    } footer: {
                        Text(consequence)
                    }
                }
            }
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
