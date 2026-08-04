import Foundation

/// A read-only, local-calendar projection. It deliberately references domain
/// records by stable identifiers instead of persisting generic calendar events.
struct TrainingCalendarMonth {
    let month: Date
    let weeks: [[TrainingCalendarDay]]
}

struct TrainingCalendarDay: Identifiable {
    let date: Date
    let day: LocalDay
    let isInDisplayedMonth: Bool
    let plannedWorkouts: [TrainingCalendarPlannedWorkout]
    let freeWorkouts: [TrainingCalendarWorkout]
    let mobilitySessions: [TrainingCalendarMobilitySession]
    /// Program-scheduled mobility sessions, projected independently of
    /// `mobilitySessions` (performed evidence). A standalone routine and a
    /// program session can both land on the same day; neither hides the
    /// other.
    let mobilityProgramSessions: [TrainingCalendarProgramMobilitySession]
    let nutrition: TrainingCalendarNutritionSummary?
    let checkIn: TrainingCalendarCheckInSummary?
    let creatine: SupplementOccurrenceStatus?

    var id: String { day.rawValue }

    var hasContent: Bool {
        !plannedWorkouts.isEmpty
            || !freeWorkouts.isEmpty
            || !mobilitySessions.isEmpty
            || !mobilityProgramSessions.isEmpty
            || nutrition != nil
            || checkIn != nil
            || creatine != nil
    }

    var completedWorkoutCount: Int {
        plannedWorkouts.filter { $0.completedWorkoutID != nil }.count + freeWorkouts.filter { $0.status == .completed }.count
    }
}

struct TrainingCalendarPlannedWorkout: Identifiable {
    let id: UUID
    let runID: UUID
    let planID: UUID
    let workoutName: String
    let planName: String
    let state: PlanCalendarDisplayState
    let completedWorkoutID: UUID?

    var isEditable: Bool {
        switch state {
        case .upcoming, .available, .missed:
            true
        case .inProgress, .completed, .skipped:
            false
        }
    }

    var isStartable: Bool { state == .available }
}

struct TrainingCalendarWorkout: Identifiable {
    let id: UUID
    let title: String
    let status: WorkoutStatus
    let startedAt: Date
}

struct TrainingCalendarMobilitySession: Identifiable {
    let id: UUID
    let name: String
    let status: MobilitySessionStatus
    let startedAt: Date
}

/// A read-only projection of one `MobilityProgramSessionProgress`, built
/// through its `ScheduledTrainingOccurrence` conformance so the calendar
/// never has to know the mobility-program run graph's shape directly.
struct TrainingCalendarProgramMobilitySession: Identifiable {
    let id: UUID
    let runID: UUID
    let programName: String
    let sessionName: String
    let status: MobilityProgramSessionStatus
    let isOptional: Bool
    /// `true` when this occurrence's linked session is currently active —
    /// derived, never persisted, mirroring `MobilityProgramSessionProgress
    /// .isInProgress(activeMobilitySessionIDs:)`.
    let isInProgress: Bool
}

struct TrainingCalendarNutritionSummary {
    let totals: NutritionMacroTotals
    let mealCount: Int
}

struct TrainingCalendarCheckInSummary {
    let status: DailyCheckInStatus

    var title: String {
        status == .completed ? "Check-in complete" : "Check-in skipped"
    }
}

enum TrainingCalendarBuilder {
    /// Sessions a stopped plan will never deliver must not keep occupying the
    /// calendar. A run the user is still following contributes its whole
    /// schedule; a completed or archived one contributes only what actually
    /// happened, so history survives while phantom future sessions do not.
    static func schedulableProgress(in run: PlanRun) -> [PlanWorkoutProgress] {
        switch run.status {
        case .active, .paused, .testDayAvailable:
            return run.orderedWorkoutProgress
        case .completed, .archived:
            return run.orderedWorkoutProgress.filter {
                $0.status == .completed || $0.status == .skipped
            }
        }
    }

    /// Mirrors `schedulableProgress(in:)` for a `MobilityProgramRun`: an
    /// open run contributes its whole schedule, a terminal one contributes
    /// only what actually happened.
    static func schedulableSessionProgress(in run: MobilityProgramRun) -> [MobilityProgramSessionProgress] {
        switch run.status {
        case .active, .paused:
            return run.orderedSessionProgress
        case .completed, .archived:
            return run.orderedSessionProgress.filter { $0.status == .completed || $0.status == .skipped || $0.status == .missed }
        }
    }

