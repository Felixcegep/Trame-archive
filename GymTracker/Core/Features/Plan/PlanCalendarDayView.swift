import SwiftData
import SwiftUI

struct PlanCalendarDayView: View {
    @Environment(\.modelContext) private var modelContext

    let run: PlanRun
    let day: PlanCalendarDay

    @State private var reschedulingEntry: PlanCalendarEntry?
    @State private var rescheduleDate = Date.now
    @State private var entryToSkip: PlanCalendarEntry?
    @State private var errorMessage: String?

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

                                Menu {
                                    Button("Unschedule", systemImage: "calendar.badge.minus") {
                                        guard PlanCoordinator.unschedule(progress, in: run, using: modelContext) else {
                                            errorMessage = "The workout could not be unscheduled. Try again."
                                            return
                                        }
                                    }

                                    if entry.displayState == .available {
                                        Button("Skip", systemImage: "forward.end", role: .destructive) {
                                            entryToSkip = entry
                                        }
                                    }
                                } label: {
                                    Label("More", systemImage: "ellipsis.circle")
                                }
                                    .buttonStyle(.bordered)
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
                onSave: { date, shiftRemaining in
                    guard let progress = progress(for: entry) else { return false }
                    if shiftRemaining {
                        return PlanCoordinator.rescheduleRemaining(
                            from: progress,
                            to: date,
                            in: run,
                            using: modelContext
                        )
                    }
                    return PlanCoordinator.reschedule(progress, to: date, in: run, using: modelContext)
                }
            )
        }
        .confirmationDialog(
            "Skip this workout?",
            isPresented: Binding(
                get: { entryToSkip != nil },
                set: { if !$0 { entryToSkip = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Skip Workout", role: .destructive) {
                guard let entry = entryToSkip else { return }
                guard let progress = progress(for: entry),
                      PlanCoordinator.skip(progress, in: run, using: modelContext)
                else {
                    errorMessage = "The workout could not be skipped. Try again."
                    return
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The workout will remain visible in the program schedule as skipped.")
        }
        .alert("Schedule Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The schedule could not be updated.")
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
    let onSave: (Date, Bool) -> Bool
    @State private var shiftRemaining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Scheduled date", selection: $date, displayedComponents: .date)
                    Toggle("Shift remaining workouts", isOn: $shiftRemaining)
                } header: {
                    Text(entry.workoutName)
                }

                Section {
                    Button("Save new date") {
                        if onSave(date, shiftRemaining) {
                            dismiss()
                        } else {
                            errorMessage = "The schedule could not be saved. Try again."
                        }
                    }
                    .accessibilityIdentifier("calendar-confirm-reschedule")

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.gymDestructive)
                    }
                }
            }
            .navigationTitle("Reschedule")
        }
    }
}
