import SwiftUI
import SwiftData

/// The value columns of a set row: one tappable button per tracked field.
///
/// Split out of `SetRowView` for size. Nothing here writes to the model — a
/// button only selects its field, and the set-entry panel's keypad owns the
/// writing. The accessibility identifiers are load-bearing for the UI tests and
/// must stay byte-identical to what `SetRowView` used to emit.
struct SetRowFieldStack: View {
    let index: Int
    @Bindable var exerciseSet: ExerciseSet
    let exerciseEntry: ExerciseEntry
    let coordinator: SetInputCoordinator
    let previousSet: PreviousSetPerformance?
    let isCompletedAndLocked: Bool
    /// Whether this row is the next incomplete set — the one a fill marks as
    /// "this is what you'd act on next", independent of whether any of its
    /// fields are actively focused.
    let isCurrentSet: Bool
    let isTimerRunning: Bool
    let isStacked: Bool
    /// Clears the row's validation message when a field is selected.
    let onFieldSelected: () -> Void

    private var trackingType: TrackingType {
        exerciseEntry.trackingTypeSnapshot
    }

    var body: some View {
        if isStacked {
            inputFieldsStacked
        } else {
            inputFieldsHorizontal
        }
    }

    @ViewBuilder
    private var inputFieldsHorizontal: some View {
        if trackingType.usesReps { repsField }
        if trackingType.usesWeight { weightField }
        if trackingType.usesDuration { durationField }
        if trackingType.usesDistance { distanceField }
        if trackingType.usesCalories { caloriesField }
    }

