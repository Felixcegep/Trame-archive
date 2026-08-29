import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let plan: WorkoutPlan
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartPlan: (WorkoutPlan, Date) -> Void
    let onResumePlan: (PlanRun) -> Void
    let onStartTestDay: (PlanRun) -> Void
    let onOpenProgramPath: (ProgramPathRoute) -> Void
    let onOpenWeeklyReview: (WeeklyProgramReviewRoute) -> Void

    @State private var isShowingStartDate = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingEditor = false
    @State private var startDate = Date.now
    @State private var reschedulingProgress: PlanWorkoutProgress?
    @State private var rescheduleDate = Date.now
    @State private var isShowingRenamePrompt = false
    @State private var renameText = ""
    @State private var lifecycleFeedback: String?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxl) {
                        TrameMetric(
                            value: "\(plan.durationWeeks)",
                            label: "Weeks",
                            accessibilityLabel: "\(plan.durationWeeks) weeks"
                        )
                        TrameMetric(
                            value: "\(plan.daysPerWeek)",
                            label: "Days per week",
                            accessibilityLabel: "\(plan.daysPerWeek) days per week"
                        )
                    }

                    if pausedRun != nil {
                        Text("Plan paused")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameAttention)
                    } else if testDayRun != nil {
                        Text("Test day ready")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameActionDeep)
                    } else if let run = activeRun, let progress = nextProgress(in: run) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("NEXT SESSION")
                                .font(AppFont.micro)
                                .tracking(0.8)
                                .foregroundStyle(Color.trameSubdued)
                            Text(progress.plannedWorkoutName)
                                .font(AppFont.stageTitle)
                                .foregroundStyle(Color.trameText)
                            Text(progress.scheduledDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? String(localized: "Ready now"))
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                        }
                    } else {
                        Text("Your schedule repeats each week.")
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                .padding(.vertical, Spacing.s)
            } header: {
                TrameDomainSectionRule(title: "Plan", color: Color.trameStrength)
            }

            Section {
                NavigationLink {
                    PlanPrescriptionPreviewView(plan: plan)
                } label: {
                    Label("Preview prescriptions", systemImage: AppIcon.chart)
                }
                .accessibilityIdentifier("view-program-prescription-preview")
            } header: {
                TrameDomainSectionRule(title: "Prescription", color: Color.trameStrength)
            }

            if let notes = plan.notes, !notes.isEmpty {
                Section {
                    Text(notes)
                        .font(AppFont.body)
                        .foregroundStyle(Color.trameText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Spacing.xs)
                } header: {
                    TrameDomainSectionRule(title: "Safety & progression", color: Color.trameAttention)
                }
            }

            if hasAmbiguousCurrentRuns {
                Section {
                    Text("More than one current run was found. Resolve the duplicate runs before starting or changing this plan.")
                        .font(AppFont.body)
                        .foregroundStyle(Color.trameText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Spacing.xs)
                } header: {
                    TrameDomainSectionRule(title: "Plan needs attention", color: Color.trameAttention)
                }
            } else if let run = activeRun, nextProgress(in: run) != nil {
                Section {
                    programPathLink(for: run)
                    weeklyReviewLink(for: run)

                    NavigationLink {
                        PlanCalendarView(run: run)
                    } label: {
                        Label("View Schedule", systemImage: AppIcon.plan)
                    }
                    .accessibilityIdentifier("view-plan-schedule")

                } header: {
                    TrameDomainSectionRule(title: "Current run", color: Color.trameStrength)
                }
            } else if let run = pausedRun {
                Section {
                    programPathLink(for: run)
                    weeklyReviewLink(for: run)

                    NavigationLink {
                        PlanCalendarView(run: run)
                    } label: {
                        Label("View Schedule", systemImage: AppIcon.plan)
                    }
                    .accessibilityIdentifier("view-plan-schedule")

                } header: {
                    TrameDomainSectionRule(title: "Plan paused", color: Color.trameAttention)
                }
            } else if let run = testDayRun, nextProgress(in: run) != nil {
                Section {
                    programPathLink(for: run)
                    weeklyReviewLink(for: run)

                } header: {
                    TrameDomainSectionRule(title: "Test day", color: Color.trameCompetition)
                }
            } else if !plan.isArchived && !hasAmbiguousCurrentRuns {
                EmptyView()
            }

            ForEach(plan.orderedWeeks) { week in
                Section {
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
                                .tint(Color.trameAttention)
                                .accessibilityIdentifier("reschedule-planned-workout-\(workout.id)")
                            }
                        }
                    }
                } header: {
                    TrameDomainSectionRule(
                        title: LocalizedStringKey(
                            week.weekIndex == currentWeekIndex
                                ? "Current week · Week \(week.weekIndex + 1)"
                                : "Week \(week.weekIndex + 1)"
                        ),
                        color: week.weekIndex == currentWeekIndex ? Color.trameStrength : Color.trameSeparator
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            primaryPlanAction
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !plan.isArchived {
                        Button("Edit") {
                            isShowingEditor = true
                        }
                        .accessibilityIdentifier("edit-plan")
                    }

                    Button {
                        renameText = plan.name
                        isShowingRenamePrompt = true
                    } label: {
                        Label("Rename", systemImage: AppIcon.edit)
                    }
                    .accessibilityIdentifier("rename-plan")

                    Button {
                        do {
                            try WorkoutPlanArchiveService.duplicate(plan, using: modelContext)
                            lifecycleFeedback = "Plan duplicated."
                        } catch {
                            lifecycleFeedback = "Could not duplicate the plan."
                        }
                    } label: {
                        Label("Duplicate", systemImage: AppIcon.duplicate)
                    }
                    .accessibilityIdentifier("duplicate-plan")

                    Divider()

                    if let run = activeRun {
                        Button("Pause this plan") {
                            PlanCoordinator.pause(run, using: modelContext)
                        }
                        Button("End this plan run", role: .destructive) {
                            isShowingArchiveConfirmation = true
                        }
                    } else if pausedRun != nil || testDayRun != nil {
                        Button("End this plan run", role: .destructive) {
                            isShowingArchiveConfirmation = true
                        }
                    }

                    Divider()

                    if plan.isArchived {
                        Button {
                            do {
                                try WorkoutPlanArchiveService.restore(plan, using: modelContext)
                                lifecycleFeedback = "Plan restored."
                            } catch {
                                lifecycleFeedback = "Could not restore the plan."
                            }
                        } label: {
                            Label("Restore", systemImage: AppIcon.restore)
                        }
                        .accessibilityIdentifier("restore-plan")
                    }

                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label(plan.isArchived ? "Delete" : "Delete", systemImage: AppIcon.trash)
                    }
                    .accessibilityIdentifier("delete-plan")
                } label: {
                    Image(systemName: AppIcon.options)
                        .accessibilityLabel("Plan options")
                }
            }
        }
        .alert("Rename Plan", isPresented: $isShowingRenamePrompt) {
            TextField("Plan name", text: $renameText)
            Button("Save") {
                do {
                    try WorkoutPlanArchiveService.rename(plan, to: renameText, using: modelContext)
                } catch {
                    lifecycleFeedback = "Could not rename the plan."
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Plan Updated", isPresented: Binding(
            get: { lifecycleFeedback != nil },
            set: { if !$0 { lifecycleFeedback = nil } }
        )) {
            Button("OK") { lifecycleFeedback = nil }
        } message: {
            Text(lifecycleFeedback ?? "")
        }
        .confirmationDialog(
            "Delete this plan?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                do {
                    let outcome = try WorkoutPlanArchiveService.hideOrDeleteResult(plan, using: modelContext)
                    if case .archived(let reason) = outcome {
                        lifecycleFeedback = reason
                    }
                } catch {
                    lifecycleFeedback = "Could not delete the plan."
                }
            }
        } message: {
            Text("This plan and its prescriptions will be removed. Completed workouts and run history are always preserved.")
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
                            onStartPlan(plan, startDate)
                            isShowingStartDate = false
                        }
                        .accessibilityIdentifier(canOfferRestart ? "confirm-restart-plan" : "confirm-start-plan")
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
            "End this plan run?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Plan Run", role: .destructive) {
                guard let run = currentRun else { return }
                PlanCoordinator.archive(run, using: modelContext)
            }
        } message: {
            Text("This run will end, but the plan, its progress, and completed workouts remain available. You can start a new run later.")
        }
    }

    /// The run's derived position and history. Kept beside "View Schedule"
    /// because both answer questions about this run rather than about the
    /// reusable plan the rest of the screen describes.
    private func programPathLink(for run: PlanRun) -> some View {
        Button {
            onOpenProgramPath(.fixedRun(run.id))
        } label: {
            Label(ProgramPathPresentation.entryTitle, systemImage: AppIcon.routine)
        }
        .accessibilityIdentifier("view-plan-program-path")
        .accessibilityHint(Text(ProgramPathPresentation.entryDetail))
    }

    /// Fixed-plan only — this view has no repeating-plan equivalent, so no
    /// extra gating beyond "a run exists" is needed here.
    private func weeklyReviewLink(for run: PlanRun) -> some View {
        Button {
            onOpenWeeklyReview(WeeklyProgramReviewRoute(runID: run.id))
        } label: {
            Label(WeeklyProgramReviewPresentation.entryTitle, systemImage: AppIcon.chart)
        }
        .accessibilityIdentifier("view-plan-weekly-review")
        .accessibilityHint(Text(WeeklyProgramReviewPresentation.entryDetail))
    }

    @ViewBuilder
    private var primaryPlanAction: some View {
        if !hasAmbiguousCurrentRuns, currentRun != nil || !plan.isArchived {
            VStack(spacing: 0) {
                if let run = activeRun, let progress = nextProgress(in: run) {
                    Button {
                        onStartPlannedWorkout(run, progress)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Text(progress.status == .inProgress ? "Resume workout" : "Start workout")
                            Spacer(minLength: Spacing.s)
                            Image(systemName: progress.status == .inProgress ? AppIcon.workout : AppIcon.chevronRight)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.tramePrimaryAction)
                    .accessibilityIdentifier("start-planned-workout")
                } else if let run = pausedRun {
                    Button("Resume plan") { onResumePlan(run) }
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("resume-plan")
                } else if let run = testDayRun, nextProgress(in: run) != nil {
                    Button("Start test day") { onStartTestDay(run) }
                        .buttonStyle(.tramePrimaryAction)
                        .accessibilityIdentifier("start-test-day")
                } else if !plan.isArchived {
                    Button(canOfferRestart ? "Restart plan" : "Start plan") {
                        startDate = .now
                        isShowingStartDate = true
                    }
                    .buttonStyle(.tramePrimaryAction)
                    .accessibilityIdentifier(canOfferRestart ? "restart-plan" : "start-plan")
                    .disabled(plan.orderedWeeks.flatMap(\.orderedPlannedWorkouts).isEmpty)
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.s)
            .background(Color.trameSurface)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.trameSeparator).frame(height: 1)
            }
        }
    }

    private var currentWeekIndex: Int? {
        guard let currentRun else { return nil }
        return nextProgress(in: currentRun)?.weekIndex
    }

    private var activeRun: PlanRun? {
        singularRun(with: .active)
    }

    private var pausedRun: PlanRun? {
        singularRun(with: .paused)
    }

    private var testDayRun: PlanRun? {
        singularRun(with: .testDayAvailable)
    }

    private var currentRun: PlanRun? {
        activeRun ?? pausedRun ?? testDayRun
    }

    private var hasAmbiguousCurrentRuns: Bool {
        plan.runs.filter {
            $0.status == .active || $0.status == .paused || $0.status == .testDayAvailable
        }.count > 1
    }

    /// Delegates so this view and `PlanScreen`'s segments can never disagree
    /// about which run is current — see `PlanRunResolver`.
    private func singularRun(with status: PlanRunStatus) -> PlanRun? {
        PlanRunResolver.singularRun(in: plan, with: status)
    }

    private var completedRun: PlanRun? {
        plan.runs
            .filter { $0.status == .completed || $0.status == .archived }
            .sorted { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) }
            .first
    }

    private var canOfferRestart: Bool {
        guard completedRun != nil else { return false }
        if case .offerRestart = plan.programCompletionPolicy { return true }
        return false
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
            .foregroundStyle(Color.trameSubdued)
            .frame(minWidth: ComponentSize.minimumTouchTarget, minHeight: ComponentSize.minimumTouchTarget)
            .accessibilityIdentifier("skip-planned-workout")
        case .inProgress:
            Text("In progress")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameStrength)
        case .completed:
            Label("Done", systemImage: AppIcon.checkmarkCircle)
                .font(AppFont.caption)
                .foregroundStyle(Color.trameCompleted)
        case .skipped:
            Text("Skipped")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        case .upcoming:
            Text("Upcoming")
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
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

        return HStack(alignment: .top, spacing: Spacing.m) {
            Rectangle()
                .fill(progressColor(progress))
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.name)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                Text(summary)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                if workout.isOptional {
                    Text("Optional session")
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameActionDeep)
                }
                if !preparation.isEmpty {
                    Label("Preparation & mobility required", systemImage: AppIcon.info)
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameMobility)
                    Text(preparation.map { $0.exercise.name }.joined(separator: " · "))
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .lineLimit(2)
                }
                if let notes = workout.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                        .lineLimit(2)
                }
                if let scheduledDate = progress?.scheduledDate {
                    Text(scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                        .accessibilityIdentifier("planned-workout-date-\(workout.id)")
                }
            }
            Spacer()
            if let progress {
                planWorkoutStatus(progress)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func progressColor(_ progress: PlanWorkoutProgress?) -> Color {
        guard let progress else { return Color.trameSeparator }
        switch progress.status {
        case .inProgress: return Color.trameAction
        case .completed: return Color.trameCompleted
        case .available: return Color.trameStrength
        case .skipped: return Color.trameSubdued
        case .upcoming: return Color.trameSeparator
        }
    }

    private func preparationExercises(in workout: PlannedWorkout) -> [PlannedExercise] {
        workout.orderedPlannedExercises.filter { $0.role == .preparation }
    }
}
