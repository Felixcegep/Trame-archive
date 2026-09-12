import SwiftData
import SwiftUI

/// A month-at-a-glance coordination surface. It is intentionally derived from
/// plan, workout, mobility, nutrition, and check-in truth; it owns no records.
struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onOpenNutrition: (LocalDay) -> Void
    let onOpenMobilityHistory: () -> Void
    let onOpenJournalHistory: () -> Void

    @Query private var planRuns: [PlanRun]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query private var mobilityProgramRuns: [MobilityProgramRun]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var meals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var checkIns: [DailyLogEntry]
    @Query(sort: \SupplementOccurrence.createdAt, order: .reverse) private var supplementOccurrences: [SupplementOccurrence]

    @State private var displayedMonth = Date.now
    @State private var selectedDay = LocalDay.today
    @State private var reschedulingWorkout: TrainingCalendarPlannedWorkout?
    @State private var workoutToSkip: TrainingCalendarPlannedWorkout?
    @State private var errorMessage: String?
    @State private var projectionCache: TrainingCalendarProjectionCache?

    private func makeCalendarMonth() -> TrainingCalendarMonth {
        TrainingCalendarBuilder.month(
            containing: displayedMonth,
            planRuns: planRuns,
            workouts: workouts,
            mobilitySessions: mobilitySessions,
            mobilityProgramRuns: mobilityProgramRuns,
            activeMobilitySessionIDs: Set(mobilitySessions.filter { $0.status == .active }.map(\.id)),
            meals: meals,
            checkIns: checkIns,
            supplementOccurrences: supplementOccurrences
        )
    }

    private func selectedCalendarDay(in month: TrainingCalendarMonth) -> TrainingCalendarDay? {
        month.weeks.flatMap { $0 }.first { $0.day == selectedDay }
    }

    var body: some View {
        let inputID = projectionInputID
        let month = projectionCache.flatMap {
            $0.inputID == inputID ? $0.month : nil
        } ?? makeCalendarMonth()
        let selectedCalendarDay = selectedCalendarDay(in: month)
        // Resolve links through one render-scoped index. A selected day can
        // contain several planned/free workouts; each row must not rescan a
        // multi-year history to recover the corresponding model.
        let workoutsByID = Dictionary(
            workouts.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                monthControls
                monthSummary(month)
                weekdayHeader
                monthGrid(month)

                if let selectedCalendarDay {
                    TrainingCalendarDayAgenda(
                        day: selectedCalendarDay,
                        workout: { workoutsByID[$0] },
                        onStart: start,
                        onReschedule: { reschedulingWorkout = $0 },
                        onSkip: { workoutToSkip = $0 },
                        onOpenNutrition: onOpenNutrition,
                        onOpenMobilityHistory: onOpenMobilityHistory,
                        onOpenJournalHistory: onOpenJournalHistory
                    )
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.m)
            .padding(.bottom, Spacing.l)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Training Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-calendar-screen")
        .sheet(item: $reschedulingWorkout) { workout in
            let resolved = progress(for: workout)
            TrainingCalendarRescheduleSheet(
                workout: workout,
                progress: resolved?.progress,
                run: resolved?.run
            ) { date, shiftRemaining in
                guard let resolved = progress(for: workout) else { return false }
                if shiftRemaining {
                    return PlanCoordinator.rescheduleRemaining(
                        from: resolved.progress,
                        to: date,
                        in: resolved.run,
                        using: modelContext
                    )
                }
                return PlanCoordinator.reschedule(
                    resolved.progress,
                    to: date,
                    in: resolved.run,
                    using: modelContext
                )
            }
        }
        .confirmationDialog(
            "Skip this workout?",
            isPresented: Binding(
                get: { workoutToSkip != nil },
                set: { if !$0 { workoutToSkip = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Skip Workout", role: .destructive) {
                guard let workoutToSkip,
                      let resolved = progress(for: workoutToSkip),
                      PlanCoordinator.skip(resolved.progress, in: resolved.run, using: modelContext)
                else {
                    errorMessage = "The workout could not be skipped. Try again."
                    return
                }
                self.workoutToSkip = nil
            }
            Button("Cancel", role: .cancel) { workoutToSkip = nil }
        } message: {
            Text("The reusable plan and completed workout history will not change.")
        }
        .alert("Calendar Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The calendar could not be updated.")
        }
        // The first render after a source revision builds the exact current
        // projection synchronously, preserving the existing no-loading-state
        // behavior. Store that value after the render so selection, sheets,
        // and alerts reuse it instead of regrouping every observed history.
        .task(id: inputID) {
            projectionCache = TrainingCalendarProjectionCache(inputID: inputID, month: month)
        }
    }

    /// Tracks only fields whose changes can alter the month projection.
    /// Building this identity is linear in root records but never traverses
    /// workout sets, plan progress, meal items, or mobility result graphs.
    private var projectionInputID: Int {
        var revision = Hasher()
        revision.combine(LocalDay(date: displayedMonth))
        revision.combine(LocalDay.today)
        for run in planRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.status.rawValue)
            revision.combine(workout.name)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
        }
        for session in mobilitySessions {
            revision.combine(session.id)
            revision.combine(session.updatedAt)
        }
        for run in mobilityProgramRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        for meal in meals {
            revision.combine(meal.id)
            revision.combine(meal.updatedAt)
        }
        for checkIn in checkIns {
            revision.combine(checkIn.id)
            revision.combine(checkIn.updatedAt)
        }
        for occurrence in supplementOccurrences {
            revision.combine(occurrence.id)
            revision.combine(occurrence.updatedAt)
        }
        return revision.finalize()
    }

    private var monthControls: some View {
        HStack(spacing: Spacing.m) {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                selectFirstDayInDisplayedMonth()
            } label: {
                Image(systemName: AppIcon.chevronLeft)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("training-calendar-previous-month")

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.trameText)
                .frame(maxWidth: .infinity)

            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                selectFirstDayInDisplayedMonth()
            } label: {
                Image(systemName: AppIcon.chevronRight)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("training-calendar-next-month")

            Button("Today") {
                displayedMonth = .now
                selectedDay = .today
            }
            .font(AppFont.metadata)
            .foregroundStyle(Color.trameText)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .buttonStyle(.plain)
            .accessibilityIdentifier("training-calendar-today")
        }
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols
        return LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.trameSubdued)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    private func monthSummary(_ month: TrainingCalendarMonth) -> some View {
        let days = month.weeks.flatMap { $0 }.filter(\.isInDisplayedMonth)
        let planned = days.reduce(0) { $0 + $1.plannedWorkouts.count }
        let completed = days.reduce(0) { $0 + $1.completedWorkoutCount }
        let activeDays = days.filter { $0.completedWorkoutCount > 0 }.count
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("MONTH")
                .font(AppFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.trameSubdued)
            HStack(spacing: Spacing.l) {
                calendarMetric(value: planned, label: "Planned")
                Divider().overlay(Color.trameSeparator)
                calendarMetric(value: completed, label: "Completed")
                Divider().overlay(Color.trameSeparator)
                calendarMetric(value: activeDays, label: "Training days")
            }
        }
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
        .accessibilityIdentifier("training-calendar-month-summary")
    }

    private func calendarMetric(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text("\(value)").font(AppFont.metricCompact).foregroundStyle(Color.trameText)
            Text(label).font(AppFont.caption).foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity)
    }

    private func monthGrid(_ month: TrainingCalendarMonth) -> some View {
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(month.weeks.flatMap { $0 }) { day in
                TrainingCalendarDayButton(
                    day: day,
                    isSelected: day.day == selectedDay,
                    isToday: Calendar.current.isDateInToday(day.date)
                ) {
                    selectedDay = day.day
                }
            }
        }
        .accessibilityIdentifier("training-calendar-month-grid")
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)
    }

    private var orderedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.isEmpty == false else { return [] }
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private func selectFirstDayInDisplayedMonth() {
        selectedDay = LocalDay(date: displayedMonth)
    }

    private func progress(for workout: TrainingCalendarPlannedWorkout) -> (run: PlanRun, progress: PlanWorkoutProgress)? {
        guard let run = planRuns.first(where: { $0.id == workout.runID }),
              run.sourcePlanID == workout.planID,
              let progress = run.workoutProgress.first(where: { $0.id == workout.id })
        else { return nil }
        return (run, progress)
    }

    private func start(_ workout: TrainingCalendarPlannedWorkout) {
        guard let resolved = progress(for: workout),
              resolved.progress.status == .available
        else {
            errorMessage = "This workout is no longer ready to start."
            return
        }
        onStartPlannedWorkout(resolved.run, resolved.progress)
    }

}

