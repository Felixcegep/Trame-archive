import SwiftData
import SwiftUI

/// Turns a stored result plus the comparison service's verdict into display
/// text. The service owns *whether* two observations may be compared; this file
/// only decides how to say it.
///
/// A delta is shown **only** when the service reports `.direct`. Anything else
/// is rendered as two separate observations with the differing condition named,
/// because a difference across changed conditions is not a change in range.
struct MobilityAssessmentComparisonNote: Equatable {
    let comparability: MobilityAssessmentComparability
    let text: String
    /// Present only for a direct comparison, so callers can never surface a
    /// delta the service declined to produce.
    let differenceText: String?
}

@MainActor
enum MobilityAssessmentComparisonPresenter {

    static func note(
        for result: MobilityAssessmentResult,
        using context: ModelContext
    ) -> MobilityAssessmentComparisonNote? {
        // Side is one of the comparability conditions, so the query is already
        // scoped to it: comparing left against right would be a category error,
        // not a "limited" comparison.
        let history = (try? MobilityAssessmentHistoryQuery.results(
            definitionCatalogueKey: result.definitionCatalogueKeySnapshot,
            side: result.side,
            using: context
        )) ?? []

        let comparison = MobilityAssessmentComparisonService.latestComparison(
            for: result,
            among: history
        )
        guard let previousID = comparison.previousResultID,
              let previous = history.first(where: { $0.id == previousID }) else {
            return nil
        }

        let previousValue = MobilityAssessmentValueFormatter.text(
            numericValue: previous.numericValue,
            criteria: previous.criteria,
            unit: previous.unit
        )
        let previousDate = previous.createdAt.formatted(
            .dateTime.month(.abbreviated).day().year()
        )

        switch comparison.comparability {
        case .direct:
            let difference = comparison.numericDelta.flatMap {
                MobilityAssessmentValueFormatter.differenceText($0, unit: result.unit)
            }
            return MobilityAssessmentComparisonNote(
                comparability: .direct,
                text: String(
                    localized: "mobility.assessment.comparison.direct",
                    defaultValue: "Previous observation under the same conditions: \(previousValue) on \(previousDate)."
                ),
                differenceText: difference
            )
        case .notDirect:
            let conditions = comparison.differingConditions
                .map(\.displayName)
                .formatted(.list(type: .and))
            return MobilityAssessmentComparisonNote(
                comparability: .notDirect,
                text: String(
                    localized: "mobility.assessment.comparison.notDirect",
                    defaultValue: "Previous observation: \(previousValue) on \(previousDate). Kept separate because these conditions changed: \(conditions)."
                ),
                differenceText: nil
            )
        }
    }
}

/// One recorded observation, resolved for display. Built once per render pass so
/// the row itself stays free of formatting and service calls.
struct MobilityAssessmentObservation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let definitionCatalogueKey: String
    let recordedOn: Date
    let side: MobilityAssessmentSide
    let unit: MobilityMeasurementUnit
    let numericValue: Double?
    let valueText: String
    let spokenValueText: String
    let conditionsText: String
    let provenanceText: String
    let comparison: MobilityAssessmentComparisonNote?

    init(
        result: MobilityAssessmentResult,
        comparison: MobilityAssessmentComparisonNote? = nil
    ) {
        id = result.id
        // The recorded snapshot name, never the live definition: renaming a
        // catalogue entry must not rewrite what a past observation was called.
        title = result.definitionNameSnapshot
        definitionCatalogueKey = result.definitionCatalogueKeySnapshot
        recordedOn = result.createdAt
        side = result.side
        unit = result.unit
        numericValue = result.numericValue
        valueText = MobilityAssessmentValueFormatter.text(
            numericValue: result.numericValue,
            criteria: result.criteria,
            unit: result.unit
        )
        spokenValueText = MobilityAssessmentValueFormatter.accessibilityText(
            numericValue: result.numericValue,
            criteria: result.criteria,
            unit: result.unit
        )
        conditionsText = MobilityAssessmentCopy.conditionsSummary(
            setupKey: result.setupKey,
            isActiveRange: result.isActiveRange,
            isWarm: result.isWarm
        )
        provenanceText = MobilityAssessmentCopy.provenanceSummary(
            source: result.source,
            confidence: result.confidence
        )
        self.comparison = comparison
    }
}

