import Foundation

struct Spacing {
    nonisolated static let xxs: CGFloat = 2
    nonisolated static let xs: CGFloat = 4
    nonisolated static let s: CGFloat = 8
    nonisolated static let md: CGFloat = 10
    nonisolated static let m: CGFloat = 12
    nonisolated static let l: CGFloat = 16
    nonisolated static let xl: CGFloat = 20
    nonisolated static let xxl: CGFloat = 24
    nonisolated static let xxxl: CGFloat = 32

    /// Standard inset for custom full-width Trame compositions. Native lists,
    /// forms, navigation chrome, and sheets keep their system-provided insets.
    nonisolated static let screenInset: CGFloat = 18
}
