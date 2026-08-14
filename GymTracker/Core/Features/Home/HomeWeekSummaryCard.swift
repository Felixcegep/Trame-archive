import SwiftData
import SwiftUI

/// The training week at a glance, directly under the workout card.
///
/// Seven marks and one total line — deliberately not a chart. Today is a screen
/// someone opens before a session, not to analyse one, so this states whether
/// the week is on track and hands anything deeper to Progress.
struct HomeWeekSummaryCard: View {
    let isPrimaryCardOfferingStart: Bool
    /// Whether Today is playing its first-run assembly. The strip fills left to
    /// right as part of that sequence and is static otherwise.
    var isPlayingAssembly: Bool = false
    let onStartWorkout: () -> Void
    
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]

    init(
        isPrimaryCardOfferingStart: Bool,
        isPlayingAssembly: Bool = false,
        onStartWorkout: @escaping () -> Void
    ) {
        self.isPrimaryCardOfferingStart = isPrimaryCardOfferingStart
        self.isPlayingAssembly = isPlayingAssembly
        self.onStartWorkout = onStartWorkout

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        _workouts = Query(
            filter: #Predicate<Workout> {
                $0.endTime != nil && $0.startTime >= weekStart
            },
            sort: [SortDescriptor(\Workout.startTime, order: .reverse)]
        )
    }

    private var summary: TrainingWeekSummary {
        TrainingWeekSummary.make(
            recentWorkoutsNewestFirst: workouts,
            scheduled: scheduledDays
        )
    }

    /// Sessions an active plan still expects.
    ///
    /// Only `upcoming` and `available` occurrences: a completed one is already
    /// counted by the workout it produced, and a skipped one is a decision the
    /// lifter made — re-advertising it as expected would argue with them.
    /// Written as a loop rather than a chain: the equivalent
    /// `filter/flatMap/compactMap` over SwiftData models pushed the expression
    /// past the type-checker's budget.
    private var scheduledDays: [TrainingWeekSummary.ScheduledDay] {
        var days: [TrainingWeekSummary.ScheduledDay] = []
        for run in planRuns where run.status == .active {
            for progress in run.workoutProgress {
                guard progress.status == .upcoming || progress.status == .available,
                      let date = progress.scheduledDate
                else { continue }
                days.append(
                    TrainingWeekSummary.ScheduledDay(
                        date: date,
                        title: progress.plannedWorkoutName
                    )
                )
            }
        }
        return days
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
                    ForEach(Array(weekSummary.days.enumerated()), id: \.element.id) { position, day in
                        dayColumn(day)
                            .gymStripFill(position: position, isActive: isPlayingAssembly)
                    }
                }

                Divider()
                    .overlay(Color.gymBorder)

                HStack(spacing: Spacing.s) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(weekSummary.detailText)
                            .font(weekSummary.hasTraining ? AppFont.subheadlineMediumMonospaced : AppFont.subheadline)
                            .foregroundStyle(weekSummary.hasTraining ? Color.gymText : Color.gymSubduedText)

                        // What the strip cannot say. A ring on Thursday tells
                        // the lifter *that* something is expected; only a line
                        // of text can tell them what it is, and "what am I
                        // doing Thursday" was the question that previously
                        // required opening the calendar.
                        if let next = weekSummary.nextScheduled {
                            nextScheduledLine(next)
                        }

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
                // Today's mark gets the one settle beat, after the sweep has
                // reached it. It is the mark that means something on an empty
                // week — the other six are places a session could go.
                .gymSettleBeat(index: day.isToday ? 7 : 0, isActive: isPlayingAssembly && day.isToday)
        }
        .frame(maxWidth: .infinity)
    }

    /// Four marks, four silhouettes.
    ///
    /// Shape carries the state before colour does, so the strip survives
    /// greyscale, Increase Contrast, and every form of colour blindness:
    ///
    /// - trained — filled disc with a checkmark
    /// - today, untrained — dashed ring
    /// - scheduled — solid ring, hollow: something is expected but has not
    ///   happened, which is exactly "an outline of the filled state"
    /// - nothing — a small dot
    ///
    /// Order matters. Trained wins over scheduled, because a completed session
    /// is not still expected; today wins over scheduled, because "now" is the
    /// more urgent fact and the card above already names today's session.
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
        } else if day.isScheduled {
            Circle()
                .stroke(Color.gymPrimary.opacity(0.55), lineWidth: 2)
                .frame(width: markDiameter, height: markDiameter)
        } else {
            Circle()
                .fill(day.isFuture ? Color.gymBorder.opacity(0.6) : Color.gymBorder)
                .frame(width: emptyMarkDiameter, height: emptyMarkDiameter)
                .frame(width: markDiameter, height: markDiameter)
        }
    }

    /// "Next · Thursday · Lower Body", or "Next · Today · …" when the expected
    /// session is the one the card above is already offering.
    private func nextScheduledLine(_ next: TrainingWeekSummary.ScheduledDay) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: AppIcon.plan)
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)

            Text(nextScheduledText(next))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-week-next-scheduled")
    }

    private func nextScheduledText(_ next: TrainingWeekSummary.ScheduledDay) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(next.date) {
            day = String(localized: "Today")
        } else if calendar.isDateInTomorrow(next.date) {
            day = String(localized: "Tomorrow")
        } else if let week = calendar.dateInterval(of: .weekOfYear, for: .now),
                  week.contains(next.date) {
            // Inside this week the weekday alone is unambiguous; beyond it,
            // "Monday" could be any Monday, so the date is spelled out.
            day = next.date.formatted(.dateTime.weekday(.wide))
        } else {
            day = next.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return String(localized: "Next · \(day) · \(next.title)")
    }

    private var markDiameter: CGFloat { 26 }
    private var emptyMarkDiameter: CGFloat { 8 }

    /// One sentence, not fifteen marks.
    ///
    /// The scheduled days are spoken as their own clause rather than folded in
    /// with the trained ones: the strip now carries two different kinds of fact,
    /// and a reader who cannot see the difference in silhouette needs to hear
    /// the difference in wording.
    private func accessibilityLabel(for summary: TrainingWeekSummary) -> String {
        var sentences = [String(localized: "This week. \(summary.detailText).")]

        let trained = summary.days
            .filter(\.isTrained)
            .map { $0.date.formatted(.dateTime.weekday(.wide)) }
        if !trained.isEmpty {
            sentences.append(
                String(localized: "Trained \(trained.formatted(.list(type: .and))).")
            )
        }

        let scheduled = summary.days
            .filter(\.isScheduled)
            .map { $0.date.formatted(.dateTime.weekday(.wide)) }
        if !scheduled.isEmpty {
            sentences.append(
                String(localized: "Scheduled \(scheduled.formatted(.list(type: .and))).")
            )
        }

        if let next = summary.nextScheduled {
            sentences.append(nextScheduledText(next) + ".")
        }

        return sentences.joined(separator: " ")
    }
}
