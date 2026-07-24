import SwiftUI

/// Pure, locale-aware parsing for decimal entry. This is the shared brain of
/// every decimal input in the app (workout weight/distance, food reference and
/// serving amounts, recipe ingredient quantities and yield, nutrition targets).
///
/// The core rule is that the *text being edited* is kept separate from the
/// stored numeric value, so a partially typed value such as ".", "0.", ",5" is
/// never destroyed by immediately trying to turn it into a number.
enum DecimalParser {
    /// Both ASCII separators are accepted regardless of the device locale so a
    /// French user can type "," and an English user "." and both round-trip.
    private static let separators: Set<Character> = [".", ","]

    /// Returns a cleaned version of the candidate text if it is a legal
    /// (possibly partial) decimal, or `nil` when it contains a disallowed
    /// character or a second decimal separator. Returning `nil` lets a bound
    /// `TextField` reject the keystroke and keep the previous text.
    static func sanitizedEditingText(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        var separatorCount = 0
        for character in trimmed {
            if character.isNumber { continue }
            if separators.contains(character) {
                separatorCount += 1
                if separatorCount > 1 { return nil }
                continue
            }
            // Letters, "-", "+", symbols, or grouping marks are rejected.
            return nil
        }
        return trimmed
    }

    /// Interprets edited text as a number. ".5" and ",5" both become 0.5, "5."
    /// becomes 5, and partial input ("", ".", ",") stays `nil` so the value is
    /// left untouched until the entry is complete.
    static func value(from text: String) -> Double? {
        let normalized = normalized(text)
        guard normalized.isEmpty == false, normalized != "." else { return nil }
        return Double(normalized)
    }

    /// Formats a stored value back into locale-appropriate display text with no
    /// trailing zeros. Used to normalize the field when editing ends.
    static func displayText(for value: Double?, locale: Locale = .current) -> String {
        guard let value else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    private static func normalized(_ text: String) -> String {
        String(text.map { separators.contains($0) ? "." : $0 })
    }
}

/// A reusable decimal text field that keeps the in-progress text separate from
/// the committed numeric value, accepts partial input, respects the regional
/// decimal separator, and clamps into an optional range when editing ends.
///
/// Bind it to an optional `Double`: `nil` represents an empty / unknown value,
/// which is intentionally distinct from `0`.
struct DecimalField: View {
    private let titleKey: LocalizedStringKey
    @Binding private var value: Double?
    private let promptText: String?
    private let range: ClosedRange<Double>?
    private let onCommit: (() -> Void)?

    @State private var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.locale) private var locale

    init(
        _ titleKey: LocalizedStringKey,
        value: Binding<Double?>,
        prompt: String? = nil,
        range: ClosedRange<Double>? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        _value = value
        self.promptText = prompt
        self.range = range
        self.onCommit = onCommit
        _text = State(initialValue: DecimalParser.displayText(for: value.wrappedValue))
    }

    var body: some View {
        TextField(titleKey, text: editingBinding, prompt: promptText.map(Text.init))
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                if focused == false { commit() }
            }
            .onChange(of: value) { _, newValue in
                // Reflect programmatic changes (e.g. a Stepper) while the user
                // is not actively editing, without clobbering in-progress text.
                if isFocused == false {
                    text = DecimalParser.displayText(for: newValue, locale: locale)
                }
            }
    }

    private var editingBinding: Binding<String> {
        Binding(
            get: { text },
            set: { candidate in
                guard let sanitized = DecimalParser.sanitizedEditingText(candidate) else {
                    return // reject the keystroke; keep the previous text
                }
                text = sanitized
                if sanitized.isEmpty {
                    value = nil
                } else if let parsed = DecimalParser.value(from: sanitized) {
                    value = parsed
                }
                // A partial value like "." leaves the stored value unchanged.
            }
        )
    }

    private func commit() {
        if let value, let range {
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            if clamped != value { self.value = clamped }
        }
        text = DecimalParser.displayText(for: value, locale: locale)
        onCommit?()
    }
}
