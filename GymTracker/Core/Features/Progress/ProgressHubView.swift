import SwiftData
import SwiftUI

/// A navigation hub for recorded facts across GymTracker's product pillars.
/// It deliberately links to domain-owned history instead of copying or
/// reinterpreting their persisted truth.
struct ProgressHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query(sort: \MobilitySession.startTime, order: .reverse) private var mobilitySessions: [MobilitySession]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse) private var assessmentSessions: [MobilityAssessmentSession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var dailyLogEntries: [DailyLogEntry]
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    @State private var overviewRange: AnalyticsDateRange = .twelveWeeks
    @State private var overviewState: ProgressOverviewState = .loading

    var body: some View {
        List {
            Section {
                // The range control is a list row rather than a toolbar menu:
                // toolbar buttons do not reliably fire on pushed screens in
                // this iOS generation, and a row keeps the control reachable
                // with the same gesture as everything else on the screen.
                Picker("Period", selection: $overviewRange) {
                    ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("progress-overview-range")

                // Only the cards drop the row surface — they bring their own.
                // Clearing it for the whole section stripped the picker of its
                // grouped background too, leaving the control floating on the
                // page as if it were a caption.
                ProgressOverviewSection(range: overviewRange, state: overviewState)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: 0, trailing: 0))
            } header: {
                Text("Overview")
            }

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
                if featureFlags.isEnabled(.nutrition) {
                    progressLink(
                        route: .nutritionHistory,
                        title: "Nutrition history",
                        detail: countDescription(loggedMeals.count, singular: "logged meal"),
                        icon: AppIcon.nutrition
                    )
                }
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
        // Recomputed when the range changes rather than in `body`: these are
        // store reads, and running them as computed properties re-ran them on
        // every re-render. `task(id:)` also cancels a superseded load when the
        // lifter changes range twice quickly.
        .task(id: overviewRange) {
            overviewState = loadOverview()
        }
    }

    /// Reads the overview from the analytics services.
    ///
    /// Synchronous on the main actor by design: these services hold a
    /// `ModelContext`, which is not `Sendable`, so the work must not hop off
    /// the actor that owns it.
    private func loadOverview() -> ProgressOverviewState {
        guard completedWorkouts.isEmpty == false else { return .empty }

        let displayWeightType: WeightType = UserDefaults.standard.unitSystem == .metric ? .kg : .lbs
        let calendar = Calendar.current

        do {
            let consistency = try TrainingConsistencyAnalyticsService(modelContext: modelContext)
                .analytics(calendar: calendar)
            let records = try PersonalRecordAnalyticsService(modelContext: modelContext)
                .personalRecords(dateRange: overviewRange, displayWeightType: displayWeightType)
            let series = try ExerciseProgressAnalyticsService(modelContext: modelContext)
                .series(dateRange: overviewRange, displayWeightType: displayWeightType)

            let rangeInterval = overviewRange.dateInterval()
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now)

            return .loaded(
                ProgressOverviewSummary(
                    workoutsThisWeek: consistency.weeklyFrequency.last?.workoutCount ?? 0,
                    trainingTimeThisWeekText: trainingTimeText(in: weekInterval),
                    consistencyTakeaway: consistency.takeawayText,
                    latestRecord: records.max { $0.date < $1.date },
                    featuredSeries: series.max { totalPoints($0) < totalPoints($1) },
                    mobilitySessionsInRange: completedMobilitySessions.filter { session in
                        rangeInterval.map { $0.contains(session.startTime) } ?? true
                    }.count,
                    assessmentRecencyText: assessmentRecencyText
                )
            )
        } catch {
            print("ProgressHubView: analytics read failed: \(error)")
            return .failed
        }
    }

    private func totalPoints(_ series: ExerciseProgressSeries) -> Int {
        series.loadPoints.count + series.volumePoints.count + series.repsPoints.count
    }

    /// Nil rather than "0m" when nothing was recorded: an absent duration and a
    /// zero-length session are different facts.
    private func trainingTimeText(in interval: DateInterval?) -> String? {
        guard let interval else { return nil }
        let seconds = completedWorkouts
            .filter { interval.contains($0.startTime) }
            .reduce(into: TimeInterval.zero) { total, workout in
                guard let end = workout.endTime else { return }
                total += end.timeIntervalSince(workout.startTime)
            }
        guard seconds > 0 else { return nil }
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private var assessmentRecencyText: String {
        guard let latest = recordedAssessmentSessions.first else {
            return "No assessment recorded yet."
        }
        let days = Calendar.current.dateComponents([.day], from: latest.startedAt, to: .now).day ?? 0
        switch days {
        case 0: return "Last assessment today."
        case 1: return "Last assessment yesterday."
        default: return "Last assessment \(days) days ago."
        }
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
    @Query private var mobilityEvidenceRecords: [MobilityResultEvidence]

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
                        if let evidenceDetail = evidenceDetail(for: session) {
                            Text(evidenceDetail)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
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

    private var mobilityEvidenceByResultID: [UUID: MobilityResultEvidence] {
        Dictionary(mobilityEvidenceRecords.map { ($0.resultID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Routes this existing history surface through the mobility analytics
    /// policy rather than adding a parallel analytics screen — see
    /// `MobilityAnalyticsPolicy.swift`.
    private var analyticsPolicy: MobilityAnalyticsPolicy {
        StandardMobilityAnalyticsPolicy(evidenceByResultID: mobilityEvidenceByResultID)
    }

    private func evidenceDetail(for session: MobilitySession) -> String? {
        let records = session.orderedEntries
            .flatMap(\.orderedResults)
            .compactMap { mobilityEvidenceByResultID[$0.id] }
        guard records.isEmpty == false else { return nil }

        var labels: [String] = []
        let methods = uniqueStrings(records.compactMap(\.methodSnapshot).map(\.displayName))
        let purposes = uniqueStrings(records.compactMap(\.purposeSnapshot).map(\.displayName))
        // Stop signals (pain/numbness/tingling) are kept out of the general
        // "Sensation" line and always surfaced under their own label — stop
        // signals remain historical evidence even though they are excluded
        // from progression evidence (`MobilityResultEvidence
        // .isProgressionEligible`, `MobilityAnalyticsService
        // .stopSignalHistory`).
        let allSensations = records.compactMap(\.sensation)
        let sensations = uniqueStrings(allSensations.filter { $0.isStopSignal == false }.map(\.displayName))
        let stopSignals = uniqueStrings(allSensations.filter(\.isStopSignal).map(\.displayName))
        let qualities = uniqueStrings(records.compactMap(\.movementQuality).map(\.displayName))
        let supports = uniqueStrings(records.compactMap { ($0.performedSupportLevel ?? $0.supportLevelSnapshot)?.displayName })
        let assistances = uniqueStrings(records.compactMap { evidence in
            guard let prescription = evidence.assistancePrescriptionSnapshot else { return nil }
            let name = prescription.assistanceType?.displayName ?? prescription.assistanceTypeRaw
            let level = evidence.performedAssistanceLevel ?? prescription.level
            return level.map { String(localized: "\(name), level \($0)") } ?? name
        })
        let breathing = records.compactMap(\.performedBreathingCycles)
        let tempos = uniqueStrings(records.compactMap { evidence -> String? in
            guard let tempo = evidence.tempoPrescriptionSnapshot else { return nil }
            return [tempo.moveIntoRangeSeconds, tempo.holdSeconds, tempo.returnSeconds, tempo.pauseSeconds]
                .map { $0.map(String.init) ?? "–" }
                .joined(separator: "–")
        })
        if methods.isEmpty == false { labels.append(methods.joined(separator: ", ")) }
        if purposes.isEmpty == false { labels.append(purposes.joined(separator: ", ")) }
        if sensations.isEmpty == false { labels.append(String(localized: "Sensation: \(sensations.joined(separator: ", "))")) }
        if stopSignals.isEmpty == false { labels.append(String(localized: "Stop signal: \(stopSignals.joined(separator: ", "))")) }
        if qualities.isEmpty == false { labels.append(String(localized: "Quality: \(qualities.joined(separator: ", "))")) }
        if supports.isEmpty == false { labels.append(String(localized: "Support: \(supports.joined(separator: ", "))")) }
        if assistances.isEmpty == false { labels.append(String(localized: "Assistance: \(assistances.joined(separator: ", "))")) }
        if breathing.isEmpty == false { labels.append(String(localized: "Breathing cycles: \(breathing.map(String.init).joined(separator: ", "))")) }
        if tempos.isEmpty == false { labels.append(String(localized: "Tempo: \(tempos.joined(separator: ", ")) sec")) }
        if let developmentVolumeSummary = developmentVolumeSummary(for: session) {
            labels.append(developmentVolumeSummary)
        }
        return labels.isEmpty ? nil : labels.joined(separator: " · ")
    }

    /// Only shown when the session actually mixes preparation and
    /// development purposes — the bundled plans deliberately author
    /// preparation and development as separate sessions
    /// (Squat/Overhead Mobility Integration), so this stays silent for
    /// them; a session that does mix the two (a user-authored routine, or a
    /// future plan) gets an explicit, policy-driven breakdown rather than a
    /// silently inflated volume count.
    private func developmentVolumeSummary(for session: MobilitySession) -> String? {
        let entries = session.orderedEntries.filter { $0.orderedResults.isEmpty == false }
        guard entries.isEmpty == false else { return nil }
        let policy = analyticsPolicy
        let developmentCount = entries.filter { policy.contributesToDevelopmentVolume(entry: $0) }.count
        guard developmentCount > 0, developmentCount < entries.count else { return nil }
        return String(localized: "Development volume: \(developmentCount) of \(entries.count) exercises")
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
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
