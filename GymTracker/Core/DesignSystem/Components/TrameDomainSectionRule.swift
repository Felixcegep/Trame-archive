import SwiftUI

/// A localized section header with a high-chroma domain-specific indicator rail.
struct TrameDomainSectionRule: View {
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.s) {
            Rectangle()
                .fill(color)
                .frame(width: 18, height: 3)
                .accessibilityHidden(true)

            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
                .textCase(.uppercase)

            Rectangle()
                .fill(Color.trameSeparator)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}
