import SwiftData
import SwiftUI

struct PlanCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    let run: PlanRun

    @State private var selectedEntry: PlanCalendarEntry?

    private var weeks: [PlanCalendarWeek] {
        PlanCalendarBuilder.weeks(for: run)
    }

    var body: some View {
        ScrollView {
            if weeks.isEmpty {
                ContentUnavailableView(
                    "No scheduled workouts",
                    systemImage: AppIcon.plan,
                    description: Text("Start this plan to see its schedule.")
                )
            }

            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ForEach(weeks) { week in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        TrameDomainSectionRule(title: LocalizedStringKey(weekTitle(week)), color: Color.trameStrength)
                        weekGrid(week)

                        if !week.unscheduledEntries.isEmpty {
                            ForEach(week.unscheduledEntries) { entry in
                                PlanCalendarUnscheduledRow(entry: entry) {
                                    selectedEntry = entry
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.m)
        }
        .scrollIndicators(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle("Schedule")
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("plan-calendar-screen", label: "Plan schedule")
        }
        .sheet(item: $selectedEntry) { entry in
            ScheduleUnscheduledWorkoutSheet(entry: entry) { date in
                guard let progress = progress(for: entry) else { return false }
                return PlanCoordinator.reschedule(progress, to: date, in: run, using: modelContext)
            }
        }
    }

    private func weekGrid(_ week: PlanCalendarWeek) -> some View {
        LazyVGrid(columns: weekColumns, spacing: Spacing.xs) {
            ForEach(week.days) { day in
                NavigationLink {
                    PlanCalendarDayView(run: run, day: day)
                } label: {
                    PlanCalendarDayGridCell(day: day)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan-calendar-day")
            }
        }
    }

    private var weekColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)
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

    private func progress(for entry: PlanCalendarEntry) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.id == entry.id }
    }
}

private struct PlanCalendarDayGridCell: View {
    let day: PlanCalendarDay

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
            Text(day.date.formatted(.dateTime.day()))
                .font(AppFont.metricCompact)
                .foregroundStyle(Color.trameText)
            HStack(spacing: Spacing.xxs) {
                ForEach(day.entries.prefix(3)) { entry in
                    Circle()
                        .fill(stateColor(entry.displayState))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Calendar.current.isDateInToday(day.date) ? Color.trameStrength : Color.trameSeparator)
                .frame(height: Calendar.current.isDateInToday(day.date) ? 2 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dayAccessibilityLabel)
    }

    private var dayAccessibilityLabel: String {
        let entries = day.entries.map {
            "\($0.workoutName), \($0.displayState.title)"
        }.joined(separator: ", ")
        return "\(day.date.formatted(date: .complete, time: .omitted)), \(entries)"
    }

    private func stateColor(_ state: PlanCalendarDisplayState) -> Color {
        switch state {
        case .completed: return .trameCompleted
        case .available, .inProgress: return .trameStrength
        case .missed: return .trameAttention
        case .upcoming, .skipped: return .trameSeparator
        }
    }
}

private struct PlanCalendarDayRow: View {
    let day: PlanCalendarDay

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(spacing: Spacing.xxs) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppFont.micro)
                    .foregroundStyle(isToday ? Color.trameActionDeep : Color.trameSubdued)
                Text(day.date.formatted(.dateTime.day()))
                    .font(AppFont.metricCompact)
                    .foregroundStyle(Color.trameText)
            }
            .frame(minWidth: 44, minHeight: 44)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isToday ? Color.trameAction : Color.trameSeparator)
                    .frame(width: 3)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(day.date.formatted(date: .complete, time: .omitted))
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                Text(day.entries.map(\.workoutName).joined(separator: " · "))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
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
    let entry: PlanCalendarEntry
    let onSchedule: () -> Void

    var body: some View {
        Button(action: onSchedule) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(entry.workoutName)
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.trameText)
                    Text("Unscheduled · Tap to choose a date")
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                }
                Spacer()
                Image(systemName: AppIcon.reschedule)
                    .foregroundStyle(Color.trameActionDeep)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
        .padding(.vertical, Spacing.xs)
    }
}

private struct ScheduleUnscheduledWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: PlanCalendarEntry
    let onSave: (Date) -> Bool
    @State private var date = Date.now
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Scheduled date", selection: $date, displayedComponents: .date)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.trameDestructiveText)
                }
            }
            .navigationTitle("Schedule Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        if onSave(date) { dismiss() }
                        else { errorMessage = "The schedule could not be saved. Try again." }
                    }
                }
            }
        }
    }
}

struct PlanCalendarStateBadge: View {
    let state: PlanCalendarDisplayState

    var body: some View {
        Label(state.title, systemImage: state.icon)
            .font(AppFont.micro)
            .foregroundStyle(stateColor)
            .accessibilityIdentifier(state.accessibilityIdentifier)
    }

    private var stateColor: Color {
        switch state {
        case .completed: return Color.trameCompleted
        case .available: return Color.trameStrength
        case .inProgress: return Color.trameActionDeep
        case .missed: return Color.trameAttention
        case .upcoming, .skipped: return Color.trameSubdued
        }
    }
}
