import SwiftUI
import UIKit

extension Color {
    /// Resolves per appearance and, where supplied, per contrast setting.
    ///
    /// Increase Contrast is handled here rather than at call sites: it is a
    /// trait, so a `UIColor` closure sees it for free, and every one of the
    /// hundreds of places that reference a token then responds without
    /// changing. Reading `colorSchemeContrast` in views instead would have
    /// meant touching each of them.
    private static func dynamicColor(
        light: UIColor,
        dark: UIColor,
        lightIncreasedContrast: UIColor? = nil,
        darkIncreasedContrast: UIColor? = nil
    ) -> Color {
        Color(UIColor { traitCollection in
            let wantsIncreasedContrast = traitCollection.accessibilityContrast == .high
            if traitCollection.userInterfaceStyle == .dark {
                return wantsIncreasedContrast ? (darkIncreasedContrast ?? dark) : dark
            }
            return wantsIncreasedContrast ? (lightIncreasedContrast ?? light) : light
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
    
    /// Attention: a running rest period, a warning, a blocked value, an
    /// estimate. Never data.
    ///
    /// It used to mean five things at once — including the weight column in
    /// every set row — so the eye could not use it to separate "something needs
    /// your attention" from "this is a number you typed". Data emphasis moved
    /// to `gymDataEmphasis`; this is attention only.
    ///
    /// Darkened in light mode from `#A1683A`, which was 3.84:1 as text on
    /// `gymAccentSurface` — the rest card's own fill, where the countdown lives
    /// — and 3.66:1 on the current set's row.
    static let gymAccent = dynamicColor(
        light: UIColor(red: 0x92 / 255.0, green: 0x59 / 255.0, blue: 0x30 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xD4 / 255.0, green: 0x8D / 255.0, blue: 0x58 / 255.0, alpha: 1.0)
    )

    /// A performed or prescribed number that should be findable at a glance —
    /// today, the weight in a set row.
    ///
    /// **Resolved to `gymText`.** This was its own violet hue, on the reasoning
    /// that every other token carries a *state* and a weight is not a state. The
    /// reasoning was right and the conclusion was backwards: giving data a fifth
    /// hue meant four colours competed on the Active Workout screen at once
    /// (blue chrome, green completion, warm rest, violet weight), and nothing
    /// that is always coloured can be emphasis.
    ///
    /// A number leads by *weight*, not by hue — which is what Hevy, Apple
    /// Fitness and Oura all do, and what the column header plus the surrounding
    /// subdued metadata already achieve here. The separation that actually
    /// matters on a set row is logged-versus-suggested, and that is carried by
    /// `gymSubduedText` on unlogged values (see `SetRowFieldStack`).
    ///
    /// Kept as a named token rather than deleted so the intent stays greppable
    /// and a future decision to re-introduce a data hue has one place to land.
    static let gymDataEmphasis = gymText
    
    /// Time is running out but there is still time. The middle band of the rest
    /// dial, and nothing else yet.
    ///
    /// This could not reuse `gymAccent`: that brown *is* the rest surface's own
    /// colour, so a rest dial cannot use it to mean "hurry" — the alarm and the
    /// ground it sits on would be the same hue.
    ///
    /// Used as a graphic, not as text, so it is tuned for the 3:1 non-text
    /// contrast minimum against `gymAccentSurface` rather than 4.5:1.
    static let gymCaution = dynamicColor(
        light: UIColor(red: 0xB8 / 255.0, green: 0x80 / 255.0, blue: 0x2A / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xE0 / 255.0, green: 0xA8 / 255.0, blue: 0x3E / 255.0, alpha: 1.0)
    )

    /// The last few seconds before a set. Deliberately *not* `gymDestructive`.
    ///
    /// Destructive red means "this deletes your data" everywhere else in the
    /// app. Spending it on a countdown would teach the lifter that red is
    /// ambient rather than dangerous, which is the one association a
    /// destructive colour cannot afford to lose.
    static let gymUrgent = dynamicColor(
        light: UIColor(red: 0xC0 / 255.0, green: 0x39 / 255.0, blue: 0x2B / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xFF / 255.0, green: 0x7A / 255.0, blue: 0x6E / 255.0, alpha: 1.0)
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
    
    /// A deeper blue for surfaces that carry white text.
    ///
    /// `gymPrimary` is tuned to read as an accent *on* the background; white on
    /// top of it computes to 4.46:1, which clears WCAG AA for large text but
    /// misses the 4.5:1 that 15–17pt body text needs. This is the same hue,
    /// darkened just past that line, for filled surfaces only. It is not a
    /// replacement for `gymPrimary` as a tint or a text colour.
    static let gymPrimaryDeep = dynamicColor(
        light: UIColor(red: 0x3A / 255.0, green: 0x6D / 255.0, blue: 0xD8 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x3F / 255.0, green: 0x6F / 255.0, blue: 0xDC / 255.0, alpha: 1.0)
    )

    // Semantic opacity-derived design system tokens
    static let gymMutedSurface = gymSecondary.opacity(0.16)
    static let gymBorder = dynamicColor(
        light: UIColor(red: 0x27 / 255.0, green: 0x26 / 255.0, blue: 0x35 / 255.0, alpha: 0.09),
        dark: UIColor(red: 0xF6 / 255.0, green: 0xF0 / 255.0, blue: 0xE7 / 255.0, alpha: 0.15)
    )

    /// The one muted text tone. Clears 4.5:1 against **every** surface token in
    /// both appearances — worst case is `gymCurrentSetSurface`, the tinted fill
    /// under the row being logged.
    ///
    /// Both muted tones were opacity-derived and both failed AA. The audit
    /// caught `gymSubtleText` at 2.90:1 on `gymCard`; measuring against the
    /// tinted surfaces rather than only the card showed `gymSubduedText` failing
    /// too, at 4.22:1 on `gymCurrentSetSurface`.
    ///
    /// Solving each against its worst surface produced `#65636C` and `#66646D`
    /// — indistinguishable. That is the real finding: **this palette does not
    /// support two muted luminance tiers that both pass.** A cream-to-white
    /// surface range leaves too little headroom below secondary text. So there
    /// is now one tone, and hierarchy below it comes from size, weight, and
    /// case — which the affected captions ("REPS", "WEIGHT") already use.
    static let gymSubduedText = dynamicColor(
        light: UIColor(red: 0x66 / 255.0, green: 0x64 / 255.0, blue: 0x6D / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xB0 / 255.0, green: 0xAC / 255.0, blue: 0xA7 / 255.0, alpha: 1.0),
        lightIncreasedContrast: UIColor(red: 0x45 / 255.0, green: 0x43 / 255.0, blue: 0x4C / 255.0, alpha: 1.0),
        darkIncreasedContrast: UIColor(red: 0xD5 / 255.0, green: 0xD1 / 255.0, blue: 0xCB / 255.0, alpha: 1.0)
    )

    /// Formerly a third, lighter text tier; now the same tone as
    /// `gymSubduedText` for the reason documented there.
    ///
    /// Kept as a name rather than removed so 47 call sites do not churn inside
    /// an accessibility change. Prefer `gymSubduedText` in new code, and reach
    /// for a smaller or lighter *font* when something needs to recede further —
    /// not a fainter colour, which this palette has no room for.
    static let gymSubtleText = gymSubduedText
}