    private var inputFieldsStacked: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) {
                if trackingType.usesReps { labeledField(label: "REPS", field: repsField) }
                if trackingType.usesWeight { labeledField(label: "WEIGHT", field: weightField) }
                if trackingType.usesDuration { labeledField(label: "SECONDS", field: durationField) }
                if trackingType.usesDistance { labeledField(label: "DISTANCE", field: distanceField) }
                if trackingType.usesCalories { labeledField(label: "CALORIES", field: caloriesField) }
            }
            VStack(spacing: Spacing.s) {
                if trackingType.usesReps { labeledField(label: "REPS", field: repsField) }
                if trackingType.usesWeight { labeledField(label: "WEIGHT", field: weightField) }
                if trackingType.usesDuration { labeledField(label: "SECONDS", field: durationField) }
                if trackingType.usesDistance { labeledField(label: "DISTANCE", field: distanceField) }
                if trackingType.usesCalories { labeledField(label: "CALORIES", field: caloriesField) }
            }
        }
    }

    private func labeledField<Field: View>(label: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(AppFont.captionBold)
                .tracking(0.55)
                .foregroundStyle(Color.gymSubduedText)
            field
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueButton(
        _ field: SetInputFocus.Field,
        unit: String? = nil,
        textColor: Color = .gymText
    ) -> some View {
        let focusID = inputFocus(field)
        let isActive = coordinator.focus == focusID
        let shown = coordinator.displayText(for: focusID, storedValue: storedText(for: field))

        return Button {
            selectField(field)
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text(shown.isEmpty ? placeholder(for: field) : shown)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(valueColor(shown: shown, isActive: isActive, textColor: textColor))
                    .lineLimit(1)

                if let unit {
                    Text(unit)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityHidden(true)
                }
            }
            .frame(minWidth: 70, maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(cellFill(isActive: isActive))
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            // Border marks only the one field being typed into. Every field
            // used to carry a grey outline unless locked, which drew a box
            // around a set that had not happened yet as readily as one about
            // to be logged — outline was doing the fill's job and doing it
            // for rows that had not earned it. Blue is now the only stroke
            // this cell ever wears, and only while it is the field with focus.
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(Color.gymPrimary, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .disabled(isFieldDisabled(field))
        .accessibilityLabel(fieldAccessibilityLabel(field))
        .accessibilityValue(accessibilityValue(for: field, shown: shown))
        .accessibilityHint(accessibilityHint(field, isActive: isActive))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityIdentifier("\(identifierPrefix(field))-field-\(exerciseEntry.exercise.name)-\(index)")
    }

    /// Ink for a fact or for what's next; subdued only for a further-out guess.
    ///
    /// A planned workout arrives with every cell prefilled, and those numbers
    /// used to render exactly like the ones the lifter had actually
    /// performed — same size, same weight, same colour, whether it was set 1
    /// (done) or set 4 (three sets away). The rule the codebase already
    /// applies to empty versus zero — "missing and zero stay distinct" — one
    /// level up: a fact, an immediate target, and a distant guess stay
    /// distinct from each other.
    ///
    /// Done and current both read as ink, not just done: the current set's
    /// prefilled value is what the lifter is about to match, and dimming it
    /// the same as a set three away would bury the one number that matters
    /// most right now. `isCurrentSet` already marks that row with a fill
    /// (`cellFill`, below); ink is the second half of the same signal. Only a
    /// genuinely future set — one the lifter has not reached and is not
    /// about to — stays subdued.
    ///
    /// The focused field is exempt regardless of row, because a value being
    /// typed is the lifter's own input and dimming it under their thumb would
    /// read as a fault.
    ///
    /// This is also what makes retiring the weight column's violet safe: the
    /// separation a set row needs is fact/next-versus-later, not weight-
    /// versus-everything, and contrast now carries it.
    private func valueColor(shown: String, isActive: Bool, textColor: Color) -> Color {
        if shown.isEmpty { return .gymSubduedText }
        if isActive || isCompletedAndLocked { return textColor }
        if exerciseSet.done { return textColor }
        return isCurrentSet ? textColor : .gymSubduedText
    }

    /// A fill marks "the row you would act on next" — not "editable", and not
    /// "focused". A completed field draws none (plain text stands on its own
    /// once logged); a future set's field draws none (nothing to fill in
    /// yet); the current set's fields fill whether or not the lifter has
    /// tapped into one of them yet, so the eye finds where to go before the
    /// keypad is even open.
    private func cellFill(isActive: Bool) -> Color {
        if isActive { return Color.gymRowSurface }
        if isCompletedAndLocked { return .clear }
        return isCurrentSet ? Color.gymRowSurface : .clear
    }

    private var repsField: some View {
        valueButton(.repetitions)
    }

    private var weightField: some View {
        valueButton(.weight)
    }

    private var durationField: some View {
        valueButton(.duration, unit: "sec")
    }

    private var caloriesField: some View {
        valueButton(.calories, unit: "cal")
    }

    private var distanceField: some View {
        valueButton(.distance, unit: distanceMeasurement?.unit.symbol ?? preferredDistanceUnit.symbol)
    }

    private func storedText(for field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions:
            return exerciseSet.repetitions == 0 ? "" : Formatters.formatFloat(exerciseSet.repetitions)
        case .weight:
            return exerciseSet.weight == 0 ? "" : Formatters.formatFloat(exerciseSet.weight)
        case .duration:
            guard let duration = exerciseSet.duration, duration > 0 else { return "" }
            return String(Int(duration))
        case .distance:
            guard let measurement = distanceMeasurement, measurement.value > 0 else { return "" }
            return Formatters.formatFloat(measurement.value)
        case .calories:
            guard let calories = exerciseSet.calories, calories > 0 else { return "" }
            return Formatters.formatFloat(Float(calories))
        }
    }

    private func placeholder(for field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions:
            return prescribedRepetitionsPrompt
                ?? previousSet.map { Formatters.formatFloat($0.repetitions) }
                ?? "\u{2014}"
        case .weight:
            return prescribedWeightPrompt
                ?? previousSet.map { Formatters.formatFloat(displayWeight(for: $0)) }
                ?? "\u{2014}"
        case .duration:
            return exerciseSet.prescribedDurationSecondsSnapshot.map { String(Int($0)) }
                ?? previousSet?.duration.map { String(Int($0)) }
                ?? "\u{2014}"
        case .distance:
            return prescribedDistancePrompt
                ?? previousSet.map { Formatters.formatFloat(displayDistance(for: $0)) }
                ?? "\u{2014}"
        case .calories:
            return exerciseSet.prescribedCaloriesSnapshot.map { Formatters.formatFloat(Float($0)) }
                ?? previousSet?.calories.map { Formatters.formatFloat(Float($0)) }
                ?? "\u{2014}"
        }
    }

    private func isFieldDisabled(_ field: SetInputFocus.Field) -> Bool {
        if isCompletedAndLocked { return true }
        return field == .duration && isTimerRunning
    }

    private func identifierPrefix(_ field: SetInputFocus.Field) -> String {
        switch field {
        case .repetitions: return "reps"
        case .weight: return "weight"
        case .duration: return "duration"
        case .distance: return "distance"
        case .calories: return "calories"
        }
    }

    private func fieldAccessibilityLabel(_ field: SetInputFocus.Field) -> String {
        let semantics = exerciseEntry.loggingSemanticsSnapshot
        switch field {
        case .repetitions:
            let perSide = semantics.laterality == .unilateral && semantics.repCountingStyle == .perSide
            return perSide
                ? String(localized: "Set \(index + 1) reps per side")
                : String(localized: "Set \(index + 1) reps")
        case .weight:
            let perUnit = semantics.weightEntryStyle == .perLoadUnit
            return perUnit
                ? String(localized: "Set \(index + 1) weight per unit, \(exerciseSet.weightType.rawValue)")
                : String(localized: "Set \(index + 1) weight, \(exerciseSet.weightType.rawValue)")
        case .duration:
            return String(localized: "Set \(index + 1) duration in seconds")
        case .distance:
            return String(localized: "Set \(index + 1) distance, \(distanceMeasurement?.unit.rawValue ?? preferredDistanceUnit.rawValue)")
        case .calories:
            return String(localized: "Set \(index + 1) calories")
        }
    }

    private func accessibilityValue(for field: SetInputFocus.Field, shown: String) -> String {
        shown.isEmpty ? String(localized: "Not entered") : shown
    }

    /// A locked field used to promise the keypad it would never open. The hint
    /// now names the state and the way out of it; the timer case is separate
    /// because that field unlocks on its own when the timer stops.
    private func accessibilityHint(_ field: SetInputFocus.Field, isActive: Bool) -> String {
        if isCompletedAndLocked {
            return String(localized: "Locked. Use the edit button to change this value.")
        }
        if field == .duration && isTimerRunning {
            return String(localized: "Locked while the timer is running.")
        }
        return isActive
            ? String(localized: "Currently editing")
            : String(localized: "Opens the keypad for this value")
    }

    private func selectField(_ field: SetInputFocus.Field) {
        onFieldSelected()
        coordinator.focus = inputFocus(field)
    }

    private func inputFocus(_ field: SetInputFocus.Field) -> SetInputFocus {
        SetInputFocus(
            exerciseID: exerciseEntry.persistentModelID,
            setID: exerciseSet.persistentModelID,
            field: field
        )
    }

    /// The placeholder is a suggestion the lifter may be about to match, not a
    /// report of history, so it is shown on the equipment's grid. The recorded
    /// set it derives from is unchanged; History reports it as performed.
    private func displayWeight(for previousSet: PreviousSetPerformance) -> Float {
        WorkoutLoadRounding.converted(
            previousSet.weight,
            from: previousSet.weightType,
            to: exerciseSet.weightType,
            for: exerciseEntry.exercise
        )
    }

    private func displayDistance(for previousSet: PreviousSetPerformance) -> Float {
        let meters = WorkoutDistancePolicy.meters(
            storedValue: previousSet.distance ?? 0,
            storedUnit: previousSet.distanceType
        ) ?? 0
        return UnitConversion.distance(meters, from: .meters, to: preferredDistanceUnit)
    }

    private var distanceMeasurement: DistanceMeasurement? {
        WorkoutDistancePolicy.displayMeasurement(
            for: exerciseSet,
            system: UserDefaults.standard.unitSystem
        )
    }

    private var preferredDistanceUnit: DistanceType {
        WorkoutDistancePolicy.preferredDisplayUnit(
            forMeters: exerciseSet.prescribedDistanceMetersSnapshot.map(Float.init)
                ?? WorkoutDistancePolicy.meters(of: exerciseSet),
            system: UserDefaults.standard.unitSystem
        )
    }

    private var prescribedRepetitionsPrompt: String? {
        if let repetitions = exerciseSet.prescribedRepetitions {
            return String(repetitions)
        }
        if let minimum = exerciseSet.prescribedRepRangeMinimum,
           let maximum = exerciseSet.prescribedRepRangeMaximum {
            return minimum == maximum ? String(minimum) : "\(minimum)–\(maximum)"
        }
        return exerciseSet.prescribedRepRangeMaximum.map(String.init)
            ?? exerciseSet.prescribedRepRangeMinimum.map(String.init)
    }

    private var prescribedWeightPrompt: String? {
        guard let load = exerciseSet.prescribedSuggestedLoad,
              let type = exerciseSet.prescribedSuggestedLoadType else {
            return nil
        }
        let converted = WorkoutLoadRounding.converted(
            Float(load),
            from: type,
            to: exerciseSet.weightType,
            for: exerciseEntry.exercise
        )
        return Formatters.formatFloat(converted)
    }

    private var prescribedDistancePrompt: String? {
        guard let meters = exerciseSet.prescribedDistanceMetersSnapshot else {
            return nil
        }
        let unit = WorkoutDistancePolicy.preferredDisplayUnit(
            forMeters: Float(meters),
            system: UserDefaults.standard.unitSystem
        )
        return Formatters.formatFloat(
            UnitConversion.distance(Float(meters), from: .meters, to: unit)
        )
    }
}
