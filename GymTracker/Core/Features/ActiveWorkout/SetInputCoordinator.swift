import SwiftUI
import SwiftData

/// Owns which set input is currently being edited.
///
/// This replaces the `@FocusState` that used to live on `ActiveWorkoutView`.
/// The set-entry panel is not a keyboard toolbar — it needs to read and move the
/// focus from outside the row that owns the field, which `@FocusState` cannot
/// express because its projected binding only flows downward.
///
/// The ordered list of inputs backing previous/next navigation is rebuilt when
/// focus changes rather than on every render. The old `allInputs` computed
/// property walked every exercise × set × field each time the keyboard toolbar
/// re-evaluated, which is many times per keystroke on a long workout.
@Observable
@MainActor
final class SetInputCoordinator {
    /// Written through a computed property rather than a stored one with a
    /// `didSet`: `@Observable` only tracks plain stored properties, and adding
    /// an observer to `focus` would silently stop every view from updating when
    /// the selection changes.
    var focus: SetInputFocus? {
        get { focusStorage }
        set {
            guard newValue != focusStorage else { return }
            focusStorage = newValue
            // Every selection starts a fresh entry: the stored value stays
            // visible and the first digit replaces it, which is how a lifter
            // retypes a load mid-set.
            entryText = nil
            // Moving to another value means the lifter has moved on from
            // whatever was refused. Clearing here — rather than in a view's
            // `onChange` — is what lets the blocked path set focus first and
            // record the refusal second without the two fighting.
            blockedMessage = nil
        }
    }

    private var focusStorage: SetInputFocus?

    /// Why the last completion attempt was refused, or `nil` if nothing has
    /// been refused since the lifter last moved.
    ///
    /// This lives on the coordinator rather than inside the entry panel because
    /// a set can be completed from three places — the panel's own button, the
    /// command bar's "Log set", and a VoiceOver action on the row — and only
    /// one of them used to be able to say why it failed. Tapping "Log set" and
    /// getting a keypad with no explanation is the same dead end as a message
    /// nobody sees, arrived at from the other direction.
    private(set) var blockedMessage: String?

    /// Bumped on every refusal, including repeats of the same one. Views drive
    /// the shake and the haptic off this, so a second identical attempt is
    /// answered as loudly as the first — that is exactly when the lifter is
    /// most stuck.
    private(set) var blockedAttemptCount = 0

    /// Records a refused completion. Set `focus` to the blocking field *before*
    /// calling this; the focus setter clears the message.
    func recordBlockedAttempt(_ message: String) {
        blockedMessage = message
        blockedAttemptCount += 1
    }

    func clearBlockedAttempt() {
        blockedMessage = nil
    }

    /// Digits typed since the focused value was selected, or `nil` when nothing
    /// has been typed yet. The displayed value comes from the set until this
    /// holds something, so selecting a field never rewrites it.
    private(set) var entryText: String?

    private var orderedInputs: [SetInputFocus] = []

    func isFocused(_ input: SetInputFocus) -> Bool {
        focus == input
    }

    /// Recomputes the navigation order. Call when focus changes or the set list
    /// is mutated — not from a view body.
    func refreshOrder(in workout: Workout?) {
        guard let workout else {
            orderedInputs = []
            return
        }

        orderedInputs = workout.orderedExercises.flatMap { exercise in
            let fields = Self.inputFields(for: exercise.trackingTypeSnapshot)
            return exercise.orderedSets.flatMap { set in
                fields.map {
                    SetInputFocus(
                        exerciseID: exercise.persistentModelID,
                        setID: set.persistentModelID,
                        field: $0
                    )
                }
            }
        }
    }

    var previousInput: SetInputFocus? {
        guard let focus,
              let index = orderedInputs.firstIndex(of: focus),
              index > 0 else { return nil }
        return orderedInputs[index - 1]
    }

    var nextInput: SetInputFocus? {
        guard let focus,
              let index = orderedInputs.firstIndex(of: focus),
              orderedInputs.indices.contains(index + 1) else { return nil }
        return orderedInputs[index + 1]
    }

    func moveFocus(by offset: Int) {
        guard let destination = offset < 0 ? previousInput : nextInput else { return }
        focus = destination
    }

    /// Moves focus between fields of the set already being edited, used by the
    /// panel's value pills.
    func focusField(_ field: SetInputFocus.Field) {
        guard let focus else { return }
        self.focus = SetInputFocus(
            exerciseID: focus.exerciseID,
            setID: focus.setID,
            field: field
        )
    }

