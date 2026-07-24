import SwiftData
import SwiftUI

/// A month-at-a-glance coordination surface. It is intentionally derived from
/// plan, workout, mobility, nutrition, and check-in truth; it owns no records.
struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    let onStartPlannedWorkout: (PlanRun, PlanWorkoutProgress) -> Void
    let onOpenNutrition: () -> Void
    let onOpenMobilityHistory: () -> Void
    let onOpenJournalHistory: () -> Void

    @Query private var planRuns: [PlanRun]
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var meals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var checkIns: [DailyLogEntry]
    @Query(sort: \SupplementOccurrence.createdAt, order: .reverse) private var supplementOccurrences: [SupplementOccurrence]

    @State private var displayedMonth = Date.now
    @State private var selectedDay = LocalDay.today
    @State private var reschedulingWorkout: TrainingCalendarPlannedWorkout?
    @State private var workoutToSkip: TrainingCalendarPlannedWorkout?
    @State private var errorMessage: String?

    private var calendarMonth: TrainingCalendarMonth {
        TrainingCalendarBuilder.month(
            containing: displayedMonth,
            planRuns: planRuns,
            workouts: workouts,
            mobilitySessions: mobilitySessions,
            meals: meals,
            checkIns: checkIns,
            supplementOccurrences: supplementOccurrences
        )
    }

    private func selectedCalendarDay(in month: TrainingCalendarMonth) -> TrainingCalendarDay? {
        month.weeks.flatMap { $0 }.first { $0.day == selectedDay }
    }

    var body: some View {
        let month = calendarMonth
        let selectedCalendarDay = selectedCalendarDay(in: month)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                monthControls
                monthSummary(month)
                weekdayHeader
                monthGrid(month)

                if let selectedCalendarDay {
                    TrainingCalendarDayAgenda(
                        day: selectedCalendarDay,
                        workout: workout,
                        onStart: start,
                        onReschedule: { reschedulingWorkout = $0 },
                        onSkip: { workoutToSkip = $0 },
                        onOpenNutrition: onOpenNutrition,
                        onOpenMobilityHistory: onOpenMobilityHistory,
                        onOpenJournalHistory: onOpenJournalHistory
                    )
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
        }
        .background(Color.gymBackground)
        .navigationTitle("Training Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-calendar-screen")
        .sheet(item: $reschedulingWorkout) { workout in
            TrainingCalendarRescheduleSheet(workout: workout) { date, shiftRemaining in
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
    }

    private var monthControls: some View {
        HStack(spacing: Spacing.m) {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                selectFirstDayInDisplayedMonth()
            } label: {
                Image(systemName: AppIcon.chevronLeft)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("training-calendar-previous-month")

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymText)
                .frame(maxWidth: .infinity)

            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                selectFirstDayInDisplayedMonth()
            } label: {
                Image(systemName: AppIcon.chevronRight)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("training-calendar-next-month")

            Button("Today") {
                displayedMonth = .now
                selectedDay = .today
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gymPrimary)
            .accessibilityIdentifier("training-calendar-today")
        }
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols
        return LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubduedText)
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
        return GymCard(variant: .completed) {
            GymSectionHeader(title: "Month at a glance", detail: "A concise view of planned and performed training.", systemImage: AppIcon.chart)
            HStack(spacing: Spacing.l) {
                calendarMetric(value: planned, label: "Planned")
                Divider()
                calendarMetric(value: completed, label: "Completed")
                Divider()
                calendarMetric(value: activeDays, label: "Training days")
            }
        }
        .accessibilityIdentifier("training-calendar-month-summary")
    }

    private func calendarMetric(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text("\(value)").font(AppFont.titleSmallSemiboldMonospaced).foregroundStyle(Color.gymText)
            Text(label).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
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

    private func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }
}

