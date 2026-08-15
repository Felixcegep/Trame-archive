import SwiftData
import SwiftUI

/// The lifter's training history across plans, newest first.
///
/// Program Path answers "where am I inside this run". This answers the
/// different question of what the whole history has looked like — which plans
/// were followed, for how long, and what came out of them.
///
/// Vertical and chronological by design, not as a fallback: it is the
/// representation that survives Dynamic Type and reads correctly under
/// VoiceOver, so it is the one that ships first and stays.
struct TrainingJourneyView: View {
    @Query(
        filter: #Predicate<Workout> { $0.endTime != nil },
        sort: \Workout.startTime,
        order: .forward
    ) private var workouts: [Workout]
    @Query private var fixedRuns: [PlanRun]
    @Query private var repeatingRuns: [RepeatingPlanRun]
    @Query(
        filter: #Predicate<MobilitySession> { $0.statusRaw == "completed" },
        sort: \MobilitySession.startTime,
        order: .forward
    ) private var mobilitySessions: [MobilitySession]
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .forward)
    private var assessments: [MobilityAssessmentSession]

    @State private var years: [TrainingJourneyYear] = []
    @State private var loadState: LoadState = .loading
    @State private var presentation: JourneyPresentation = .list
    @State private var timelineProjection: TrainingJourneyTimelineProjection?
    @State private var practiceTransitions = TrainingJourneyPracticeTransitionProjection(markers: [])
    @State private var timelineDate = Date.now

    private enum LoadState: Equatable {
        case loading
        case failed
        case ready
    }

    private enum JourneyPresentation: String, CaseIterable, Identifiable {
        case list
        case timeline

        var id: String { rawValue }
        var title: String {
            switch self {
            case .list: "List"
            case .timeline: "Timeline"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Journey view", selection: $presentation) {
                ForEach(JourneyPresentation.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .accessibilityIdentifier("training-journey-presentation")

            Group {
                switch presentation {
                case .list:
                    listContent
                case .timeline:
                    timelineContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.gymBackground)
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-journey-screen")
        .task(id: journeyInputID) {
            let projectedYears = TrainingJourneyBuilder().journey(
                workouts: workouts,
                fixedRuns: fixedRuns,
                repeatingRuns: repeatingRuns,
                mobilitySessions: mobilitySessions,
                assessments: assessments
            )
            years = projectedYears
            let chapters = projectedYears.flatMap(\.chapters)
            let timeline = TrainingJourneyTimelineProjectionService.project(
                chapters: chapters,
                calendar: .current,
                referenceDate: .now
            )
            timelineProjection = timeline
            practiceTransitions = TrainingJourneyPracticeTransitionProjectionService.project(
                chapters: chapters,
                timeline: timeline
            )
            if loadState == .loading
                || timelineDate < timeline.domain.start
                || timelineDate >= timeline.domain.endExclusive {
                timelineDate = chapters.first?.start ?? .now
            }
            loadState = .ready
        }
    }

    /// Root revisions are sufficient because completed workout/session graphs
    /// are immutable evidence. Mutable runs and assessment sittings expose
    /// `updatedAt`, so Journey refreshes without traversing every child merely
    /// to form the task identity.
    private var journeyInputID: Int {
        var revision = Hasher()
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
        }
        for run in fixedRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        for run in repeatingRuns {
            revision.combine(run.id)
            revision.combine(run.updatedAt)
        }
        for session in mobilitySessions {
            revision.combine(session.id)
            revision.combine(session.updatedAt)
        }
        for assessment in assessments {
            revision.combine(assessment.id)
            revision.combine(assessment.updatedAt)
        }
        revision.combine(LocalDay.today)
        return revision.finalize()
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                switch loadState {
                case .loading:
                    loadingRow
                case .failed:
                    failedRow
                case .ready:
                    if years.isEmpty {
                        emptyRow
                    } else {
                        ForEach(years) { year in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: Spacing.m) {
                                    Text(verbatim(year.year))
                                        .font(AppFont.sectionTitle)
                                        .foregroundStyle(Color.trameText)
                                    Rectangle()
                                        .fill(Color.trameSeparator)
                                        .frame(height: 1)
                                        .accessibilityHidden(true)
                                }
                                    .padding(.bottom, Spacing.s)
                                ForEach(year.chapters) { chapter in
                                    chapterRow(chapter)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Color.gymBackground)
    }

    @ViewBuilder
    private var timelineContent: some View {
        switch loadState {
        case .loading:
            VStack {
                ProgressView()
                Text("Reading your history…")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("training-journey-loading")
        case .failed:
            failedRow
                .padding(Spacing.l)
        case .ready:
            if let timelineProjection,
               timelineProjection.lanes.contains(where: { $0.segments.isEmpty == false }) {
                TrainingJourneyTimelineView(
                    projection: timelineProjection,
                    selectedDate: $timelineDate,
                    practiceTransitions: practiceTransitions
                )
            } else {
                emptyRow
                    .padding(Spacing.l)
            }
        }
    }

    // MARK: - Rows

    private func chapterRow(_ chapter: TrainingJourneyChapter) -> some View {
        NavigationLink {
            TrainingJourneyChapterEvidenceView(chapter: chapter)
        } label: {
            HStack(alignment: .top, spacing: Spacing.m) {
                Rectangle()
                    .fill(tint(for: chapter.kind))
                    .frame(width: Spacing.xs)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(chapter.title)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)

                    Text(dateRangeText(chapter))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)

                    if let statusText = chapter.statusText {
                        // Status is a word, never a colour alone — a paused run and
                        // a completed one must be distinguishable without relying
                        // on the chip tint.
                        Text(statusText)
                            .font(AppFont.micro)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.trameSubdued)
                    }

                    Text(summaryText(chapter))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let disciplineSummary = TrainingJourneyChapterEvidencePresentation.summary(
                        distribution: chapter.disciplineDistribution
                    ) {
                        Text(disciplineSummary)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymDataEmphasis)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
            .padding(.vertical, Spacing.m)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.trameSeparator)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(chapter))
        .accessibilityHint(String(localized: "training.journey.chapter.drilldown.hint", defaultValue: "Shows the recorded discipline and workout evidence for this chapter."))
        .accessibilityIdentifier("training-journey-chapter-\(chapter.id)")
    }

    private var loadingRow: some View {
        HStack(spacing: Spacing.m) {
            ProgressView()
            Text("Reading your history…")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .accessibilityIdentifier("training-journey-loading")
    }

    /// Distinct from empty: a failed read must not look like "you never trained".
    private var failedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Journey unavailable")
            Text("Your history could not be read just now. Training history and records still open from Progress.")
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("training-journey-failed")
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "No training history yet")
            Text("Complete a workout, or start a plan, and it appears here as a chapter of your training.")
                .font(AppFont.body)
                .foregroundStyle(Color.trameSubdued)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("training-journey-empty")
    }

    // MARK: - Presentation

    private func verbatim(_ year: Int) -> String {
        // Year is an identifier, not a formatted number: `1 234` or `1,234`
        // would be wrong in every locale.
        String(year)
    }

    private func tint(for kind: TrainingJourneyChapter.Kind) -> Color {
        switch kind {
        case .fixedPlan: .trameStrength
        case .repeatingPlan: .trameCompleted
        case .freeTraining: .trameSubdued
        }
    }

    private func dateRangeText(_ chapter: TrainingJourneyChapter) -> String {
        let start = chapter.start.formatted(date: .abbreviated, time: .omitted)
        guard let end = chapter.end else { return "\(start) — now" }
        let endText = end.formatted(date: .abbreviated, time: .omitted)
        // A chapter that began and ended on one day reads as a date, not as a
        // range from a day to itself.
        return start == endText ? start : "\(start) — \(endText)"
    }

    /// Counts are listed, never fused into a score. A "journey score" would
    /// invent a comparison the records do not support.
    private func summaryText(_ chapter: TrainingJourneyChapter) -> String {
        var parts: [String] = [
            chapter.completedWorkouts == 1 ? "1 workout" : "\(chapter.completedWorkouts) workouts"
        ]
        if chapter.personalRecords > 0 {
            parts.append(chapter.personalRecords == 1 ? "1 record" : "\(chapter.personalRecords) records")
        }
        if chapter.mobilitySessions > 0 {
            parts.append(
                chapter.mobilitySessions == 1
                    ? "1 mobility session"
                    : "\(chapter.mobilitySessions) mobility sessions"
            )
        }
        if chapter.assessments > 0 {
            parts.append(chapter.assessments == 1 ? "1 assessment" : "\(chapter.assessments) assessments")
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(_ chapter: TrainingJourneyChapter) -> String {
        [
            chapter.title,
            dateRangeText(chapter),
            chapter.statusText,
            summaryText(chapter),
            TrainingJourneyChapterEvidencePresentation.summary(distribution: chapter.disciplineDistribution)
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// Evidence drill-down for one chapter. It remains read-only and resolves
/// source references back to the existing completed workouts; no Journey or
/// reporting data is persisted.
struct TrainingJourneyChapterEvidenceView: View {
    let chapter: TrainingJourneyChapter

    @Query(sort: \Workout.startTime, order: .reverse)
    private var workouts: [Workout]

    private var presentation: TrainingJourneyChapterEvidencePresentation {
        .make(distribution: chapter.disciplineDistribution)
    }

    var body: some View {
        let workoutsByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                if presentation.hasEvidence {
                    disciplineSection
                    evidenceSection(workoutsByID: workoutsByID)
                } else {
                    GymCard {
                        ContentUnavailableView(
                            String(localized: "training.journey.chapter.empty.title", defaultValue: "No completed exercise evidence"),
                            systemImage: AppIcon.history,
                            description: Text(String(localized: "training.journey.chapter.empty.detail", defaultValue: "This chapter has no completed exercise entries to classify."))
                        )
                    }
                }

                Text(String(localized: "training.journey.chapter.method.note", defaultValue: "Disciplines come from the completed entry snapshot. Unclassified entries remain unclassified instead of being inferred from the current exercise catalogue."))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("training-journey-chapter-method-note")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(String(localized: "training.journey.chapter.title", defaultValue: "Chapter evidence"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("training-journey-chapter-evidence")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(chapter.title)
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            Text(dateRangeText)
                .font(AppFont.subheadline)
                .foregroundStyle(Color.gymSubduedText)
            Text(summaryText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(
                title: String(localized: "training.journey.chapter.disciplines.title", defaultValue: "Recorded disciplines"),
                detail: String(localized: "training.journey.chapter.disciplines.detail", defaultValue: "Descriptive distribution from completed exercise entries.")
            )

            GymCard {
                ForEach(presentation.slices) { slice in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                            Text(slice.title)
                                .font(AppFont.subheadlineSemibold)
                                .foregroundStyle(Color.gymText)
                            Spacer(minLength: Spacing.s)
                            Text(slice.entryCountLabel)
                                .font(AppFont.captionSemiboldMonospaced)
                                .foregroundStyle(Color.gymDataEmphasis)
                        }
                        Text(slice.proportionLabel)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                        if slice.recordKindTitles.isEmpty == false {
                            Text(slice.recordKindTitles.joined(separator: " · "))
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(slice.accessibilityLabel)
                    .accessibilityIdentifier("training-journey-discipline-\(slice.id)")

                    if slice.id != presentation.slices.last?.id {
                        Divider()
                    }
                }
            }
        }
        .accessibilityIdentifier("training-journey-discipline-section")
    }

    private func evidenceSection(workoutsByID: [UUID: Workout]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(
                title: String(localized: "training.journey.chapter.evidence.title", defaultValue: "Source evidence"),
                detail: String(localized: "training.journey.chapter.evidence.detail", defaultValue: "Completed workouts contributing to each recorded slice.")
            )

            ForEach(presentation.slices) { slice in
                GymCard {
                    Text(slice.title)
                        .font(AppFont.subheadlineSemibold)
                        .foregroundStyle(Color.gymText)
                    ForEach(slice.evidence) { source in
                        if let workout = workoutsByID[source.workoutID] {
                            NavigationLink {
                                HistoryWorkoutView(workout: workout)
                            } label: {
                                sourceRow(workout: workout, source: source)
                            }
                            .accessibilityIdentifier("training-journey-source-\(source.id)")
                        } else {
                            sourceUnavailableRow(source)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("training-journey-evidence-section")
    }

    private func sourceRow(workout: Workout, source: AnalyticsSourceReference) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: AppIcon.history)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.displayTitle)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
                Text(workout.startTime, format: .dateTime.month(.abbreviated).day().year())
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                if let entryID = source.entryID {
                    Text(String(format: String(localized: "training.journey.chapter.evidence.entry", defaultValue: "Entry %@"), String(entryID.uuidString.prefix(8))))
                        .font(AppFont.caption2)
                        .foregroundStyle(Color.gymSubduedText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func sourceUnavailableRow(_ source: AnalyticsSourceReference) -> some View {
        Label(
            String(localized: "training.journey.chapter.evidence.unavailable", defaultValue: "Completed workout evidence is unavailable"),
            systemImage: AppIcon.info
        )
        .font(AppFont.caption)
        .foregroundStyle(Color.gymSubduedText)
        .accessibilityLabel("\(String(localized: "training.journey.chapter.evidence.unavailable", defaultValue: "Completed workout evidence is unavailable")), \(source.workoutID.uuidString)")
    }

    private var dateRangeText: String {
        let start = chapter.start.formatted(date: .abbreviated, time: .omitted)
        guard let end = chapter.end else { return "\(start) — \(String(localized: "common.now", defaultValue: "now"))" }
        let endText = end.formatted(date: .abbreviated, time: .omitted)
        return start == endText ? start : "\(start) — \(endText)"
    }

    private var summaryText: String {
        let count = chapter.completedWorkouts
        return count == 1
            ? String(localized: "training.journey.chapter.one.workout", defaultValue: "1 completed workout")
            : String(format: String(localized: "training.journey.chapter.workouts", defaultValue: "%lld completed workouts"), Int64(count))
    }
}

private extension TrainingJourneyChapterEvidencePresentation.DisciplineSlice {
    var entryCountLabel: String {
        entryCount == 1
            ? String(localized: "training.journey.chapter.one.entry", defaultValue: "1 entry")
            : String(format: String(localized: "training.journey.chapter.entries", defaultValue: "%lld entries"), Int64(entryCount))
    }

    var proportionLabel: String {
        let percent = (proportion * 100).rounded()
        return String(format: String(localized: "training.journey.chapter.percent", defaultValue: "%.0f%% of recorded entries"), percent)
    }

    var accessibilityLabel: String {
        [title, entryCountLabel, proportionLabel, recordKindTitles.joined(separator: ", ")]
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}
