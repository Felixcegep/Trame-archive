import SwiftUI

/// A quiet section label with a single domain mark.
///
/// Color identifies Strength, Mobility, or attention once — on the header —
/// rather than as a dash-plus-hairline or a rail on every following row.
struct TrameDomainSectionRule: View {
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Rectangle()
                .fill(color)
                .frame(width: Spacing.xxs, height: Spacing.m)
                .accessibilityHidden(true)

            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
                .textCase(.uppercase)
        }
        .accessibilityElement(children: .combine)
    }
}
