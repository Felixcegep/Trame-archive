import SwiftUI

/// Moving a planned session, with its consequence stated before it happens.
///
/// Replaces the legacy compact `Form` date picker with a dedicated graphical
/// calendar layout that follows Apple's HIG date-picker guidance and our
/// design system tokens. Current and proposed dates form an open comparison;
/// the native calendar is the instrument, and the consequence is rule-led.
struct PlanRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let workoutName: String
    let initialDate: Date?
    let progress: PlanWorkoutProgress?
    let run: PlanRun?
    let title: String
    let confirmIdentifier: String
    let datePickerIdentifier: String
    let onSaveWithShift: ((Date, Bool) -> Bool)?
    let onSaveSingle: ((Date) -> Bool)?

    @State private var date: Date
    @State private var shiftsRemaining: Bool = false
    @State private var errorMessage: String?

    init(
        workoutName: String,
        initialDate: Date?,
        progress: PlanWorkoutProgress? = nil,
        run: PlanRun? = nil,
        title: String = "Reschedule",
        confirmIdentifier: String = "plan-reschedule-confirm",
        datePickerIdentifier: String = "plan-reschedule-date",
        onSave: @escaping (Date, Bool) -> Bool
    ) {
        self.workoutName = workoutName
        self.initialDate = initialDate
        self.progress = progress
        self.run = run
        self.title = title
        self.confirmIdentifier = confirmIdentifier
        self.datePickerIdentifier = datePickerIdentifier
        self.onSaveWithShift = onSave
        self.onSaveSingle = nil
        _date = State(initialValue: initialDate ?? .now)
    }

    init(
        workoutName: String,
        initialDate: Date?,
        progress: PlanWorkoutProgress? = nil,
        run: PlanRun? = nil,
        title: String = "Reschedule",
        confirmIdentifier: String = "plan-reschedule-confirm",
        datePickerIdentifier: String = "plan-reschedule-date",
        onSave: @escaping (Date) -> Bool
    ) {
        self.workoutName = workoutName
        self.initialDate = initialDate
        self.progress = progress
        self.run = run
        self.title = title
        self.confirmIdentifier = confirmIdentifier
        self.datePickerIdentifier = datePickerIdentifier
        self.onSaveWithShift = nil
        self.onSaveSingle = onSave
        _date = State(initialValue: initialDate ?? .now)
    }

    private var preview: PlanCoordinator.ReschedulePreview? {
        guard let progress, let run else { return nil }
        return PlanCoordinator.reschedulePreview(for: progress, to: date, in: run)
    }

    private var isUnchanged: Bool {
        guard let initialDate else { return false }
        return Calendar.current.isDate(initialDate, inSameDayAs: date)
    }

    private var canShiftRemaining: Bool {
        if let preview {
            return preview.canShiftRemaining
        }
        return initialDate != nil
    }

    private var movingSessionCount: Int {
        if let preview {
            return preview.followingSessionCount + 1
        }
        return 1
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

                    // MARK: – Error Message
                    if let errorMessage {
                        errorSection(errorMessage)
                    }

                    // MARK: – Hint
                    hintFooter
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color.trameCanvas.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isUnchanged)
                        .accessibilityIdentifier(confirmIdentifier)
                }
            }
        }
    }

    // MARK: - Sections

    /// Workout name displayed prominently at the top.
    private var headerSection: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.reschedule)
                .foregroundStyle(Color.trameActionDeep)
                .font(AppFont.body)

            Text(workoutName)
                .font(AppFont.subheadlineBold)
                .foregroundStyle(Color.trameText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rescheduling \(workoutName)")
    }

    /// Old date (subdued, read-only) → new date (reflecting the picker).
    private var datePillsSection: some View {
        HStack(spacing: Spacing.m) {
            if let initialDate {
                datePill(
                    label: "Current",
                    date: initialDate,
                    foreground: Color.trameSubdued
                )
                .accessibilityIdentifier("plan-reschedule-current-date")

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }

            datePill(
                label: "New",
                date: date,
                foreground: Color.trameStrength
            )
            .accessibilityIdentifier("plan-reschedule-new-date")
        }
    }

    /// One date in the open comparison.
    private func datePill(
        label: String,
        date: Date,
        foreground: Color
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
        .padding(.horizontal, Spacing.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(foreground).frame(height: label == "New" ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// The native graphical picker is the instrument; rules define its field.
    private var datePickerSection: some View {
        DatePicker(
            "Scheduled date",
            selection: $date,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .tint(Color.trameStrength)
        .labelsHidden()
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .top) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
        .accessibilityIdentifier(datePickerIdentifier)
    }

    /// Shift-remaining toggle, affected count, and consequence copy.
    private var shiftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Toggle(isOn: $shiftsRemaining) {
                Label {
                    Text("Shift remaining workouts")
                        .font(AppFont.body)
                        .foregroundStyle(Color.trameText)
                } icon: {
                    Image(systemName: AppIcon.fastForward)
                        .foregroundStyle(Color.trameActionDeep)
                }
            }
            .tint(Color.trameActionDeep)
            .accessibilityIdentifier("plan-reschedule-shift-remaining")

            if shiftsRemaining, !isUnchanged, movingSessionCount > 1 {
                Divider()

                HStack {
                    Text("Workouts that move")
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.trameSubdued)

                    Spacer()

                    Text(movingSessionCount, format: .number)
                        .font(AppFont.subheadlineBold)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameText)
                }
                .accessibilityIdentifier("plan-reschedule-affected-count")
            }

            Text(consequence)
                .font(AppFont.footnote)
                .foregroundStyle(Color.trameSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
    }

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: AppIcon.warning)
                .foregroundStyle(Color.trameDestructiveText)
            Text(message)
                .font(AppFont.footnote)
                .foregroundStyle(Color.trameDestructiveText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.m)
        .overlay(alignment: .leading) { Rectangle().fill(Color.trameDestructiveText).frame(width: 3) }
    }

    /// An explanatory footnote explaining schedule behavior.
    private var hintFooter: some View {
        Text("Any date is allowed. A date in the past is recorded as missed, and one outside the plan's range still keeps the plan's order.")
            .font(AppFont.footnote)
            .foregroundStyle(Color.trameSubdued)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xs)
    }

    // MARK: - Consequence

    private var consequence: LocalizedStringKey {
        guard !isUnchanged else {
            return "This workout keeps its current date."
        }
        guard shiftsRemaining else {
            return "Only this workout moves. Later workouts keep their dates."
        }
        if let preview {
            guard preview.followingSessionCount > 0 else {
                return "No later workouts are scheduled, so only this workout moves."
            }
            return "This workout and every later workout move by the same number of days. Completed workouts never move."
        }
        return "This workout and any subsequent workouts move by the same number of days. Completed workouts never move."
    }

    private func save() {
        let success: Bool
        if let onSaveWithShift {
            success = onSaveWithShift(date, shiftsRemaining)
        } else if let onSaveSingle {
            success = onSaveSingle(date)
        } else {
            success = true
        }

        if success {
            dismiss()
        } else {
            errorMessage = String(localized: "The workout could not be rescheduled. Try again.")
        }
    }
}
