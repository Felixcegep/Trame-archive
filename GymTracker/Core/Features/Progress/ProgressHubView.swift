import SwiftData
import SwiftUI

/// A navigation hub for recorded facts across GymTracker's product pillars.
/// It deliberately links to domain-owned history instead of copying or
/// reinterpreting their persisted truth.
struct ProgressHubView: View {
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var dailyLogEntries: [DailyLogEntry]

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
                progressLink(
                    route: .mobilityHistory,
                    title: "Mobility history",
                    detail: countDescription(completedMobilitySessions.count, singular: "completed session"),
                    icon: AppIcon.mobility
                )
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
        case .nutritionHistory: "nutrition-history"
        case .journalHistory: "journal-history"
        }
    }
}

struct MobilityHistoryView: View {
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var sessions: [MobilitySession]

    var body: some View {
        List {
            if completedSessions.isEmpty {
                ContentUnavailableView("No Mobility History", systemImage: AppIcon.mobility, description: Text("Complete a mobility routine to review it here."))
            } else {
                ForEach(completedSessions) { session in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(session.nameSnapshot).font(AppFont.subheadlineSemibold)
                        Text(session.startTime, format: .dateTime.month(.abbreviated).day().year())
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Mobility history")
    }

    private var completedSessions: [MobilitySession] { sessions.filter { $0.status == .completed } }
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
        Array(Set(meals.map(\.dayKey)))
            .sorted(by: >)
            .prefix(7)
            .map { key in
                let day = LocalDay(rawValue: key)
                return NutritionHistoryDay(
                    day: day,
                    totals: NutritionDaySummary.resolve(day: day, meals: meals).totals
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
