import SwiftData
import SwiftUI

/// The training week at a glance, directly under the workout card.
///
/// Seven marks and one total line — deliberately not a chart. Today is a screen
/// someone opens before a session, not to analyse one, so this states whether
/// the week is on track and hands anything deeper to Progress.
struct HomeWeekSummaryCard: View {
    let isPrimaryCardOfferingStart: Bool
    let onStartWorkout: () -> Void
    
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
                // The figure first.
                //
                // Today reported the week as seven small marks and a sentence,
                // which is a picture of the week rather than an answer about it.
                // The count is the answer, and it costs nothing new: it is
                // already on `TrainingWeekSummary`, from the same query this
                // card was making anyway.
                //
                // Deliberately *not* rendered as "2 of 4". A denominator implies
                // a weekly target, and nothing here knows one — a plan's
                // `supportedDaysPerWeek` is what a plan *can* run at, not what
                // this lifter committed to. Inventing the goal to make the
                // number look like progress would be the screen asserting
                // something it cannot support.
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text("\(weekSummary.workoutCount)")
                        .font(AppFont.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.gymText)

                    Text(CountPhrase.sessionsThisWeek(weekSummary.workoutCount))
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .accessibilityHidden(true)

                HStack(spacing: Spacing.xs) {
                    ForEach(weekSummary.days) { day in
                        dayColumn(day)
                    }
                }

                Divider()
                    .overlay(Color.gymBorder)

                HStack(spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(weekSummary.detailText)
                            .font(weekSummary.hasTraining ? AppFont.subheadlineMediumMonospaced : AppFont.subheadline)
                            .foregroundStyle(weekSummary.hasTraining ? Color.gymText : Color.gymSubduedText)
                        
                        if !weekSummary.hasTraining && !isPrimaryCardOfferingStart {
                            Button(action: onStartWorkout) {
                                Text("Start a session today")
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(Color.gymPrimary)
                            }
                            .accessibilityIdentifier("today-week-start-session")
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(Spacing.l)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.gymCard)
            }
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
                .font(AppFont.captionBold)
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
