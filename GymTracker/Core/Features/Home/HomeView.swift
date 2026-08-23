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
    let onResumeMobility: (MobilitySession) -> Void
    /// Today navigates to Train's libraries; it never selects a routine or an
    /// exercise itself.
    let onOpenExercises: () -> Void
    let onOpenMobility: () -> Void
    let onOpenPlan: (UUID) -> Void
    let onOpenTrainingCalendar: () -> Void
    let onOpenSettings: () -> Void
    /// Opens the training profile for a lifter who skipped setup. Offered from
    /// a passive card here rather than from the workout-save confirmation,
    /// which is a screen that is already leaving.
    let onPersonalize: () -> Void
    @Binding var requestedRescheduleProgressID: UUID?
    /// Owned by the root so a confirmation raised elsewhere — saving a workout,
    /// which dismisses its own screen — can still land here, where the user
    /// ends up.
    @Binding var statusMessage: GymStatusMessage?

    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]
    @Query(filter: #Predicate<RepeatingPlanRun> { $0.endedAt == nil }) private var repeatingPlanRuns: [RepeatingPlanRun]
    @State private var isShowingTemplatePicker = false
    @State private var reschedulingProgress: PlanWorkoutProgress?
    @State private var rescheduleDate = Date.now
    /// Reset on every presentation. Carrying a shift decision from one
    /// reschedule into the next would move sessions the user never looked at.
    @State private var rescheduleShiftsRemaining = false
    @State private var progressToSkip: PlanWorkoutProgress?
    @State private var scheduleActionError: ValidationIssue?
    /// Increments only on a schedule mutation that actually committed, so the
    /// error branches stay silent.
    @State private var scheduleChangeCount = 0
    /// Resolved once per appearance rather than per render: the policy reads
    /// the store and `UserDefaults`, and neither belongs in a body.
    @State private var isShowingPersonalizationPrompt = false
    @State private var completedWorkoutCount = 0
    @State private var workoutStartCount = 0
    @State private var pendingTemplateStart: WorkoutTemplate?
    /// Whether Today plays the Trame assembly on this appearance.
    ///
    /// Resolved once, in `onAppear`, and never in `body` — reading it during a
    /// render would let a re-render mid-animation restart the sequence.
    @State private var isPlayingAssembly = false

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
            .sheet(isPresented: $isShowingTemplatePicker, onDismiss: handleTemplatePickerDismissal) {
                templatePicker
                    .presentationDetents([.large])
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
            .gymStatusBanner($statusMessage)
            .gymFeedback(.scheduleChanged, trigger: scheduleChangeCount)
            .gymFeedback(.workoutStarted, trigger: workoutStartCount)
            .onDisappear {
                statusMessage = nil
            }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                HomeWelcomeHeader(
                    activePlanRun: activePlanRun,
                    activeRepeatingPlanRun: activeRepeatingPlanRun,
                    showsPersonalizationOffer: isShowingPersonalizationPrompt,
                    onOpenPlan: onOpenPlan,
                    onPersonalize: {
                        isShowingPersonalizationPrompt = false
                        onPersonalize()
                    },
                    onDeferPersonalization: {
                        isShowingPersonalizationPrompt = false
                        PersonalizationPromptPolicy.postpone(
                            atCompletedWorkoutCount: completedWorkoutCount
                        )
                    }
                )
                .gymAssembly(index: 0, isActive: isPlayingAssembly)

                HomePrimaryWorkoutCard(
                    activeWorkout: workoutVM.activeWorkout,
                    activePlanRun: activePlanRun,
                    activePlanProgress: activePlanProgress,
                    summary: todayWorkoutSummary,
                    onOpen: openPrimaryWorkout,
                    onOpenSavedWorkouts: { isShowingTemplatePicker = true },
                    onPostpone: postponePlannedWorkoutUntilTomorrow,
                    onReschedule: beginRescheduling,
                    onSkip: { progressToSkip = $0 }
                )
                .gymAssembly(index: 1, isActive: isPlayingAssembly)

                HomeActiveTrainingSupport(
                    onOpenMobility: onOpenMobility,
                    onResumeMobility: onResumeMobility
                )

                HomeWeekSummaryCard(
                    isPrimaryCardOfferingStart: todayWorkoutSummary.offersStartAction,
                    isPlayingAssembly: isPlayingAssembly,
                    onStartWorkout: { isShowingTemplatePicker = true },
                    onOpenCalendar: onOpenTrainingCalendar
                )
                .gymAssembly(index: 2, isActive: isPlayingAssembly)

                HomeQuickAccessSection(
                    onOpenExercises: onOpenExercises,
                    onOpenMobility: onOpenMobility
                )
                .gymAssembly(index: 3, isActive: isPlayingAssembly)
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(Color.trameText)
        .background(Color.trameCanvas)
        .tint(Color.trameStrength)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.trameCanvas, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: AppIcon.settings)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-settings")
                .accessibilityLabel("Settings")
            }
        }
        .onAppear(perform: resolveAssembly)
        .onAppear(perform: presentRequestedRescheduleIfNeeded)
        .onAppear(perform: evaluatePersonalizationPrompt)
        .onChange(of: requestedRescheduleProgressID) { _, _ in
            presentRequestedRescheduleIfNeeded()
        }
    }

    private var templatePicker: some View {
        NavigationStack {
            SavedWorkoutTemplatePicker { template in
                pendingTemplateStart = template
                isShowingTemplatePicker = false
            } onStartEmpty: {
                isShowingTemplatePicker = false
                DispatchQueue.main.async {
                    startEmptyWorkout()
                }
            } onStartPersonalized: { draft in
                let didStart = startPersonalizedWorkout(draft)
                if didStart {
                    workoutStartCount += 1
                }
                return didStart
            }
        }
    }

    private func rescheduleSheet(for progress: PlanWorkoutProgress) -> some View {
        RescheduleWorkoutSheet(
            progress: progress,
            run: run(containing: progress),
            date: $rescheduleDate,
            shiftsRemaining: $rescheduleShiftsRemaining,
            onCancel: { reschedulingProgress = nil },
            onSave: { saveReschedule(progress) }
        )
    }

    private func handleTemplatePickerDismissal() {
        guard let template = pendingTemplateStart else { return }
        pendingTemplateStart = nil
        workoutStartCount += 1
        onStartWorkout(template)
    }
}

