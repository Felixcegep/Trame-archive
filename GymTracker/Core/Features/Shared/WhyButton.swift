import SwiftUI

/// The single affordance that opens a `WhyExplanationView`.
///
/// Four surfaces adopted the shared explanation independently and each
/// hand-rolled this button. They happened to converge on the same icon, font,
/// and colour — which is exactly the kind of agreement that quietly drifts the
/// first time someone tweaks one of them. One component makes the consistency
/// structural instead of coincidental.
///
/// It is deliberately a separate control rather than a tappable row: reading
/// the reasoning must never be the same gesture as accepting it.
struct WhyButton: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: AppIcon.info)
                Text("Why?")
            }
            .font(AppFont.footnoteMedium)
            .foregroundStyle(Color.gymPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// Anything that can explain itself through the shared surface.
///
/// The point of the protocol is the Phase 2c requirement that *any future*
/// recommendation ships with an explanation. A new presentation type cannot be
/// handed to an explanation-aware surface without providing one, so the
/// guarantee is enforced by the compiler rather than by a promise in a
/// planning document.
protocol WhyExplainable {
    var whyModel: WhyExplanationModel { get }
}
