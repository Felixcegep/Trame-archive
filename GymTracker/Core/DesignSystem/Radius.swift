import Foundation

/// Corner radii, deliberately few.
///
/// This used to carry six values — `8 · 12 · 16 · 18 · 18 · 20` — of which three
/// (`large`, `section`, `card`) described the same object at three
/// indistinguishable sizes, and two shared a number under different names. A
/// scale nobody can perceive is not a scale; it is six chances to be
/// inconsistent. Apple ships 14–18 across the whole of Fitness.
///
/// The names are kept so call sites still read as intent — a card asks for
/// `card`, a chip asks for `small` — while the values collapse to three
/// perceptible steps: inline, container, pill.
struct Radius {
    /// Inline surfaces inside a container: input cells, keypad keys, small chips.
    static let small: CGFloat = 8

    /// The one intermediate step, kept because 54 call sites rely on it and
    /// folding it into `small` or `card` is a visual judgement that wants a
    /// screenshot pass rather than a token edit.
    static let medium: CGFloat = 12

    /// Containers. `large`, `section` and `card` are one value now: a card is a
    /// card, whatever the feature calls it.
    static let large: CGFloat = 16
    static let card: CGFloat = large
    static let section: CGFloat = large

    /// Buttons are pills. At the 44pt minimum touch target the previous 18pt was
    /// already within 4pt of a pill, so this reads as the same shape resolved —
    /// not a new one introduced.
    static let button: CGFloat = 999
}
