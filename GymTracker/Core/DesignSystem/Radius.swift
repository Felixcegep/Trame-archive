import Foundation

/// Trame's compact shape grammar.
///
/// A pill is an explicit semantic choice for filters, tags, and compact
/// segmented values. Buttons and content containers do not become pills by
/// default.
struct Radius {
    // MARK: - Trame semantic roles

    static let icon: CGFloat = 8
    static let field: CGFloat = 10
    static let control: CGFloat = 11
    static let card: CGFloat = 12
    static let hero: CGFloat = 14
    static let floating: CGFloat = 18
    static let pill: CGFloat = 999

    // MARK: - Compatibility roles

    // Keep ambiguous legacy call sites source-compatible until their
    // screen-focused migrations select a precise role. `card` itself is the
    // canonical Trame role and therefore adopts 12 immediately.
    static let small: CGFloat = icon
    static let medium: CGFloat = card
    static let large: CGFloat = 16
    static let section: CGFloat = large
    static let button: CGFloat = pill

    // Staged Today aliases from the first Trame slice.
    static let editorialAction: CGFloat = control
    static let editorialGroup: CGFloat = card
    static let editorialHero: CGFloat = hero
}
