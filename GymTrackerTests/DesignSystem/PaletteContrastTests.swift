import UIKit
import SwiftUI
import XCTest
@testable import GymTracker

@MainActor
final class PaletteContrastTests: XCTestCase {
    func testMutedTextPassesAAOnEverySupportedSurfaceAndTrait() {
        let textTokens: [(String, UIColor)] = [
            ("gymText", UIColor(Color.gymText)),
            ("gymSubduedText", UIColor(Color.gymSubduedText)),
            ("gymSubtleText", UIColor(Color.gymSubtleText))
        ]
        let surfaces: [UIColor] = [
            UIColor(Color.gymPrimarySurface),
            UIColor(Color.gymSecondarySurface),
            UIColor(Color.gymAccentSurface),
            UIColor(Color.gymRowSurface),
            UIColor(Color.gymCurrentSetSurface)
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(accessibilityContrast: contrast)
                ])
                for (name, text) in textTokens {
                    let resolvedText = text.resolvedColor(with: traits)
                    for surface in surfaces {
                        let ratio = contrastRatio(
                            foreground: resolvedText,
                            background: surface.resolvedColor(with: traits)
                        )
                        XCTAssertGreaterThanOrEqual(
                            ratio,
                            4.5,
                            "\(name) contrast \(ratio) failed for \(style)/\(contrast)"
                        )
                    }
                }
            }
        }
    }

    private func contrastRatio(foreground: UIColor, background: UIColor) -> CGFloat {
        var fr: CGFloat = 0
        var fg: CGFloat = 0
        var fb: CGFloat = 0
        var fa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        XCTAssertTrue(foreground.getRed(&fr, green: &fg, blue: &fb, alpha: &fa))
        XCTAssertTrue(background.getRed(&br, green: &bg, blue: &bb, alpha: &ba))

        func luminance(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGFloat {
            [red, green, blue].map { value in
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }.enumerated().reduce(0) { partial, pair in
                partial + pair.element * [0.2126, 0.7152, 0.0722][pair.offset]
            }
        }

        let foregroundLuminance = luminance(fr, fg, fb)
        let backgroundLuminance = luminance(br, bg, bb)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
