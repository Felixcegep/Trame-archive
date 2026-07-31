import SwiftUI
import UIKit

/// The fixed identity colours of the Trame mark.
///
/// Deliberately a separate file from `Colors.swift`. Every token there is
/// *semantic* and resolves per appearance and per contrast setting, because a
/// button or a caption has to stay legible in whatever environment the user
/// chose. These do not resolve: a logo that shifts hue with the appearance is
/// a different logo, and the mark has to match the app icon, the launch
/// screen, and exported share graphics — none of which can see the user's
/// settings.
///
/// Use `Color.gym*` for interface. Use these only when drawing the mark, its
/// plate, or a share/export surface that has to match printed identity.
extension Color {
    /// Brand navy. The dark tone of the identity and the app icon's plate.
    ///
    /// Not `.black`: pure black reads as system chrome, flattens the mark
    /// against dark backgrounds, and loses the slight violet cast that makes
    /// the cream look warm rather than grey next to it.
    static let trameNavy = Color(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0)

    /// Brand cream. The mark's light tone, drawn on navy.
    static let trameCream = Color(red: 0xFF / 255.0, green: 0xFC / 255.0, blue: 0xF7 / 255.0)

    /// The identity's parchment tone — the ground the mark sits on in the
    /// motion identity and in share graphics. Matches `gymBackground`'s light
    /// value, but stated fixed here because an export has no appearance.
    static let trameParchment = Color(red: 0xF6 / 255.0, green: 0xF0 / 255.0, blue: 0xE7 / 255.0)

    /// The mark drawn *inside the app* — over app surfaces rather than over
    /// its own plate. Navy on light, cream on dark.
    ///
    /// This is the one brand colour that resolves, and only because it is
    /// drawn on a surface that resolves. On its own plate (app icon, launch
    /// screen, export) use `trameCream` on `trameNavy` directly.
    static let trameMark = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255.0, green: 0xFC / 255.0, blue: 0xF7 / 255.0, alpha: 1.0)
            : UIColor(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0, alpha: 1.0)
    })
}
