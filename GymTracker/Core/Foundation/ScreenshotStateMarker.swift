import SwiftUI

@ViewBuilder
func screenshotStateMarker(_ identifier: String, label: String) -> some View {
    if CommandLine.arguments.contains("-ui-testing") {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}
