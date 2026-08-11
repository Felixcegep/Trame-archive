import SwiftUI

/// The user-facing composition and approval flow for in-app beta feedback.
/// Diagnostics are shown in full, exact preview before the user can share
/// anything, and the system share sheet is only presented after the user
/// explicitly taps Share — nothing is attached automatically.
struct BetaFeedbackScreen: View {
    @Environment(\.dismiss) private var dismiss
    let context: BetaFeedbackContext
    @State private var feedbackText: String = ""
    @State private var includeDiagnostics: Bool

    init(context: BetaFeedbackContext) {
        self.context = context
        // The simulator's nested SwiftUI/Form switch proxy is not reliably
        // tappable on iOS 26. Keep a deterministic UI-test seam for verifying
        // the privacy-off state while the shipped control remains a native
        // Toggle for VoiceOver and Dynamic Type users.
        _includeDiagnostics = State(
            initialValue: !AppLaunchArguments.current.contains("-ui-testing-beta-feedback-diagnostics-off")
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 140)
                        .accessibilityIdentifier("beta-feedback-editor")
                        .accessibilityLabel(Text("Feedback"))
                } header: {
                    Text("What's on your mind?")
                } footer: {
                    Text("Describe what happened, what you expected, or anything else worth flagging. English or French are both fine.")
                }

                Section {
                    Toggle("Include technical context", isOn: $includeDiagnostics)
                        .accessibilityIdentifier("beta-feedback-diagnostics-toggle")

                    if includeDiagnostics {
                        ForEach(context.diagnosticLines, id: \.label) { line in
                            LabeledContent(line.label, value: line.value)
                        }
                    }
                } header: {
                    Text("Diagnostics")
                        .accessibilityIdentifier("beta-feedback-diagnostics-preview")
                } footer: {
                    Text("No workout, meal, health, or journal content is ever included — only the details shown above.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Send Beta Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("beta-feedback-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: shareText) {
                        Text("Share")
                    }
                    .accessibilityIdentifier("beta-feedback-share")
                }
            }
        }
        .accessibilityIdentifier("beta-feedback-screen")
    }

    var shareText: String {
        var lines = [String(localized: "Trame Beta Feedback"), ""]
        if !feedbackText.isEmpty {
            lines.append(feedbackText)
            lines.append("")
        }
        if includeDiagnostics {
            lines.append("--- \(String(localized: "Diagnostics")) ---")
            lines.append(context.diagnosticText)
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    BetaFeedbackScreen(
        context: BetaFeedbackContext(
            appVersion: "1.0",
            buildNumber: "42",
            schemaVersion: "1",
            backupFormatVersion: 14,
            buildChannel: .beta,
            enabledFlags: [.today, .betaFeedback],
            deviceModel: "iPhone15,2",
            osVersion: "iOS 18.0",
            screen: .settings
        )
    )
}
