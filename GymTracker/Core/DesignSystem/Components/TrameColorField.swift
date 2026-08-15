import SwiftUI

/// An opaque semantic field for one focal object or state.
struct TrameColorField<Content: View>: View {
    let fill: Color
    let ink: Color
    let border: Color
    let radius: CGFloat
    @ViewBuilder let content: Content

    init(
        fill: Color,
        ink: Color,
        border: Color,
        radius: CGFloat = Radius.field,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.ink = ink
        self.border = border
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(ink)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border)
            }
    }
}
