import SwiftUI

/// The seven-day selector Today already uses, made tappable.
///
/// The plan builder previously spent seven `Toggle` rows — each with a nested
/// workout picker underneath — on what is fundamentally a seven-way multiple
/// choice. As a strip it fits one line, and the shape of the training week is
/// legible without scrolling.
struct WeekdayStrip: View {
    /// Day offsets, Monday = 0, matching `PlanCoordinator.DayAssignment`.
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(WeekdayStrip.days, id: \.offset) { day in
                let isSelected = selection.contains(day.offset)
                Button {
                    toggle(day.offset)
                } label: {
                    Text(day.initial)
                        .font(AppFont.subheadlineBold)
                        .foregroundStyle(isSelected ? .white : Color.gymSubduedText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            isSelected ? Color.gymPrimary : Color.gymRowSurface,
                            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan-day-\(day.offset)")
                .accessibilityLabel(day.name)
                // Selection is conveyed by trait as well as fill, so it never
                // depends on colour alone.
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func toggle(_ offset: Int) {
        if selection.contains(offset) {
            selection.remove(offset)
        } else {
            selection.insert(offset)
        }
    }

    static let days: [(name: String, initial: String, offset: Int)] = [
        (String(localized: "Monday"), String(localized: "M", comment: "Single-letter Monday"), 0),
        (String(localized: "Tuesday"), String(localized: "T", comment: "Single-letter Tuesday"), 1),
        (String(localized: "Wednesday"), String(localized: "W", comment: "Single-letter Wednesday"), 2),
        (String(localized: "Thursday"), String(localized: "T", comment: "Single-letter Thursday"), 3),
        (String(localized: "Friday"), String(localized: "F", comment: "Single-letter Friday"), 4),
        (String(localized: "Saturday"), String(localized: "S", comment: "Single-letter Saturday"), 5),
        (String(localized: "Sunday"), String(localized: "S", comment: "Single-letter Sunday"), 6)
    ]

    static func name(for offset: Int) -> String {
        days.first { $0.offset == offset }?.name ?? ""
    }

    static func shortName(for offset: Int) -> String {
        String(name(for: offset).prefix(3))
    }
}
