import SwiftData
import SwiftUI

/// A navigation hub for recorded facts across GymTracker's product pillars.
/// It deliberately links to domain-owned history instead of copying or
/// reinterpreting their persisted truth.
struct ProgressHubView: View {
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse) private var assessmentSessions: [MobilityAssessmentSession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var dailyLogEntries: [DailyLogEntry]
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        List {
            Section("Training") {
                progressLink(
                    route: .workoutHistory,
                    title: "Training history",
                    detail: countDescription(completedWorkouts.count, singular: "completed workout"),
                    icon: AppIcon.history
                )
                progressLink(
                    route: .records,
                    title: "Records",
                    detail: "Best performed sets and exercise progress",
                    icon: AppIcon.trophy
                )
                progressLink(
                    route: .trainingTrends,
                    title: "Exercise trends",
                    detail: "Completed load, volume, and repetition history",
                    icon: AppIcon.progression
                )
                progressLink(
                    route: .muscleGroupVolume,
                    title: "Muscle-group volume",
                    detail: "Estimated working-set distribution and evidence",
                    icon: AppIcon.muscles
                )
            }

            Section("Supporting history") {
                // These two use inflected catalogue strings rather than
                // `countDescription`, which builds its plural by appending "s"
                // to an English singular and so cannot translate. The remaining
                // rows still carry that older pattern.
                progressLink(
                    route: .mobilityHistory,
                    title: "Mobility routines",
                    detail: CountPhrase.completedSessions(completedMobilitySessions.count),
                    icon: AppIcon.mobility
                )
                if featureFlags.isEnabled(.mobilityAssessment) {
                    progressLink(
                        route: .mobilityAssessmentHistory,
                        title: "Mobility assessments",
                        detail: CountPhrase.recordedAssessments(recordedAssessmentSessions.count),
                        icon: AppIcon.mobilityAssessment
                    )
                }
                progressLink(
                    route: .nutritionHistory,
                    title: "Nutrition history",
                    detail: countDescription(loggedMeals.count, singular: "logged meal"),
                    icon: AppIcon.nutrition
                )
                progressLink(
                    route: .journalHistory,
                    title: "Journal history",
                    detail: countDescription(dailyLogEntries.count, singular: "daily check-in"),
                    icon: AppIcon.routine
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Progress")
        .accessibilityIdentifier("progress-screen")
    }

    private var completedWorkouts: [Workout] {
        workouts.filter { $0.status == .completed }
    }

    private var completedMobilitySessions: [MobilitySession] {
        mobilitySessions.filter { $0.status == .completed }
    }

    /// A sitting that saved nothing measured nothing, so it is not counted as a
    /// recorded assessment.
    private var recordedAssessmentSessions: [MobilityAssessmentSession] {
        assessmentSessions.filter { $0.results.isEmpty == false }
    }

    private func progressLink(route: ProgressRoute, title: String, detail: String, icon: String) -> some View {
        NavigationLink(value: route) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.subheadlineSemibold)
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                }
            } icon: {
                GymIconChip(systemImage: icon)
            }
        }
        .accessibilityIdentifier("progress-\(route.accessibilityIdentifier)")
    }

    private func countDescription(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

extension ProgressRoute {
    var accessibilityIdentifier: String {
        switch self {
        case .workoutHistory: "workout-history"
        case .records: "records"
        case .trainingTrends: "training-trends"
        case .muscleGroupVolume: "muscle-group-volume"
        case .mobilityHistory: "mobility-history"
        case .mobilityAssessmentHistory: "mobility-assessment-history"
        case .nutritionHistory: "nutrition-history"
        case .journalHistory: "journal-history"
        }
    }
}

struct MobilityHistoryView: View {
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var sessions: [MobilitySession]
    @Query private var workouts: [Workout]

    var body: some View {
        // Resolved once per render rather than scanned per row.
        let workoutTitles = workoutTitlesByID

        return List {
            if completedSessions.isEmpty {
                ContentUnavailableView("No Mobility History", systemImage: AppIcon.mobility, description: Text("Complete a mobility routine to review it here."))
            } else {
                ForEach(completedSessions) { session in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        // The routine's recorded name stays primary; a later
                        // rename, relink, or removal never rewrites it.
                        Text(session.sourceRoutineName ?? session.nameSnapshot)
                            .font(AppFont.subheadlineSemibold)

                        Text(historyDetail(for: session, workoutTitles: workoutTitles))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("mobility-history-context-\(session.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Mobility history")
    }

    private var completedSessions: [MobilitySession] { sessions.filter { $0.status == .completed } }

    private var workoutTitlesByID: [UUID: String] {
        Dictionary(
            workouts.map { ($0.id, $0.displayTitle) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func historyDetail(
        for session: MobilitySession,
        workoutTitles: [UUID: String]
    ) -> String {
        let date = session.startTime.formatted(.dateTime.month(.abbreviated).day().year())
        guard session.context != .standalone else { return date }

        // A deleted workout loses its name, never the before/after context the
        // completed session recorded.
        let workoutName = session.workoutID.flatMap { workoutTitles[$0] }

        switch (session.context, workoutName) {
        case (.warmup, .some(let name)):
            return String(localized: "Before \(name) · \(date)")
        case (.cooldown, .some(let name)):
            return String(localized: "After \(name) · \(date)")
        case (.warmup, .none):
            return String(localized: "Before workout · \(date)")
        case (.cooldown, .none):
            return String(localized: "After workout · \(date)")
        case (.standalone, _):
            return date
        }
    }
}

struct NutritionHistoryView: View {
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var meals: [LoggedMeal]

    var body: some View {
        List {
            if meals.isEmpty {
                ContentUnavailableView("No Nutrition History", systemImage: AppIcon.nutrition, description: Text("Log food to build your nutrition history."))
            } else {
                Section("Last 7 days") {
                    ForEach(daySummaries) { summary in
                        HStack {
                            Text(summary.day.rawValue)
                            Spacer()
                            Text("\(FoodLibraryService.format(summary.totals.calories)) kcal")
                                .font(AppFont.subheadlineSemibold)
                            Text("P \(FoodLibraryService.format(summary.totals.protein)) g")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                        .accessibilityLabel("\(summary.day.rawValue), \(FoodLibraryService.format(summary.totals.calories)) calories, \(FoodLibraryService.format(summary.totals.protein)) grams protein")
                    }
                }

                Section("Recent meals") {
                    ForEach(meals.prefix(20)) { meal in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(meal.nameSnapshot).font(AppFont.subheadlineSemibold)
                            Text("\(meal.slot.displayName) · \(meal.loggedAt.formatted(.dateTime.month(.abbreviated).day().year()))")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Nutrition history")
    }

    private var daySummaries: [NutritionHistoryDay] {
        let selectedKeys = Set(meals.map(\.dayKey))
            .sorted(by: >)
            .prefix(7)
        let mealsByDay = Dictionary(grouping: meals, by: \.dayKey)
        return selectedKeys.map { key in
            let day = LocalDay(rawValue: key)
            return NutritionHistoryDay(
                day: day,
                totals: NutritionDaySummary.resolve(day: day, meals: mealsByDay[key] ?? []).totals
            )
        }
    }
}

private struct NutritionHistoryDay: Identifiable {
    let day: LocalDay
    let totals: NutritionMacroTotals

    var id: String { day.rawValue }
}

struct JournalHistoryView: View {
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var entries: [DailyLogEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No Journal History", systemImage: AppIcon.routine, description: Text("Complete a daily check-in to review it here."))
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(entry.dayKey).font(AppFont.subheadlineSemibold)
                        Text(entry.status == .completed ? "Check-in complete" : "Check-in skipped")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Journal history")
    }
}
