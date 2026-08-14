import SwiftUI

/// Fixed-order, validated chart colors for `SportDiscipline`.
///
/// Every chart in Progress used to color its series with
/// `.foregroundStyle(by: .value(...))` and nothing else — Swift Charts then
/// assigns hues from its own built-in ramp in whatever order the data happens
/// to arrive. That is an auto-generated palette, not a designed one: two
/// people with different workout histories could see Powerlifting in two
/// different colors, and nothing here was ever checked for whether a
/// colorblind reader could tell two series apart.
///
/// This is the fix: one hue per discipline, in a fixed order that never
/// changes regardless of how many disciplines a given chart happens to plot,
/// checked against the actual six-check color method (fixed hue anchors,
/// lightness band, chroma floor, CVD separation, a normal-vision floor, and
/// contrast) rather than eyeballed. The colors themselves live in
/// `Colors.swift` as `Color.chart*` — this file only owns the assignment.
///
/// Re-validate before changing any assignment or hue:
/// ```
/// node scripts/validate_palette.js "<8 hex, light order>" --mode light --surface "#FFFCF7"
/// node scripts/validate_palette.js "<8 hex, dark order>"  --mode dark  --surface "#1C1C20"
/// ```
/// Both currently report ALL CHECKS PASS. Light mode carries a WARN on three
/// slots (aqua, yellow, magenta sit under 3:1 on cream) — legal only with the
/// "relief" the method requires: those three must always ship with a visible
/// legend and, where there is room, a direct label. Never render one of them
/// as a bare, unlabeled dot or thin line.
enum SportDisciplinePalette {
    /// One slot per real discipline, in `SportDiscipline`'s own declaration
    /// order — `.mixed` deliberately has no slot, because a mixed workout
    /// contributes to the *real* disciplines it touches rather than existing
    /// as a plottable category of its own (see `ProgressSportProjections`).
    ///
    /// `gymPrimary` (Trame's own action blue) is reserved for the Global lens
    /// elsewhere in Progress and deliberately not assigned here — a bar in
    /// the app's own action color would read as "this one is special," not
    /// "this one is Powerlifting."
    private static let assignments: [SportDiscipline: Color] = [
        .generalStrength: .chartOrange,
        .bodybuilding: .chartAqua,
        .powerlifting: .chartYellow,
        .olympicWeightlifting: .chartMagenta,
        .strongman: .chartGreen,
        .hybridFitnessRacing: .chartViolet,
        .generalCardio: .chartRed
    ]

    /// The chart color for one discipline. Falls back to `gymSubduedText` for
    /// `.mixed` or anything unrecognised — a neutral "no single identity"
    /// reading rather than a color that silently drifts if the enum grows
    /// before this table does.
    static func color(for discipline: SportDiscipline?) -> Color {
        guard let discipline, let color = assignments[discipline] else {
            return .gymSubduedText
        }
        return color
    }

    /// The bucket a chart falls back to for a slice with no resolvable
    /// discipline — the exact string call sites already use as their `??`
    /// fallback. Declared here, once, so every chart's domain agrees on it
    /// rather than each call site inventing its own literal.
    static let unknownLabel = String(localized: "Unknown")

    /// `.chartForegroundStyleScale(domain:range:)` wants both arrays walked in
    /// the same fixed order — this is that order, so every chart in the app
    /// builds its scale from one shared source instead of re-deriving it.
    ///
    /// Includes `unknownLabel` as a fixed, always-present entry. Leaving it
    /// out would mean any slice that legitimately falls back to "Unknown"
    /// escapes this scale's domain entirely — and an out-of-domain value is
    /// exactly what sends Swift Charts back to its own auto-generated color,
    /// silently reintroducing the bug this file exists to close.
    static var domain: [String] {
        SportDiscipline.allCases.filter { $0 != .mixed }.map(\.title) + [unknownLabel]
    }
    static var range: [Color] {
        SportDiscipline.allCases.filter { $0 != .mixed }.map { color(for: $0) } + [.gymSubduedText]
    }
}

/// Fixed-order colors for a HYROX-style race split composition (run / station /
/// transition). Only three categories, but every one of them sits beside the
/// other two at once — a stacked composition bar, not a time series — so this
/// uses the palette's **all-pairs-validated** slots (the first three: Trame's
/// own blue, then orange, then aqua) rather than the adjacent-pairs slots the
/// seven-discipline palette relies on. See `palette.md`'s note on why only the
/// first three of the eight hues clear the stricter all-pairs CVD floor.
enum WorkoutSplitPalette {
    /// Matches `HybridRaceSportLensView.composition(_:)`'s own fixed
    /// construction order — run, then station, then transition.
    private static let orderedKinds: [WorkoutSplitKind] = [.run, .station, .transition]

    private static let assignments: [WorkoutSplitKind: Color] = [
        .run: .gymPrimary,
        .station: .chartOrange,
        .transition: .chartAqua
    ]

    static func color(for kind: WorkoutSplitKind) -> Color {
        assignments[kind] ?? .gymSubduedText
    }

    static var domain: [String] { orderedKinds.map(\.title) }
    static var range: [Color] { orderedKinds.map { color(for: $0) } }
}
