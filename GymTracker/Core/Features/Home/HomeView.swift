import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let workoutVM: WorkoutViewModel
    @Binding var isShowingActiveWorkout: Bool
    let onStartWorkout: (WorkoutTemplate) -> Void
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartRepeatingWorkout: (RepeatingPlanRun) -> Void
    let onResolveGuidedSourceConflict: () -> Void
    let onStartMobility: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    let onResumeMobility: (MobilitySession) -> Void
    let onOpenNutrition: () -> Void
    let onOpenPlan: (UUID) -> Void
    let onOpenTrainingCalendar: () -> Void
    let onOpenSettings: () -> Void
    @Binding var requestedRescheduleProgressID: UUID?

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query private var planRuns: [PlanRun]
    @Query private var repeatingPlanRuns: [RepeatingPlanRun]
    @State private var isShowingTemplatePicker = false
    @State private var isShowingDailyCheckIn = false
    @State private var isShowingCaffeineLog = false
    @State private var reschedulingProgress: PlanWorkoutProgress?
    @State private var rescheduleDate = Date.now
    @State private var progressToSkip: PlanWorkoutProgress?
    @State private var scheduleActionError: ValidationIssue?

    private var activeFixedPlanRuns: [PlanRun] {
        planRuns
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    private var activeRepeatingPlanRuns: [RepeatingPlanRun] {
        repeatingPlanRuns
            .filter { $0.status == .active }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    private var activePlanRun: PlanRun? {
        guard activeFixedPlanRuns.count == 1, activeRepeatingPlanRuns.isEmpty else { return nil }
        return activeFixedPlanRuns[0]
    }

    private var activeRepeatingPlanRun: RepeatingPlanRun? {
        guard activeRepeatingPlanRuns.count == 1, activeFixedPlanRuns.isEmpty else { return nil }
        return activeRepeatingPlanRuns[0]
    }

    private var activePlanProgress: PlanWorkoutProgress? {
        guard let activePlanRun else { return nil }
        return PlanCoordinator.nextProgress(in: activePlanRun)
    }

    private var todayWorkoutSummary: TodayWorkoutSummary {
        TodayWorkoutSummary.resolve(
            activeWorkout: workoutVM.activeWorkout,
            planRuns: activeFixedPlanRuns,
            repeatingPlanRuns: activeRepeatingPlanRuns
        )
    }

    var body: some View {
        homeContent
            .sheet(isPresented: $isShowingTemplatePicker) {
                templatePicker
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $isShowingDailyCheckIn) {
                DailyCheckInSheet(day: .today) {
                    Task { await CheckInNotificationScheduler.shared.reconcile(using: modelContext) }
                }
            }
            .sheet(isPresented: $isShowingCaffeineLog) {
                CaffeineQuickLogSheet()
            }
            .sheet(item: $reschedulingProgress) { progress in
                rescheduleSheet(for: progress)
            }
            .confirmationDialog(
                "Skip this workout?",
                isPresented: Binding(
                    get: { progressToSkip != nil },
                    set: { if !$0 { progressToSkip = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Skip Workout", role: .destructive, action: skipPlannedWorkout)
                    .accessibilityIdentifier("today-confirm-skip-workout")
                Button("Cancel", role: .cancel) { progressToSkip = nil }
            } message: {
                Text("This session will remain in the plan schedule as skipped. Your plan and workout history will not change.")
            }
            .alert("Couldn’t update workout", isPresented: Binding(
                get: { scheduleActionError != nil },
                set: { if !$0 { scheduleActionError = nil } }
            )) {
                Button("OK", role: .cancel) { scheduleActionError = nil }
            } message: {
                Text(scheduleActionError?.message ?? "Please try again.")
            }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HomeWelcomeHeader(
                    activePlanRun: activePlanRun,
                    activeRepeatingPlanRun: activeRepeatingPlanRun,
                    onOpenPlan: onOpenPlan
                )
                HomePrimaryWorkoutCard(
                    activeWorkout: workoutVM.activeWorkout,
                    activePlanRun: activePlanRun,
                    activePlanProgress: activePlanProgress,
                    summary: todayWorkoutSummary,
                    onOpen: openPrimaryWorkout,
                    onPostpone: postponePlannedWorkoutUntilTomorrow,
                    onReschedule: beginRescheduling,
                    onSkip: { progressToSkip = $0 }
                )
                HomeTodaySection(
                    activeWorkout: workoutVM.activeWorkout,
                    isShowingDailyCheckIn: $isShowingDailyCheckIn,
                    isShowingCaffeineLog: $isShowingCaffeineLog,
                    onOpenNutrition: onOpenNutrition,
                    onStartMobility: onStartMobility,
                    onResumeMobility: onResumeMobility
                )
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.gymText)
        .background(Color.gymBackground)
        .tint(Color.gymPrimary)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.gymBackground, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onOpenTrainingCalendar) {
                    Label("Training Calendar", systemImage: AppIcon.plan)
                }
                .accessibilityIdentifier("open-training-calendar")
                .accessibilityLabel("Training Calendar")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Label("Settings", systemImage: AppIcon.settings)
                }
                .accessibilityIdentifier("open-settings")
                .accessibilityLabel("Settings")
            }
        }
        .onAppear(perform: presentRequestedRescheduleIfNeeded)
        .onChange(of: requestedRescheduleProgressID) { _, _ in
            presentRequestedRescheduleIfNeeded()
        }
    }

    private var templatePicker: some View {
        NavigationStack {
            SavedWorkoutTemplatePicker(templates: workoutTemplates) { template in
                isShowingTemplatePicker = false
                DispatchQueue.main.async {
                    onStartWorkout(template)
                }
            } onStartEmpty: {
                isShowingTemplatePicker = false
                DispatchQueue.main.async {
                    startEmptyWorkout()
                }
            }
        }
    }

    private func rescheduleSheet(for progress: PlanWorkoutProgress) -> some View {
        NavigationStack {
            Form {
                DatePicker("Scheduled date", selection: $rescheduleDate, displayedComponents: .date)
            }
            .navigationTitle("Reschedule workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { reschedulingProgress = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReschedule(progress) }
                        .accessibilityIdentifier("today-confirm-reschedule")
                }
            }
        }
    }

}

