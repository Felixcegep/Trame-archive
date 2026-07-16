import SwiftUI

struct PlanCalendarView: View {
    let run: PlanRun

    private var weeks: [PlanCalendarWeek] {
        PlanCalendarBuilder.weeks(for: run.orderedWorkoutProgress)
    }

    var body: some View {
        List {
            if weeks.isEmpty {
                ContentUnavailableView(
                    "No scheduled workouts",
                    systemImage: AppIcon.plan,
                    description: Text("Start this program to see its schedule.")
                )
            }

            ForEach(weeks) { week in
                Section(weekTitle(week)) {
                    ForEach(week.days) { day in
                        NavigationLink {
                            PlanCalendarDayView(run: run, day: day)
                        } label: {
                            PlanCalendarDayRow(day: day)
                        }
                        .accessibilityIdentifier("plan-calendar-day")
                    }

                    if !week.unscheduledEntries.isEmpty {
                        PlanCalendarUnscheduledRow(entries: week.unscheduledEntries)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Schedule")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("plan-calendar-screen", label: "Program schedule")
        }
    }

    private func weekTitle(_ week: PlanCalendarWeek) -> String {
        let dates = week.days.map(\.date)
        guard let first = dates.first, let last = dates.last else {
            return "Week \(week.weekIndex + 1)"
        }
        let range = first == last
            ? first.formatted(date: .abbreviated, time: .omitted)
            : "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
        return "Week \(week.weekIndex + 1) · \(range)"
    }
}

private struct PlanCalendarDayRow: View {
    let day: PlanCalendarDay

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(spacing: Spacing.xxs) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppFont.caption2Bold)
                    .foregroundStyle(isToday ? Color.white : .secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(AppFont.headlineSemibold)
                    .foregroundStyle(isToday ? Color.white : Color.gymText)
            }
            .frame(width: 44, height: 44)
            .background(isToday ? Color.gymPrimary : Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(day.date.formatted(date: .complete, time: .omitted))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(day.entries.map(\.workoutName).joined(separator: " · "))
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: Spacing.s)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                ForEach(day.entries) { entry in
                    PlanCalendarStateBadge(state: entry.displayState)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }
}

private struct PlanCalendarUnscheduledRow: View {
    let entries: [PlanCalendarEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Unscheduled")
                .font(AppFont.subheadlineSemibold)
            Text(entries.map(\.workoutName).joined(separator: " · "))
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xs)
    }
}

struct PlanCalendarStateBadge: View {
    let state: PlanCalendarDisplayState

    var body: some View {
        Label(state.title, systemImage: icon)
            .font(AppFont.caption2Bold)
            .foregroundStyle(color)
            .accessibilityIdentifier(state.accessibilityIdentifier)
    }

    private var icon: String {
        switch state {
        case .completed: AppIcon.checkmarkCircle
        case .missed: AppIcon.warning
        case .upcoming: AppIcon.circleDashed
        case .available: AppIcon.circleFill
        case .inProgress: AppIcon.workout
        case .skipped: AppIcon.circleDashed
        }
    }

    private var color: Color {
        switch state {
        case .completed: Color.gymSuccess
        case .available, .inProgress: Color.gymPrimary
        case .missed: Color.gymDestructive
        case .upcoming, .skipped: .secondary
        }
    }
}