/// Observations that share a body zone.
///
/// The zone is a grouping label and nothing more. There is no zone value, score,
/// or coverage bar here: a zone has no defensible magnitude to plot, and an
/// empty zone is simply absent rather than drawn at zero.
struct MobilityAssessmentZoneGroup: Identifiable, Equatable {
    /// `nil` when the recorded assessment no longer resolves to a catalogue
    /// entry — the observation is still real and still shown.
    let zone: MobilityAssessmentZone?
    let observations: [MobilityAssessmentObservation]

    var id: String { zone?.rawValue ?? "unclassified" }

    var title: String {
        zone?.displayName ?? String(localized: "Other observations")
    }

    /// Builds every observation once — each comparison costs a fetch — and
    /// groups them in the catalogue's presentation order.
    @MainActor
    static func groups(
        for results: [MobilityAssessmentResult],
        zonesByCatalogueKey: [String: MobilityAssessmentZone],
        using context: ModelContext
    ) -> [MobilityAssessmentZoneGroup] {
        let resolved = results.map { result in
            (
                zone: zonesByCatalogueKey[result.definitionCatalogueKeySnapshot],
                observation: MobilityAssessmentObservation(
                    result: result,
                    comparison: MobilityAssessmentComparisonPresenter.note(
                        for: result,
                        using: context
                    )
                )
            )
        }

        var groups = MobilityAssessmentZone.displayOrder.compactMap { zone -> MobilityAssessmentZoneGroup? in
            let matching = resolved.filter { $0.zone == zone }.map(\.observation)
            guard matching.isEmpty == false else { return nil }
            return MobilityAssessmentZoneGroup(zone: zone, observations: matching)
        }

        // An observation whose definition no longer resolves still belongs to
        // the record. It is kept under its own heading rather than dropped.
        let unresolved = resolved.filter { $0.zone == nil }.map(\.observation)
        if unresolved.isEmpty == false {
            groups.append(MobilityAssessmentZoneGroup(zone: nil, observations: unresolved))
        }
        return groups
    }
}

/// A single observation row: value first, interpretation after.
///
/// The value is a monospaced role so a column of observations stays scannable,
/// and it is deliberately the heaviest element in the row — the conditions and
/// any comparison are supporting evidence, not the headline.
struct MobilityAssessmentObservationRow: View {
    let observation: MobilityAssessmentObservation
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if showsTitle {
                Text(observation.title)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.gymText)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(observation.side.displayName)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                Spacer(minLength: Spacing.s)
                Text(observation.valueText)
                    .font(AppFont.titleSmallSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
            }

            Text(observation.conditionsText)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)

            // Provenance travels with the value. A hand-entered observation is
            // labelled as entered and carries the confidence it was frozen with,
            // so it is never read as something the phone measured.
            Text(observation.provenanceText)
                .font(AppFont.caption2)
                .foregroundStyle(Color.gymSubtleText)

            if let comparison = observation.comparison {
                comparisonView(comparison)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func comparisonView(
        _ comparison: MobilityAssessmentComparisonNote
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let differenceText = comparison.differenceText {
                // A difference between two directly comparable observations. It
                // is stated as a difference and nothing more: no arrow, no
                // colour, no better/worse framing.
                Text(differenceText)
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
            }
            Text(comparison.text)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if showsTitle { parts.append(observation.title) }
        parts.append(observation.side.displayName)
        parts.append(observation.spokenValueText)
        parts.append(observation.conditionsText)
        parts.append(observation.provenanceText)
        if let comparison = observation.comparison {
            if let differenceText = comparison.differenceText {
                parts.append(differenceText)
            }
            parts.append(comparison.text)
        }
        return parts.joined(separator: ", ")
    }
}

/// The standing note that accompanies every assessment surface.
///
/// It is not a disclaimer bolted onto the bottom of a score — there is no score.
/// It states plainly what the record is, which is what keeps the feature inside
/// the product boundary.
struct MobilityAssessmentScopeNote: View {
    var body: some View {
        Label {
            Text("These are observations you record under conditions you choose. They are not a diagnosis, an injury-risk assessment, or a score.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: AppIcon.info)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
