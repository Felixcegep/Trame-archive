import Foundation

enum ComponentSize {
    static let minimumTouchTarget: CGFloat = 44
    /// One key on the set-entry keypad. Sits exactly on the minimum touch
    /// target: four rows of keys are the single largest block on the Active
    /// Workout screen, and every point above 44 is taken from the set list the
    /// lifter is trying to read while typing.
    static let keypadKeyHeight: CGFloat = minimumTouchTarget
    static let iconChip: CGFloat = 36
    static let compactChartHeight: CGFloat = 180
    static let standardChartHeight: CGFloat = 210
    static let nutritionRing: CGFloat = 112
}
