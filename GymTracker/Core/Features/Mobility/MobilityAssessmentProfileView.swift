import SwiftData
import SwiftUI

/// Read-only profile over immutable observations. It deliberately applies no
/// population band until a cited, protocol-specific band is authored.
struct MobilityAssessmentProfileView: View {
    @Query(
        filter: #Predicate<MobilityAssessmentDefinition> { !$0.isArchived },
        sort: \MobilityAssessmentDefinition.sortOrder
    )
    private var definitions: [MobilityAssessmentDefinition]
    @Query(sort: \MobilityAssessmentResult.createdAt, order: .reverse)
    private var results: [MobilityAssessmentResult]

    private func makeProfile() -> MobilityAssessmentProfile {
        MobilityAssessmentProfileProjectionService.project(
            protocols: definitions.flatMap { MobilityAssessmentProfileProtocolAdapter.protocols($0) },
            results: results,
            bands: []
        )
    }

    var body: some View {
        let profile = makeProfile()

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                coverageCard(profile)

                if profile.measurements.isEmpty {
                    ContentUnavailableView(
                        String(localized: "mobility.profile.empty.title", defaultValue: "No mobility observations"),
                        systemImage: AppIcon.mobilityAssessment,
                        description: Text(String(localized: "mobility.profile.empty.detail", defaultValue: "Record an assessment to build your profile."))
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    measurementSection(profile)
                    if profile.sideGaps.isEmpty == false { sideSection(profile) }
                }

                Text(String(localized: "mobility.profile.scope", defaultValue: "This profile describes protocol-bound observations. It is not a score, diagnosis, injury-risk estimate, or universal normal range."))
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mobility-profile-scope")
            }
            .padding(.horizontal, Spacing.screenInset)
            .padding(.vertical, Spacing.l)
        }
        .background(Color.trameCanvas)
        .navigationTitle(String(localized: "mobility.profile.title", defaultValue: "Mobility profile"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("mobility-assessment-profile")
    }

    private func coverageCard(_ profile: MobilityAssessmentProfile) -> some View {
        TrameColorField(fill: .trameSurface, ink: .trameText, border: .trameMobility, radius: Radius.card) {
            VStack(alignment: .leading, spacing: Spacing.s) {
            Text(String(localized: "mobility.profile.coverage", defaultValue: "Observation coverage"))
                .font(AppFont.caption2Bold)
                .textCase(.uppercase)
                .tracking(0.55)
                .foregroundStyle(Color.trameSubdued)
            Text("\(profile.coverage.measuredCount) / \(profile.coverage.expectedCount)")
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.trameText)
            Text(String(localized: "mobility.profile.coverage.detail", defaultValue: "Each assessment side is kept separate. Missing observations remain missing."))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            }
            .padding(Spacing.l)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mobility-profile-coverage")
    }

    private func measurementSection(_ profile: MobilityAssessmentProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameDomainSectionRule(title: "Latest observations", color: .trameMobility)
            Text(String(localized: "mobility.profile.observations.detail", defaultValue: "Values and comparisons use the recorded setup and method."))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            ForEach(orderedMeasurements(in: profile)) { measurement in
                measurementRow(measurement)
                    .padding(.vertical, Spacing.s)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.trameSeparator).frame(height: 1) }
            }
        }
    }

    private func orderedMeasurements(
        in profile: MobilityAssessmentProfile
    ) -> [MobilityAssessmentProfileMeasurement] {
        profile.measurements.sorted { lhs, rhs in
            if (lhs.resultID != nil) != (rhs.resultID != nil) {
                return lhs.resultID != nil
            }
            if lhs.testName != rhs.testName { return lhs.testName < rhs.testName }
            return lhs.side.rawValue < rhs.side.rawValue
        }
    }

    private func sideSection(_ profile: MobilityAssessmentProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameDomainSectionRule(title: "Side differences", color: .trameMobility)
            Text(String(localized: "mobility.profile.sides.detail", defaultValue: "Shown only for numeric observations in the same unit."))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            ForEach(profile.sideGaps) { gap in
                Text(sideGapText(gap))
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.trameText)
                    .padding(.vertical, Spacing.s)
                    .accessibilityIdentifier("mobility-profile-side-gap-\(gap.id)")
            }
        }
    }

    private func measurementRow(_ measurement: MobilityAssessmentProfileMeasurement) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(measurement.testName)
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameText)
                Spacer(minLength: Spacing.s)
                Text(measurement.side.displayName)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }
            Text(valueText(measurement.value))
                .font(AppFont.titleSmall)
                .foregroundStyle(Color.trameText)
            Text(historyText(measurement.history, unit: measurement.expectedUnit))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
            Text(String(localized: "mobility.profile.no.band", defaultValue: "No population comparison is applied."))
                .font(AppFont.caption)
                .foregroundStyle(Color.trameSubdued)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mobility-profile-measurement-\(measurement.id)")
    }

    private func valueText(_ value: MobilityAssessmentProfileValue) -> String {
        switch value {
        case .missing:
            String(localized: "common.not.measured", defaultValue: "Not measured")
        case .numeric(let value, let unit):
            "\(value.formatted(.number.precision(.fractionLength(0...1))))\(MobilityAssessmentValueFormatter.unitSuffix(unit))"
        case .criteria(let value, _):
            value.displayName
        }
    }

    private func historyText(_ history: MobilityAssessmentProfileHistory, unit: MobilityMeasurementUnit) -> String {
        switch history {
        case .noPriorObservation:
            String(localized: "mobility.profile.history.none", defaultValue: "No earlier matching observation")
        case .directlyComparableDelta(let delta):
            String(localized: "mobility.profile.history.delta", defaultValue: "Change under matching conditions: \(delta.formatted(.number.precision(.fractionLength(0...1))))\(MobilityAssessmentValueFormatter.unitSuffix(unit))")
        case .directlyComparableWithoutNumericDelta:
            String(localized: "mobility.profile.history.comparable", defaultValue: "Earlier observation used matching conditions")
        case .notComparable:
            String(localized: "mobility.profile.history.not.comparable", defaultValue: "Earlier observation used different conditions")
        }
    }

    private func sideGapText(_ gap: MobilityAssessmentProfileSideGap) -> String {
        switch gap.difference {
        case .available(let value, let unit):
            String(localized: "mobility.profile.side.gap", defaultValue: "\(value.formatted(.number.precision(.fractionLength(0...1))))\(MobilityAssessmentValueFormatter.unitSuffix(unit)) between sides")
        case .missingObservation:
            String(localized: "mobility.profile.side.missing", defaultValue: "One side is not measured")
        case .notNumeric:
            String(localized: "mobility.profile.side.not.numeric", defaultValue: "Side difference needs numeric observations")
        case .incompatibleUnits:
            String(localized: "mobility.profile.side.units", defaultValue: "Sides use different units")
        }
    }
}

