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
    var focus: SetInputFocus?

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
