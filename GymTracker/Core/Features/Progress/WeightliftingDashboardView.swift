import SwiftData
import SwiftUI

/// Specialist weightlifting evidence surface. The destination derives its
/// presentation from the authored CE6.1 projection and never manufactures a
/// best lift or treats missing evidence as zero.
struct WeightliftingDashboardDestination: View {
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    private let presentationOverride: WeightliftingDashboardPresentation?
    private let onStartCompetitionDay: ((Workout) -> Void)?

    init(
        presentation: WeightliftingDashboardPresentation? = nil,
        onStartCompetitionDay: ((Workout) -> Void)? = nil
    ) {
        presentationOverride = presentation
        self.onStartCompetitionDay = onStartCompetitionDay
    }

    var body: some View {
        WeightliftingDashboardView(
            presentation: presentationOverride ?? .make(
                projection: .project(workouts: workouts)
            ),
            onStartCompetitionDay: onStartCompetitionDay
        )
    }
}

struct WeightliftingDashboardView: View {
    @Environment(\.calendar) private var calendar
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @Query private var programDefinitions: [ProgramDefinitionRecord]
    @Query private var planRuns: [PlanRun]
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }) private var exercises: [Exercise]
    let presentation: WeightliftingDashboardPresentation
    let onStartCompetitionDay: ((Workout) -> Void)?
    @State private var eventDate = Date.now
    @State private var buildError: String?

    init(
        presentation: WeightliftingDashboardPresentation,
        onStartCompetitionDay: ((Workout) -> Void)? = nil
    ) {
        self.presentation = presentation
        self.onStartCompetitionDay = onStartCompetitionDay
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                introduction

                competitionDaySection

                switch presentation.availability {
                case .empty:
                    emptyState
                case .sparse, .populated:
                    dashboardContent
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Color.gymBackground)
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
    }

    private var competitionDaySection: some View {
        let preparation = CompetitionDayPreparationService.prepare(
            workouts: workouts,
            definitions: programDefinitions,
            planRuns: planRuns,
            eventDate: eventDate,
            asOfDate: calendar.startOfDay(for: .now)
        )

        return GymCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                GymSectionHeader(
                    title: String(localized: "Competition day"),
                    detail: String(localized: "Review evidence, then record the two lifts in the active workout.")
                )

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
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("competition-day-section")
    }

    private func competitionProposal(
        preparation: CompetitionDayPreparation,
        proposal: CompetitionPreparationProposal
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let programName = preparation.programName {
                Text(programName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
            }
            ForEach(CompetitionLift.allCases, id: \.self) { lift in
                let attempts = proposal.attempts(for: lift)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(lift.displayName)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Color.gymText)
                    Text(attemptSummary(attempts))
                        .font(AppFont.caption)
                        .foregroundStyle(Color.gymSubduedText)
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
                .foregroundStyle(Color.gymAccent)
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
        GymSectionHeader(
            title: String(localized: "Weightlifting evidence"),
            detail: String(localized: "Full-lift outcomes and component evidence stay separate.")
        )
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
        fullLiftSection
        componentSection
        if let qualityTrend = presentation.qualityTrend {
            GymCard {
                GymEyebrow("Quality trend")
                Text(qualityTrend)
                    .font(AppFont.body)
                    .foregroundStyle(Color.gymText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weightlifting-quality-trend")
        }
        if let evidenceNote = presentation.evidenceNote {
            Text(evidenceNote)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("weightlifting-evidence-note")
        }
    }

    private var fullLiftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow("Full-lift outcomes")

            if let fullLiftBest = presentation.fullLiftBest {
                metricCard(fullLiftBest, identifier: "weightlifting-full-lift-best")
            } else {
                unavailableMetric(String(localized: "No complete full-lift result recorded yet."))
            }

            if let attemptSummary = presentation.attemptSummary {
                Text(attemptSummary)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightlifting-attempt-summary")
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymEyebrow("Component evidence")

            HStack(alignment: .top, spacing: Spacing.s) {
                metricCard(
                    presentation.cleanBest ?? unavailableMetricModel(title: String(localized: "Clean")),
                    identifier: "weightlifting-clean-best"
                )
                metricCard(
                    presentation.jerkAfterCleanBest ?? unavailableMetricModel(title: String(localized: "Jerk after clean")),
                    identifier: "weightlifting-jerk-after-clean-best"
                )
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

    private func metricCard(
        _ metric: WeightliftingDashboardMetric,
        identifier: String
    ) -> some View {
        GymCard(variant: metric.evidenceAvailable ? .standard : .accent) {
            Text(metric.title)
                .font(AppFont.captionBold)
                .foregroundStyle(Color.gymSubduedText)

            if let value = metric.value, metric.evidenceAvailable {
                Text(value)
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(Color.gymDataEmphasis)
            } else {
                Text(String(localized: "Not recorded"))
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymSubduedText)
            }

            if let detail = metric.detail {
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
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
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubduedText)
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
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            HStack(spacing: Spacing.m) {
                outcome(String(localized: "Made"), summary.made)
                outcome(String(localized: "Partial"), summary.partial)
                outcome(String(localized: "Missed"), summary.missed)
                outcome(String(localized: "Skipped"), summary.skipped)
            }
            .font(AppFont.captionSemiboldMonospaced)
            .foregroundStyle(Color.gymSubduedText)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(outcomeAccessibilityLabel(summary))
        .accessibilityIdentifier("weightlifting-component-outcomes-\(summary.id)")
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
            String(format: String(localized: "Skipped %@"), summary.skipped.displayText)
        ].joined(separator: ", ")
    }
}