private enum MobilityAssessmentProfileProtocolAdapter {
    static func protocols(_ definition: MobilityAssessmentDefinition) -> [MobilityAssessmentProtocol] {
        definition.supportedSides.map { side in
            MobilityAssessmentProtocol(
                protocolID: definition.catalogueKey,
                protocolVersion: definition.definitionVersion,
                measurement: String(localized: String.LocalizationValue(definition.measurementDescriptionLocalizationKey)),
                testName: MobilityAssessmentCopy.name(for: definition),
                position: String(localized: String.LocalizationValue(definition.setupInstructionsLocalizationKey)),
                setupKey: definition.defaultSetupKey,
                side: side,
                unit: definition.unit,
                activePassive: definition.defaultIsActiveRange ? .active : .passive,
                recordsWarmCold: true,
                preferredMethod: method(definition.preferredMode),
                manualFallback: true,
                reliabilitySource: String(localized: "mobility.profile.protocol.source", defaultValue: "App-authored assessment protocol"),
                limitations: String(localized: String.LocalizationValue(definition.measurementLimitationsLocalizationKey))
            )
        }
    }

    private static func method(_ mode: MobilityMeasurementMode) -> MobilityAssessmentProtocol.Method {
        switch mode {
        case .manualAngle, .manualLinear, .manualCriteria, .cameraPose: .manual
        case .inclinometer: .inclinometer
        case .axialRotation, .twoSegmentAngle, .dynamicRange: .deviceMotion
        }
    }
}
