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
    /// Owned by the root so a confirmation raised elsewhere — saving a workout,
    /// which dismisses its own screen — can still land here, where the user
    /// ends up.
    @Binding var statusMessage: GymStatusMessage?

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
    /// Increments only on a schedule mutation that actually committed, so the
    /// error branches stay silent.
    @State private var scheduleChangeCount = 0

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
                // Keep an explicit action here rather than relying on the
                // platform's implicit cancel row; it remains discoverable to
                // VoiceOver and UI automation on iOS 26.
                Button("Cancel") { progressToSkip = nil }
                    .accessibilityIdentifier("today-cancel-skip-workout")
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
            // Moving or skipping a session used to change the card and say
            // nothing. "Tomorrow" sits eight points from "Reschedule", so a
            // near-miss silently moved a workout by a day with no way to tell.
            .gymStatusBanner($statusMessage)
            .gymFeedback(.scheduleChanged, trigger: scheduleChangeCount)
            .onDisappear {
                // Confirmations are scoped to Today; leaving the screen must
                // not make an old message reappear on a later return.
                statusMessage = nil
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
        let originalDate = progress.scheduledDate
        let isUnchanged = originalDate.map {
            Calendar.current.isDate($0, inSameDayAs: rescheduleDate)
        } ?? false

        return NavigationStack {
            Form {
                Section {
                    DatePicker("Scheduled date", selection: $rescheduleDate, displayedComponents: .date)
                } footer: {
                    // A past date is allowed and becomes a missed session. That
                    // is deliberate, but nothing said so, and a date picker with
                    // no stated bounds invites the assumption that it is
                    // constrained.
                    Text("Any date is allowed. A date in the past is recorded as missed, and one outside the plan's range still keeps the plan's order.")
                }
            }
            .navigationTitle("Reschedule workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { reschedulingProgress = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReschedule(progress) }
                        // Saving the date it already has is a no-op that still
                        // reported "Moved to …", which is a confirmation of
                        // nothing.
                        .disabled(isUnchanged)
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
        confirmScheduleChange(
            String(
                localized: "Moved to \(rescheduleDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))."
            )
        )
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
        confirmScheduleChange(String(localized: "Moved to tomorrow."))
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
        confirmScheduleChange(
            String(localized: "Workout skipped. It stays in your plan schedule."),
            systemImage: AppIcon.skip
        )
    }

    /// The single success path for a schedule mutation, so the visible, spoken,
    /// and tactile confirmations can never disagree about whether one happened.
    /// Called only after the coordinator has reported success.
    func confirmScheduleChange(_ text: String, systemImage: String = AppIcon.checkmarkCircle) {
        statusMessage = GymStatusMessage(text, systemImage: systemImage)
        scheduleChangeCount += 1
    }

}
