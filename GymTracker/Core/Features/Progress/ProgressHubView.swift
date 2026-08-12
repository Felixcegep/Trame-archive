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
    @Query private var planRuns: [PlanRun]
    @Query private var repeatingPlanRuns: [RepeatingPlanRun]
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var onOpenPlan: ((UUID) -> Void)? = nil

    @State private var overviewRange: AnalyticsDateRange = .twelveWeeks
    @State private var overviewState: ProgressOverviewState = .loading
    /// Collapsed on every appearance rather than remembered. The three rows
    /// inside are visited rarely and deliberately; restoring an expansion from
    /// a previous session would put them back at the weight this change exists
    /// to take away.
    @State private var isShowingTools = false

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
                ProgressOverviewSection(range: overviewRange, state: overviewState, onOpenPlan: onOpenPlan)
            } header: {
                Text("Overview")
            }

            // Four rows, not seven.
            //
            // Training history, records, trends and volume are what a lifter
            // opens Progress for. Weightlifting, the ledger and coach exchange
            // are specialist instruments — a competition dashboard, a
            // recommendation audit log, and a coach hand-off format — and
            // presenting all seven at equal weight made the four common ones
            // as hard to find as the three rare ones. Nothing is removed; the
            // rare three moved one disclosure deeper.
            Section("Training") {
                progressLink(
                    route: .workoutHistory,
                    title: "Training history",
                    detail: countDescription(completedWorkouts.count, singular: "completed workout")
                )
                progressLink(
                    route: .records,
                    title: "Records",
                    detail: "Best performed sets and exercise progress"
                )
                progressLink(
                    route: .trainingTrends,
                    title: "Exercise trends",
                    detail: "Completed load, volume, and repetition history"
                )
                progressLink(
                    route: .muscleGroupVolume,
                    title: "Muscle-group volume",
                    detail: "Estimated working-set distribution and evidence"
                )

                DisclosureGroup(isExpanded: $isShowingTools) {
                    progressLink(
                        route: .weightlifting,
                        title: "Weightlifting",
                        detail: "Full lifts, components, and quality evidence"
                    )
                    progressLink(
                        route: .trainingLedger,
                        title: String(localized: "progression.ledger.title", defaultValue: "Training ledger"),
                        detail: String(localized: "progression.ledger.entry.detail", defaultValue: "Recommendation decisions and evidence")
                    )
                    progressLink(
                        route: .coachExchange,
                        title: String(localized: "coach.exchange.title", defaultValue: "Coach exchange"),
                        detail: String(localized: "coach.exchange.entry.detail", defaultValue: "Share selected training definitions and reports")
                    )
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Tools")
                                .font(AppFont.subheadlineSemibold)
                            Text("Competition, progression evidence, and coach hand-off")
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    } icon: {
                        GymIconChip(systemImage: AppIcon.export, tint: .gymAccent)
                    }
                }
                .tint(Color.gymPrimary)
                .accessibilityIdentifier("progress-tools-disclosure")
            }

            // One row, not three.
            //
            // Mobility routines, journal check-ins and logged meals were three
            // rows opening three screens that differ only in which record they
            // list. They are now scopes inside one History screen — the row
            // still reports every count, so nothing became harder to find, and
            // the section stopped being longer than the one above it.
            Section("Supporting history") {
                progressLink(
                    route: .supportingHistory(.mobility),
                    title: "History",
                    detail: supportingHistoryDetail
                )
                if featureFlags.isEnabled(.mobilityAssessment) {
                    progressLink(
                        route: .mobilityAssessmentHistory,
                        title: "Mobility assessments",
                        detail: CountPhrase.recordedAssessments(recordedAssessmentSessions.count)
                    )
                }
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

            // The journey preview reads the same projection the Journey screen
            // renders, so the card can never disagree with the screen it opens.
            let journey = try TrainingJourneyBuilder(modelContext: modelContext).journey(calendar: calendar)
            let rangeInterval = overviewRange.dateInterval()
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: .now)

            let activeFixed = planRuns.filter { $0.status == .active }
            let activeRepeating = repeatingPlanRuns.filter { $0.status == .active }
            var currentPlanID: UUID?
            var currentPlanName: String?
            var currentPlanPhaseText: String?

            if activeFixed.count == 1 && activeRepeating.isEmpty {
                let run = activeFixed[0]
                currentPlanID = run.sourcePlanID
                currentPlanName = run.sourcePlanName
                currentPlanPhaseText = "Week \(run.currentWeekIndex + 1)"
            } else if activeRepeating.count == 1 && activeFixed.isEmpty {
                let run = activeRepeating[0]
                currentPlanID = run.sourcePlanID
                currentPlanName = run.sourcePlanName
                currentPlanPhaseText = "Cycle \(run.completedCycleCount + 1)"
            }

            return .loaded(
                ProgressOverviewSummary(
                    workoutsThisWeek: consistency.weeklyFrequency.last?.workoutCount ?? 0,
                    trainingTimeThisWeekText: trainingTimeText(in: weekInterval),
                    consistencyTakeaway: consistency.takeawayText,
                    currentPlanID: currentPlanID,
                    currentPlanName: currentPlanName,
                    currentPlanPhaseText: currentPlanPhaseText,
                    latestRecord: records.max { $0.date < $1.date },
                    featuredSeries: series.max { totalPoints($0) < totalPoints($1) },
                    mobilitySessionsInRange: completedMobilitySessions.filter { session in
                        rangeInterval.map { $0.contains(session.startTime) } ?? true
                    }.count,
                    assessmentRecencyText: assessmentRecencyText,
                    latestChapterTitle: journey.first?.chapters.first?.title,
                    journeySummaryText: journeySummaryText(journey)
                )
            )
        } catch {
            print("ProgressHubView: analytics read failed: \(error)")
            return .failed
        }
    }

    /// Counts chapters rather than naming a "milestone": a chapter count is a
    /// fact the records support, where "3 milestones" would be a category this
    /// app has never defined.
    private func journeySummaryText(_ journey: [TrainingJourneyYear]) -> String {
        let chapters = journey.reduce(0) { $0 + $1.chapters.count }
        guard chapters > 0 else { return "Your training history appears here as you complete workouts." }
        let years = journey.count
        let chapterText = chapters == 1 ? "1 chapter" : "\(chapters) chapters"
        let yearText = years == 1 ? "1 year" : "\(years) years"
        return "\(chapterText) across \(yearText)"
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

    /// Icon and tint come from the route — see `ProgressRoute.tint`. They were
    /// arguments, and `GymIconChip`'s default tint meant every row here was
    /// blue while the Overview above tinted the same destinations by mood.
    private func progressLink(route: ProgressRoute, title: String, detail: String) -> some View {
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
                GymIconChip(systemImage: route.icon, tint: route.tint)
            }
        }
        .accessibilityIdentifier("progress-\(route.accessibilityIdentifier)")
    }

    /// Every count the three rows used to report, on the one row that replaced
    /// them — collapsing rows must not cost the lifter the ability to see, from
    /// the hub, whether there is anything in there.
    ///
    /// Nutrition is omitted entirely when its flag is off, matching the scope
    /// picker inside.
    private var supportingHistoryDetail: String {
        var parts = [
            CountPhrase.completedSessions(completedMobilitySessions.count),
            countDescription(dailyLogEntries.count, singular: "daily check-in")
        ]
        if featureFlags.isEnabled(.nutrition) {
            parts.append(countDescription(loggedMeals.count, singular: "logged meal"))
        }
        return parts.joined(separator: " · ")
    }

    private func countDescription(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

extension ProgressRoute {
    /// The glyph for a destination, wherever it is drawn.
    var icon: String {
        switch self {
        case .workoutHistory: AppIcon.history
        case .trainingJourney: AppIcon.journey
        case .records: AppIcon.trophy
        case .trainingTrends: AppIcon.progression
        case .muscleGroupVolume: AppIcon.muscles
        case .weightlifting: AppIcon.trophy
        case .trainingLedger: AppIcon.progression
        case .coachExchange: AppIcon.export
        case .supportingHistory: AppIcon.routine
        case .mobilityAssessmentHistory: AppIcon.mobilityAssessment
        }
    }

    /// The tint for a destination, wherever it is drawn.
    ///
    /// One tint per route, resolved here rather than at each call site — the
    /// Overview and the hub below it previously disagreed about the same
    /// destinations, which spent the palette's meanings on decoration.
    ///
    /// The rule is the design system's own: `gymPrimary` is training data,
    /// `gymSecondary` is something achieved, `gymAccent` is supporting
    /// context. A reader should be able to infer the kind of screen from the
    /// colour before reading the label.
    var tint: Color {
        switch self {
        case .workoutHistory, .trainingTrends, .muscleGroupVolume:
            .gymPrimary
        case .records, .weightlifting:
            .gymSecondary
        case .trainingJourney, .trainingLedger, .coachExchange,
             .supportingHistory, .mobilityAssessmentHistory:
            .gymAccent
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .workoutHistory: "workout-history"
        case .trainingJourney: "training-journey"
        case .records: "records"
        case .trainingTrends: "training-trends"
        case .muscleGroupVolume: "muscle-group-volume"
        case .weightlifting: "weightlifting"
        case .trainingLedger: "training-ledger"
        case .coachExchange: "coach-exchange"
        case let .supportingHistory(scope): "supporting-history-\(scope.rawValue)"
        case .mobilityAssessmentHistory: "mobility-assessment-history"
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
    }
}
