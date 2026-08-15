import SwiftUI

/// Trame's editorial type roles.
///
/// Every canonical role is based on a semantic SwiftUI text style so it follows
/// Dynamic Type. Standard SF Pro geometry is intentional: hierarchy comes from
/// scale, weight, and macro/micro contrast rather than rounded display type.
struct AppFont {
    // MARK: - Trame semantic roles

    /// Primary title for a full-screen composition.
    static let screenTitle = Font.system(.largeTitle, design: .default).weight(.bold)

    /// The exercise, movement, or other subject that owns the current stage.
    static let stageTitle = Font.system(.title, design: .default).weight(.bold)

    /// The answer when one performance number owns the composition.
    static let metricHero = Font.system(.largeTitle, design: .default)
        .weight(.black)
        .monospacedDigit()

    /// A prominent supporting performance value.
    static let metricLarge = Font.system(.title, design: .default)
        .weight(.bold)
        .monospacedDigit()

    /// A compact value in a strip, row, or comparison.
    static let metricCompact = Font.system(.title3, design: .default)
        .weight(.semibold)
        .monospacedDigit()

    static let sectionTitle = Font.headline.weight(.bold)
    static let eyebrow = Font.caption.weight(.bold)
    static let body = Font.body
    static let metadata = Font.footnote.weight(.medium)
    static let micro = Font.caption2.weight(.semibold)

    /// Direct performance entry where stable digit alignment supports accuracy.
    static let numericInput = Font.system(.title2, design: .default)
        .weight(.medium)
        .monospacedDigit()

    /// Timing at glance distance. The semantic base keeps accessibility scaling
    /// intact; the screen composition, not a fixed point size, supplies emphasis.
    static let timer = Font.system(.largeTitle, design: .default)
        .weight(.black)
        .monospacedDigit()

    /// The Rest field scales a larger timing answer from the same semantic
    /// large-title category. Keeping the geometry here preserves the type role;
    /// the view supplies only its Dynamic Type-scaled composition size.
    static func timer(scaledPointSize: CGFloat) -> Font {
        Font.system(size: scaledPointSize, weight: .black, design: .default)
            .monospacedDigit()
    }

    // MARK: - Compatibility roles

    // Existing consumers remain source-compatible while feature-focused PRs
    // migrate them to the more precise semantic names above.
    static let displayLarge = metricHero
    static let displayMedium = metricLarge
    /// Legacy fixed display size retained for Mobility's hold ring. Rest uses
    /// the scaled semantic timer role above.
    static let restCountdown = Font.system(size: 72, weight: .black, design: .default)
        .monospacedDigit()

    // Titles
    static let title = Font.title
    static let titleMedium = Font.title2.weight(.bold)
    static let titleSmall = Font.title3.weight(.bold)
    static let titleSmallSemibold = Font.title3.weight(.semibold)
    static let titleSmallSemiboldMonospaced = Font.title3.monospacedDigit().weight(.semibold)
    static let titleMediumMonospaced = Font.title2.monospacedDigit()

    // Headings
    static let headline = Font.headline
    static let headlineSemibold = Font.headline.weight(.semibold)
    static let headlineMonospaced = Font.headline.monospacedDigit()

    // Body text
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
