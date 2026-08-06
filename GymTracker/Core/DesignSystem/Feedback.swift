import SwiftUI
import UIKit

/// The app's feedback vocabulary, named by **event** rather than by intensity.
///
/// Call sites say what happened; this type decides how it feels. That keeps the
/// escalation ladder reviewable in one place, which is the thing that actually
/// goes wrong otherwise: before this existed, four of the app's five haptics
/// were `.success`, so a routine set completion felt exactly like finishing an
/// entire workout and the ladder carried no information.
///
/// The ladder, weakest to strongest:
///
/// | Feedback | Meaning |
/// | --- | --- |
/// | light impact | routine, low-consequence, repeated |
/// | medium impact | a logged unit of work, or a significant state change |
/// | rigid impact | a snap point, or an irreversible commit |
/// | selection | moving through discrete positions |
/// | warning | attention needed now, or a blocked action |
/// | success | session-level completion, **after** persistence |
/// | error | the action failed |
///
/// Rules that hold for every case here, from `Documentation/MotionAndHaptics.md`:
///
/// - One user action produces at most one haptic.
/// - Feedback fires from the committed domain event, never from a view
///   appearing, a task starting, or a button being pressed.
/// - Boolean triggers are guarded so the reverse transition is silent.
/// - **State restoration is not an event.** Anything reachable from
///   `restorePersistedRestTimer`, `restoreActiveWorkout`, an external
///   mutation, or a UI-test fixture must not fire.
/// - Never duplicate system feedback. `Picker`, `Stepper`, `List` reorder, and
///   `swipeActions` already produce their own.
enum GymFeedback {
    /// A key on the set-entry keypad. High frequency, so the lightest thing
    /// available — and the custom keypad raises no first responder, so it
    /// replaces a system keyboard click rather than adding to one.
    case keyPressed
    /// A deliberate user action started a new workout (not resumed an existing one).
    case workoutStarted
    /// A set or exercise was appended.
    case itemAdded
    /// A set was marked complete. Deliberately *not* `.success`: this happens
    /// 20–40 times a session, and reserving success for session-level
    /// completion is what lets a saved workout feel different from a set.
    case setCompleted
    /// A drag crossed the threshold at which releasing would commit. Fires on
    /// the crossing, not the commit, so the lifter learns where the edge is
    /// while they can still back out.
    case swipeArmed
    /// An irreversible destruction actually committed — not when it was
    /// requested, and not while it can still be undone.
    case destructiveCommitted
    /// A rest period reached its deadline. `.warning` rather than `.success`
    /// because the meaning is "attention needed now", not "well done".
    case restReady
    /// A hold or interval reached its prescribed duration.
    case timedTargetReached
    /// An action was refused because required input is missing.
    case validationBlocked
    /// A scheduled session moved: postponed, rescheduled, or skipped. Routine
    /// and reversible, so it sits on the same rung as adding a set.
    case scheduleChanged
    /// A training source changed state: a plan or rotation paused, resumed,
    /// activated, restarted, or ended. Rarer and more consequential than moving
    /// one session, because it changes what Today will offer from now on.
    case planStateChanged
    /// A session-level record was persisted: a workout saved to History, a
    /// mobility assessment recorded, a backup imported. Fires only after
    /// persistence has actually succeeded.
    case sessionSaved
    /// An asynchronous generation produced a result the user is now looking at
    /// — a recipe draft, not a saved recipe.
    case generationCompleted
    /// A session-level save failed.
    case saveFailed

    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .workoutStarted:
            .impact(flexibility: .soft)
        case .keyPressed, .itemAdded, .scheduleChanged:
            .impact(weight: .light)
        case .setCompleted, .planStateChanged:
            .impact(weight: .medium)
        case .swipeArmed, .destructiveCommitted:
            .impact(flexibility: .rigid)
        case .restReady, .validationBlocked:
            .warning
        case .timedTargetReached, .sessionSaved, .generationCompleted:
            .success
        case .saveFailed:
            .error
        }
    }
}

extension View {
    /// Fires `feedback` when `trigger` changes.
    func gymFeedback<T: Equatable>(_ feedback: GymFeedback, trigger: T) -> some View {
        sensoryFeedback(feedback.sensoryFeedback, trigger: trigger)
    }

    /// Fires `feedback` when `trigger` changes and `condition` allows it.
    ///
    /// Use the condition for boolean triggers, so only the meaningful direction
    /// fires — reopening a completed set, or a rest timer being cancelled, must
    /// stay silent.
    func gymFeedback<T: Equatable>(
        _ feedback: GymFeedback,
        trigger: T,
        condition: @escaping (T, T) -> Bool
    ) -> some View {
        sensoryFeedback(feedback.sensoryFeedback, trigger: trigger, condition: condition)
    }
}

/// Spoken confirmation for outcomes a sighted user learns from a haptic or a
/// screen change that VoiceOver would otherwise miss.
///
/// `Documentation/Accessibility.md` requires that completion be conveyed
/// visibly *and* spoken, independently of haptics — a haptic is never the only
/// channel. This sits beside `GymFeedback` so the pairing is hard to forget:
/// an asynchronous outcome generally needs both.
enum GymAnnouncement {
    /// Posts a VoiceOver announcement. A no-op when VoiceOver is not running,
    /// so call sites do not need to check.
    static func post(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
