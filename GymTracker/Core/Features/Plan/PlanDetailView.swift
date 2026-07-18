import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void

    @State private var isShowingStartDate = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingEditor = false
    @State private var startDate = Date.now
    @State private var reschedulingProgress: PlanWorkoutProgress?
    @State private var rescheduleDate = Date.now

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("\(plan.durationWeeks) weeks · \(plan.daysPerWeek) days per week")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                    if pausedRun != nil {
                        Text("Program paused")
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(.secondary)
                    } else if let run = activeRun, let progress = nextProgress(in: run) {
                        Text(progress.scheduledDate.map { "Next: \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Next workout ready")
                            .font(AppFont.subheadlineSemibold)
                    } else {
                        Text("Your schedule repeats each week.")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Prescription") {
                NavigationLink {
                    PlanPrescriptionPreviewView(plan: plan)
                } label: {
                    Label("Preview prescriptions", systemImage: AppIcon.chart)
                }
                .accessibilityIdentifier("view-program-prescription-preview")
            }

            if let notes = plan.notes, !notes.isEmpty {
                Section("Safety & progression") {
                    Text(notes)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let run = activeRun, let progress = nextProgress(in: run) {
                Section("Current program") {
                    NavigationLink {
                        PlanCalendarView(run: run)
                    } label: {
                        Label("View Schedule", systemImage: AppIcon.plan)
                    }
                    .accessibilityIdentifier("view-plan-schedule")

                    Button {
                        onStartPlannedWorkout(run, progress)
                    } label: {
                        Label(
                            progress.status == .inProgress
                                ? "Resume Active Workout"
                                : "Start \(progress.plannedWorkoutName)",
                            systemImage: progress.status == .inProgress ? AppIcon.workout : AppIcon.play
                        )
                    }
                    .accessibilityIdentifier("start-planned-workout")

                    Button("Pause Program") {
                        PlanCoordinator.pause(run, using: modelContext)
                    }

                    Button("Archive Program Run", role: .destructive) {
                        isShowingArchiveConfirmation = true
                    }
                }
            } else if let run = pausedRun {
                Section("Program paused") {
                    NavigationLink {
                        PlanCalendarView(run: run)
                    } label: {
                        Label("View Schedule", systemImage: AppIcon.plan)
                    }
                    .accessibilityIdentifier("view-plan-schedule")

                    Button("Resume Program") {
                        PlanCoordinator.resume(run, using: modelContext)
                    }
                    .accessibilityIdentifier("resume-plan")

                    Button("Archive Program Run", role: .destructive) {
                        isShowingArchiveConfirmation = true
                    }
                }
            } else if !plan.isArchived {
                Section {
                    Button {
                        startDate = .now
                        isShowingStartDate = true
                    } label: {
                        Label(completedRun == nil ? "Start Program" : "Restart Program", systemImage: AppIcon.play)
                    }
                    .accessibilityIdentifier(completedRun == nil ? "start-plan" : "restart-plan")
                    .disabled(plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts).isEmpty)
                }
            }

            ForEach(plan.orderedWeeks) { week in
                Section("Week \(week.weekIndex + 1)") {
                    ForEach(week.orderedPlannedWorkouts) { workout in
                        let progress = progress(for: workout)
                        planWorkoutRow(workout, progress: progress)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let progress,
                               let run = currentRun,
                               canReschedule(progress, in: run) {
                                Button {
                                    beginReschedule(progress)
                                } label: {
                                    Label("Reschedule", systemImage: AppIcon.reschedule)
                                }
                                .tint(Color.gymAccent)
                                .accessibilityIdentifier("reschedule-planned-workout-\(workout.id)")
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(plan.name)
        .toolbar {
            if !plan.isArchived {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        isShowingEditor = true
                    }
                    .accessibilityIdentifier("edit-plan")
                }
            }
        }
        .sheet(isPresented: $isShowingStartDate) {
            NavigationStack {
                Form {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                }
                .navigationTitle("Start Program")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingStartDate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start") {
                            let started: PlanRun?
                            if let completedRun,
                               case .offerRestart(let carryState) = plan.programCompletionPolicy {
                                started = ProgramRunLifecycleService.restartRun(
                                    for: plan,
                                    from: completedRun,
                                    startDate: startDate,
                                    carryState: carryState,
                                    using: modelContext
                                )
                            } else {
                                started = PlanCoordinator.startRun(for: plan, startDate: startDate, using: modelContext)
                            }
                            guard started != nil else { return }
                            isShowingStartDate = false
                        }
                        .accessibilityIdentifier(completedRun == nil ? "confirm-start-plan" : "confirm-restart-plan")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                PlanEditorView(plan: plan)
            }
        }
        .sheet(item: $reschedulingProgress) { progress in
            NavigationStack {
                Form {
                    DatePicker("Scheduled date", selection: $rescheduleDate, displayedComponents: .date)
                }
                .navigationTitle("Reschedule")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { reschedulingProgress = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let run = currentRun else { return }
                            _ = PlanCoordinator.reschedule(
                                progress,
                                to: rescheduleDate,
                                in: run,
                                using: modelContext
                            )
                            reschedulingProgress = nil
                        }
                        .accessibilityIdentifier("confirm-reschedule")
                    }
                }
            }
        }
        .confirmationDialog(
            "Archive this program run?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Program Run", role: .destructive) {
                guard let run = currentRun else { return }
                PlanCoordinator.archive(run, using: modelContext)
            }
        } message: {
            Text("Your completed workouts remain in History. You can start this program again later.")
        }
    }

    private var activeRun: PlanRun? {
        plan.runs.first { $0.status == .active }
    }

    private var pausedRun: PlanRun? {
        plan.runs.first { $0.status == .paused }
    }

    private var currentRun: PlanRun? {
        activeRun ?? pausedRun
    }

    private var completedRun: PlanRun? {
        plan.runs
            .filter { $0.status == .completed || $0.status == .archived }
            .sorted { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) }
            .first
    }

    private func nextProgress(in run: PlanRun) -> PlanWorkoutProgress? {
        PlanCoordinator.nextProgress(in: run)
    }

    private func canReschedule(_ progress: PlanWorkoutProgress, in run: PlanRun) -> Bool {
        PlanCoordinator.canEditSchedule(progress, in: run)
    }

    private func beginReschedule(_ progress: PlanWorkoutProgress) {
        rescheduleDate = progress.scheduledDate ?? .now
        reschedulingProgress = progress
    }

    @ViewBuilder
    private func planWorkoutStatus(_ progress: PlanWorkoutProgress) -> some View {
        switch progress.status {
        case .available:
            Button("Skip") {
                guard let run = currentRun else { return }
                _ = PlanCoordinator.skip(progress, in: run, using: modelContext)
            }
            .font(AppFont.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("skip-planned-workout")
        case .inProgress:
            Text("In progress")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymPrimary)
        case .completed:
            Label("Done", systemImage: AppIcon.checkmarkCircle)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSuccess)
        case .skipped:
            Text("Skipped")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        case .upcoming:
            Text("Upcoming")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func progress(for workout: PlannedWorkout) -> PlanWorkoutProgress? {
        currentRun?.orderedWorkoutProgress.first { $0.plannedWorkoutID == workout.id }
    }

    private func planWorkoutRow(
        _ workout: PlannedWorkout,
        progress: PlanWorkoutProgress?
    ) -> some View {
        let preparation = preparationExercises(in: workout)
        let summary = "Day \(workout.dayOffset + 1) · \(workout.orderedPlannedExercises.count) exercises"

        return HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.name)
                    .font(AppFont.subheadlineSemibold)
                Text(summary)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                if !preparation.isEmpty {
                    Label("Preparation & mobility required", systemImage: AppIcon.info)
                        .font(AppFont.caption2Bold)
                        .foregroundStyle(Color.gymPrimary)
                    Text(preparation.map { $0.exercise.name }.joined(separator: " · "))
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let notes = workout.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let scheduledDate = progress?.scheduledDate {
                    Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("planned-workout-date-\(workout.id)")
                }
            }
            Spacer()
            if let progress {
                planWorkoutStatus(progress)
            }
        }
    }

    private func preparationExercises(in workout: PlannedWorkout) -> [PlannedExercise] {
        workout.orderedPlannedExercises.filter { $0.role == .preparation }
    }
}
