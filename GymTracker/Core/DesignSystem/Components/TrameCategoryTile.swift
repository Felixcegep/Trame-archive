import SwiftUI

/// An opaque training-category square using a semantic SF Symbol token.
struct TrameCategoryTile: View {
    let systemImage: String
    let fill: Color
    var ink: Color = .trameSemanticFieldInk
    var size: CGFloat = ComponentSize.iconChip

    var body: some View {
        Image(systemName: systemImage)
            .font(AppFont.metricCompact)
            .foregroundStyle(ink)
            .frame(
                width: size,
                height: size
            )
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.icon, style: .continuous))
            .accessibilityHidden(true)
    }
}