private struct TrainingCalendarProjectionCache {
    let inputID: Int
    let month: TrainingCalendarMonth
}

private struct TrainingCalendarDayButton: View {
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current
    let day: TrainingCalendarDay
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Text(day.date.formatted(.dateTime.day()))
                    .font(AppFont.subheadlineSemibold)
                HStack(spacing: Spacing.xxs) {
                    if !day.plannedWorkouts.isEmpty {
                        Image(systemName: AppIcon.plan)
                            .foregroundStyle(Color.trameStrength)
                    }
                    if day.completedWorkoutCount > 0 {
                        Image(systemName: AppIcon.checkmarkCircle)
                            .foregroundStyle(Color.trameCompleted)
                    }
                    if !day.mobilitySessions.isEmpty || !day.mobilityProgramSessions.isEmpty {
                        Image(systemName: AppIcon.mobility)
                            .foregroundStyle(Color.trameMobility)
                    }
                    if day.checkIn != nil || day.creatine != nil
                        || (featureFlags.isEnabled(.nutrition) && day.nutrition != nil) {
                        Circle()
                            .fill(Color.trameAttention)
                            .frame(width: 5, height: 5)
                    }
                }
                .font(AppFont.caption2Bold)
                .opacity(day.hasContent ? 1 : 0)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: Spacing.xxxl + Spacing.l)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? Color.trameText : (isToday ? Color.trameStrength : Color.clear))
                    .frame(height: isSelected ? 3 : 1)
            }
        }
        .buttonStyle(.gymPress)
        .disabled(!day.isInDisplayedMonth)
        .accessibilityIdentifier("training-calendar-day-\(day.day.rawValue)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foregroundColor: Color {
        day.isInDisplayedMonth ? Color.trameText : Color.trameSubdued
    }

    private var accessibilityLabel: String {
        var parts = [day.date.formatted(date: .complete, time: .omitted)]
        if isSelected { parts.append("selected") }
        if isToday { parts.append("today") }
        if !day.plannedWorkouts.isEmpty { parts.append("\(day.plannedWorkouts.count) planned workout\(day.plannedWorkouts.count == 1 ? "" : "s")") }
        if day.completedWorkoutCount > 0 { parts.append("\(day.completedWorkoutCount) completed workout\(day.completedWorkoutCount == 1 ? "" : "s")") }
        if !day.mobilitySessions.isEmpty { parts.append("\(day.mobilitySessions.count) mobility session\(day.mobilitySessions.count == 1 ? "" : "s")") }
        if !day.mobilityProgramSessions.isEmpty { parts.append("\(day.mobilityProgramSessions.count) mobility plan session\(day.mobilityProgramSessions.count == 1 ? "" : "s")") }
        if featureFlags.isEnabled(.nutrition), day.nutrition != nil { parts.append("nutrition logged") }
        if day.checkIn != nil { parts.append("check-in recorded") }
        return parts.joined(separator: ", ")
    }
}

