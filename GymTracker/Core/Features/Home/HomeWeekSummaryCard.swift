import SwiftData
import SwiftUI

/// The training week at a glance, directly under the workout card.
///
/// Seven marks and one total line — deliberately not a chart. Today is a screen
/// someone opens before a session, not to analyse one, so this states whether
/// the week is on track and hands anything deeper to Progress / Calendar.
struct HomeWeekSummaryCard: View {
    let isPrimaryCardOfferingStart: Bool
    /// Whether Today is playing its first-run assembly. The strip fills left to
    /// right as part of that sequence and is static otherwise.
    var isPlayingAssembly: Bool = false
    let onStartWorkout: () -> Void
    let onOpenCalendar: () -> Void

    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]

    init(
        isPrimaryCardOfferingStart: Bool,
        isPlayingAssembly: Bool = false,
        onStartWorkout: @escaping () -> Void,
        onOpenCalendar: @escaping () -> Void = {}
    ) {
        self.isPrimaryCardOfferingStart = isPrimaryCardOfferingStart
        self.isPlayingAssembly = isPlayingAssembly
        self.onStartWorkout = onStartWorkout
        self.onOpenCalendar = onOpenCalendar

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
    private var scheduledDays: [TrainingWeekSummary.ScheduledDay] {
        var days: [TrainingWeekSummary.ScheduledDay] = []
        for run in planRuns where run.status == .active {
            if run.plan?.scheduleMode.usesFlexibleWeekWindow == true {
                guard let next = PlanCoordinator.nextProgress(in: run),
                      next.status == .available || next.status == .upcoming
                else { continue }
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: .now)
                guard PlanWeekWindow.contains(
                    today,
                    weekIndex: next.weekIndex,
                    runStart: run.startDate,
                    calendar: calendar
                ) else { continue }
                days.append(
                    TrainingWeekSummary.ScheduledDay(
                        date: today,
                        title: next.plannedWorkoutName
                    )
                )
                continue
            }
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
            HomeWeekHeader(
                sessionCount: weekSummary.workoutCount,
                onOpenCalendar: onOpenCalendar
            )

            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(weekSummary.days.enumerated()), id: \.element.id) { position, day in
                        dayColumn(day)
                            .gymStripFill(position: position, isActive: isPlayingAssembly)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: weekSummary))

                if let next = weekSummary.nextScheduled,
                   !Calendar.current.isDateInToday(next.date) {
                    nextSessionRow(next)
                        .accessibilityHidden(true)
                }

                if !weekSummary.hasTraining && !isPrimaryCardOfferingStart {
                    Divider().overlay(Color.trameSeparator)

                    Button(action: onStartWorkout) {
                        Text("Start a session today")
                            .font(AppFont.captionBold)
                            .foregroundStyle(Color.trameStrength)
                            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("today-week-start-session")
                }
            }
            .padding(.top, Spacing.xs)
        }
        .accessibilityIdentifier("today-week-summary")
    }

    private func nextSessionRow(_ next: TrainingWeekSummary.ScheduledDay) -> some View {
        HStack(spacing: Spacing.s) {
            Rectangle()
                .fill(Color.trameStrength)
                .frame(width: Spacing.xs, height: Spacing.xl)
                .accessibilityHidden(true)

            Text(nextScheduledText(next))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)

            Spacer()
        }
        .padding(.top, Spacing.xxs)
    }

    private func dayColumn(_ day: TrainingWeekSummary.Day) -> some View {
        VStack(spacing: Spacing.s) {
            Text(day.initial)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.trameSubdued)

            mark(for: day)
                .gymSettleBeat(index: day.isToday ? 7 : 0, isActive: isPlayingAssembly && day.isToday)

            Text(day.date.formatted(.dateTime.day()))
                .font(AppFont.caption2)
                .monospacedDigit()
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func mark(for day: TrainingWeekSummary.Day) -> some View {
        if day.isTrained {
            Image(systemName: AppIcon.checkmark)
                .font(AppFont.caption2Bold)
                .foregroundStyle(Color.trameActionInk)
                .frame(width: markDiameter, height: markDiameter)
                .background(Color.trameCompleted, in: Circle())
        } else if day.isToday {
            Circle()
                .stroke(Color.trameStrength, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                .frame(width: markDiameter, height: markDiameter)
        } else if day.isScheduled {
            Circle()
                .stroke(Color.trameSubdued, lineWidth: 2)
                .frame(width: markDiameter, height: markDiameter)
        } else {
            Circle()
                .fill(day.isFuture ? Color.trameSeparator.opacity(0.6) : Color.trameSeparator)
                .frame(width: emptyMarkDiameter, height: emptyMarkDiameter)
                .frame(width: markDiameter, height: markDiameter)
        }
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
            day = next.date.formatted(.dateTime.weekday(.wide))
        } else {
            day = next.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return String(localized: "Next · \(day) · \(next.title)")
    }

    private var markDiameter: CGFloat { ComponentSize.todayWeekMark }
    private var emptyMarkDiameter: CGFloat { Spacing.s }

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

/// Interactive week section header serving as the entry point to Training Calendar.
struct HomeWeekHeader: View {
    let sessionCount: Int
    let onOpenCalendar: () -> Void

    var body: some View {
        Button(action: onOpenCalendar) {
            HStack(spacing: Spacing.m) {
                Text("WEEK")
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)

                Rectangle()
                    .fill(Color.trameStrength)
                    .frame(width: 20, height: 2)
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")")
                    .font(AppFont.metadata)
                    .monospacedDigit()
                    .foregroundStyle(Color.trameSubdued)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("open-training-calendar")
        .accessibilityLabel(Text("Week, \(sessionCount) \(sessionCount == 1 ? "session" : "sessions"). Open training calendar."))
    }
}
