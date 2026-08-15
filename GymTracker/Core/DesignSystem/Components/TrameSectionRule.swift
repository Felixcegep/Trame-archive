import SwiftUI

/// A localized section title carried by a structural rule rather than a card.
struct TrameSectionRule: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: Spacing.m) {
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
