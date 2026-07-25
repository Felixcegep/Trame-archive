import SwiftUI
import UIKit

/// Hosts the single shared ``NumericKeypad`` instance used as the `inputView`
/// for every keypad-backed field in the app.
///
/// Only one field can be first responder at a time, so one hosting controller
/// serves them all. That matters: an active workout can hold dozens of sets with
/// up to five fields each, and giving every one its own `UIHostingController`
/// would allocate hundreds of them for a keyboard the user sees once.
@MainActor
private final class KeypadInputViewHost {
    static let shared = KeypadInputViewHost()

    /// Re-pointed at whichever field just became first responder.
    var onKey: ((KeypadKey) -> Void)?

    private var hostingController: UIHostingController<NumericKeypad>?
    private var container: UIInputView?

    /// The self-sizing container handed to `UITextField.inputView`.
    func inputView(decimalSeparator: String, showsDecimalKey: Bool) -> UIInputView {
        let keypad = NumericKeypad(
            decimalSeparator: decimalSeparator,
            showsDecimalKey: showsDecimalKey
        ) { [weak self] key in
            self?.onKey?(key)
        }

        if let hostingController, let container {
            hostingController.rootView = keypad
            return container
        }

        let controller = UIHostingController(rootView: keypad)
        controller.view.backgroundColor = .clear
        controller.sizingOptions = .intrinsicContentSize
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = controller

        let inputContainer = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        inputContainer.allowsSelfSizing = true
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor)
        ])

        container = inputContainer
        return inputContainer
    }
}

/// A numeric text field that raises ``NumericKeypad`` instead of the system
/// `.decimalPad`.
///
/// This stays a real `UITextField` rather than a tappable label so the value,
/// caret, selection, VoiceOver text-field trait, and `XCUIElementQuery.textFields`
/// lookups all behave exactly as they did before the custom keyboard landed. The
/// keypad drives it through `UIKeyInput`, so any `text` binding that already
/// worked with a SwiftUI `TextField` keeps working untouched.
struct KeypadTextField<Focus: Hashable>: UIViewRepresentable {
    @Binding var text: String
    @Binding var focus: Focus?
    /// The value of `focus` that means "this field is active".
    let focusValue: Focus
    var prompt: String?
    var isEnabled: Bool = true
    var showsDecimalKey: Bool = true
    /// Called when the field resigns first responder, so callers can normalize
    /// in-progress text back into display form.
    var onEditingEnded: (() -> Void)?

    @Environment(\.locale) private var locale
    /// Honors any surrounding `.disabled(_:)`, which is how the set rows already
    /// lock completed sets and duration fields with a running timer.
    @Environment(\.isEnabled) private var isEnvironmentEnabled

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.tintColor = UIColor(Color.gymPrimary)
        textField.textColor = UIColor(Color.gymText)
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize,
            weight: .semibold
        )
        // No system keyboard is ever shown, but the trait keeps hardware-keyboard
        // typing (which the UI tests rely on) restricted to numeric input.
        textField.keyboardType = .decimalPad
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        // Let the surrounding SwiftUI chrome own the size.
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }

        uiView.isEnabled = isEnabled && isEnvironmentEnabled
        uiView.attributedPlaceholder = prompt.map {
            NSAttributedString(
                string: $0,
                attributes: [.foregroundColor: UIColor(Color.gymSubtleText)]
            )
        }

        let shouldBeFocused = focus == focusValue
        if shouldBeFocused, !uiView.isFirstResponder {
            context.coordinator.attachKeypad(
                to: uiView,
                locale: locale,
                showsDecimalKey: showsDecimalKey
            )
            uiView.becomeFirstResponder()
        } else if !shouldBeFocused, uiView.isFirstResponder, focus == nil {
            // Only resign when focus was cleared outright. When focus moved to a
            // sibling field, that field's `becomeFirstResponder` takes over
            // implicitly — resigning here first would dismiss and re-present the
            // keypad, producing a visible flicker between every field.
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeypadTextField

        init(parent: KeypadTextField) {
            self.parent = parent
        }

        func attachKeypad(to textField: UITextField, locale: Locale, showsDecimalKey: Bool) {
            let separator = locale.decimalSeparator ?? "."
            KeypadInputViewHost.shared.onKey = { [weak textField] key in
                guard let textField else { return }
                Self.apply(key, to: textField, separator: separator)
            }
            textField.inputView = KeypadInputViewHost.shared.inputView(
                decimalSeparator: separator,
                showsDecimalKey: showsDecimalKey
            )
            textField.reloadInputViews()
        }

        private static func apply(_ key: KeypadKey, to textField: UITextField, separator: String) {
            switch key {
            case .digit(let value):
                textField.insertText("\(value)")
            case .decimal:
                // A second separator would be rejected by `DecimalParser` anyway;
                // swallowing it here avoids a dead-feeling key press.
                guard textField.text?.contains(separator) != true else { return }
                textField.insertText(separator)
            case .backspace:
                textField.deleteBackward()
            }
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if parent.focus != parent.focusValue {
                parent.focus = parent.focusValue
            }
            // Select the existing value so the first digit replaces it instead of
            // appending — retyping a load is far more common mid-workout than
            // editing one digit of it.
            DispatchQueue.main.async {
                textField.selectedTextRange = textField.textRange(
                    from: textField.beginningOfDocument,
                    to: textField.endOfDocument
                )
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            textField.inputView = nil
            let endedValue = parent.focusValue

            // Deferred deliberately. UIKit sends this *before* the newly tapped
            // field's `didBeginEditing`, so clearing focus synchronously would
            // blank it for a beat — long enough for SwiftUI to swap the panel out
            // and for `updateUIView` to resign the field that is mid-way through
            // becoming first responder. By the next runloop the new field has
            // claimed focus and this correctly does nothing.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.focus == endedValue else { return }
                self.parent.focus = nil
            }

            parent.onEditingEnded?()
        }
    }
}
