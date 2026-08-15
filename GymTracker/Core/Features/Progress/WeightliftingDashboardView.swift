import SwiftData
import SwiftUI

/// Specialist weightlifting evidence surface. The destination derives its
/// presentation from the authored CE6.1 projection and never manufactures a
/// best lift or treats missing evidence as zero.
struct WeightliftingDashboardDestination: View {
    @Query(
        filter: #Predicate<Workout> { $0.endTime != nil },
        sort: \Workout.startTime,
        order: .reverse
    ) private var workouts: [Workout]
    @Query(filter: #Predicate<ProgramDefinitionRecord> { !$0.isArchived })
    private var programDefinitions: [ProgramDefinitionRecord]
    @Query private var planRuns: [PlanRun]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    private let presentationOverride: WeightliftingDashboardPresentation?
    private let onStartCompetitionDay: ((Workout) -> Void)?
    @State private var presentationCache: WeightliftingPresentationCache?

    init(
        presentation: WeightliftingDashboardPresentation? = nil,
        onStartCompetitionDay: ((Workout) -> Void)? = nil
    ) {
        presentationOverride = presentation
        self.onStartCompetitionDay = onStartCompetitionDay
    }

    var body: some View {
        let inputID = presentationInputID
        let presentation = presentationOverride
            ?? presentationCache.flatMap { $0.inputID == inputID ? $0.presentation : nil }
            ?? .make(projection: .project(workouts: workouts))

        WeightliftingDashboardView(
            presentation: presentation,
            workouts: workouts,
            programDefinitions: programDefinitions,
            planRuns: planRuns,
            exercises: exercises,
            onStartCompetitionDay: onStartCompetitionDay
        )
        .task(id: inputID) {
            guard presentationOverride == nil else { return }
            presentationCache = .init(inputID: inputID, presentation: presentation)
        }
    }

    /// Completed workout graphs are immutable historical evidence. Their root
    /// identity changes when History is added, deleted, or restored, so this
    /// avoids traversing every performed set merely to decide whether the
    /// expensive weightlifting projection can be reused.
    private var presentationInputID: Int {
        var revision = Hasher()
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
        }
        return revision.finalize()
    }
}

private struct WeightliftingPresentationCache {
    let inputID: Int
    let presentation: WeightliftingDashboardPresentation
}

struct WeightliftingDashboardView: View {
    @Environment(\.calendar) private var calendar
    let presentation: WeightliftingDashboardPresentation
    let workouts: [Workout]
    let programDefinitions: [ProgramDefinitionRecord]
    let planRuns: [PlanRun]
    let exercises: [Exercise]
    let onStartCompetitionDay: ((Workout) -> Void)?
    @State private var eventDate = Date.now
    @State private var buildError: String?
    @State private var preparationCache: CompetitionPreparationCache?

