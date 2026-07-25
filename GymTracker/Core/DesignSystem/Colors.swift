import SwiftUI
import UIKit

extension Color {
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let gymText = dynamicColor(
        light: UIColor(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF6 / 255.0, green: 0xF0 / 255.0, blue: 0xE7 / 255.0, alpha: 1.0)
    )
    
    static let gymBackground = dynamicColor(
        light: UIColor(red: 0xF6 / 255.0, green: 0xF0 / 255.0, blue: 0xE7 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0, alpha: 1.0)
    )
    
    static let gymPrimary = dynamicColor(
        light: UIColor(red: 0x3D / 255.0, green: 0x72 / 255.0, blue: 0xE2 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x58 / 255.0, green: 0x88 / 255.0, blue: 0xF5 / 255.0, alpha: 1.0)
    )
    
    static let gymSecondary = dynamicColor(
        light: UIColor(red: 0x48 / 255.0, green: 0x7A / 255.0, blue: 0x6C / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x64 / 255.0, green: 0x9E / 255.0, blue: 0x8D / 255.0, alpha: 1.0)
    )
    
    static let gymSuccess = gymSecondary
    
    static let gymAccent = dynamicColor(
        light: UIColor(red: 0xA1 / 255.0, green: 0x68 / 255.0, blue: 0x3A / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xD4 / 255.0, green: 0x8D / 255.0, blue: 0x58 / 255.0, alpha: 1.0)
    )
    
    static let gymDestructive = dynamicColor(
        light: UIColor.red,
        dark: UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
    )
    
    static let gymCard = dynamicColor(
        light: UIColor(red: 0xFF / 255.0, green: 0xFC / 255.0, blue: 0xF7 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x20 / 255.0, alpha: 1.0)
    )
    
    static let gymPrimarySurface = dynamicColor(
        light: UIColor(red: 0xE7 / 255.0, green: 0xE9 / 255.0, blue: 0xEF / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x22 / 255.0, green: 0x28 / 255.0, blue: 0x38 / 255.0, alpha: 1.0)
    )
    
    static let gymSecondarySurface = dynamicColor(
        light: UIColor(red: 0xE7 / 255.0, green: 0xEA / 255.0, blue: 0xE1 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x1D / 255.0, green: 0x29 / 255.0, blue: 0x24 / 255.0, alpha: 1.0)
    )
    
    static let gymAccentSurface = dynamicColor(
        light: UIColor(red: 0xF2 / 255.0, green: 0xE9 / 255.0, blue: 0xDD / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x30 / 255.0, green: 0x26 / 255.0, blue: 0x1E / 255.0, alpha: 1.0)
    )
    
    static let gymRowSurface = dynamicColor(
        light: UIColor(red: 0xF2 / 255.0, green: 0xF1 / 255.0, blue: 0xEF / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x2B / 255.0, alpha: 1.0)
    )
    
    static let gymCurrentSetSurface = dynamicColor(
        light: UIColor(red: 225 / 255.0, green: 229 / 255.0, blue: 239 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x25 / 255.0, green: 0x32 / 255.0, blue: 0x4B / 255.0, alpha: 1.0)
    )
    
    // Semantic opacity-derived design system tokens
    static let gymMutedSurface = gymSecondary.opacity(0.16)
    static let gymBorder = dynamicColor(
        light: UIColor(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0, alpha: 0.09),
        dark: UIColor(red: 0xF6 / 255.0, green: 0xF0 / 255.0, blue: 0xE7 / 255.0, alpha: 0.15)
    )
    static let gymSubduedText = gymText.opacity(0.68)
    static let gymSubtleText = gymText.opacity(0.48)
}
