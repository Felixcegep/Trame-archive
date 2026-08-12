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

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exerciseTemplates: [Exercise]
    @Query private var planRuns: [PlanRun]
    @Query private var repeatingPlanRuns: [RepeatingPlanRun]
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
            .gymFeedback(.workoutStarted, trigger: workoutStartCount)
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
                .gymAssembly(index: 0, isActive: isPlayingAssembly)
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
                .gymAssembly(index: 1, isActive: isPlayingAssembly)
                // Training data before navigation shortcuts.
                //
                // The week summary is the only thing on Today that reports what
                // the lifter has actually done, and it used to sit last — under
                // a list of links to other screens. Every daily surface worth
                // copying leads with the figure and puts shortcuts beneath it,
                // because "am I on track?" is the question the screen exists to
                // answer and a shortcut list answers nothing.
                HomeWeekSummaryCard(
                    isPrimaryCardOfferingStart: todayWorkoutSummary.offersStartAction,
                    isPlayingAssembly: isPlayingAssembly,
                    onStartWorkout: { isShowingTemplatePicker = true }
                )
                .gymAssembly(index: 2, isActive: isPlayingAssembly)
                HomeTodaySection(
                    onOpenExercises: onOpenExercises,
                    onOpenMobility: onOpenMobility,
                    onResumeMobility: onResumeMobility
                )
                .gymAssembly(index: 3, isActive: isPlayingAssembly)
                // Last in the page, after everything the lifter came for.
                if isShowingPersonalizationPrompt {
                    PersonalizationPromptCard(
                        onPersonalize: {
                            isShowingPersonalizationPrompt = false
                            onPersonalize()
                        },
                        onNotNow: {
                            isShowingPersonalizationPrompt = false
                            PersonalizationPromptPolicy.postpone(
                                atCompletedWorkoutCount: completedWorkoutCount
                            )
                        },
                        onNeverAsk: {
                            isShowingPersonalizationPrompt = false
                            PersonalizationPromptPolicy.declineForGood()
                        }
                    )
                }
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
        .onAppear(perform: resolveAssembly)
        .onAppear(perform: presentRequestedRescheduleIfNeeded)
        .onAppear(perform: evaluatePersonalizationPrompt)
        .onChange(of: requestedRescheduleProgressID) { _, _ in
            presentRequestedRescheduleIfNeeded()
        }
    }

    private var templatePicker: some View {
        NavigationStack {
            SavedWorkoutTemplatePicker(templates: workoutTemplates, availableExercises: exerciseTemplates) { template in
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
    /// Today assembles itself on a lifter's first look at it, and never again
    /// that session.
    ///
    /// Gated on having no training history, because that is the state the
    /// animation is *for*: an empty Today is three headings around a single
    /// button, and the assembly is what turns it from a screen waiting for
    /// data into a screen introducing itself. Someone with sessions behind
    /// them opens Today to start training, and an animation between them and
    /// the Start button is a toll, not a welcome.
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
            isShowingTemplatePicker = true
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
            // The draft remains available in the presented builder until its
            // explicit start action dismisses, so this branch only covers an
            // unexpected persistence or active-workout race.
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

        // The confirmation names the scope of what happened, because "Moved to
        // Friday" reads identically whether one session moved or twelve did.
        let movedTo = rescheduleDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        confirmScheduleChange(
            rescheduleShiftsRemaining
                ? String(localized: "Moved to \(movedTo). Later workouts moved with it.")
                : String(localized: "Moved to \(movedTo).")
        )
    }
    /// Decides whether the personalization offer belongs on the page.
    ///
    /// Never while a workout is in progress: an offer to answer questions is
    /// not what someone mid-session came to Today for.
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

    /// The single success path for a schedule mutation, so the visible, spoken,
    /// and tactile confirmations can never disagree about whether one happened.
    /// Called only after the coordinator has reported success.
    func confirmScheduleChange(_ text: String, systemImage: String = AppIcon.checkmarkCircle) {
        statusMessage = GymStatusMessage(text, systemImage: systemImage)
        scheduleChangeCount += 1
    }

}
