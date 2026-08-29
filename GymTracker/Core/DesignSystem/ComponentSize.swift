import Foundation

enum ComponentSize {
    static let minimumTouchTarget: CGFloat = 44
    /// One key on the set-entry keypad. Sits exactly on the minimum touch
    /// target: four rows of keys are the single largest block on the Active
    /// Workout screen, and every point above 44 is taken from the set list the
    /// lifter is trying to read while typing.
    static let keypadKeyHeight: CGFloat = minimumTouchTarget
    static let iconChip: CGFloat = 36
    /// A sparkline-sized overview chart. It shows a direction without taking
    /// the vertical weight of a detail-screen analysis chart.
    static let overviewChartHeight: CGFloat = 120
    /// A glanceable evidence sparkline beside one answer-sized metric.
    static let progressOverviewSparklineHeight: CGFloat = 88
    /// The primary diagram on a dashboard: tall enough for a readable scale,
    /// but quieter than the 180pt analysis chart on a detail screen.
    static let progressDashboardChartHeight: CGFloat = 156
    static let compactChartHeight: CGFloat = 180
    static let standardChartHeight: CGFloat = 210
    static let nutritionRing: CGFloat = 112
    static let todayActionHeight: CGFloat = 54
    static let todayWeekMark: CGFloat = 28
    static let todayQuickAccessIcon: CGFloat = 40
    /// Extra scroll padding so the last row of a tab-root list can rest above
    /// the tab bar without a fixed canvas strip. Apply via
    /// `contentMargins(.bottom, tabBarClearance, for: .scrollContent)`.
    static let tabBarClearance: CGFloat = 49
}