private struct TrainingCalendarDayButton: View {
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
                    }
                    if day.completedWorkoutCount > 0 {
                        Image(systemName: AppIcon.checkmarkCircle)
                    }
                    if !day.mobilitySessions.isEmpty {
                        Image(systemName: AppIcon.mobility)
                    }
                }
                .font(AppFont.caption2Bold)
                .opacity(day.hasContent ? 1 : 0)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: Spacing.xxxl + Spacing.l)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: Radius.medium)
                        .stroke(Color.gymPrimary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.gymPress)
        .disabled(!day.isInDisplayedMonth)
        .accessibilityIdentifier("training-calendar-day-\(day.day.rawValue)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if isSelected { return Color.gymPrimary }
        return day.isInDisplayedMonth ? Color.gymCard : Color.gymBackground
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        return day.isInDisplayedMonth ? Color.gymText : Color.gymSubduedText
    }

    private var accessibilityLabel: String {
        var parts = [day.date.formatted(date: .complete, time: .omitted)]
        if isSelected { parts.append("selected") }
        if isToday { parts.append("today") }
        if !day.plannedWorkouts.isEmpty { parts.append("\(day.plannedWorkouts.count) planned workout\(day.plannedWorkouts.count == 1 ? "" : "s")") }
        if day.completedWorkoutCount > 0 { parts.append("\(day.completedWorkoutCount) completed workout\(day.completedWorkoutCount == 1 ? "" : "s")") }
        if !day.mobilitySessions.isEmpty { parts.append("\(day.mobilitySessions.count) mobility session\(day.mobilitySessions.count == 1 ? "" : "s")") }
        if day.nutrition != nil { parts.append("nutrition logged") }
        if day.checkIn != nil { parts.append("check-in recorded") }
        return parts.joined(separator: ", ")
    }
}

private struct TrainingCalendarDayAgenda: View {
    let day: TrainingCalendarDay
    let workout: (UUID) -> Workout?
    let onStart: (TrainingCalendarPlannedWorkout) -> Void
    let onReschedule: (TrainingCalendarPlannedWorkout) -> Void
    let onSkip: (TrainingCalendarPlannedWorkout) -> Void
    let onOpenNutrition: () -> Void
    let onOpenMobilityHistory: () -> Void
    let onOpenJournalHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(day.date.formatted(date: .complete, time: .omitted))
                .font(AppFont.titleSmallSemibold)
                .foregroundStyle(Color.gymText)
                .accessibilityIdentifier("training-calendar-selected-day")

            if day.hasContent {
                scheduledSection
                performedSection
                contextSection
            } else {
                ContentUnavailableView(
                    "Nothing recorded for this day",
                    systemImage: AppIcon.plan,
                    description: Text("Training, mobility, nutrition, and check-ins will appear here."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
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
                                Text(item.planName).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer()
                            PlanCalendarStateBadge(state: item.state)
                        }
                        if item.isStartable || item.isEditable {
                            HStack(spacing: Spacing.s) {
                                if item.isStartable {
                                    Button { onStart(item) } label: {
                                        Label("Start", systemImage: AppIcon.play)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.gymPrimary)
                                    .accessibilityIdentifier("training-calendar-start-\(item.id)")
                                }
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
                    if item.id != day.plannedWorkouts.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private var performedSection: some View {
        let hasPerformed = day.completedWorkoutCount > 0 || !day.freeWorkouts.isEmpty || !day.mobilitySessions.isEmpty
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
            }
        }
    }

    @ViewBuilder
    private var contextSection: some View {
        if let nutrition = day.nutrition {
            agendaSection("Daily context", icon: AppIcon.nutrition) {
                Button(action: onOpenNutrition) {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: AppIcon.nutrition).foregroundStyle(Color.gymSecondary)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Nutrition").font(AppFont.subheadlineSemibold)
                            Text("\(FoodLibraryService.format(nutrition.totals.calories)) kcal · \(FoodLibraryService.format(nutrition.totals.protein)) g protein")
                                .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            if nutrition.totals.hasUnknownValues {
                                Text("Some nutrients unknown").font(AppFont.caption).foregroundStyle(Color.gymAccent)
                            }
                        }
                        Spacer()
                        Text("\(nutrition.mealCount) meal\(nutrition.mealCount == 1 ? "" : "s")")
                            .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("training-calendar-nutrition")
            }
        }
        if day.checkIn != nil || day.creatine != nil {
            agendaSection("Daily context", icon: AppIcon.routine) {
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
            Label(title, systemImage: icon)
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func performedRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon).foregroundStyle(Color.gymPrimary)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                Text(detail).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(AppFont.captionBold).foregroundStyle(Color.gymSubduedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrainingCalendarRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let workout: TrainingCalendarPlannedWorkout
    let onSave: (Date, Bool) -> Bool
    @State private var date = Date.now
    @State private var shiftRemaining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(workout.workoutName) {
                    DatePicker("Scheduled date", selection: $date, displayedComponents: .date)
                    Toggle("Shift remaining workouts", isOn: $shiftRemaining)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Color.gymDestructive)
                    }
                }
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(date, shiftRemaining) {
                            dismiss()
                        } else {
                            errorMessage = "The schedule could not be saved. Try again."
                        }
                    }
                    .accessibilityIdentifier("training-calendar-confirm-reschedule")
                }
            }
        }
    }
}