    init(
        presentation: WeightliftingDashboardPresentation,
        workouts: [Workout],
        programDefinitions: [ProgramDefinitionRecord],
        planRuns: [PlanRun],
        exercises: [Exercise],
        onStartCompetitionDay: ((Workout) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.workouts = workouts
        self.programDefinitions = programDefinitions
        self.planRuns = planRuns
        self.exercises = exercises
        self.onStartCompetitionDay = onStartCompetitionDay
    }

    var body: some View {
        let inputID = preparationInputID
        let preparation = preparationCache.flatMap {
            $0.inputID == inputID ? $0.preparation : nil
        } ?? CompetitionDayPreparationService.prepare(
            workouts: workouts,
            definitions: programDefinitions,
            planRuns: planRuns,
            eventDate: eventDate,
            asOfDate: calendar.startOfDay(for: .now)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                introduction

                switch presentation.availability {
                case .empty:
                    emptyState
                case .sparse, .populated:
                    dashboardContent
                }

                competitionDaySection(preparation: preparation)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Color.trameCanvas)
        .navigationTitle(String(localized: "Weightlifting"))
        .accessibilityIdentifier("weightlifting-dashboard")
        .alert(
            String(localized: "Competition day unavailable"),
            isPresented: Binding(
                get: { buildError != nil },
                set: { if !$0 { buildError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) { buildError = nil }
        } message: {
            Text(buildError ?? String(localized: "The competition day could not be prepared."))
        }
        .task(id: inputID) {
            preparationCache = .init(inputID: inputID, preparation: preparation)
        }
    }

    private func competitionDaySection(
        preparation: CompetitionDayPreparation
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            TrameSectionRule(title: "Competition day")
            Text(String(localized: "Review evidence, then record Snatch and Clean & Jerk in the active workout."))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)

            DatePicker(
                String(localized: "Event date"),
                selection: $eventDate,
                in: calendar.startOfDay(for: .now)...,
                displayedComponents: .date
            )
            .font(AppFont.body)
            .accessibilityIdentifier("competition-event-date")

            if let proposal = preparation.proposal {
                competitionProposal(preparation: preparation, proposal: proposal)
            } else {
                Text(String(localized: "Link an Olympic-weightlifting program to review competition attempts."))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.l)
        .background(Color.trameSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("competition-day-section")
    }

    /// Covers every root field used to select a program, resolve its start,
    /// and produce attempt evidence. The evidence graphs themselves are
    /// completed snapshots and therefore do not need to be walked here.
    private var preparationInputID: Int {
        var revision = Hasher()
        revision.combine(calendar.startOfDay(for: eventDate))
        revision.combine(calendar.startOfDay(for: .now))
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.sourceProgramDefinitionID)
            revision.combine(workout.sourcePlanRunID)
        }
        for definition in programDefinitions {
            revision.combine(definition.id)
            revision.combine(definition.updatedAt)
            revision.combine(definition.isArchived)
        }
        for run in planRuns {
            revision.combine(run.id)
            revision.combine(run.startDate)
            revision.combine(run.updatedAt)
            revision.combine(run.plan?.sourceProgramDefinitionID)
        }
        return revision.finalize()
    }

    private func competitionProposal(
        preparation: CompetitionDayPreparation,
        proposal: CompetitionPreparationProposal
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let programName = preparation.programName {
                Text(programName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameText)
            }
            ForEach(CompetitionLift.allCases, id: \.self) { lift in
                let attempts = proposal.attempts(for: lift)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(lift.displayName)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.trameText)
                    Text(attemptSummary(attempts))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(lift.displayName), \(attemptSummary(attempts))")
                .accessibilityIdentifier("competition-attempts-\(lift.rawValue)")
            }

            if proposal.requiresReview {
                Label(
                    String(localized: "Some attempts need an explicit load review."),
                    systemImage: AppIcon.info
                )
                .font(AppFont.caption)
                .foregroundStyle(Color.trameText)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                startCompetitionDay(preparation: preparation, proposal: proposal)
            } label: {
                Text(String(localized: "Start competition day"))
            }
            .buttonStyle(GymPrimaryButtonStyle(prominence: .prominent))
            .disabled(onStartCompetitionDay == nil)
            .accessibilityHint(String(localized: "Creates a reviewable active workout. Performed results are saved only when you complete the workout."))
            .accessibilityIdentifier("start-competition-day")
        }
    }

    private func attemptSummary(_ attempts: [CompetitionAttemptProposal]) -> String {
        attempts.sorted { $0.attemptNumber < $1.attemptNumber }.map { attempt in
            let load = attempt.loadKg.map { String(format: "%.1f kg", $0) } ?? String(localized: "Load to review")
            return String(format: String(localized: "Attempt %lld: %@"), Int64(attempt.attemptNumber), load)
        }.joined(separator: " · ")
    }

    private func startCompetitionDay(
        preparation: CompetitionDayPreparation,
        proposal: CompetitionPreparationProposal
    ) {
        guard let onStartCompetitionDay,
              let selected = CompetitionDayPreparationService.selectedProgram(
                  workouts: workouts,
                  definitions: programDefinitions
              ) else {
            buildError = String(localized: "No authored Olympic-weightlifting program is available.")
            return
        }
        do {
            let workout = try CompetitionDayWorkoutBuilder.build(
                program: selected.payload,
                proposal: proposal,
                exercisesByID: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) }),
                unitSystem: UserDefaults.standard.unitSystem
            )
            onStartCompetitionDay(workout)
        } catch {
            buildError = error.localizedDescription
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Text(String(localized: "Weightlifting evidence"))
                    .font(AppFont.stageTitle)
                    .foregroundStyle(Color.trameText)
                Rectangle()
                    .fill(Color.trameCompetition)
                    .frame(height: 3)
                    .accessibilityHidden(true)
            }
            Text(String(localized: "Snatch and Clean & Jerk attempts, full-lift outcomes, and technical observations remain separate."))
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No weightlifting evidence"), systemImage: AppIcon.trophy)
        } description: {
            Text(String(localized: "Complete an Olympic lifting attempt to review full lifts, clean and jerk components, and quality observations."))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .accessibilityIdentifier("weightlifting-dashboard-empty")
    }

    @ViewBuilder
    private var dashboardContent: some View {
        attemptOutcomeField
        fullLiftSection
        attemptMatrix
        componentSection
        if let qualityTrend = presentation.qualityTrend {
            VStack(alignment: .leading, spacing: Spacing.s) {
                TrameSectionRule(title: "Latest quality observation")
                Text(qualityTrend)
                    .font(AppFont.body)
                    .foregroundStyle(Color.trameText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "Recorded lift-quality observations; quality is not inferred from load or outcome."))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weightlifting-quality-trend")
        }
        if let evidenceNote = presentation.evidenceNote {
            DisclosureGroup {
                Text(evidenceNote)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.s)
            } label: {
                Text(String(localized: "Evidence & method"))
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
            }
            .tint(Color.trameText)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .accessibilityIdentifier("weightlifting-evidence-note")
        }
    }

    @ViewBuilder
    private var attemptOutcomeField: some View {
        if let summary = presentation.attemptOutcomes {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text(String(localized: "ATTEMPT OUTCOMES"))
                    .font(AppFont.eyebrow)
                    .tracking(1.2)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.l) {
                        attemptOutcomeMetrics(summary)
                    }
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        attemptOutcomeMetrics(summary)
                    }
                }
                if let attemptSummary = presentation.attemptSummary {
                    Text(attemptSummary)
                        .font(AppFont.micro)
                        .accessibilityIdentifier("weightlifting-attempt-summary")
                }
            }
            .foregroundStyle(Color.trameSemanticFieldInk)
            .padding(Spacing.l)
            .background(Color.trameCompetition, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weightlifting-attempt-outcomes")
        }
    }

    @ViewBuilder
    private func attemptOutcomeMetrics(_ summary: WeightliftingAttemptOutcomeSummary) -> some View {
        attemptOutcomeMetric(String(localized: "Made"), value: summary.made, symbol: "✓")
        attemptOutcomeMetric(String(localized: "Partial"), value: summary.partial, symbol: "◐")
        attemptOutcomeMetric(String(localized: "Missed"), value: summary.missed, symbol: "×")
        attemptOutcomeMetric(String(localized: "Skipped"), value: summary.skipped, symbol: "–")
        if summary.notStarted > 0 {
            attemptOutcomeMetric(String(localized: "Not assessed"), value: summary.notStarted, symbol: "·")
        }
    }

    private func attemptOutcomeMetric(_ label: String, value: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(symbol) \(value)")
                .font(AppFont.metricCompact)
            Text(label.uppercased())
                .font(AppFont.micro)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }

    @ViewBuilder
    private var attemptMatrix: some View {
        if presentation.recentAttempts.isEmpty == false {
            VStack(alignment: .leading, spacing: Spacing.s) {
                TrameSectionRule(title: "Recent attempts")
                Text(String(localized: "Latest recorded parent attempts in performed order; each component remains separate from the full-lift result."))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                ForEach(presentation.recentAttempts) { attempt in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                            Text(attempt.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppFont.metadata)
                                .foregroundStyle(Color.trameSubdued)
                            Spacer(minLength: 0)
                            Text(attempt.load)
                                .font(AppFont.metricCompact)
                                .foregroundStyle(Color.trameText)
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: Spacing.m) {
                                componentOutcomeViews(attempt)
                            }
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                componentOutcomeViews(attempt)
                            }
                        }
                    }
                    .padding(.vertical, Spacing.s)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(attemptAccessibilityLabel(attempt))
                    if attempt.id != presentation.recentAttempts.last?.id {
                        Divider().overlay(Color.trameSeparator)
                    }
                }
            }
            .accessibilityIdentifier("weightlifting-attempt-matrix")
        }
    }

    @ViewBuilder
    private func componentOutcomeViews(_ attempt: WeightliftingRecentAttempt) -> some View {
        ForEach(Array(attempt.components.enumerated()), id: \.offset) { index, outcome in
            let label = attempt.componentLabels.indices.contains(index)
                ? attempt.componentLabels[index]
                : String(localized: "Component \(index + 1)")
            attemptOutcomeMark(label: label, symbol: attemptSymbol(outcome), color: attemptColor(outcome))
        }
        attemptOutcomeMark(
            label: String(localized: "Full lift"),
            symbol: attemptSymbol(attempt.outcome),
            color: attemptColor(attempt.outcome)
        )
    }

    private func attemptOutcomeMark(label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(symbol)
                .font(AppFont.metricCompact)
                .foregroundStyle(color)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attemptAccessibilityLabel(_ attempt: WeightliftingRecentAttempt) -> String {
        let components = attempt.components.enumerated().map { index, outcome in
            let label = attempt.componentLabels.indices.contains(index)
                ? attempt.componentLabels[index]
                : String(localized: "Component \(index + 1)")
            return "\(label), \(outcome.title)"
        }
        return ([
            attempt.date.formatted(date: .abbreviated, time: .omitted),
            attempt.load
        ] + components + [String(localized: "Full lift, \(attempt.outcome.title)")])
            .joined(separator: ", ")
    }

    private func attemptSymbol(_ outcome: ComplexComponentOutcome) -> String {
        switch outcome {
        case .completed: "✓"
        case .partial: "◐"
        case .missed: "×"
        case .skipped: "–"
        case .notStarted: "·"
        }
    }

    private func attemptSymbol(_ outcome: OlympicAttemptOutcome) -> String {
        switch outcome {
        case .made: "✓"
        case .partial: "◐"
        case .missed: "×"
        case .skipped: "–"
        case .notStarted: "·"
        }
    }

    private func attemptColor(_ outcome: ComplexComponentOutcome) -> Color {
        switch outcome {
        case .completed: .trameCompleted
        case .partial, .missed: .trameAttention
        case .skipped, .notStarted: .trameSubdued
        }
    }

    private func attemptColor(_ outcome: OlympicAttemptOutcome) -> Color {
        switch outcome {
        case .made: .trameCompleted
        case .partial, .missed: .trameAttention
        case .skipped, .notStarted: .trameSubdued
        }
    }

    private var fullLiftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Complete parent lifts")

            if presentation.fullLiftBests.isEmpty == false {
                ForEach(presentation.fullLiftBests) { metric in
                    metricBlock(metric, identifier: "weightlifting-full-lift-best")
                }
            } else if let fullLiftBest = presentation.fullLiftBest {
                metricBlock(fullLiftBest, identifier: "weightlifting-full-lift-best")
            } else {
                unavailableMetric(String(localized: "No complete full-lift result recorded yet."))
            }

            if presentation.attemptOutcomes == nil, let attemptSummary = presentation.attemptSummary {
                Text(attemptSummary)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightlifting-attempt-summary")
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: "Component evidence")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    componentMetricBlocks
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    componentMetricBlocks
                }
            }

            if presentation.componentOutcomes.isEmpty {
                unavailableMetric(String(localized: "Component outcomes are not recorded yet."))
            } else {
                ForEach(presentation.componentOutcomes) { summary in
                    componentOutcomeRow(summary)
                }
            }
        }
    }

    @ViewBuilder
    private var componentMetricBlocks: some View {
        metricBlock(
            presentation.cleanBest ?? unavailableMetricModel(title: String(localized: "Clean")),
            identifier: "weightlifting-clean-best"
        )
        metricBlock(
            presentation.jerkAfterCleanBest ?? unavailableMetricModel(title: String(localized: "Jerk after clean")),
            identifier: "weightlifting-jerk-after-clean-best"
        )
    }

    private func metricBlock(
        _ metric: WeightliftingDashboardMetric,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(metric.title)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
                .textCase(.uppercase)

            if let value = metric.value, metric.evidenceAvailable {
                Text(value)
                    .font(AppFont.metricLarge)
                    .foregroundStyle(Color.trameText)
            } else {
                Text(String(localized: "Not recorded"))
                    .font(AppFont.metricCompact)
                    .foregroundStyle(Color.trameSubdued)
            }

            if let detail = metric.detail {
                Text(detail)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metricAccessibilityLabel(metric))
        .accessibilityIdentifier(identifier)
    }

    private func unavailableMetric(_ message: String) -> some View {
        Text(message)
            .font(AppFont.metadata)
            .foregroundStyle(Color.trameSubdued)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Spacing.xs)
    }

    private func unavailableMetricModel(title: String) -> WeightliftingDashboardMetric {
        WeightliftingDashboardMetric(
            id: title,
            title: title,
            value: nil,
            detail: nil,
            evidenceAvailable: false
        )
    }

    private func componentOutcomeRow(_ summary: WeightliftingComponentOutcomeSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(summary.title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.m) {
                    componentOutcomeCounts(summary)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    componentOutcomeCounts(summary)
                }
            }
            .font(AppFont.metadata.monospacedDigit())
            .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(outcomeAccessibilityLabel(summary))
        .accessibilityIdentifier("weightlifting-component-outcomes-\(summary.id)")
    }

    @ViewBuilder
    private func componentOutcomeCounts(_ summary: WeightliftingComponentOutcomeSummary) -> some View {
        outcome(String(localized: "Made"), summary.made)
        outcome(String(localized: "Partial"), summary.partial)
        outcome(String(localized: "Missed"), summary.missed)
        outcome(String(localized: "Skipped"), summary.skipped)
        outcome(String(localized: "Not assessed"), summary.notStarted)
    }

    private func outcome(_ label: String, _ count: WeightliftingEvidenceCount) -> some View {
        Text("\(label) \(count.displayText)")
    }

    private func metricAccessibilityLabel(_ metric: WeightliftingDashboardMetric) -> String {
        let value = metric.evidenceAvailable
            ? (metric.value ?? String(localized: "Value unavailable"))
            : String(localized: "Not recorded")
        return [metric.title, value, metric.detail].compactMap { $0 }.joined(separator: ", ")
    }

    private func outcomeAccessibilityLabel(_ summary: WeightliftingComponentOutcomeSummary) -> String {
        [
            summary.title,
            String(format: String(localized: "Made %@"), summary.made.displayText),
            String(format: String(localized: "Partial %@"), summary.partial.displayText),
            String(format: String(localized: "Missed %@"), summary.missed.displayText),
            String(format: String(localized: "Skipped %@"), summary.skipped.displayText),
            String(format: String(localized: "Not assessed %@"), summary.notStarted.displayText)
        ].joined(separator: ", ")
    }
}

private struct CompetitionPreparationCache {
    let inputID: Int
    let preparation: CompetitionDayPreparation
}
