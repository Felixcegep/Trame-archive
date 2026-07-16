import SwiftUI

enum AppMotion {
    static let pressResponse = Animation.easeOut(duration: 0.14)
    static let compact = Animation.snappy(duration: 0.22, extraBounce: 0)
    static let layout = Animation.spring(response: 0.3, dampingFraction: 1)
    static let gesture = Animation.spring(response: 0.3, dampingFraction: 0.82)
}

struct GymPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(AppMotion.pressResponse, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GymPressButtonStyle {
    static var gymPress: GymPressButtonStyle { GymPressButtonStyle() }
}
