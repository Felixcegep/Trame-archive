import SwiftData
import SwiftUI

/// A navigation hub for recorded facts across GymTracker's product pillars.
/// It deliberately links to domain-owned history instead of copying or
/// reinterpreting their persisted truth.
struct ProgressHubView: View {
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    @Query(
        filter: #Predicate<Workout> { $0.endTime != nil },
        sort: \Workout.startTime,
        order: .reverse
    ) private var workouts: [Workout]
    @Query(
        filter: #Predicate<MobilitySession> { $0.statusRaw == "completed" },
        sort: \MobilitySession.startTime,
        order: .reverse
    ) private var mobilitySessions: [MobilitySession]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse) private var assessmentSessions: [MobilityAssessmentSession]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \DailyLogEntry.createdAt, order: .reverse) private var dailyLogEntries: [DailyLogEntry]
    @Query private var planRuns: [PlanRun]
    @Query private var repeatingPlanRuns: [RepeatingPlanRun]
    @Query private var trainingProfiles: [TrainingProfile]
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var onOpenPlan: ((UUID) -> Void)? = nil
    var onNavigate: (ProgressRoute) -> Void = { _ in }

    @State private var overviewRange: AnalyticsDateRange = .twelveWeeks
    @State private var overviewState: ProgressOverviewState = .loading
    @State private var selectedLens: ProgressLens = .global
    @State private var isEditingAthleteProfile = false
    /// Collapsed on every appearance rather than remembered. The three rows
    /// inside are visited rarely and deliberately; restoring an expansion from
    /// a previous session would put them back at the weight this change exists
    /// to take away.
    @State private var isShowingTools = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                progressControls

                if selectedLens == .global {
                    ProgressOverviewSection(
                        range: overviewRange,
                        state: overviewState,
                        onOpenPlan: onOpenPlan,
                        onNavigate: onNavigate,
                        presentation: .all
                    )
                } else if hasOverviewEvidence {
                    AthleteIntelligenceSection(
                        selectedLens: $selectedLens,
                        isEditingProfile: $isEditingAthleteProfile,
                        range: overviewRange,
                        workouts: workouts,
                        showsGlobalSummary: false,
                        showsLensPicker: false,
                        onNavigate: onNavigate
                    )
                }

                exploreGroup
                supportingHistoryGroup
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.top, Spacing.s)
            .padding(.bottom, 96)
        }
        .background(Color.trameCanvas)
        .navigationTitle("Progress")
        .accessibilityIdentifier("progress-screen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingAthleteProfile = true
                } label: {
                    Image(systemName: AppIcon.settings)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                        .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Training profile")
                .accessibilityHint("Edits sport priorities without changing training history.")
                .accessibilityIdentifier("progress-athlete-profile")
            }
        }
        .sheet(isPresented: $isEditingAthleteProfile) {
            NavigationStack {
                TrainingProfileSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isEditingAthleteProfile = false }
                        }
                    }
            }
        }
        // Recomputed from the already-observed records when the range or a
        // contributing collection changes, rather than on every body pass.
        .task(id: overviewInputID) {
            overviewState = loadOverview()
        }
    }

    private var hasOverviewEvidence: Bool {
        if case .loaded = overviewState { return true }
        return false
    }

    private var progressControls: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            lensPicker
            rangePicker
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("progress-controls")
    }

    private var lensPicker: some View {
        Menu {
            Picker("Progress lens", selection: $selectedLens) {
                ForEach(availableLenses, id: \.self) { lens in
                    Text(lens.title)
                        .tag(lens)
                        .accessibilityIdentifier("progress-lens-\(lensIdentifier(lens))")
                }
            }
        } label: {
            HStack(spacing: Spacing.s) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(lensColor(selectedLens))
                    .frame(width: 10, height: 10)
                Text(selectedLens.title)
                    .font(AppFont.bodyMedium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AppFont.micro)
            }
            .foregroundStyle(Color.trameText)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
        }
        .accessibilityLabel("Progress lens")
        .accessibilityValue(selectedLens.title)
        .accessibilityIdentifier("progress-sport-lens-picker")
    }

    private func lensColor(_ lens: ProgressLens) -> Color {
        switch lens {
        case .global: return Color.trameText
        case let .sport(discipline): return SportDisciplinePalette.color(for: discipline)
        }
    }

    private var rangePicker: some View {
        Picker("Progress range", selection: $overviewRange) {
            ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                Text(rangeShortTitle(range)).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .accessibilityLabel("Progress range")
        .accessibilityValue(overviewRange.title)
        .accessibilityIdentifier("progress-overview-range")
    }

    private func rangeShortTitle(_ range: AnalyticsDateRange) -> String {
        switch range {
        case .fourWeeks: "4W"
        case .twelveWeeks: "12W"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .allTime: "All"
        }
    }

    private var exploreGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TrameSectionRule(title: "Explore")

            LibraryOpenGroup {
                progressLink(
                    route: .workoutHistory,
                    title: "History",
                    count: "\(completedWorkouts.count)"
                )
                progressLink(
                    route: .records,
                    title: "Records"
                )
                progressLink(
                    route: .trainingTrends,
                    title: "Trends"
                )
                progressLink(
                    route: .muscleGroupVolume,
                    title: "Muscles"
                )

                DisclosureGroup(isExpanded: $isShowingTools) {
                    VStack(alignment: .leading, spacing: 0) {
                        progressLink(
                            route: .weightlifting,
                            title: "Weightlifting"
                        )
                        progressLink(
                            route: .trainingLedger,
                            title: String(localized: "progression.ledger.title", defaultValue: "Training ledger")
                        )
                        progressLink(
                            route: .coachExchange,
                            title: String(localized: "coach.exchange.title", defaultValue: "Coach exchange")
                        )
                    }
                } label: {
                    HStack(spacing: Spacing.m) {
                        TrameCategoryTile(systemImage: AppIcon.export, fill: Color.trameCompetition, size: ComponentSize.iconChip)
                        Text("Tools")
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(Color.trameText)
                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .tint(Color.trameText)
                .accessibilityIdentifier("progress-tools-disclosure")
            }
        }
    }

    private var supportingHistoryGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TrameSectionRule(title: "More history")

            LibraryOpenGroup {
                progressLink(
                    route: .supportingHistory(.mobility),
                    title: "Mobility & Check-ins",
                    count: "\(completedMobilitySessions.count + dailyLogEntries.count)"
                )
                if featureFlags.isEnabled(.mobilityAssessment) {
                    progressLink(
                        route: .mobilityAssessmentHistory,
                        title: "Assessments",
                        count: recordedAssessmentSessions.isEmpty ? nil : "\(recordedAssessmentSessions.count)"
                    )
                }
            }
        }
    }

    private var availableLenses: [ProgressLens] {
        let profile = trainingProfiles.first
        let availability = ProgressSportLensAvailabilityProjector.project(
            workouts: completedWorkouts,
            primary: profile?.primaryDiscipline,
            secondary: profile?.secondaryDisciplines ?? []
        )
        .filter { $0.isAvailable && $0.discipline != .mixed }
        .sorted {
            if $0.isProfilePriority != $1.isProfilePriority { return $0.isProfilePriority }
            if $0.evidenceWorkoutCount != $1.evidenceWorkoutCount {
                return $0.evidenceWorkoutCount > $1.evidenceWorkoutCount
            }
            return $0.discipline.title < $1.discipline.title
        }

        var lenses: [ProgressLens] = [.global]
        if profile?.progressOrganizationMode == .mixed || availability.count > 1 {
            lenses.append(.sport(.mixed))
        }
        lenses.append(contentsOf: availability.map { .sport($0.discipline) })
        return lenses
    }

    private func lensIdentifier(_ lens: ProgressLens) -> String {
        switch lens {
        case .global: "global"
        case let .sport(discipline): discipline.rawValue
        }
    }

    /// Projects the overview from the hub's existing SwiftData observations.
    ///
    /// Synchronous on the main actor by design: the inputs are SwiftData model
    /// objects and must not cross to a detached task.
    private func loadOverview() -> ProgressOverviewState {
        guard completedWorkouts.isEmpty == false else { return .empty }

        let displayWeightType: WeightType = unitSystem == .metric ? .kg : .lbs
        let calendar = Calendar.current

        let consistency = TrainingConsistencyAnalyticsService.analytics(
            workouts: workouts,
            calendar: calendar
        )
        let workoutProjection = PersonalRecordAnalyticsService.overviewAnalytics(
            workouts: workouts,
            dateRange: overviewRange,
            displayWeightType: displayWeightType
        )
        let records = workoutProjection.selectedRecords
        let series = workoutProjection.exerciseSeries

        let journey = TrainingJourneyBuilder().summary(
            workouts: workouts,
            fixedRuns: planRuns,
            repeatingRuns: repeatingPlanRuns,
            calendar: calendar
        )
        let rangeInterval = overviewRange.dateInterval()
        let workoutsInRange = completedWorkouts.filter { workout in
            rangeInterval.map { $0.contains(workout.startTime) } ?? true
        }
        let globalProjection = GlobalProgressProjection.project(workouts: workoutsInRange)
        let globalInterval = rangeInterval ?? DateInterval(
            start: completedWorkouts.map(\.startTime).min() ?? .now,
            end: Date.now.addingTimeInterval(1)
        )
        let sportTimeline = ProgressSportFocusTimeline.project(
            workouts: completedWorkouts,
            interval: globalInterval
        )
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
                completedWorkoutsInRange: globalProjection.completedWorkoutCount,
                completedEntriesInRange: globalProjection.completedEntryCount,
                trainingTimeInRangeText: globalProjection.trainingTime.map(trainingTimeText),
                sportEvidence: globalProjection.sportHighlights.compactMap { highlight in
                    guard highlight.metric == .completedWorkouts,
                          let value = highlight.value
                    else { return nil }
                    return ProgressOverviewSportEvidence(
                        discipline: highlight.discipline,
                        completedWorkoutCount: Int(value),
                        quality: highlight.quality
                    )
                },
                hasComparableSportFocus: sportTimeline.quality == .adequate
                    && sportTimeline.periods.filter(\.hasEvidence).count >= 2,
                weeklyFrequency: consistency.weeklyFrequency,
                currentPlanID: currentPlanID,
                currentPlanName: currentPlanName,
                currentPlanPhaseText: currentPlanPhaseText,
                latestRecord: records.max { $0.date < $1.date },
                featuredSeries: series.max { totalPoints($0) < totalPoints($1) },
                mobilitySessionsInRange: completedMobilitySessions.filter { session in
                    rangeInterval.map { $0.contains(session.startTime) } ?? true
                }.count,
                assessmentRecencyText: assessmentRecencyText,
                latestChapterTitle: journey.latestChapterTitle,
                journeySummaryText: journeySummaryText(journey)
            )
        )
    }

    /// Counts chapters rather than naming a "milestone": a chapter count is a
    /// fact the records support, where "3 milestones" would be a category this
    /// app has never defined.
    private func journeySummaryText(_ journey: TrainingJourneySummary) -> String {
        guard journey.chapterCount > 0 else { return "Your training history appears here as you complete workouts." }
        let chapterText = journey.chapterCount == 1 ? "1 chapter" : "\(journey.chapterCount) chapters"
        let yearText = journey.yearCount == 1 ? "1 year" : "\(journey.yearCount) years"
        return "\(chapterText) across \(yearText)"
    }

    private func totalPoints(_ series: ExerciseProgressSeries) -> Int {
        series.loadPoints.count + series.volumePoints.count + series.repsPoints.count
    }

    /// Nil rather than "0m" when nothing was recorded: an absent duration and a
    /// zero-length session are different facts.
    private func trainingTimeText(_ seconds: TimeInterval) -> String {
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

    /// A compact revision over the roots consumed by the overview. Completed
    /// workout graphs are immutable by domain contract; additions, deletions,
    /// and restores change their UUID set, so traversing every exercise and set
    /// here would duplicate the analytics cost on every unrelated body update.
    /// The remaining domains expose `updatedAt` for their mutable projections.
    private var overviewInputID: Int {
        var revision = Hasher()
        revision.combine(overviewRange)
        revision.combine(LocalDay.today.rawValue)
        revision.combine(unitSystem.rawValue)
        for workout in completedWorkouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
            revision.combine(workout.sportRawValue)
        }
        for session in completedMobilitySessions {
            revision.combine(session.id)
            revision.combine(session.updatedAt)
        }
        for session in recordedAssessmentSessions {
            revision.combine(session.id)
            revision.combine(session.updatedAt)
            for result in session.results {
                revision.combine(result.id)
                revision.combine(result.updatedAt)
            }
        }
        for run in planRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        for run in repeatingPlanRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        return revision.finalize()
    }

    private var completedMobilitySessions: [MobilitySession] {
        mobilitySessions.filter { $0.status == .completed }
    }

    /// A sitting that saved nothing measured nothing, so it is not counted as a
    /// recorded assessment.
    private var recordedAssessmentSessions: [MobilityAssessmentSession] {
        assessmentSessions.filter { $0.results.isEmpty == false }
    }

    private func progressLink(
        route: ProgressRoute,
        title: String,
        count: String? = nil,
        detail: String? = nil
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.m) {
                TrameCategoryTile(systemImage: route.icon, fill: route.tint, size: ComponentSize.iconChip)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                    if let detail {
                        Text(detail)
                            .font(AppFont.metadata)
                            .foregroundStyle(Color.trameSubdued)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let count {
                    Text(count)
                        .font(AppFont.metadata)
                        .monospacedDigit()
                        .foregroundStyle(Color.trameSubdued)
                }
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
            .padding(.vertical, Spacing.md)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    var tint: Color {
        switch self {
        case .workoutHistory, .trainingTrends, .muscleGroupVolume:
            Color.trameStrength
        case .records, .weightlifting:
            Color.trameCompetition
        case .trainingJourney, .trainingLedger, .coachExchange,
             .supportingHistory:
            Color.trameRecovery
        case .mobilityAssessmentHistory:
            Color.trameMobility
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
    @Query(
        filter: #Predicate<MobilitySession> { $0.statusRaw == "completed" },
        sort: \MobilitySession.startTime,
        order: .reverse
    ) private var sessions: [MobilitySession]
    @Query private var workouts: [Workout]
    @Query private var mobilityEvidenceRecords: [MobilityResultEvidence]

    var body: some View {
        // Resolve both indexes once per render rather than rebuilding either
        // dictionary for every history row/evidence policy call.
        let workoutTitles = workoutTitlesByID
        let evidenceByResultID = Dictionary(
            mobilityEvidenceRecords.map { ($0.resultID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let analyticsPolicy = StandardMobilityAnalyticsPolicy(
            evidenceByResultID: evidenceByResultID
        )

        return Group {
            if completedSessions.isEmpty {
                SupportingHistoryEmptyState(
                    title: "No mobility yet",
                    detail: "Completed routines appear here.",
                    systemImage: AppIcon.mobility
                )
            } else {
                List {
                ForEach(completedSessions) { session in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        // The routine's recorded name stays primary; a later
                        // rename, relink, or removal never rewrites it.
                        Text(session.sourceRoutineName ?? session.nameSnapshot)
                            .font(AppFont.subheadlineSemibold)

                        Text(historyDetail(for: session, workoutTitles: workoutTitles))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                        if let evidenceDetail = evidenceDetail(
                            for: session,
                            evidenceByResultID: evidenceByResultID,
                            analyticsPolicy: analyticsPolicy
                        ) {
                            Text(evidenceDetail)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("mobility-history-context-\(session.id)")
                }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.gymBackground)
    }

    private func evidenceDetail(
        for session: MobilitySession,
        evidenceByResultID: [UUID: MobilityResultEvidence],
        analyticsPolicy: MobilityAnalyticsPolicy
    ) -> String? {
        let records = session.orderedEntries
            .flatMap(\.orderedResults)
            .compactMap { evidenceByResultID[$0.id] }
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
        if let developmentVolumeSummary = developmentVolumeSummary(
            for: session,
            analyticsPolicy: analyticsPolicy
        ) {
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
    private func developmentVolumeSummary(
        for session: MobilitySession,
        analyticsPolicy: MobilityAnalyticsPolicy
    ) -> String? {
        let entries = session.orderedEntries.filter { $0.orderedResults.isEmpty == false }
        guard entries.isEmpty == false else { return nil }
        let developmentCount = entries.filter {
            analyticsPolicy.contributesToDevelopmentVolume(entry: $0)
        }.count
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
        Group {
            if meals.isEmpty {
                SupportingHistoryEmptyState(
                    title: "No nutrition yet",
                    detail: "Logged meals appear here.",
                    systemImage: AppIcon.nutrition
                )
            } else {
                List {
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
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.gymBackground)
    }

    private var daySummaries: [NutritionHistoryDay] {
        let dayLimit = 7
        var selectedKeys: [String] = []
        selectedKeys.reserveCapacity(dayLimit)

        // Keep only the seven greatest day keys while scanning. Building a
        // set of every historical day and sorting all of it made this bounded
        // summary grow with the lifetime of the nutrition log.
        for meal in meals {
            let key = meal.dayKey
            guard selectedKeys.contains(key) == false else { continue }
            let insertionIndex = selectedKeys.firstIndex { key > $0 }
                ?? selectedKeys.endIndex
            guard insertionIndex < dayLimit else { continue }
            selectedKeys.insert(key, at: insertionIndex)
            if selectedKeys.count > dayLimit {
                selectedKeys.removeLast()
            }
        }

        let selectedKeySet = Set(selectedKeys)
        var mealsByDay: [String: [LoggedMeal]] = [:]
        for meal in meals where selectedKeySet.contains(meal.dayKey) {
            mealsByDay[meal.dayKey, default: []].append(meal)
        }

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
        Group {
            if entries.isEmpty {
                SupportingHistoryEmptyState(
                    title: "No journal yet",
                    detail: "Daily check-ins appear here.",
                    systemImage: AppIcon.routine
                )
            } else {
                List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(entry.dayKey).font(AppFont.subheadlineSemibold)
                        Text(entry.status == .completed ? "Check-in complete" : "Check-in skipped")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.gymBackground)
    }
}

private struct SupportingHistoryEmptyState: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        ScrollView {
            GymCard {
                HStack(alignment: .top, spacing: Spacing.m) {
                    GymIconChip(systemImage: systemImage, tint: .gymAccent)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        Text(detail)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.m)
        }
        .accessibilityElement(children: .combine)
    }
}
