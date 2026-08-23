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

    // MARK: - Trame Core Concept

    // Canonical production roles. These are deliberately separate from the
    // compatibility `gym…` vocabulary below: a legacy token may still combine
    // several responsibilities while its owning screens are migrated, whereas
    // every `trame…` role has one job.

    static let trameCanvas = dynamicColor(
        light: UIColor(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xE5 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x0F / 255.0, alpha: 1.0)
    )

    static let trameSurface = dynamicColor(
        light: UIColor(red: 0xF9 / 255.0, green: 0xF6 / 255.0, blue: 0xEE / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x1C / 255.0, green: 0x1B / 255.0, blue: 0x18 / 255.0, alpha: 1.0)
    )

    static let trameRow = dynamicColor(
        light: UIColor(red: 0xE9 / 255.0, green: 0xE3 / 255.0, blue: 0xD8 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x29 / 255.0, green: 0x27 / 255.0, blue: 0x22 / 255.0, alpha: 1.0)
    )

    static let trameCurrent = dynamicColor(
        light: UIColor(red: 0xE0 / 255.0, green: 0xE6 / 255.0, blue: 0xD9 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x29 / 255.0, green: 0x37 / 255.0, blue: 0x2E / 255.0, alpha: 1.0)
    )

    static let trameText = dynamicColor(
        light: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xE5 / 255.0, alpha: 1.0)
    )

    static let trameSubdued = dynamicColor(
        light: UIColor(red: 0x5F / 255.0, green: 0x5B / 255.0, blue: 0x53 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xB7 / 255.0, green: 0xB0 / 255.0, blue: 0xA3 / 255.0, alpha: 1.0),
        lightIncreasedContrast: UIColor(red: 0x47 / 255.0, green: 0x44 / 255.0, blue: 0x3F / 255.0, alpha: 1.0),
        darkIncreasedContrast: UIColor(red: 0xDE / 255.0, green: 0xD7 / 255.0, blue: 0xCB / 255.0, alpha: 1.0)
    )

    /// Structural separation. The Pale value is the exact Rule swatch from the
    /// final Core Concept; Dark uses an opaque counterpart so Increase
    /// Contrast and Reduce Transparency never depend on compositing.
    static let trameSeparator = dynamicColor(
        light: UIColor(red: 0xD8 / 255.0, green: 0xD2 / 255.0, blue: 0xC6 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x4B / 255.0, green: 0x48 / 255.0, blue: 0x41 / 255.0, alpha: 1.0),
        lightIncreasedContrast: UIColor(red: 0x8C / 255.0, green: 0x86 / 255.0, blue: 0x7C / 255.0, alpha: 1.0),
        darkIncreasedContrast: UIColor(red: 0x8F / 255.0, green: 0x89 / 255.0, blue: 0x7E / 255.0, alpha: 1.0)
    )

    /// The one dominant physical command on a screen: Ink on Paper, inverted
    /// in Dark. Domain colors identify training; they do not replace action.
    static let trameAction = dynamicColor(
        light: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xE5 / 255.0, alpha: 1.0)
    )

    static let trameActionDeep = dynamicColor(
        light: UIColor(red: 0x34 / 255.0, green: 0x33 / 255.0, blue: 0x2F / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xD8 / 255.0, green: 0xD2 / 255.0, blue: 0xC6 / 255.0, alpha: 1.0)
    )

    static let trameActionInk = dynamicColor(
        light: UIColor(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xE5 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0)
    )

    /// A structural edge for an inverse action. It is not a second action hue.
    static let trameActionOutline = dynamicColor(
        light: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xE5 / 255.0, alpha: 1.0)
    )

    /// Completion is an interface state, not the Mobility training hue.
    static let trameCompleted = dynamicColor(
        light: UIColor(red: 0x2F / 255.0, green: 0x60 / 255.0, blue: 0x47 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x7D / 255.0, green: 0xB7 / 255.0, blue: 0x8F / 255.0, alpha: 1.0),
        lightIncreasedContrast: UIColor(red: 0x24 / 255.0, green: 0x4E / 255.0, blue: 0x38 / 255.0, alpha: 1.0),
        darkIncreasedContrast: UIColor(red: 0xA6 / 255.0, green: 0xD8 / 255.0, blue: 0xB5 / 255.0, alpha: 1.0)
    )

    /// Attention as an opaque object/state field. Pair it with
    /// `trameAttentionInk`; do not assume it is suitable as small text.
    static let trameAttention = dynamicColor(
        light: UIColor(red: 0xDF / 255.0, green: 0xA2 / 255.0, blue: 0x1A / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF0 / 255.0, green: 0xB6 / 255.0, blue: 0x47 / 255.0, alpha: 1.0)
    )

    static let trameAttentionInk = dynamicColor(
        light: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0)
    )

    /// Destructive object fill from the approved palette.
    static let trameDestructive = dynamicColor(
        light: UIColor(red: 0xB9 / 255.0, green: 0x4A / 255.0, blue: 0x32 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xEF / 255.0, green: 0x7B / 255.0, blue: 0x63 / 255.0, alpha: 1.0)
    )

    static let trameDestructiveInk = trameActionInk

    /// Accessible destructive foreground for normal-size text on the canvas.
    /// The Pale palette fill itself is a 4.10:1 color against white, so it is
    /// not used as body text.
    static let trameDestructiveText = dynamicColor(
        light: UIColor(red: 0x91 / 255.0, green: 0x34 / 255.0, blue: 0x23 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xFF / 255.0, green: 0x91 / 255.0, blue: 0x79 / 255.0, alpha: 1.0),
        lightIncreasedContrast: UIColor(red: 0x79 / 255.0, green: 0x2B / 255.0, blue: 0x1D / 255.0, alpha: 1.0),
        darkIncreasedContrast: UIColor(red: 0xFF / 255.0, green: 0xB0 / 255.0, blue: 0x9E / 255.0, alpha: 1.0)
    )

    static let trameStrength = dynamicColor(
        light: UIColor(red: 0x2F / 255.0, green: 0x60 / 255.0, blue: 0x47 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x7D / 255.0, green: 0xB7 / 255.0, blue: 0x8F / 255.0, alpha: 1.0)
    )

    /// Quiet progress track derived from Strength; never a content surface.
    static let trameStrengthTrack = dynamicColor(
        light: UIColor(red: 0xA9 / 255.0, green: 0xB9 / 255.0, blue: 0xAD / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x3E / 255.0, green: 0x67 / 255.0, blue: 0x4D / 255.0, alpha: 1.0)
    )

    static let trameMobility = dynamicColor(
        light: UIColor(red: 0xEF / 255.0, green: 0x68 / 255.0, blue: 0x4F / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xFF / 255.0, green: 0x8B / 255.0, blue: 0x74 / 255.0, alpha: 1.0)
    )

    static let trameConditioning = dynamicColor(
        light: UIColor(red: 0xB9 / 255.0, green: 0x4A / 255.0, blue: 0x32 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xE8 / 255.0, green: 0x7C / 255.0, blue: 0x66 / 255.0, alpha: 1.0)
    )

    static let trameRecovery = dynamicColor(
        light: UIColor(red: 0xB9 / 255.0, green: 0x4A / 255.0, blue: 0x32 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xE8 / 255.0, green: 0x7C / 255.0, blue: 0x66 / 255.0, alpha: 1.0)
    )

    static let trameCompetition = dynamicColor(
        light: UIColor(red: 0xDF / 255.0, green: 0xA2 / 255.0, blue: 0x1A / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xF0 / 255.0, green: 0xB6 / 255.0, blue: 0x47 / 255.0, alpha: 1.0)
    )

    /// Bright Mobility and Performance fields carry Ink. Strength is too dark
    /// for this pairing and must use `trameText` on an open Paper composition,
    /// not a large filled field.
    static let trameSemanticFieldInk = dynamicColor(
        light: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x15 / 255.0, alpha: 1.0)
    )

    // MARK: - Compatibility vocabulary

    static let gymText = trameText

    static let gymBackground = trameCanvas
    
    static let gymPrimary = dynamicColor(
        light: UIColor(red: 0x3D / 255.0, green: 0x72 / 255.0, blue: 0xE2 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x58 / 255.0, green: 0x88 / 255.0, blue: 0xF5 / 255.0, alpha: 1.0)
    )
    
    static let gymSecondary = trameCompleted
    
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

    // MARK: - Chart-only categorical colors
    //
    // A distinct family from every token above: those describe a *role* in
    // the interface (primary action, completion, contextual attention) and
    // are chosen for how they read as fills, strokes, and text. These seven
    // exist for exactly one job — standing apart from up to six neighbors in
    // a chart legend — and are validated against that job specifically
    // (fixed hue order, OKLCH lightness/chroma bands, CVD separation under
    // simulated color blindness, a normal-vision floor, contrast versus the
    // chart surface). See `SportDisciplinePalette` for the assignment and the
    // exact validator invocation. Never reuse one of these for a UI role, and
    // never reuse a UI role token — `gymSecondary` included — for a chart
    // series: a color tuned for a checkmark and a color tuned to survive
    // sitting next to seven others are different jobs.
    static let chartOrange = dynamicColor(
        light: UIColor(red: 0xEB / 255.0, green: 0x68 / 255.0, blue: 0x34 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xD9 / 255.0, green: 0x59 / 255.0, blue: 0x26 / 255.0, alpha: 1.0)
    )
    static let chartAqua = dynamicColor(
        light: UIColor(red: 0x1B / 255.0, green: 0xAF / 255.0, blue: 0x7A / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x19 / 255.0, green: 0x9E / 255.0, blue: 0x70 / 255.0, alpha: 1.0)
    )
    static let chartYellow = dynamicColor(
        light: UIColor(red: 0xED / 255.0, green: 0xA1 / 255.0, blue: 0x00 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xC9 / 255.0, green: 0x85 / 255.0, blue: 0x00 / 255.0, alpha: 1.0)
    )
    static let chartMagenta = dynamicColor(
        light: UIColor(red: 0xE8 / 255.0, green: 0x7B / 255.0, blue: 0xA4 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xD5 / 255.0, green: 0x51 / 255.0, blue: 0x81 / 255.0, alpha: 1.0)
    )
    /// Deliberately not derived from `gymSecondary`. A boosted-chroma variant
    /// of it passed the chroma floor but then failed CVD separation against
    /// this palette's magenta neighbor — this exact hex is the dataviz
    /// method's own pre-validated green, kept as documented rather than
    /// retuned toward Trame's brand green.
    static let chartGreen = dynamicColor(
        light: UIColor(red: 0x00 / 255.0, green: 0x83 / 255.0, blue: 0x00 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x00 / 255.0, green: 0x83 / 255.0, blue: 0x00 / 255.0, alpha: 1.0)
    )
    static let chartViolet = dynamicColor(
        light: UIColor(red: 0x4A / 255.0, green: 0x3A / 255.0, blue: 0xA7 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0x90 / 255.0, green: 0x85 / 255.0, blue: 0xE9 / 255.0, alpha: 1.0)
    )
    static let chartRed = dynamicColor(
        light: UIColor(red: 0xE3 / 255.0, green: 0x49 / 255.0, blue: 0x48 / 255.0, alpha: 1.0),
        dark: UIColor(red: 0xE6 / 255.0, green: 0x67 / 255.0, blue: 0x67 / 255.0, alpha: 1.0)
    )

    static let gymDestructive = trameDestructiveText
    
    static let gymCard = trameSurface
    
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
    
    static let gymRowSurface = trameRow
    
    static let gymCurrentSetSurface = trameCurrent
    
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
    static let gymMutedSurface = trameRow
    static let gymBorder = trameSeparator

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
    static let gymSubduedText = trameSubdued

    // MARK: - Trame Core Concept compatibility

    /// The signature inverse Ink/Paper command. It is never a general text tint
    /// or a status color.
    static let gymAction = trameAction

    static let gymActionInk = trameActionInk

    /// Structural edge for inverse action controls and marks.
    static let gymActionOutline = trameActionOutline

    /// Semantic sport fields. Their accompanying icon or label always carries
    /// the domain name, so hue reinforces meaning without becoming the only cue.
    static let gymStrength = trameStrength
    static let gymMobility = trameMobility
    static let gymConditioning = trameConditioning
    static let gymRecovery = trameRecovery
    static let gymCompetition = trameCompetition

    /// Retained compatibility names. Today is now an open composition on Paper,
    /// so these no longer preserve the superseded cobalt hero field.
    static let gymTodayHero = trameCanvas
    static let gymTodayHeroInk = trameText
    static let gymTodayHeroSecondaryText = trameSubdued
    static let gymTodayHeroDivider = trameSeparator
    static let gymTodayWeekSurface = trameSurface

    /// Formerly a third, lighter text tier; now the same tone as
    /// `gymSubduedText` for the reason documented there.
    ///
    /// Kept as a name rather than removed so 47 call sites do not churn inside
    /// an accessibility change. Prefer `gymSubduedText` in new code, and reach
    /// for a smaller or lighter *font* when something needs to recede further —
    /// not a fainter colour, which this palette has no room for.
    static let gymSubtleText = gymSubduedText
}