private struct TrainingCalendarDayAgenda: View {
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current
    let day: TrainingCalendarDay
    let workout: (UUID) -> Workout?
    let onStart: (TrainingCalendarPlannedWorkout) -> Void
    let onReschedule: (TrainingCalendarPlannedWorkout) -> Void
    let onSkip: (TrainingCalendarPlannedWorkout) -> Void
    let onOpenNutrition: (LocalDay) -> Void
    let onOpenMobilityHistory: () -> Void
    let onOpenJournalHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(day.date.formatted(date: .complete, time: .omitted))
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.trameText)
                .accessibilityIdentifier("training-calendar-selected-day")

            if day.hasContent {
                scheduledSection
                scheduledMobilityProgramSection
                performedSection
                contextSection
            } else {
                VStack(spacing: Spacing.l) {
                    ContentUnavailableView(
                        "Nothing recorded for this day",
                        systemImage: AppIcon.plan,
                        description: Text("Training, mobility, nutrition, and check-ins will appear here."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
                    if featureFlags.isEnabled(.nutrition) {
                        Button("Log nutrition") { onOpenNutrition(day.day) }
                            .buttonStyle(.tramePrimaryAction)
                            .accessibilityIdentifier("training-calendar-log-nutrition")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduledSection: some View {
        if !day.plannedWorkouts.isEmpty {
            agendaSection("Scheduled training", icon: AppIcon.plan) {
                ForEach(day.plannedWorkouts) { item in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(item.workoutName).font(AppFont.subheadlineSemibold)
                                Text(item.planName).font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                            }
                            Spacer()
                            PlanCalendarStateBadge(state: item.state)
                        }
                        if item.isStartable || item.isEditable {
                            if item.isStartable {
                                Button { onStart(item) } label: {
                                    Label("Start", systemImage: AppIcon.play)
                                }
                                .buttonStyle(.tramePrimaryAction)
                                .accessibilityIdentifier("training-calendar-start-\(item.id)")
                            }
                            if item.isEditable || item.state == .available {
                                HStack(spacing: Spacing.s) {
                                    if item.isEditable {
                                        Button { onReschedule(item) } label: {
                                            Label("Reschedule", systemImage: AppIcon.reschedule)
                                        }
                                        .buttonStyle(.bordered)
                                        .accessibilityIdentifier("training-calendar-reschedule-\(item.id)")
                                    }
                                    if item.state == .available {
                                        Button(role: .destructive) { onSkip(item) } label: {
                                            Label("Skip", systemImage: AppIcon.skip)
                                        }
                                        .buttonStyle(.bordered)
                                        .accessibilityIdentifier("training-calendar-skip-\(item.id)")
                                    }
                                }
                            }
                        }
                    }
                    if item.id != day.plannedWorkouts.last?.id { Divider() }
                }
            }
        }
    }

    /// Read-only: starting, rescheduling, skipping, and marking missed all
    /// stay in the dedicated mobility plan screen, which owns the program's
    /// lifecycle rules. This surface only projects them so a standalone
    /// routine and a program session on the same day both stay visible.
    @ViewBuilder
    private var scheduledMobilityProgramSection: some View {
        let pending = day.mobilityProgramSessions.filter { $0.status == .pending }
        if !pending.isEmpty {
            agendaSection("Scheduled mobility plan", icon: AppIcon.mobility) {
                ForEach(pending) { item in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(item.sessionName).font(AppFont.subheadlineSemibold)
                            Text(item.programName).font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                        }
                        Spacer()
                        Text(mobilityProgramStatusLabel(item))
                            .font(AppFont.caption2Bold)
                            .foregroundStyle(Color.trameSubdued)
                    }
                    .accessibilityIdentifier("training-calendar-mobility-plan-\(item.id)")
                    if item.id != pending.last?.id { Divider() }
                }
            }
        }
    }

    private func mobilityProgramStatusLabel(_ item: TrainingCalendarProgramMobilitySession) -> String {
        if item.isInProgress { return String(localized: "In progress") }
        return item.isOptional ? String(localized: "Optional") : String(localized: "Planned")
    }

    private func mobilityProgramDetail(_ item: TrainingCalendarProgramMobilitySession) -> String {
        switch item.status {
        case .completed: String(localized: "Completed · \(item.programName)")
        case .skipped: String(localized: "Skipped · \(item.programName)")
        case .missed: String(localized: "Missed · \(item.programName)")
        case .pending: item.programName
        }
    }

    @ViewBuilder
    private var performedSection: some View {
        let terminalProgramSessions = day.mobilityProgramSessions.filter { $0.status != .pending }
        let hasPerformed = day.completedWorkoutCount > 0 || !day.freeWorkouts.isEmpty || !day.mobilitySessions.isEmpty || !terminalProgramSessions.isEmpty
        if hasPerformed {
            agendaSection("Performed", icon: AppIcon.checkmarkCircle) {
                ForEach(day.plannedWorkouts.compactMap { item in
                    item.completedWorkoutID.map { (item, $0) }
                }, id: \.0.id) { item, workoutID in
                    if let workout = workout(workoutID) {
                        NavigationLink {
                            HistoryWorkoutView(workout: workout)
                        } label: {
                            performedRow(title: item.workoutName, detail: "Completed from \(item.planName)", icon: AppIcon.checkmarkCircle)
                        }
                    }
                }
                ForEach(day.freeWorkouts) { item in
                    if let workout = workout(item.id) {
                        NavigationLink {
                            HistoryWorkoutView(workout: workout)
                        } label: {
                            performedRow(
                                title: item.title,
                                detail: item.status == .active ? "Active workout" : "Completed workout",
                                icon: item.status == .active ? AppIcon.workout : AppIcon.checkmarkCircle
                            )
                        }
                    }
                }
                ForEach(day.mobilitySessions) { item in
                    Button(action: onOpenMobilityHistory) {
                        performedRow(
                            title: item.name,
                            detail: item.status == .active ? "Active mobility session" : "Completed mobility session",
                            icon: AppIcon.mobility
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training-calendar-mobility-\(item.id)")
                }
                ForEach(terminalProgramSessions) { item in
                    Button(action: onOpenMobilityHistory) {
                        performedRow(
                            title: item.sessionName,
                            detail: mobilityProgramDetail(item),
                            icon: item.status == .completed ? AppIcon.checkmarkCircle : AppIcon.skip
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training-calendar-mobility-plan-history-\(item.id)")
                }
            }
        }
    }

    @ViewBuilder
    private var contextSection: some View {
        if featureFlags.isEnabled(.nutrition)
            || day.checkIn != nil
            || day.creatine != nil {
            agendaSection("Daily context", icon: AppIcon.nutrition) {
                if featureFlags.isEnabled(.nutrition) {
                    Button {
                        onOpenNutrition(day.day)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: AppIcon.nutrition).foregroundStyle(Color.trameConditioning)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Nutrition").font(AppFont.subheadlineSemibold)
                                if let nutrition = day.nutrition {
                                    Text("\(FoodLibraryService.format(nutrition.totals.calories)) kcal · \(FoodLibraryService.format(nutrition.totals.protein)) g protein")
                                        .font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                                    if nutrition.totals.hasUnknownValues {
                                        Text("Some nutrients unknown").font(AppFont.caption).foregroundStyle(Color.trameAttention)
                                    }
                                } else {
                                    Text("Log food for this day")
                                        .font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                                }
                            }
                            Spacer()
                            if let nutrition = day.nutrition {
                                Text("\(nutrition.mealCount) meal\(nutrition.mealCount == 1 ? "" : "s")")
                                    .font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training-calendar-nutrition")
                }
                if let checkIn = day.checkIn {
                    Button(action: onOpenJournalHistory) {
                        performedRow(title: "Journal", detail: checkIn.title, icon: AppIcon.routine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training-calendar-journal")
                }
                if let creatine = day.creatine {
                    performedRow(
                        title: "Creatine",
                        detail: creatine == .completed ? "Confirmed" : "Skipped",
                        icon: creatine == .completed ? AppIcon.checkmarkCircle : AppIcon.skip
                    )
                }
            }
        }
    }

    private func agendaSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Image(systemName: icon)
                    .foregroundStyle(Color.trameStrength)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                    .textCase(.uppercase)
                Rectangle().fill(Color.trameSeparator).frame(height: 1)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.trameSeparator).frame(height: 1)
        }
    }

    private func performedRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon).foregroundStyle(Color.trameStrength)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(AppFont.subheadlineSemibold).foregroundStyle(Color.trameText)
                Text(detail).font(AppFont.caption).foregroundStyle(Color.trameSubdued)
            }
            Spacer()
            Image(systemName: AppIcon.chevronRight).font(AppFont.captionBold).foregroundStyle(Color.trameSubdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrainingCalendarRescheduleSheet: View {
    let workout: TrainingCalendarPlannedWorkout
    let progress: PlanWorkoutProgress?
    let run: PlanRun?
    let onSave: (Date, Bool) -> Bool

    var body: some View {
        PlanRescheduleSheet(
            workoutName: workout.workoutName,
            initialDate: progress?.scheduledDate,
            progress: progress,
            run: run,
            confirmIdentifier: "training-calendar-confirm-reschedule",
            datePickerIdentifier: "training-calendar-reschedule-date",
            onSave: onSave
        )
    }
}
