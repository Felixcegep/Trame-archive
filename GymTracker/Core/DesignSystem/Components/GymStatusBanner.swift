import SwiftUI

/// A short, passive confirmation that something the user asked for actually
/// happened.
///
/// It exists because this app handled failure well and success not at all:
/// every error had an alert, a specific message, and a retry, while saving a
/// workout, postponing a session, or skipping one produced nothing. A silent
/// success is indistinguishable from a no-op, so users re-check History or
/// re-tap the control.
///
/// Passive on purpose. It carries no action and never blocks: the work is
/// already done, and asking for acknowledgement of a completed action is what
/// makes confirmation dialogs tiresome. Anything that still needs a decision
/// belongs in a dialog; anything reversible within a window — like the History
/// undo banner — is deliberately a different thing, because there the dwell
/// time is a *functional* window gating a commit, not a display duration.
struct GymStatusMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String = AppIcon.checkmarkCircle) {
        self.id = UUID()
        self.text = text
        self.systemImage = systemImage
    }
}

private struct GymStatusBannerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var message: GymStatusMessage?

    /// Long enough to read a short sentence without becoming furniture. Held
    /// longer under VoiceOver, which has to reach and speak it.
    private var dwell: TimeInterval {
        UIAccessibility.isVoiceOverRunning ? 8 : 3.5
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    banner(message)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                }
            }
            .animation(reduceMotion ? nil : AppMotion.compact, value: message)
            // Spoken as well as shown: the banner is transient and sits away
            // from where focus is, so VoiceOver would otherwise miss it.
            .onChange(of: message) { _, newValue in
                guard let newValue else { return }
                GymAnnouncement.post(newValue.text)
            }
            .task(id: message?.id) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(dwell))
                guard !Task.isCancelled else { return }
                message = nil
            }
    }

    private func banner(_ message: GymStatusMessage) -> some View {
        Label(message.text, systemImage: message.systemImage)
            .font(AppFont.subheadline)
            .foregroundStyle(Color.gymText)
            .lineLimit(2)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.section, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.section, style: .continuous)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .shadow(color: Color.gymText.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
            // One element, and not a control: it reads as a status rather than
            // something to activate.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("gym-status-banner")
    }
}

extension View {
    /// Presents a transient confirmation over this view, bottom-aligned.
    ///
    /// Handles the visible and spoken channels. The haptic stays at the call
    /// site, via `gymFeedback`, because the right rung depends on what
    /// happened — a rescheduled session and a saved workout are not equals.
    func gymStatusBanner(_ message: Binding<GymStatusMessage?>) -> some View {
        modifier(GymStatusBannerModifier(message: message))
    }
}
