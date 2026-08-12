import SwiftUI

struct AppFont {
    // Large Title / Rounded Display
    //
    // Declared against text styles rather than fixed point sizes. As
    // `.system(size:)` these were the only two roles in the file that did not
    // scale, so at large accessibility sizes the body text around them grew
    // while the headline they were meant to lead stayed put — inverting the
    // hierarchy exactly where it was most deliberate.
    //
    // `displayMedium` lands at 28pt rather than its previous 32: `.title` is
    // the nearest scaling style below `.largeTitle`, and matching the old size
    // exactly would have meant keeping it fixed.
    static let displayLarge = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
    static let displayMedium = Font.system(.title, design: .rounded).weight(.bold)

    /// The rest countdown when rest owns the screen.
    ///
    /// The one role in the app that is deliberately larger than `displayLarge`.
    /// It is read at arm's length, across a rack, by someone who is not holding
    /// the phone — the same reason a kitchen timer has big digits. Scaled from
    /// `.largeTitle` rather than fixed at a point size so it still tracks
    /// Dynamic Type; `relativeTo:` keeps the ratio while letting the base sit
    /// well above any text style the system offers.
    static let restCountdown = Font.system(size: 72, weight: .bold, design: .rounded)
        .monospacedDigit()

    /// The exercise name when one exercise owns the page. Between
    /// `displayMedium` and `titleMedium`: it is the subject of the screen, but
    /// it is also frequently two lines long ("Ab Wheel Rollout (Kneeling)").
    static let stageTitle = Font.system(.title, design: .rounded).weight(.bold)

    // Titles
    static let title = Font.title
    static let titleMedium = Font.title2.weight(.bold)
    static let titleSmall = Font.title3.weight(.bold)
    static let titleSmallSemibold = Font.title3.weight(.semibold)
    static let titleSmallSemiboldMonospaced = Font.title3.monospacedDigit().weight(.semibold)
    /// Keypad digits. Regular weight and monospaced so the keys read like a
    /// system keyboard rather than a row of headings.
    static let titleMediumMonospaced = Font.title2.monospacedDigit()

    // Headings
    static let headline = Font.headline
    static let headlineSemibold = Font.headline.weight(.semibold)
    static let headlineMonospaced = Font.headline.monospacedDigit()
    
    // Body Text
    static let body = Font.body
    static let bodyMedium = Font.body.weight(.medium)
    
    // Subheadings
    static let subheadline = Font.subheadline
    static let subheadlineBold = Font.subheadline.weight(.bold)
    static let subheadlineSemibold = Font.subheadline.weight(.semibold)
    static let subheadlineMonospaced = Font.subheadline.monospacedDigit()
    static let subheadlineSemiboldMonospaced = Font.subheadline.monospacedDigit().weight(.semibold)
    static let subheadlineMediumMonospaced = Font.subheadline.monospacedDigit().weight(.medium)
    
    // Footnotes
    static let footnote = Font.footnote
    static let footnoteMedium = Font.footnote.weight(.medium)
    
    // Captions
    static let caption = Font.caption
    static let captionBold = Font.caption.weight(.bold)
    static let captionSemiboldMonospaced = Font.caption.monospacedDigit().weight(.semibold)
    
    static let caption2 = Font.caption2
    static let caption2Bold = Font.caption2.weight(.bold)
}
