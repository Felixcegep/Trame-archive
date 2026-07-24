import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let workoutVM: WorkoutViewModel
    @Binding var isShowingActiveWorkout: Bool
    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onStartMobility: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    let onResumeMobility: (MobilitySession) -> Void
    let onOpenNutrition: () -> Void
    let onOpenTrainMobility: () -> Void
    let onOpenTrainingCalendar: () -> Void
    let onOpenSettings: () -> Void
    @Binding var requestedRescheduleProgressID: UUID?

    @Query private var workoutTemplates: [WorkoutTemplate]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query private var planRuns: [PlanRun]
    @Query private var dailyLogEntries: [DailyLogEntry]
    @Query private var supplementOccurrences: [SupplementOccurrence]
    @Query(sort: \MobilityRoutine.updatedAt, order: .reverse) private var mobilityRoutines: [MobilityRoutine]
    @Query(sort: \MobilitySession.updatedAt, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var nutritionTargets: [NutritionTarget]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?
    @State private var isShowingTemplatePicker = false
    @State private var isShowingDailyCheckIn = false
    @State private var isShowingCaffeineLog = false
    @State private var reschedulingProgress: PlanWorkoutProgress?
    @State private var rescheduleDate = Date.now
    @State private var progressToSkip: PlanWorkoutProgress?
    @State private var scheduleActionError: ValidationIssue?
    @State private var templateToStart: WorkoutTemplate? = nil
    @State private var isShowingActiveWorkoutConflictAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                welcomeHeader
                primaryWorkoutCard
                dailyContext
                nutritionContext
                mobilityContext
                quickActions
                recentActivity
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
        .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
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
        .sheet(isPresented: $isShowingTemplatePicker) {
            NavigationStack {
                SavedWorkoutTemplatePicker(templates: workoutTemplates) { template in
                    isShowingTemplatePicker = false
                    DispatchQueue.main.async {
                        startWorkout(from: template)
                    }
                }
            }
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
        .confirmationDialog(
            "Skip this workout?",
            isPresented: Binding(
                get: { progressToSkip != nil },
                set: { if !$0 { progressToSkip = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Skip Workout", role: .destructive) { skipPlannedWorkout() }
                .accessibilityIdentifier("today-confirm-skip-workout")
            Button("Cancel", role: .cancel) { progressToSkip = nil }
        } message: {
            Text("This session will remain in the program schedule as skipped. Your plan and workout history will not change.")
        }
        .alert("Couldn’t update workout", isPresented: Binding(
            get: { scheduleActionError != nil },
            set: { if !$0 { scheduleActionError = nil } }
        )) {
            Button("OK", role: .cancel) { scheduleActionError = nil }
        } message: {
            Text(scheduleActionError?.message ?? "Please try again.")
        }
        .confirmationDialog(
            "An active workout is already in progress",
            isPresented: $isShowingActiveWorkoutConflictAlert,
            titleVisibility: .visible
        ) {
            Button("Resume Active Workout") {
                isShowingActiveWorkout = true
                templateToStart = nil
            }
            Button("Discard & Start New", role: .destructive) {
                workoutVM.discardActiveWorkout(using: modelContext)
                if let template = templateToStart {
                    workoutVM.startWorkout(with: template, using: modelContext)
                    isShowingActiveWorkout = true
                }
                templateToStart = nil
            }
            Button("Cancel", role: .cancel) {
                templateToStart = nil
            }
        } message: {
            Text("Do you want to continue your active workout, or discard it and start a new one?")
        }
    }

    private var todayWorkoutSummary: TodayWorkoutSummary {
        TodayWorkoutSummary.resolve(
            activeWorkout: workoutVM.activeWorkout,
            activePlanRun: activePlanRun,
            nextPlanProgress: activePlanProgress
        )
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppFont.subheadlineMediumMonospaced)
                .foregroundStyle(Color.gymAccent)

            if let activePlanRun {
                activePlanContext(for: activePlanRun)
                    .padding(.bottom, Spacing.xs)
            }

            Text(todayWorkoutSummary.title)
                .font(AppFont.displayMedium)

            Text(workoutVM.hasActiveWorkout
                 ? "Your session is still running."
                 : "Train, reflect, and keep the day simple.")
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private func activePlanContext(for run: PlanRun) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: AppIcon.plan)
                .font(AppFont.captionBold)

            Text(run.sourcePlanName)
                .font(AppFont.captionBold)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Spacing.s)

            Text("Week \(run.currentWeekIndex + 1)")
                .font(AppFont.caption2Bold)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background(Color.gymCard.opacity(0.72), in: Capsule())
        }
        .foregroundStyle(Color.gymAccent)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymAccentSurface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active program: \(run.sourcePlanName), week \(run.currentWeekIndex + 1)")
        .accessibilityIdentifier("active-plan-badge")
    }

    private var primaryWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openPrimaryWorkout) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack {
                        Label(
                            primaryCardLabel,
                            systemImage: primaryCardIcon
                        )
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymPrimary)

                        Spacer()

                        if workoutVM.hasActiveWorkout {
                            Image(systemName: "chevron.right")
                                .font(AppFont.subheadlineBold)
                                .foregroundStyle(.white)
                        }
                    }

                    Text(primaryCardTitle)
                        .font(AppFont.titleMedium)
                        .foregroundStyle(workoutVM.hasActiveWorkout ? .white : Color.gymText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(primaryCardSubtitle)
                        .font(AppFont.subheadline)
                        .foregroundStyle(workoutVM.hasActiveWorkout ? .white.opacity(0.86) : Color.gymSubduedText)

                    if let workout = workoutVM.activeWorkout, workout.totalSetCount > 0 {
                        ProgressView(
                            value: Double(workout.completedSetCount),
                            total: Double(workout.totalSetCount)
                        )
                        .tint(.white.opacity(0.95))
                        .padding(.top, Spacing.xxs)
                    }

                    if !workoutVM.hasActiveWorkout {
                        HStack(spacing: Spacing.s) {
                            Text("Start workout")
                                .font(AppFont.subheadlineBold)
                            Image(systemName: "arrow.right")
                                .font(AppFont.captionBold)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, Spacing.md)
                        .padding(.horizontal, Spacing.xl)
                        .background(Color.gymPrimary, in: Capsule())
                        .padding(.top, Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.l)
            }
            .buttonStyle(.gymPress)
            .accessibilityHint(primaryCardHint)
            .accessibilityIdentifier(primaryCardAccessibilityIdentifier)

            if let activePlanRun, let activePlanProgress,
               !workoutVM.hasActiveWorkout,
               PlanCoordinator.canEditSchedule(activePlanProgress, in: activePlanRun) {
                Divider()
                    .overlay(Color.gymBorder)
                    .padding(.horizontal, Spacing.l)

                HStack(spacing: Spacing.s) {
                    Button {
                        postponePlannedWorkoutUntilTomorrow()
                    } label: {
                        Label("Tomorrow", systemImage: AppIcon.tomorrow)
                    }
                    .accessibilityIdentifier("today-postpone-planned-workout")

                    Button {
                        rescheduleDate = activePlanProgress.scheduledDate ?? .now
                        reschedulingProgress = activePlanProgress
                    } label: {
                        Label("Reschedule", systemImage: AppIcon.reschedule)
                    }
                    .accessibilityIdentifier("today-reschedule-planned-workout")

                    Spacer(minLength: Spacing.s)

                    Button(role: .destructive) {
                        progressToSkip = activePlanProgress
                    } label: {
                        Label("Skip", systemImage: AppIcon.skip)
                    }
                    .accessibilityIdentifier("today-skip-planned-workout")
                }
                .font(AppFont.subheadlineSemibold)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
            }
        }
        .background {
            if workoutVM.hasActiveWorkout {
                LinearGradient(
                    colors: [Color.gymPrimary, Color.gymPrimary.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.gymCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.03), radius: 6, x: 0, y: 3)
        .overlay {
            if !workoutVM.hasActiveWorkout {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.gymPrimary.opacity(0.16), lineWidth: 1.5)
            }
        }
    }

    private var quickActions: some View {
        Group {
            if !workoutVM.hasActiveWorkout {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("QUICK ACTIONS")
                        .font(AppFont.captionBold)
                        .tracking(0.8)
                        .foregroundStyle(Color.gymSubduedText)

                    Button {
                        isShowingTemplatePicker = true
                    } label: {
                        quickActionRow(
                            icon: "rectangle.stack",
                            iconColor: Color.gymPrimary,
                            title: "Use a Saved Workout",
                            detail: "Follow a reusable session"
                        )
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityIdentifier("start-from-template")
                }
            }
        }
    }

    private var dailyContext: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("TODAY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            Button {
                isShowingDailyCheckIn = true
            } label: {
                dailyContextRow(
                    icon: "text.book.closed",
                    iconColor: Color.gymAccent,
                    title: dailyCheckInTitle,
                    detail: dailyCheckInDetail,
                    completion: dailyLogEntry?.status == .completed
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("open-daily-check-in")

            Button(action: toggleCreatine) {
                dailyContextRow(
                    icon: "drop.fill",
                    iconColor: Color.gymSecondary,
                    title: "Creatine",
                    detail: creatineTaken ? "Confirmed for today" : "Confirm today’s dose",
                    completion: creatineTaken
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("toggle-creatine")
            .accessibilityValue(creatineTaken ? "Confirmed" : "Not confirmed")
        }
    }

    private var nutritionContext: some View {
        let summary = NutritionDaySummary.resolve(day: .today, meals: loggedMeals)
        let resolution = NutritionTargetResolver.resolve(day: .today, planRuns: planRuns, targets: nutritionTargets)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("NUTRITION")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            Button {
                onOpenNutrition()
            } label: {
                dailyContextRow(
                    icon: AppIcon.nutrition,
                    iconColor: Color.gymSecondary,
                    title: "\(FoodLibraryService.format(summary.totals.calories)) kcal · \(FoodLibraryService.format(summary.totals.protein)) g protein",
                    detail: nutritionDetail(summary: summary, resolution: resolution),
                    completion: summary.meals.isEmpty == false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("open-nutrition-today")
            .accessibilityLabel("Nutrition today, \(FoodLibraryService.format(summary.totals.calories)) calories, \(FoodLibraryService.format(summary.totals.protein)) grams protein")

            Button { isShowingCaffeineLog = true } label: {
                dailyContextRow(
                    icon: AppIcon.caffeine,
                    iconColor: Color.gymAccent,
                    title: "Caffeine",
                    detail: caffeineDetail(summary: summary),
                    completion: false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("today-caffeine-summary")
            .accessibilityLabel("Caffeine today, \(caffeineAccessibilityValue(summary: summary)). Add a drink.")
        }
    }

    private func nutritionDetail(
        summary: NutritionDaySummary,
        resolution: (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues)
    ) -> String {
        let target = resolution.values.calories.map { "of \(FoodLibraryService.format($0)) kcal" } ?? "No calorie target"
        let unknown = summary.totals.hasUnknownValues ? " · Some nutrients unknown" : ""
        return "\(resolution.kind.displayName) · \(target)\(unknown)"
    }

    private var caffeineDailyLimit: CaffeineDailyLimit {
        let birthdate = caffeineBirthdateTimestamp.map { Date(timeIntervalSince1970: $0) }
        let ageBand = CaffeineGuidance.ageBand(birthdate: birthdate)
        return CaffeineGuidance.dailyLimit(ageBand: ageBand, bodyWeightKilograms: bodyWeightEntries.first.map { Double($0.kilograms) })
    }

    private func caffeineReferenceSuffix(loggedMilligrams: Double) -> String {
        guard case .milligrams(let mg, _) = caffeineDailyLimit else { return "" }
        let isOver = loggedMilligrams > mg
        let isNear = !isOver && mg > 0 && loggedMilligrams >= mg * 0.8
        var suffix = " · \(FoodLibraryService.format(mg)) mg reference"
        if isOver { suffix += " · Over daily reference" } else if isNear { suffix += " · Near daily reference" }
        return suffix
    }

    private func caffeineDetail(summary: NutritionDaySummary) -> String {
        if summary.meals.isEmpty { return "No nutrition entries today" }
        let value = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) mg logged\(caffeineReferenceSuffix(loggedMilligrams: summary.totals.caffeineMilligrams))"
        return summary.totals.unknownCaffeineCount > 0 ? "\(value) · Some entries unknown" : value
    }

    private func caffeineAccessibilityValue(summary: NutritionDaySummary) -> String {
        let value = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) milligrams logged\(caffeineReferenceSuffix(loggedMilligrams: summary.totals.caffeineMilligrams))"
        return summary.totals.unknownCaffeineCount > 0 ? "\(value), some entries have unknown caffeine" : value
    }

    private var mobilityContext: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("MOBILITY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            if let activeMobilitySession {
                Button {
                    onResumeMobility(activeMobilitySession)
                } label: {
                    dailyContextRow(
                        icon: AppIcon.mobility,
                        iconColor: Color.gymAccent,
                        title: "Resume mobility",
                        detail: "\(activeMobilitySession.nameSnapshot) · Movement \(min(activeMobilitySession.currentEntryIndex + 1, activeMobilitySession.entries.count)) of \(activeMobilitySession.entries.count)",
                        completion: false
                    )
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("resume-mobility-session")
            } else if let routine = availableMobilityRoutine {
                Button {
                    let context: MobilitySessionContext = workoutVM.activeWorkout == nil ? .standalone : .warmup
                    onStartMobility(routine, context, workoutVM.activeWorkout?.id)
                } label: {
                    dailyContextRow(
                        icon: AppIcon.mobility,
                        iconColor: Color.gymAccent,
                        title: workoutVM.activeWorkout == nil ? "Start mobility" : "Start mobility warm-up",
                        detail: "\(routine.name) · \(routine.items.count) movement\(routine.items.count == 1 ? "" : "s")",
                        completion: false
                    )
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("start-mobility-routine")
            } else {
                Button {
                    onOpenTrainMobility()
                } label: {
                    dailyContextRow(
                        icon: AppIcon.mobility,
                        iconColor: Color.gymAccent,
                        title: "Create a mobility routine",
                        detail: "Build a short warm-up or recovery sequence",
                        completion: false
                    )
                }
                .buttonStyle(.gymPress)
                .accessibilityIdentifier("create-mobility-routine-from-today")
            }

            Button("Manage mobility routines") {
                onOpenTrainMobility()
            }
            .font(AppFont.captionBold)
            .accessibilityIdentifier("manage-mobility-routines")
        }
    }

    private func dailyContextRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String,
        completion: Bool,
        showsDisclosure: Bool = true
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: completion ? "checkmark.circle.fill" : icon)
                .font(AppFont.headline)
                .frame(width: 38, height: 38)
                .foregroundStyle(completion ? Color.gymSecondary : iconColor)
                .background((completion ? Color.gymSecondary : iconColor).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            if completion || showsDisclosure {
                Image(systemName: completion ? "checkmark" : "chevron.right")
                    .font(AppFont.captionBold)
                    .foregroundStyle(completion ? Color.gymSecondary : Color.gymSubduedText)
            }
        }
        .padding(Spacing.m)
        .background(Color.gymCard)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private func quickActionRow(
        icon: String,
        iconColor: Color,
        title: String,
        detail: String,
        isInformational: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(AppFont.headline)
                .frame(width: 38, height: 38)
                .foregroundStyle(iconColor)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.subheadlineSemibold)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }

            Spacer()

            Image(systemName: isInformational ? "info.circle" : "chevron.right")
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)
        }
        .padding(Spacing.m)
        .background(Color.gymCard)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(Color.gymBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private var recentActivity: some View {
        let completedWorkouts = workouts.filter { $0.status == .completed }

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("HISTORY")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            if completedWorkouts.isEmpty {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppFont.headline)
                        .frame(width: 38, height: 38)
                        .foregroundStyle(Color.gymAccent)
                        .background(Color.gymAccent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("No workouts yet")
                            .font(AppFont.subheadlineSemibold)
                        Text("Finish a workout to unlock performance and progression history.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gymCard)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .stroke(Color.gymBorder, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(completedWorkouts.prefix(3), id: \.self) { workout in
                        NavigationLink(destination: HistoryWorkoutView(workout: workout)) {
                            HStack(spacing: Spacing.m) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AppFont.headline)
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(Color.gymSecondary)
                                    .background(Color.gymSecondary.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(workout.displayTitle)
                                        .font(AppFont.subheadlineSemibold)
                                    Text(workout.startTime, style: .date)
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.gymSubduedText)
                                }

                                Spacer()

                                Text("^[\(workout.exercises.count) exercise](inflect: true)")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)

                                Image(systemName: "chevron.right")
                                    .font(AppFont.captionBold)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            .padding(Spacing.m)
                            .background(Color.gymCard)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                                    .stroke(Color.gymBorder, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                            .shadow(color: Color.gymText.opacity(0.02), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.gymPress)
                    }
                }
            }
        }
    }

    private var primaryCardTitle: LocalizedStringKey {
        if let workout = workoutVM.activeWorkout {
            if let name = workout.name, !name.isEmpty {
                return "Resume \(name)"
            }
            return "Resume workout"
        }
        if let progress = activePlanProgress {
            return LocalizedStringKey(progress.plannedWorkoutName)
        }
        return "Free Workout"
    }

    private var todayDay: LocalDay { .today }

    private var dailyLogEntry: DailyLogEntry? {
        dailyLogEntries.first { $0.dayKey == todayDay.rawValue }
    }

    private var dailyCheckInTitle: String {
        guard let dailyLogEntry else { return "Daily check-in" }
        return dailyLogEntry.status == .completed ? "Daily check-in complete" : "Daily check-in skipped"
    }

    private var dailyCheckInDetail: String {
        guard let dailyLogEntry else { return "Reflect on sleep, energy, and training" }
        return dailyLogEntry.status == .completed ? "You can edit today’s reflection" : "You can still add a reflection"
    }

    private var creatineOccurrence: SupplementOccurrence? {
        supplementOccurrences.first {
            $0.dayKey == todayDay.rawValue && $0.kind == .creatine
        }
    }

    private var activeMobilitySession: MobilitySession? {
        mobilitySessions.first { $0.status == .active }
    }

    private var availableMobilityRoutine: MobilityRoutine? {
        mobilityRoutines.first { $0.isArchived == false && $0.items.isEmpty == false }
    }

    private var creatineTaken: Bool {
        creatineOccurrence?.status == .completed
    }

    private func toggleCreatine() {
        let occurrence = creatineOccurrence ?? SupplementOccurrence(
            kind: .creatine,
            day: todayDay,
            status: .skipped,
            completedAt: nil
        )
        occurrence.update(status: creatineTaken ? .skipped : .completed)
        if creatineOccurrence == nil {
            modelContext.insert(occurrence)
        }
        _ = modelContext.saveOrRollback()
    }

    private var primaryCardSubtitle: LocalizedStringKey {
        if let workout = workoutVM.activeWorkout {
            guard workout.totalSetCount > 0 else {
                return "No exercises yet · Pick your first exercise"
            }
            let completedSets = workout.completedSetCount
            let totalSets = workout.totalSetCount
            let nextDesc = nextExerciseDescription(in: workout)
            return "\(completedSets) / \(totalSets) sets · \(nextDesc)"
        }
        if let progress = activePlanProgress {
            let week = progress.weekIndex + 1
            if let scheduledDate = progress.scheduledDate, Calendar.current.isDateInToday(scheduledDate) {
                return "Week \(week) · Today"
            }
            return "Week \(week) · Start early when you are ready"
        }
        return "Jump in and add exercises as you go."
    }

    private func nextExerciseDescription(in workout: Workout) -> String {
        guard let exercise = workout.orderedExercises.first(where: { $0.orderedSets.contains(where: { !$0.done }) }),
              let setIndex = exercise.orderedSets.firstIndex(where: { !$0.done })
        else {
            return String(localized: "Workout complete")
        }

        let format = String(localized: "Next: %@ · Set %lld")
        return String(format: format, exercise.exercise.name, Int64(setIndex + 1))
    }

    private func openPrimaryWorkout() {
        if workoutVM.hasActiveWorkout {
            isShowingActiveWorkout = true
        } else if let run = activePlanRun, let progress = activePlanProgress {
            onStartPlannedWorkout(run, progress)
        } else {
            workoutVM.startWorkout(using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private func saveReschedule(_ progress: PlanWorkoutProgress) {
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

    private func presentRequestedRescheduleIfNeeded() {
        guard let progressID = requestedRescheduleProgressID else { return }
        defer { requestedRescheduleProgressID = nil }
        guard let run = planRuns.first(where: { run in
            run.workoutProgress.contains(where: { $0.id == progressID })
        }),
        let progress = run.workoutProgress.first(where: { $0.id == progressID }),
        PlanReminderEligibility.isActionableToday(progress, in: run)
        else {
            return
        }
        rescheduleDate = progress.scheduledDate ?? .now
        reschedulingProgress = progress
    }

    private func postponePlannedWorkoutUntilTomorrow() {
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

    private func skipPlannedWorkout() {
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

    private func startWorkout(from template: WorkoutTemplate) {
        if workoutVM.hasActiveWorkout {
            templateToStart = template
            isShowingActiveWorkoutConflictAlert = true
        } else {
            workoutVM.startWorkout(with: template, using: modelContext)
            isShowingActiveWorkout = true
        }
    }

    private var activePlanRun: PlanRun? {
        planRuns
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    private var activePlanProgress: PlanWorkoutProgress? {
        guard let activePlanRun else { return nil }
        return PlanCoordinator.nextProgress(in: activePlanRun)
    }

    private var primaryCardLabel: LocalizedStringKey {
        if workoutVM.hasActiveWorkout { return "ACTIVE WORKOUT" }
        if activePlanProgress != nil { return "PLANNED WORKOUT" }
        return "FREE WORKOUT"
    }

    private var primaryCardIcon: String {
        workoutVM.hasActiveWorkout || activePlanProgress != nil
            ? "figure.strengthtraining.traditional"
            : "bolt.fill"
    }

    private var primaryCardHint: String {
        if workoutVM.hasActiveWorkout { return "Returns to your active workout." }
        if activePlanProgress != nil { return "Starts the next workout in your active program." }
        return "Starts a blank workout."
    }

    private var primaryCardAccessibilityIdentifier: String {
        if workoutVM.hasActiveWorkout { return "resume-active-workout" }
        if activePlanProgress != nil { return "start-planned-workout" }
        return "start-free-workout"
    }
}
