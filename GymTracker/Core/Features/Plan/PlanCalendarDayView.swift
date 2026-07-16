import SwiftData
import SwiftUI

struct PlanCalendarDayView: View {
    @Environment(\.modelContext) private var modelContext

    let run: PlanRun
    let day: PlanCalendarDay

    @State private var reschedulingEntry: PlanCalendarEntry?
    @State private var rescheduleDate = Date.now

    private var entries: [PlanCalendarEntry] {
        let progressIDs = Set(day.entries.map(\.id))
        return PlanCalendarBuilder.weeks(for: run.orderedWorkoutProgress)
            .flatMap { $0.days }
            .first(where: { $0.date == day.date })?
            .entries
            .filter { progressIDs.contains($0.id) } ?? []
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No workouts on this day",
                    systemImage: AppIcon.plan,
                    description: Text("Rescheduled workouts appear on their new date.")
                )
            }

            ForEach(entries) { entry in
                Section {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                            Text(entry.workoutName)
                                .font(AppFont.headlineSemibold)
                                .foregroundStyle(Color.gymText)
                            Spacer()
                            PlanCalendarStateBadge(state: entry.displayState)
                        }

                        Text(exerciseCountText(for: entry))
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)

                        if let progress = progress(for: entry),
                           entry.isReschedulable,
                           PlanCoordinator.canEditSchedule(progress, in: run) {
                            HStack(spacing: Spacing.s) {
                                Button {
                                    rescheduleDate = entry.scheduledDate ?? .now
                                    reschedulingEntry = entry
                                } label: {
                                    Label("Reschedule", systemImage: AppIcon.reschedule)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("calendar-reschedule-\(entry.id)")

                                if entry.displayState == .available {
                                    Button("Skip", role: .destructive) {
                                        _ = PlanCoordinator.skip(progress, in: run, using: modelContext)
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("calendar-skip-\(entry.id)")
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(day.date.formatted(date: .abbreviated, time: .omitted))
        .overlay(alignment: .topLeading) {
            screenshotStateMarker("plan-calendar-day-screen", label: "Scheduled day")
        }
        .sheet(item: $reschedulingEntry) { entry in
            RescheduleCalendarWorkoutSheet(
                entry: entry,
                date: $rescheduleDate,
                onSave: { date in
                    guard let progress = progress(for: entry) else { return }
                    _ = PlanCoordinator.reschedule(progress, to: date, in: run, using: modelContext)
                }
            )
        }
    }

    private func progress(for entry: PlanCalendarEntry) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.id == entry.id }
    }

    private func exerciseCountText(for entry: PlanCalendarEntry) -> String {
        let count = progress(for: entry)
            .flatMap { PlanCoordinator.plannedWorkout(for: $0, in: run) }?
            .orderedPlannedExercises
            .count ?? 0
        return "\(count) \(count == 1 ? "exercise" : "exercises")"
    }
}

private struct RescheduleCalendarWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entry: PlanCalendarEntry
    @Binding var date: Date
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Scheduled date", selection: $date, displayedComponents: .date)
                } header: {
                    Text(entry.workoutName)
                }

                Section {
                    Button("Save new date") {
                        onSave(date)
                        dismiss()
                    }
                    .accessibilityIdentifier("calendar-confirm-reschedule")

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reschedule")
        }
    }
}
