import Foundation

/// Counted nouns, written out rather than inflected.
///
/// The app's automatic grammar agreement markup — `^[\(n) day](inflect: true)`
/// — only resolves when the exact key is present in `Localizable.xcstrings`.
/// A key that has not been extracted yet renders its own markup on screen, and
/// a resolved string passed back through `LocalizedStringKey` (which
/// `GymTagChip` does) can mangle it a second time. Both failures are invisible
/// in review and obvious to the person holding the phone.
///
/// So the counted phrases onboarding builds at runtime are spelled out here
/// instead. Two plain keys per noun, each independently translatable, and
/// nothing that can leak syntax into the interface.
enum CountPhrase {
    static func days(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 day")
            : String(localized: "\(count) days")
    }

    static func daysPerWeek(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 day per week")
            : String(localized: "\(count) days per week")
    }

    /// The compact form used on summary chips, where the full phrase would wrap.
    static func daysPerWeekAbbreviated(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 day/week")
            : String(localized: "\(count) days/week")
    }

    static func sessions(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 session")
            : String(localized: "\(count) sessions")
    }

    static func completedWorkouts(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 completed workout")
            : String(localized: "\(count) completed workouts")
    }

    static func recordedSessions(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 recorded session")
            : String(localized: "\(count) recorded sessions")
    }

    static func sessionsPerWeek(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 session a week")
            : String(localized: "\(count) sessions a week")
    }

    /// The noun beside a count that is typeset separately.
    ///
    /// Unlike every other phrase here this one omits the digits: Today renders
    /// the figure large and monospaced on its own, so repeating it in the label
    /// would print the number twice. It still has to agree in number, which is
    /// why it is a function and not a constant.
    static func sessionsThisWeek(_ count: Int) -> String {
        count == 1
            ? String(localized: "session this week")
            : String(localized: "sessions this week")
    }

    static func items(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 item")
            : String(localized: "\(count) items")
    }

    static func completedSessions(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 completed session")
            : String(localized: "\(count) completed sessions")
    }

    static func sets(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 set")
            : String(localized: "\(count) sets")
    }

    static func completedSets(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 completed set")
            : String(localized: "\(count) completed sets")
    }

    static func incompleteSets(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 incomplete set")
            : String(localized: "\(count) incomplete sets")
    }

    static func exercises(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 exercise")
            : String(localized: "\(count) exercises")
    }

    static func observations(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 observation")
            : String(format: String(localized: "%lld observations"), Int64(count))
    }

    static func assessments(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 assessment")
            : String(format: String(localized: "%lld assessments"), Int64(count))
    }

    static func recordedAssessments(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 recorded assessment")
            : String(format: String(localized: "%lld recorded assessments"), Int64(count))
    }

    static func routines(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 routine")
            : String(localized: "\(count) routines")
    }

    static func movements(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 movement")
            : String(localized: "\(count) movements")
    }

    static func minutes(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 min")
            : String(localized: "\(count) min")
    }
}