    static func month(
        containing month: Date,
        planRuns: [PlanRun],
        workouts: [Workout],
        mobilitySessions: [MobilitySession],
        mobilityProgramRuns: [MobilityProgramRun] = [],
        activeMobilitySessionIDs: Set<UUID> = [],
        meals: [LoggedMeal],
        checkIns: [DailyLogEntry],
        supplementOccurrences: [SupplementOccurrence],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> TrainingCalendarMonth {
        let monthStart = calendar.dateInterval(of: .month, for: month)?.start ?? calendar.startOfDay(for: month)
        let visibleStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let finalDay = calendar.date(byAdding: .day, value: -1, to: monthEnd) ?? monthStart
        let finalWeekStart = calendar.dateInterval(of: .weekOfYear, for: finalDay)?.start ?? finalDay
        let visibleEnd = calendar.date(byAdding: .day, value: 7, to: finalWeekStart) ?? monthEnd
        let dates = dates(from: visibleStart, until: visibleEnd, calendar: calendar)

        let plannedByDay = Dictionary(grouping: planRuns.flatMap { run in
            schedulableProgress(in: run).compactMap { progress -> (String, TrainingCalendarPlannedWorkout)? in
                guard let scheduledDate = progress.scheduledDate else { return nil }
                let day = LocalDay(date: scheduledDate, calendar: calendar)
                return (
                    day.rawValue,
                    TrainingCalendarPlannedWorkout(
                        id: progress.id,
                        runID: run.id,
                        planID: run.sourcePlanID,
                        workoutName: progress.plannedWorkoutName,
                        planName: run.sourcePlanName,
                        state: PlanCalendarBuilder.displayState(
                            status: progress.status,
                            scheduledDate: scheduledDate,
                            today: today,
                            calendar: calendar
                        ),
                        completedWorkoutID: progress.completedWorkout?.id
                    )
                )
            }
        }, by: \.0)
        let workoutsByDay = Dictionary(grouping: workouts) { LocalDay(date: $0.startTime, calendar: calendar).rawValue }
        let mobilityByDay = Dictionary(grouping: mobilitySessions) { LocalDay(date: $0.startTime, calendar: calendar).rawValue }
        let programSessionsByDay = Dictionary(grouping: mobilityProgramRuns.flatMap { run in
            schedulableSessionProgress(in: run).compactMap { progress -> (String, TrainingCalendarProgramMobilitySession)? in
                guard progress.scheduledDate != nil else { return nil }
                return (
                    progress.scheduledDay.rawValue,
                    TrainingCalendarProgramMobilitySession(
                        id: progress.id,
                        runID: run.id,
                        programName: run.sourceProgramName,
                        sessionName: progress.displayName,
                        status: progress.status,
                        isOptional: progress.isOptional,
                        isInProgress: progress.isInProgress(activeMobilitySessionIDs: activeMobilitySessionIDs)
                    )
                )
            }
        }, by: \.0)
        let mealsByDay = Dictionary(grouping: meals, by: \.dayKey)
        let checkInsByDay = Dictionary(grouping: checkIns, by: \.dayKey)
        let supplementsByDay = Dictionary(grouping: supplementOccurrences, by: \.dayKey)

        let days = dates.map { date in
            let day = LocalDay(date: date, calendar: calendar)
            let plannedWorkouts = (plannedByDay[day.rawValue] ?? [])
                .map(\.1)
                .sorted { lhs, rhs in
                    if lhs.planName != rhs.planName { return lhs.planName.localizedStandardCompare(rhs.planName) == .orderedAscending }
                    return lhs.workoutName.localizedStandardCompare(rhs.workoutName) == .orderedAscending
                }
            let pairedWorkoutIDs = Set(plannedWorkouts.compactMap(\.completedWorkoutID))
            let freeWorkouts = (workoutsByDay[day.rawValue] ?? []).compactMap { workout -> TrainingCalendarWorkout? in
                guard !pairedWorkoutIDs.contains(workout.id), workout.status == .active || workout.status == .completed else { return nil }
                return TrainingCalendarWorkout(id: workout.id, title: workout.displayTitle, status: workout.status, startedAt: workout.startTime)
            }
            .sorted { $0.startedAt < $1.startedAt }
            let projectedMobility = (mobilityByDay[day.rawValue] ?? []).compactMap { session -> TrainingCalendarMobilitySession? in
                guard session.status == .active || session.status == .completed else { return nil }
                return TrainingCalendarMobilitySession(id: session.id, name: session.nameSnapshot, status: session.status, startedAt: session.startTime)
            }
            .sorted { $0.startedAt < $1.startedAt }
            let programSessions = (programSessionsByDay[day.rawValue] ?? [])
                .map(\.1)
                .sorted { $0.sessionName.localizedStandardCompare($1.sessionName) == .orderedAscending }
            let dayMeals = mealsByDay[day.rawValue] ?? []
            let nutrition = dayMeals.isEmpty ? nil : TrainingCalendarNutritionSummary(
                totals: NutritionDaySummary.resolve(day: day, meals: dayMeals).totals,
                mealCount: dayMeals.count
            )
            let checkIn = checkInsByDay[day.rawValue]?.first.map { TrainingCalendarCheckInSummary(status: $0.status) }
            let creatine = supplementsByDay[day.rawValue]?.first(where: { $0.kind == .creatine })?.status
            return TrainingCalendarDay(
                date: calendar.startOfDay(for: date),
                day: day,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                plannedWorkouts: plannedWorkouts,
                freeWorkouts: freeWorkouts,
                mobilitySessions: projectedMobility,
                mobilityProgramSessions: programSessions,
                nutrition: nutrition,
                checkIn: checkIn,
                creatine: creatine
            )
        }

        return TrainingCalendarMonth(
            month: monthStart,
            weeks: stride(from: 0, to: days.count, by: 7).map { index in
                Array(days[index..<min(index + 7, days.count)])
            }
        )
    }

    static func day(
        for date: Date,
        isInDisplayedMonth: Bool = true,
        planRuns: [PlanRun],
        workouts: [Workout],
        mobilitySessions: [MobilitySession],
        mobilityProgramRuns: [MobilityProgramRun] = [],
        activeMobilitySessionIDs: Set<UUID> = [],
        meals: [LoggedMeal],
        checkIns: [DailyLogEntry],
        supplementOccurrences: [SupplementOccurrence],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> TrainingCalendarDay {
        let day = LocalDay(date: date, calendar: calendar)
        let plannedWorkouts = planRuns.flatMap { run in
            schedulableProgress(in: run).compactMap { progress -> TrainingCalendarPlannedWorkout? in
                guard let scheduledDate = progress.scheduledDate,
                      calendar.isDate(scheduledDate, inSameDayAs: date)
                else { return nil }
                return TrainingCalendarPlannedWorkout(
                    id: progress.id,
                    runID: run.id,
                    planID: run.sourcePlanID,
                    workoutName: progress.plannedWorkoutName,
                    planName: run.sourcePlanName,
                    state: PlanCalendarBuilder.displayState(
                        status: progress.status,
                        scheduledDate: progress.scheduledDate,
                        today: today,
                        calendar: calendar
                    ),
                    completedWorkoutID: progress.completedWorkout?.id
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.planName != rhs.planName { return lhs.planName.localizedStandardCompare(rhs.planName) == .orderedAscending }
            return lhs.workoutName.localizedStandardCompare(rhs.workoutName) == .orderedAscending
        }

        let pairedWorkoutIDs = Set(plannedWorkouts.compactMap(\.completedWorkoutID))
        let freeWorkouts = workouts.compactMap { workout -> TrainingCalendarWorkout? in
            guard calendar.isDate(workout.startTime, inSameDayAs: date),
                  !pairedWorkoutIDs.contains(workout.id),
                  workout.status == .active || workout.status == .completed
            else { return nil }
            return TrainingCalendarWorkout(
                id: workout.id,
                title: workout.displayTitle,
                status: workout.status,
                startedAt: workout.startTime
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        let projectedMobility = mobilitySessions.compactMap { session -> TrainingCalendarMobilitySession? in
            guard calendar.isDate(session.startTime, inSameDayAs: date),
                  session.status == .active || session.status == .completed
            else { return nil }
            return TrainingCalendarMobilitySession(
                id: session.id,
                name: session.nameSnapshot,
                status: session.status,
                startedAt: session.startTime
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        let programSessions = mobilityProgramRuns.flatMap { run in
            schedulableSessionProgress(in: run).compactMap { progress -> TrainingCalendarProgramMobilitySession? in
                guard let scheduledDate = progress.scheduledDate, calendar.isDate(scheduledDate, inSameDayAs: date) else { return nil }
                return TrainingCalendarProgramMobilitySession(
                    id: progress.id,
                    runID: run.id,
                    programName: run.sourceProgramName,
                    sessionName: progress.displayName,
                    status: progress.status,
                    isOptional: progress.isOptional,
                    isInProgress: progress.isInProgress(activeMobilitySessionIDs: activeMobilitySessionIDs)
                )
            }
        }
        .sorted { $0.sessionName.localizedStandardCompare($1.sessionName) == .orderedAscending }

        let dayMeals = meals.filter { $0.dayKey == day.rawValue }
        let nutrition = dayMeals.isEmpty ? nil : TrainingCalendarNutritionSummary(
            totals: NutritionDaySummary.resolve(day: day, meals: dayMeals).totals,
            mealCount: dayMeals.count
        )
        let checkIn = checkIns.first(where: { $0.dayKey == day.rawValue }).map {
            TrainingCalendarCheckInSummary(status: $0.status)
        }
        let creatine = supplementOccurrences.first(where: {
            $0.dayKey == day.rawValue && $0.kind == .creatine
        })?.status

        return TrainingCalendarDay(
            date: calendar.startOfDay(for: date),
            day: day,
            isInDisplayedMonth: isInDisplayedMonth,
            plannedWorkouts: plannedWorkouts,
            freeWorkouts: freeWorkouts,
            mobilitySessions: projectedMobility,
            mobilityProgramSessions: programSessions,
            nutrition: nutrition,
            checkIn: checkIn,
            creatine: creatine
        )
    }

    private static func dates(from start: Date, until end: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var date = start
        while date < end {
            result.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }
}
