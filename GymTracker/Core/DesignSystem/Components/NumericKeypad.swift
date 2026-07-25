import SwiftUI

/// A key on ``NumericKeypad``. Deliberately free of any text-editing semantics:
/// the keypad only reports which key was pressed and the host decides what that
/// means for its own text storage.
enum KeypadKey: Hashable {
    case digit(Int)
    case decimal
    case backspace

    var accessibilityLabel: String {
        switch self {
        case .digit(let value): return "\(value)"
        case .decimal: return "Decimal separator"
        case .backspace: return "Delete"
        }
    }
}

/// The custom numeric keyboard used for set entry. It replaces `.decimalPad` so
/// the keys can carry the app's own surfaces, sit at a comfortable size for a
/// sweaty thumb mid-set, and keep a predictable height that the set-entry panel
/// above it can rely on.
///
/// This view is intentionally dependency-free so it can be hosted as a
/// `UITextField.inputView` (see ``KeypadTextField``) without dragging workout
/// state into UIKit.
struct NumericKeypad: View {
    /// The separator drawn on the decimal key. Passed in rather than read from
    /// the environment because an input view is hosted outside the SwiftUI
    /// hierarchy that would otherwise carry the locale.
    var decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    var showsDecimalKey: Bool = true
    let onKey: (KeypadKey) -> Void

    @State private var lastPressedKey: KeypadKey?

    private let rows: [[KeypadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)]
    ]

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Spacing.s) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }

            HStack(spacing: Spacing.s) {
                if showsDecimalKey {
                    keyButton(.decimal)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
                keyButton(.digit(0))
                keyButton(.backspace)
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.gymBackground)
        // Digits are already oversized, so growth past this point only steals
        // room from the set list without improving legibility.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sensoryFeedback(.impact(weight: .light), trigger: lastPressedKey)
    }

    private func keyButton(_ key: KeypadKey) -> some View {
        Button {
            lastPressedKey = key
            onKey(key)
        } label: {
            keyLabel(key)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(keyBackground(for: key))
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .stroke(Color.gymBorder, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityLabel(key.accessibilityLabel)
        .accessibilityIdentifier(identifier(for: key))
    }

    @ViewBuilder
    private func keyLabel(_ key: KeypadKey) -> some View {
        switch key {
        case .digit(let value):
            Text("\(value)")
                .font(AppFont.titleMediumMonospaced)
                .foregroundStyle(Color.gymText)
        case .decimal:
            Text(decimalSeparator)
                .font(AppFont.titleMediumMonospaced)
                .foregroundStyle(Color.gymText)
        case .backspace:
            Image(systemName: AppIcon.backspace)
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func keyBackground(for key: KeypadKey) -> Color {
        key == .backspace ? Color.gymCard.opacity(0.6) : Color.gymCard
    }

    private func identifier(for key: KeypadKey) -> String {
        switch key {
        case .digit(let value): return "keypad-key-\(value)"
        case .decimal: return "keypad-key-decimal"
        case .backspace: return "keypad-key-backspace"
        }
    }
}

#Preview {
    VStack {
        Spacer()
        NumericKeypad { _ in }
    }
    .background(Color.gymBackground)
}
