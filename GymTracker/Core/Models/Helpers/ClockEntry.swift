import Foundation

/// Right-to-left clock entry, the way a stopwatch, an oven timer, and a
/// microwave all behave.
///
/// The alternative — a plain numeric field holding a count of seconds — makes
/// the lifter convert 1:30 into "90" in their head, mid-set, for every timed
/// exercise in the app. Digits here shift in from the right instead: the last
/// two are seconds, everything before them is minutes. That needs no separator
/// key, so the keypad stays ten digits and a delete.
enum ClockEntry {

    /// Seconds represented by a raw run of typed digits.
    ///
    /// - `"45"`  → 45      (0:45)
    /// - `"130"` → 90      (1:30)
    /// - `"200"` → 120     (2:00)
    /// - `"1230"` → 750    (12:30)
    ///
    /// Returns `nil` for input containing no digits, so callers can fall back
    /// to whatever they used before rather than writing a zero the lifter never
    /// typed.
    ///
    /// Seconds are **not** clamped to 59: a lifter typing `"90"` means 0:90,
    /// which is the same instant as 1:30, and silently rewriting their digits
    /// mid-entry is worse than briefly showing an unusual clock. Typing the
    /// next digit resolves it anyway — `"90"` becoming `"901"` is 9:01.
    static func seconds(fromTypedDigits text: String) -> Double? {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        // A long run is a mistype, not a real rest or hold. Keep the most
        // recent digits, which is what the lifter is currently looking at.
        let trimmed = digits.count > 6 ? String(digits.suffix(6)) : digits

        let secondsPart = String(trimmed.suffix(2))
        let minutesPart = String(trimmed.dropLast(2))

        let seconds = Double(secondsPart) ?? 0
        let minutes = minutesPart.isEmpty ? 0 : (Double(minutesPart) ?? 0)

        return minutes * 60 + seconds
    }

    /// The `m:ss` rendering of a stored duration, for the value pill and the
    /// set row.
    static func clockText(seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// What a partially typed entry should display.
    ///
    /// Shown from the digits rather than from the stored value so the field
    /// reads back exactly what has been pressed so far — typing `1` shows
    /// `0:01`, then `1·3` shows `0:13`, then `1·3·0` shows `1:30`.
    static func displayText(forTypedDigits text: String) -> String? {
        guard let seconds = seconds(fromTypedDigits: text) else { return nil }
        return clockText(seconds: seconds)
    }
}
