import SwiftUI

/// The dominant Trame command: opaque lime, compact rectangular geometry, and
/// no decorative depth. This lives beside the legacy `gymPrimary` style so a
/// feature can migrate without silently restyling every older call site.
struct TramePrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.sectionTitle)
            .foregroundStyle(isEnabled ? Color.trameActionInk : Color.trameSubdued)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(isEnabled ? Color.trameAction : Color.trameRow)
            }
            .overlay {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .stroke(Color.trameSeparator, lineWidth: 1)
                }
            }
            .weightedPulse(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TramePrimaryActionButtonStyle {
    static var tramePrimaryAction: TramePrimaryActionButtonStyle {
        TramePrimaryActionButtonStyle()
    }
}