private extension HomeView {
    func openPrimaryWorkout() {
        if workoutVM.hasActiveWorkout {
            isShowingActiveWorkout = true
        } else if let run = activePlanRun, let progress = activePlanProgress {
            onStartPlannedWorkout(run, progress)
        } else if let run = activeRepeatingPlanRun {
            onStartRepeatingWorkout(run)
        } else if todayWorkoutSummary.kind == .guidedConflict {
            onResolveGuidedSourceConflict()
        } else if todayWorkoutSummary.kind == .unavailable {
            return
        } else {
            isShowingTemplatePicker = true
        }
    }
    func startEmptyWorkout() {
        guard !workoutVM.hasActiveWorkout else {
            isShowingActiveWorkout = true
            return
        }
        workoutVM.startWorkout(using: modelContext)
        isShowingActiveWorkout = true
    }
    func beginRescheduling(_ progress: PlanWorkoutProgress) {
        rescheduleDate = progress.scheduledDate ?? .now
        reschedulingProgress = progress
    }
    func saveReschedule(_ progress: PlanWorkoutProgress) {
        guard let run = planRuns.first(where: { $0.workoutProgress.contains(where: { $0.id == progress.id }) }),
              PlanCoordinator.reschedule(progress, to: rescheduleDate, in: run, using: modelContext)
        else {
            scheduleActionError = ValidationIssue(
                severity: .error,
                message: "The workout could not be rescheduled. Try again."
            )
            return
        }
        reschedulingProgress = nil
    }
    func presentRequestedRescheduleIfNeeded() {
        guard let progressID = requestedRescheduleProgressID else { return }
        defer { requestedRescheduleProgressID = nil }
        guard let run = planRuns.first(where: {
            $0.workoutProgress.contains(where: { $0.id == progressID })
        }),
        let progress = run.workoutProgress.first(where: { $0.id == progressID }),
        PlanReminderEligibility.isActionableToday(progress, in: run)
        else { return }
        beginRescheduling(progress)
    }
    func postponePlannedWorkoutUntilTomorrow() {
        guard let run = activePlanRun,
              let progress = activePlanProgress,
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now),
              PlanCoordinator.reschedule(progress, to: tomorrow, in: run, using: modelContext)
        else {
            scheduleActionError = ValidationIssue(
                severity: .error,
                message: "The workout could not be moved to tomorrow. Try again."
            )
            return
        }
    }
    func skipPlannedWorkout() {
        defer { progressToSkip = nil }
        guard let progress = progressToSkip,
              let run = activePlanRun,
              PlanCoordinator.skip(progress, in: run, using: modelContext)
        else {
            scheduleActionError = ValidationIssue(
                severity: .error,
                message: "The workout could not be skipped. Try again."
            )
            return
        }
    }

}
