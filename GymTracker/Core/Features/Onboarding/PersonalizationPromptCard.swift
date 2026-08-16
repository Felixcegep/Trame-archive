import SwiftData
import SwiftUI

/// Whether to offer personalization to someone who skipped it.
///
/// The offer is made *after* the app has given something back, never before,
/// and never during a save. A prompt that interrupts the confirmation of a
/// finished workout is charging the lifter for their own success; the same
/// prompt sitting on Today the next time they open it costs nothing and is
/// still there when they are curious.
@MainActor
enum PersonalizationPromptPolicy {
    /// How many completed workouts a "Not now" defers by. Long enough that the
    /// answer means something, short enough that a lifter who was genuinely
    /// interested gets a second chance.
    static let deferralWorkoutCount = 3

    static func shouldPrompt(
        completedWorkoutCount: Int,
        using context: ModelContext,
        defaults: UserDefaults = .standard,
        arguments: [String] = AppLaunchArguments.current
    ) -> Bool {
        // Suppressed under UI testing for the same reason the welcome screen
        // is: every fixture asserts against a specific screen, and a card that
        // appears once a fixture happens to include a saved workout would make
        // Today's assertions depend on unrelated seed data. The dedicated
        // argument opts one scene back in.
        if arguments.contains("-ui-testing"), !arguments.contains("-ui-testing-show-personalization-prompt") {
            return false
        }
        // Never asked twice of someone who has already declined for good.
        guard !defaults.bool(forKey: DefaultsKey.hasDeclinedPersonalization) else { return false }
        // Nor of someone who already answered — the profile is the answer.
        guard TrainingProfileService.current(using: context)?.completedCoreOnboardingAt == nil else {
            return false
        }
        // Nothing has been given back yet. Asking now is asking on credit.
        guard completedWorkoutCount >= 1 else { return false }
        let deferredAt = defaults.integer(forKey: DefaultsKey.personalizationPromptDeferralCount)
        guard deferredAt > 0 else { return true }
        return completedWorkoutCount >= deferredAt + deferralWorkoutCount
    }

    static func postpone(atCompletedWorkoutCount count: Int, defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: DefaultsKey.personalizationPromptDeferralCount)
    }

    static func declineForGood(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: DefaultsKey.hasDeclinedPersonalization)
    }
}

