import SwiftUI

enum WorkoutPalette {
    static let text = Color.gymText
    static let background = Color.gymBackground
    static let primary = Color.gymPrimary
    static let secondary = Color.gymSecondary
    static let accent = Color.gymAccent

    static let surface = Color.gymCard
    static let primarySurface = Color.gymPrimarySurface
    static let currentSetSurface = Color.gymCurrentSetSurface
    static let completedSurface = Color.gymSecondarySurface
    static let accentSurface = Color.gymAccentSurface
    static let rowSurface = Color.gymRowSurface
    static let mutedSurface = secondary.opacity(0.12)
    static let border = text.opacity(0.09)
    static let subduedText = text.opacity(0.58)
}
