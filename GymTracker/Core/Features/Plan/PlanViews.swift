import SwiftData
import SwiftUI

struct PlansBrowserView: View {
    @Query private var plans: [WorkoutPlan]

    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void

    var body: some View {
        List {
            if activePlans.isEmpty && archivedPlans.isEmpty {
                ContentUnavailableView(
                    "No plans yet",
                    systemImage: AppIcon.planAdd,
                    description: Text("Create a multi-week plan from a workout template in Library."))
            } else {
                Section("Plans") {
                    ForEach(activePlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                        } label: {
                            planRow(plan)
                        }
                        .accessibilityIdentifier("plan-row-\(plan.name)")
                    }
                }

                if !archivedPlans.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPlans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan, onStartPlannedWorkout: onStartPlannedWorkout)
                            } label: {
                                planRow(plan)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Plans")
    }

    private var activePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var archivedPlans: [WorkoutPlan] {
        plans.filter(\.isArchived).sorted { $0.updatedAt > $1.updatedAt }
    }

    private func planRow(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: AppIcon.plan)
                .foregroundStyle(Color.gymAccent)
                .frame(width: 32, height: 32)
                .background(Color.gymAccentSurface, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(plan.name)
                    .font(AppFont.subheadlineSemibold)
                Text("\(plan.durationWeeks) weeks · \(plan.daysPerWeek) days per week")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void

    @State private var isShowingStartDate = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingEditor = false
    @State private var startDate = Date.now

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("\(plan.durationWeeks) weeks · \(plan.daysPerWeek) days per week")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                    if pausedRun != nil {
                        Text("Plan paused")
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

            if let run = activeRun, let progress = nextProgress(in: run) {
                Section("Current plan") {
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

                    Button("Pause Plan") {
                        PlanCoordinator.pause(run)
                        saveModelContext(modelContext)
                    }

                    Button("Archive Plan Run", role: .destructive) {
                        isShowingArchiveConfirmation = true
                    }
                }
            } else if let run = pausedRun {
                Section("Plan paused") {
                    Button("Resume Plan") {
                        PlanCoordinator.resume(run)
                        saveModelContext(modelContext)
                    }
                    .accessibilityIdentifier("resume-plan")

                    Button("Archive Plan Run", role: .destructive) {
                        isShowingArchiveConfirmation = true
                    }
                }
            } else if !plan.isArchived {
                Section {
                    Button {
                        startDate = .now
                        isShowingStartDate = true
                    } label: {
                        Label("Start Plan", systemImage: AppIcon.play)
                    }
                    .accessibilityIdentifier("start-plan")
                    .disabled(plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts).isEmpty)
                }
            }

            ForEach(plan.orderedWeeks) { week in
                Section("Week \(week.weekIndex + 1)") {
                    ForEach(week.orderedPlannedWorkouts) { workout in
                        HStack(spacing: Spacing.s) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(workout.name)
                                    .font(AppFont.subheadlineSemibold)
                                Text("Day \(workout.dayOffset + 1) · \(workout.orderedPlannedExercises.count) exercises")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let progress = progress(for: workout) {
                                planWorkoutStatus(progress)
                            }
                        }
                    }
                }
            }
        }
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
                .navigationTitle("Start Plan")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingStartDate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start") {
                            guard let run = PlanCoordinator.startRun(for: plan, startDate: startDate) else { return }
                            modelContext.insert(run)
                            saveModelContext(modelContext)
                            isShowingStartDate = false
                        }
                        .accessibilityIdentifier("confirm-start-plan")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                PlanEditorView(plan: plan)
            }
        }
        .confirmationDialog(
            "Archive this plan run?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Plan Run", role: .destructive) {
                guard let run = currentRun else { return }
                PlanCoordinator.archive(run)
                saveModelContext(modelContext)
            }
        } message: {
            Text("Your completed workouts remain in History. You can start this plan again later.")
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

    private func nextProgress(in run: PlanRun) -> PlanWorkoutProgress? {
        run.orderedWorkoutProgress.first { $0.status == .available || $0.status == .inProgress }
    }

    @ViewBuilder
    private func planWorkoutStatus(_ progress: PlanWorkoutProgress) -> some View {
        switch progress.status {
        case .available:
            Button("Skip") {
                guard let run = activeRun else { return }
                PlanCoordinator.skip(progress, in: run)
                saveModelContext(modelContext)
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
}
