import SwiftData
import SwiftUI

/// Every assessment sitting that recorded something, newest first.
///
/// History is deliberately a list of *sittings*, not a chart: the comparison
/// rule means two observations are only relatable when their conditions match,
/// and a trend line drawn across changed conditions would assert exactly the
/// thing the domain refuses to assert.
struct MobilityAssessmentHistoryView: View {
    @Query(sort: \MobilityAssessmentSession.startedAt, order: .reverse)
    private var sessions: [MobilityAssessmentSession]

    var body: some View {
        List {
            if recordedSessions.isEmpty {
                ContentUnavailableView(
                    "No assessments yet",
                    systemImage: AppIcon.mobilityAssessment,
                    description: Text("Record an assessment to build a history you can compare against.")
                )
            } else {
                ForEach(recordedSessions) { session in
                    NavigationLink {
                        MobilityAssessmentSessionDetailView(session: session)
                    } label: {
                        sessionRow(session)
                    }
                    .accessibilityIdentifier("mobility-assessment-history-session-\(session.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Assessment history")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionRow(_ session: MobilityAssessmentSession) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            Text(detail(for: session))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// A sitting that saved nothing is not a measurement of anything, so it is
    /// left out rather than listed as an empty result.
    private var recordedSessions: [MobilityAssessmentSession] {
        sessions.filter { $0.results.isEmpty == false }
    }

    private func detail(for session: MobilityAssessmentSession) -> String {
        let count = CountPhrase.observations(session.results.count)
        switch session.status {
        case .completed:
            return count
        case .active:
            return String(
                localized: "mobility.assessment.history.detail.inProgress",
                defaultValue: "\(count) · In progress"
            )
        case .stopped:
            // Stopped is a neutral fact about the sitting, not about the
            // observations it saved.
            return String(
                localized: "mobility.assessment.history.detail.stopped",
                defaultValue: "\(count) · Stopped early"
            )
        }
    }
}

/// One assessment sitting, decomposed: every observation it saved, the
/// conditions each was recorded under, and what it was skipped.
struct MobilityAssessmentSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: MobilityAssessmentSession

    @State private var definitions: [MobilityAssessmentDefinition] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        GymSectionHeader(title: group.title)
                        GymCard {
                            ForEach(group.observations) { observation in
                                NavigationLink {
                                    MobilityAssessmentTimelineView(
                                        title: observation.title,
                                        catalogueKey: observation.definitionCatalogueKey,
                                        side: observation.side
                                    )
                                } label: {
                                    MobilityAssessmentObservationRow(observation: observation)
                                }
                                .buttonStyle(.gymPress)
                                .accessibilityIdentifier("mobility-assessment-observation-\(observation.id)")
                            }
                        }
                    }
                }

                if skippedNames.isEmpty == false {
                    GymCard {
                        GymEyebrow("Skipped assessments")
                        ForEach(skippedNames, id: \.self) { name in
                            MobilityAssessmentBulletRow(systemImage: AppIcon.skip, text: name)
                        }
                    }
                }

                MobilityAssessmentScopeNote()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
        .navigationTitle("Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.gymText)
            Text(
                CountPhrase.observations(session.results.count)
            )
            .font(AppFont.subheadline)
            .foregroundStyle(Color.gymSubduedText)
        }
        .accessibilityElement(children: .combine)
    }

    private var groups: [MobilityAssessmentZoneGroup] {
        MobilityAssessmentZoneGroup.groups(
            for: session.orderedResults,
            zonesByCatalogueKey: Dictionary(
                definitions.map { ($0.catalogueKey, $0.zone) },
                uniquingKeysWith: { first, _ in first }
            ),
            using: modelContext
        )
    }

    private var skippedNames: [String] {
        session.skippedDefinitionKeys.compactMap { key in
            definitions.first { $0.catalogueKey == key }.map(MobilityAssessmentCopy.name(for:))
        }
    }

    private func load() {
        definitions = (try? MobilityAssessmentCatalogService.definitions(
            using: modelContext,
            includeArchived: true
        )) ?? []
    }
}

/// One assessment, one side, every time it was observed.
///
/// This is where test–retest actually pays off, so each entry states its own
/// conditions and each comparison says explicitly whether it is a difference in
/// range or two observations that simply cannot be compared.
struct MobilityAssessmentTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let catalogueKey: String
    let side: MobilityAssessmentSide

    @State private var observations: [MobilityAssessmentObservation] = []
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppFont.titleSmall)
                        .foregroundStyle(Color.gymText)
                    Text(side.displayName)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.gymSubduedText)
                }
                .accessibilityElement(children: .combine)

                if hasLoaded, observations.isEmpty {
                    GymCard {
                        ContentUnavailableView(
                            "No observations",
                            systemImage: AppIcon.mobilityAssessment,
                            description: Text("Nothing has been recorded for this assessment and side.")
                        )
                    }
                } else {
                    ForEach(observations) { observation in
                        GymCard {
                            Text(dateText(for: observation))
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                            MobilityAssessmentObservationRow(
                                observation: observation,
                                showsTitle: false
                            )
                        }
                    }
                }

                MobilityAssessmentScopeNote()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.gymBackground)
        .navigationTitle("Observations")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func dateText(for observation: MobilityAssessmentObservation) -> String {
        observation.recordedOn.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func load() {
        let results = (try? MobilityAssessmentHistoryQuery.results(
            definitionCatalogueKey: catalogueKey,
            side: side,
            using: modelContext
        )) ?? []
        observations = results.map { result in
            MobilityAssessmentObservation(
                result: result,
                comparison: MobilityAssessmentComparisonPresenter.note(
                    for: result,
                    using: modelContext
                )
            )
        }
        hasLoaded = true
    }
}