private extension HomeView {
    func resolveAssembly() {
        guard completedWorkoutCount == 0,
              (try? modelContext.fetchCount(FetchDescriptor<Workout>())) ?? 0 == 0,
              GymAssemblySession.claim("today")
        else {
            return
        }
        isPlayingAssembly = true
    }

    func openPrimaryWorkout() {
        if workoutVM.hasActiveWorkout {
            isShowingActiveWorkout = true
        } else if let run = activePlanRun, let progress = activePlanProgress {
            workoutStartCount += 1
            onStartPlannedWorkout(run, progress)
        } else if let run = activeRepeatingPlanRun {
            workoutStartCount += 1
            onStartRepeatingWorkout(run)
        } else if todayWorkoutSummary.kind == .guidedConflict {
            onResolveGuidedSourceConflict()
        } else if todayWorkoutSummary.kind == .unavailable {
            return
        } else {
            startEmptyWorkout()
        }
    }

    func startEmptyWorkout() {
        guard !workoutVM.hasActiveWorkout else {
            isShowingActiveWorkout = true
            return
        }
        workoutVM.startWorkout(using: modelContext)
        workoutStartCount += 1
        isShowingActiveWorkout = true
    }

    func startPersonalizedWorkout(_ draft: ValidatedWorkoutDraft) -> Bool {
        guard !workoutVM.hasActiveWorkout else {
            isShowingActiveWorkout = true
            return false
        }
        do {
            _ = try GeneratedWorkoutStartService.start(
                draft,
                using: modelContext,
                unitSystem: UserDefaults.standard.unitSystem
            )
            _ = workoutVM.restoreActiveWorkout(using: modelContext)
            isShowingActiveWorkout = workoutVM.hasActiveWorkout
            guard isShowingActiveWorkout else { return false }
            isShowingTemplatePicker = false
            return true
        } catch {
            isShowingActiveWorkout = workoutVM.hasActiveWorkout
            return false
        }
    }

    func run(containing progress: PlanWorkoutProgress) -> PlanRun? {
        planRuns.first { $0.workoutProgress.contains { $0.id == progress.id } }
    }

    func beginRescheduling(_ progress: PlanWorkoutProgress) {
        rescheduleDate = progress.scheduledDate ?? .now
        rescheduleShiftsRemaining = false
        reschedulingProgress = progress
    }

    func saveReschedule(_ progress: PlanWorkoutProgress) {
        guard let run = run(containing: progress) else {
            scheduleActionError = ValidationIssue(
                severity: .error,
                message: "The workout could not be rescheduled. Try again."
            )
            return
        }

        let didReschedule = rescheduleShiftsRemaining
            ? PlanCoordinator.rescheduleRemaining(from: progress, to: rescheduleDate, in: run, using: modelContext)
            : PlanCoordinator.reschedule(progress, to: rescheduleDate, in: run, using: modelContext)

        guard didReschedule else {
            scheduleActionError = ValidationIssue(
                severity: .error,
                message: "The workout could not be rescheduled. Try again."
            )
            return
        }
        reschedulingProgress = nil

        let movedTo = rescheduleDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        confirmScheduleChange(
            rescheduleShiftsRemaining
                ? String(localized: "Moved to \(movedTo). Later workouts moved with it.")
                : String(localized: "Moved to \(movedTo).")
        )
    }

    func evaluatePersonalizationPrompt() {
        guard workoutVM.activeWorkout == nil else {
            isShowingPersonalizationPrompt = false
            return
        }
        let count = (try? modelContext.fetchCount(FetchDescriptor<Workout>())) ?? 0
        completedWorkoutCount = count
        isShowingPersonalizationPrompt = PersonalizationPromptPolicy.shouldPrompt(
            completedWorkoutCount: count,
            using: modelContext
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

    func confirmScheduleChange(_ text: String, systemImage: String = AppIcon.checkmarkCircle) {
        statusMessage = GymStatusMessage(text, systemImage: systemImage)
        scheduleChangeCount += 1
    }
}
