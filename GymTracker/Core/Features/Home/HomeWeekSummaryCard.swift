import SwiftData
import SwiftUI

/// The training week at a glance, directly under the workout card.
///
/// Seven marks and one total line — deliberately not a chart. Today is a screen
/// someone opens before a session, not to analyse one, so this states whether
/// the week is on track and hands anything deeper to Progress.
struct HomeWeekSummaryCard: View {
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]

    private var summary: TrainingWeekSummary {
        TrainingWeekSummary.make(recentWorkoutsNewestFirst: workouts)
    }

    var body: some View {
        let weekSummary = summary

        return VStack(alignment: .leading, spacing: Spacing.m) {
            // Pre-localized: `LibrarySectionTitle` takes a `String`, so a bare
            // literal would never reach the string catalog.
            LibrarySectionTitle(String(localized: "This week"))

            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.xs) {
                    ForEach(weekSummary.days) { day in
                        dayColumn(day)
                    }
                }

                Divider()
                    .overlay(Color.gymBorder)

                HStack(spacing: Spacing.s) {
                    Text(weekSummary.detailText)
                        .font(weekSummary.hasTraining ? AppFont.subheadlineMediumMonospaced : AppFont.subheadline)
                        .foregroundStyle(weekSummary.hasTraining ? Color.gymText : Color.gymSubduedText)

                    Spacer(minLength: 0)
                }
            }
            .padding(Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.gymCard)
                    .stroke(Color.gymBorder, lineWidth: 1)
            }
            .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
        }
        // One stop, not fifteen. Read day by day this card is a stutter of
        // single letters; read as a sentence it is the same information.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: weekSummary))
        .accessibilityIdentifier("today-week-summary")
    }

    private func dayColumn(_ day: TrainingWeekSummary.Day) -> some View {
        VStack(spacing: Spacing.s) {
            Text(day.initial)
                .font(AppFont.caption2Bold)
                .foregroundStyle(day.isToday ? Color.gymPrimary : Color.gymSubduedText)

            mark(for: day)
        }
        .frame(maxWidth: .infinity)
    }

    /// A trained day is a filled disc carrying a checkmark, an untrained day a
    /// dot or a ring. The states differ in shape before they differ in colour,
    /// so the row survives greyscale and Increase Contrast.
    @ViewBuilder
    private func mark(for day: TrainingWeekSummary.Day) -> some View {
        if day.isTrained {
            Image(systemName: AppIcon.checkmark)
                .font(AppFont.caption2Bold)
                .foregroundStyle(.white)
                .frame(width: markDiameter, height: markDiameter)
                .background(Color.gymPrimaryDeep, in: Circle())
        } else if day.isToday {
            Circle()
                .stroke(Color.gymPrimary, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                .frame(width: markDiameter, height: markDiameter)
        } else {
            Circle()
                .fill(day.isFuture ? Color.gymBorder.opacity(0.6) : Color.gymBorder)
                .frame(width: emptyMarkDiameter, height: emptyMarkDiameter)
                .frame(width: markDiameter, height: markDiameter)
        }
    }

    private var markDiameter: CGFloat { 26 }
    private var emptyMarkDiameter: CGFloat { 8 }

    private func accessibilityLabel(for summary: TrainingWeekSummary) -> String {
        let trained = summary.days
            .filter(\.isTrained)
            .map { $0.date.formatted(.dateTime.weekday(.wide)) }

        guard !trained.isEmpty else {
            return String(localized: "This week. \(summary.detailText)")
        }
        return String(
            localized: "This week. \(summary.detailText). Trained \(trained.formatted(.list(type: .and)))."
        )
    }
}