    /// Applies one keypad press to the in-progress entry and returns the text to
    /// commit, or `nil` when the press changes nothing. The coordinator owns the
    /// text so the keypad never needs a text field, a first responder, or a
    /// system keyboard to drive.
    func applyKey(_ key: KeypadKey, decimalSeparator: String) -> String? {
        var text = entryText ?? ""

        switch key {
        case .digit(let value):
            // Longer than this is a mistyped value, not a real load or rep count.
            guard text.filter(\.isNumber).count < 6 else { return nil }
            text += "\(value)"
        case .decimal:
            guard !text.contains(decimalSeparator) else { return nil }
            text += text.isEmpty ? "0\(decimalSeparator)" : decimalSeparator
        case .backspace:
            // Backspacing an untouched value clears it outright rather than
            // deleting a digit the lifter never typed.
            guard !text.isEmpty else {
                entryText = ""
                return ""
            }
            text.removeLast()
        }

        entryText = text
        return text
    }

    /// Ends the in-progress entry so the display falls back to the stored value.
    ///
    /// Call this from every path that changes a set's value by something other
    /// than the keypad — a stepper, the unit toggle, copying the last set, a
    /// sheet. Typed text is committed on each keystroke, so it is purely a
    /// display artifact; leaving it behind makes the pill keep showing the old
    /// digits while the model moves underneath it, and the next digit typed
    /// would append to a number the lifter had already stepped away from.
    func endEntry() {
        entryText = nil
    }

    /// Ends the entry only when the change lands on the field being typed into.
    /// Typed text is shown for the focused field alone, so a write to any other
    /// field leaves it untouched — that pill already renders the stored value.
    func endEntry(ifEditing field: SetInputFocus.Field) {
        guard focusStorage?.field == field else { return }
        endEntry()
    }

    /// The text a field should display: the in-progress entry while this field
    /// is the one being typed into, and the stored value otherwise.
    func displayText(for input: SetInputFocus, storedValue: String) -> String {
        guard focus == input, let entryText else { return storedValue }
        // Duration is typed right-to-left as a clock, so the in-progress entry
        // has to be formatted the same way the committed value is. Echoing the
        // raw digits would show "130" for one keystroke and then "1:30" once
        // focus moved — the field disagreeing with itself.
        if input.field == .duration, let clock = ClockEntry.displayText(forTypedDigits: entryText) {
            return clock
        }
        return entryText
    }

    /// The field a whole-row tap should land on. Tapping a row means "let me log
    /// this set", so focus goes to the first value the lifter still owes: a
    /// required value that would block completion first, then any tracked value
    /// with nothing entered yet (added or assisted load is optional but still
    /// worth offering), and finally the first field when nothing is missing.
    ///
    /// This chooses focus only. It never writes a value and never infers a
    /// missing value as zero.
    static func firstMissingField(
        in set: ExerciseSet,
        for type: TrackingType
    ) -> SetInputFocus.Field {
        let fields = inputFields(for: type)
        let validation = WorkoutSetCompletionValidator.validate(.init(set: set, trackingType: type))
        let blocking = validation.firstInvalidReason.flatMap { field(for: $0.metric) }
        return blocking
            ?? fields.first { !hasEnteredValue($0, in: set) }
            ?? fields.first
            ?? .repetitions
    }

    private static func field(for metric: TrackingMetric) -> SetInputFocus.Field? {
        switch metric {
        case .repetitions: .repetitions
        case .load: .weight
        case .duration: .duration
        case .distance: .distance
        case .calories: .calories
        case .meanVelocity, .peakVelocity, .jumpHeight, .contactTime,
                .throwDistance, .cadence: nil
        }
    }

    private static func hasEnteredValue(
        _ field: SetInputFocus.Field,
        in set: ExerciseSet
    ) -> Bool {
        switch field {
        case .repetitions: set.repetitions > 0
        case .weight: set.weight > 0
        case .duration: (set.duration ?? 0) > 0
        case .distance: (set.distance ?? 0) > 0
        case .calories: (set.calories ?? 0) > 0
        }
    }

    static func inputFields(for type: TrackingType) -> [SetInputFocus.Field] {
        var fields: [SetInputFocus.Field] = []
        if type.usesReps { fields.append(.repetitions) }
        if type.usesWeight { fields.append(.weight) }
        if type.usesDuration { fields.append(.duration) }
        if type.usesDistance { fields.append(.distance) }
        if type.usesCalories { fields.append(.calories) }
        return fields
    }
}
