import SwiftUI

enum WorkoutPalette {
    static let text = Color(red: 39 / 255, green: 38 / 255, blue: 53 / 255)
    static let background = Color(red: 251 / 255, green: 247 / 255, blue: 239 / 255)
    static let primary = Color(red: 106 / 255, green: 149 / 255, blue: 241 / 255)
    static let secondary = Color(red: 108 / 255, green: 154 / 255, blue: 139 / 255)
    static let accent = Color(red: 161 / 255, green: 104 / 255, blue: 58 / 255)

    static let surface = Color(red: 255 / 255, green: 253 / 255, blue: 249 / 255)
    static let primarySurface = Color(red: 231 / 255, green: 233 / 255, blue: 239 / 255)
    static let currentSetSurface = Color(red: 225 / 255, green: 229 / 255, blue: 239 / 255)
    static let completedSurface = Color(red: 231 / 255, green: 234 / 255, blue: 225 / 255)
    static let accentSurface = Color(red: 242 / 255, green: 233 / 255, blue: 221 / 255)
    static let rowSurface = Color(red: 242 / 255, green: 241 / 255, blue: 239 / 255)
    static let mutedSurface = secondary.opacity(0.12)
    static let border = text.opacity(0.09)
    static let subduedText = text.opacity(0.58)
}
