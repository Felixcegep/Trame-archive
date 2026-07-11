import SwiftUI

struct AppFont {
    // Large Title / Rounded Display
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
    static let displayMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    
    // Titles
    static let title = Font.title
    static let titleMedium = Font.title2.weight(.bold)
    static let titleSmall = Font.title3.weight(.bold)
    static let titleSmallSemibold = Font.title3.weight(.semibold)
    static let titleSmallSemiboldMonospaced = Font.title3.monospacedDigit().weight(.semibold)
    
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
