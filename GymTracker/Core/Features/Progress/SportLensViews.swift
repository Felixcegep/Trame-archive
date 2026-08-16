import Charts
import SwiftUI

/*
 Sport-lens diagram contracts (`Documentation/Design/DiagramGrammar.md`):

 QUESTION      How is completed, comparable evidence distributed or changing?
 DATA          Weekly working sets; HYROX split kind/duration and measured run
               distance; weekly cardio distance/duration; mixed-workout shares.
               Missing pairs and empty weeks remain missing/empty, never inferred.
 ENCODING      Week or performed order is position; bar/line extent is the exact
               set, duration, distance, pace, delta, or proportion value; hue is
               a labelled sport/split/state cue.
 INTERACTION   Native Progress lens/range controls own selection; methodology is
               available through native DisclosureGroup controls.
 DETAIL        Exact values, units, period, evidence count, and calculation rules
               appear in labels, ordered rows, accessibility text, and disclosure.
 EMPTY STATE   No eligible completed evidence produces prose, not a zero result.
 ACCESSIBILITY Each Chart has a complete ordered textual equivalent; color never
               carries identity or direction without labels, symbols, or values.
 */

/// Sport-specific presentation over immutable completed-workout projections.
/// Each lens keeps unlike measurements separate rather than manufacturing a
/// cross-sport score or converting evidence that was logged under different
/// conditions.
struct SpecializedSportLensView: View {
    @AppStorage(DefaultsKey.useMetric) private var unitSystem: UnitSystem = .metric
    let discipline: SportDiscipline
    let workouts: [Workout]
    let interval: DateInterval
    let competitionLifts: PowerliftingLiftIdentity?
    let onNavigate: (ProgressRoute) -> Void
    @State private var projectionCache: SpecializedSportLensProjectionCache?

    var body: some View {
        let inputID = projectionInputID
        let projection = projectionCache.flatMap {
            $0.inputID == inputID ? $0.projection : nil
        } ?? makeProjection()

        VStack(alignment: .leading, spacing: Spacing.l) {
            SportLensHeader(
                title: discipline.title,
                period: "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(interval.end.formatted(date: .abbreviated, time: .omitted))",
                tint: disciplineTint
            )

            switch projection {
            case .strength(let value):
                StrengthSportLensView(
                    projection: value,
                    competitionLifts: competitionLifts,
                    displayWeightType: unitSystem == .metric ? .kg : .lbs
                )
            case .hybrid(let value):
                HybridRaceSportLensView(projection: value)
            case .strongman(let value):
                StrongmanSportLensView(projection: value)
            case .bodybuilding(let metrics):
                BodybuildingSportLensView(
                    metrics: metrics,
                    onOpenMuscleExposure: { onNavigate(.muscleGroupVolume) }
                )
            case .cardio(let value):
                CardioSportLensView(projection: value)
            case .mixed(let value):
                MixedSportLensView(projection: value)
            case .weightlifting:
                WeightliftingSportLensLink(onOpen: { onNavigate(.weightlifting) })
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .accessibilityIdentifier("progress-sport-lens-\(discipline.rawValue)")
        .task(id: inputID) {
            guard projectionCache?.inputID != inputID else { return }
            projectionCache = .init(inputID: inputID, projection: projection)
        }
    }

    private var projectionInputID: Int {
        var revision = Hasher()
        revision.combine(discipline)
        revision.combine(interval.start)
        revision.combine(interval.end)
        revision.combine(competitionLifts?.squatExerciseID)
        revision.combine(competitionLifts?.benchExerciseID)
        revision.combine(competitionLifts?.deadliftExerciseID)
        revision.combine(unitSystem.rawValue)
        for workout in workouts {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
        }
        return revision.finalize()
    }

    private func makeProjection() -> SpecializedSportLensProjection {
        switch discipline {
        case .powerlifting, .generalStrength:
            .strength(StrengthProgressProjection.project(
                workouts: workouts,
                discipline: discipline,
                interval: interval,
                competitionLifts: competitionLifts,
                displayWeightType: unitSystem == .metric ? .kg : .lbs
            ))
        case .hybridFitnessRacing:
            .hybrid(HybridRaceProgressProjection.project(workouts: workouts))
        case .strongman:
            .strongman(StrongmanProgressProjection.project(workouts: workouts))
        case .bodybuilding:
            .bodybuilding(BodybuildingProgressProjection.project(
                workouts: workouts,
                interval: interval
            ).weeklyWorkingSets)
        case .generalCardio:
            .cardio(CardioProgressProjection.project(workouts: workouts, interval: interval))
        case .mixed:
            .mixed(MixedProgressProjection.project(workouts: workouts, interval: interval))
        case .olympicWeightlifting:
            .weightlifting
        }
    }

    private var disciplineTint: Color {
        switch discipline {
        case .generalStrength, .powerlifting:
            .trameStrength
        case .bodybuilding, .mixed:
            .trameRecovery
        case .olympicWeightlifting, .strongman:
            .trameCompetition
        case .hybridFitnessRacing, .generalCardio:
            .trameConditioning
        }
    }
}

@MainActor
private struct SpecializedSportLensProjectionCache {
    let inputID: Int
    let projection: SpecializedSportLensProjection
}

@MainActor
private enum SpecializedSportLensProjection {
    case strength(StrengthProgressProjection)
    case hybrid(HybridRaceProgressProjection)
    case strongman(StrongmanProgressProjection)
    case bodybuilding([ProgressWeekMetric])
    case cardio(CardioProgressProjection)
    case mixed(MixedProgressProjection)
    case weightlifting
}

// MARK: - Sport Lens Building Blocks

struct SportLensHeader: View {
    let title: String
    var detail: String? = nil
    let period: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.stageTitle)
                .foregroundStyle(Color.trameText)
            Spacer(minLength: Spacing.m)
            Text(period)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

struct SportMetricFieldItem: Identifiable {
    var id: String { label }
    let value: String
    let label: String
    let accessibilityLabel: String
}

struct SportMetricField: View {
    let tint: Color
    var eyebrow: String? = nil
    let metrics: [SportMetricFieldItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(AppFont.eyebrow)
                    .tracking(1.0)
                    .foregroundStyle(Color.trameSemanticFieldInk)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.l) {
                    ForEach(metrics) { item in
                        metricItemView(item)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(metrics) { item in
                        metricItemView(item)
                    }
                }
            }
        }
        .foregroundStyle(Color.trameSemanticFieldInk)
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func metricItemView(_ item: SportMetricFieldItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(item.value)
                .font(metrics.count == 1 ? AppFont.metricHero : AppFont.metricLarge)
                .monospacedDigit()
            Text(item.label)
                .font(AppFont.micro)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

struct SportEvidenceDisclosure: View {
    let summary: String
    let detail: String

    var body: some View {
        DisclosureGroup {
            Text(detail)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
                .padding(.top, Spacing.s)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text(summary)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
        }
        .tint(Color.trameText)
        .frame(minHeight: ComponentSize.minimumTouchTarget)
    }
}

struct SportLensEvidenceChart<Content: View>: View {
    let title: String
    let evidence: String
    @ViewBuilder let content: Content

    init(title: String, evidence: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.evidence = evidence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TrameSectionRule(title: LocalizedStringKey(title))
            Text(evidence)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)

            content
                .padding(.top, Spacing.xs)
        }
        .padding(.vertical, Spacing.xs)
    }
}

struct SportLensDestinationRow: View {
    let title: String
    let detail: String
    var tint: Color = .trameAction

    var body: some View {
        HStack(spacing: Spacing.m) {
            TrameCategoryTile(systemImage: AppIcon.muscles, fill: tint)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                Text(detail)
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
            Spacer(minLength: 0)
            Image(systemName: AppIcon.chevronRight)
                .font(AppFont.micro)
                .foregroundStyle(Color.trameSubdued)
        }
        .frame(minHeight: ComponentSize.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct SportLensEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(Color.trameText)
            Text(detail)
                .font(AppFont.metadata)
                .foregroundStyle(Color.trameSubdued)
        }
        .padding(.vertical, Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Strength Lens

private struct StrengthSportLensView: View {
    let projection: StrengthProgressProjection
    let competitionLifts: PowerliftingLiftIdentity?
    let displayWeightType: WeightType

    var body: some View {
        if projection.exerciseRecords.isEmpty {
            SportLensEmptyState(
                title: String(localized: "No strength records yet"),
                detail: String(localized: "Complete working sets with load to populate this lens.")
            )
        } else {
            if projection.discipline == .powerlifting {
                powerliftingBoard
            } else {
                SportMetricField(
                    tint: .trameStrength,
                    metrics: [
                        .init(
                            value: number(projection.weeklyWorkingSets.map(\.value).reduce(0, +)),
                            label: String(localized: "working sets"),
                            accessibilityLabel: String(localized: "\(number(projection.weeklyWorkingSets.map(\.value).reduce(0, +))) completed working sets in this period")
                        ),
                        .init(
                            value: "\(projection.exerciseRecords.count)",
                            label: String(localized: "exercise records"),
                            accessibilityLabel: String(localized: "\(projection.exerciseRecords.count) exercise records in this period")
                        )
                    ]
                )
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                TrameSectionRule(title: "Exercise records")
                ForEach(recordsByUnit, id: \.unit) { group in
                    Text(group.unit.rawValue.uppercased())
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)

                    ForEach(group.records.prefix(6)) { record in
                        StrengthRecordRow(record: record)
                        if record.id != group.records.prefix(6).last?.id {
                            Divider().overlay(Color.trameSeparator)
                        }
                    }
                }
            }

            WeeklySetsSportLensView(
                title: String(localized: "Working sets per week"),
                evidence: String(localized: "Completed eligible strength sets; warm-ups and non-working sets are excluded."),
                metrics: projection.weeklyWorkingSets,
                tint: .trameStrength
            )

            SportEvidenceDisclosure(
                summary: String(localized: "Evidence & e1RM method"),
                detail: strengthMethodology
            )
        }
    }

    private var recordsByUnit: [(unit: WeightType, records: [StrengthExerciseProgressRecord])] {
        Dictionary(grouping: projection.exerciseRecords, by: \.weightUnit)
            .map { unit, records in
                (unit, records.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
            }
            .sorted { $0.unit.rawValue < $1.unit.rawValue }
    }

    private var strengthMethodology: String {
        let sets = Int(projection.weeklyWorkingSets.map(\.value).reduce(0, +))
        return String(localized: "\(sets) completed eligible working sets in the selected period. Estimated 1RM uses load × (1 + repetitions ÷ 30) only for eligible completed sets of 10 repetitions or fewer. Units remain separate in exercise records.")
    }

    private var powerliftingBoard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(String(localized: "ESTIMATED SBD"))
                .font(AppFont.eyebrow)
                .tracking(1.2)

            if let sum = projection.estimatedThreeLiftSum,
               let unit = projection.estimatedThreeLiftSumUnit {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text("≈\(number(sum))")
                        .font(AppFont.metricHero)
                    Text(unit.rawValue)
                        .font(AppFont.metricCompact)
                }
                Text(String(localized: "Estimate · not a competition total"))
                    .font(AppFont.micro)
            } else {
                Text(String(localized: "Not available"))
                    .font(AppFont.metricLarge)
                Text(String(localized: "Squat, Bench, and Deadlift identities and eligible estimates are all required."))
                    .font(AppFont.metadata)
            }

            Rectangle()
                .fill(Color.trameSemanticFieldInk)
                .frame(height: 1)
                .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Spacing.l) {
                    ForEach(powerliftingLifts) { lift in
                        PowerliftingLiftMetric(lift: lift)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ForEach(powerliftingLifts) { lift in
                        PowerliftingLiftMetric(lift: lift)
                    }
                }
            }
        }
        .foregroundStyle(Color.trameSemanticFieldInk)
        .padding(Spacing.l)
        .background(Color.trameStrength, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress-powerlifting-sbd-board")
    }

    private var powerliftingLifts: [PowerliftingLiftReading] {
        guard let competitionLifts else {
            return [
                .init(id: "squat", label: String(localized: "Squat"), value: nil, detail: String(localized: "Role not authored")),
                .init(id: "bench", label: String(localized: "Bench"), value: nil, detail: String(localized: "Role not authored")),
                .init(id: "deadlift", label: String(localized: "Deadlift"), value: nil, detail: String(localized: "Role not authored"))
            ]
        }
        return [
            powerliftingLift(id: "squat", label: String(localized: "Squat"), exerciseID: competitionLifts.squatExerciseID),
            powerliftingLift(id: "bench", label: String(localized: "Bench"), exerciseID: competitionLifts.benchExerciseID),
            powerliftingLift(id: "deadlift", label: String(localized: "Deadlift"), exerciseID: competitionLifts.deadliftExerciseID)
        ]
    }

    private func powerliftingLift(id: String, label: String, exerciseID: UUID) -> PowerliftingLiftReading {
        let candidates = projection.exerciseRecords.compactMap { record -> (Double, StrengthExerciseProgressRecord)? in
            guard record.exerciseID == exerciseID,
                  let estimate = record.bestEstimatedOneRepMax
            else { return nil }
            let converted = UnitConversion.weight(Float(estimate), from: record.weightUnit, to: displayWeightType)
            guard converted.isFinite else { return nil }
            return (Double(converted), record)
        }
        guard let best = candidates.max(by: { $0.0 < $1.0 }) else {
            let hasLoad = projection.exerciseRecords.contains { $0.exerciseID == exerciseID }
            return .init(
                id: id,
                label: label,
                value: nil,
                detail: hasLoad ? String(localized: "No eligible estimate") : String(localized: "Not recorded")
            )
        }
        return .init(
            id: id,
            label: label,
            value: "≈\(number(best.0)) \(displayWeightType.rawValue)",
            detail: CountPhrase.sets(best.1.completedWorkingSetCount)
        )
    }
}

private struct PowerliftingLiftReading: Identifiable {
    let id: String
    let label: String
    let value: String?
    let detail: String
}

private struct PowerliftingLiftMetric: View {
    let lift: PowerliftingLiftReading

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(lift.label.uppercased())
                .font(AppFont.micro)
            Text(lift.value ?? "—")
                .font(AppFont.metricCompact)
            Text(lift.detail)
                .font(AppFont.micro)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([lift.label, lift.value ?? String(localized: "Not available"), lift.detail].joined(separator: ", "))
    }
}

private struct StrengthRecordRow: View {
    let record: StrengthExerciseProgressRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.name)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(Color.trameText)
                Text(CountPhrase.sets(record.completedWorkingSetCount))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
            }
            Spacer(minLength: Spacing.m)
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("\(number(record.bestLoad)) \(record.weightUnit.rawValue)")
                    .font(AppFont.metricCompact)
                    .foregroundStyle(Color.trameText)
                if let estimate = record.bestEstimatedOneRepMax {
                    Text(String(localized: "e1RM ≈\(number(estimate)) \(record.weightUnit.rawValue)"))
                        .font(AppFont.micro)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

private struct WeeklySetsSportLensView: View {
    let title: String
    let evidence: String
    let metrics: [ProgressWeekMetric]
    var tint: Color = .trameStrength

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    var body: some View {
        if metrics.contains(where: { $0.value > 0 }) {
            SportLensEvidenceChart(title: title, evidence: evidence) {
                Chart(metrics) { metric in
                    BarMark(
                        x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                        y: .value(String(localized: "Sets"), metric.value),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(tint)
                }
                .gymChartAxisStyle()
                .frame(height: ComponentSize.compactChartHeight)
                .accessibilityLabel(weeklySetsAccessibilityLabel)
            }
        } else {
            SportLensEmptyState(
                title: String(localized: "No weekly set history"),
                detail: String(localized: "Weeks remain empty until eligible working sets are completed.")
            )
        }
    }

    private var weeklySetsAccessibilityLabel: String {
        let values = metrics.map { "\(Self.accessibilityDateFormatter.string(from: $0.id)): \(number($0.value)) sets" }
        return ([title, evidence] + values).joined(separator: ". ")
    }
}

// MARK: - Bodybuilding Lens

private struct BodybuildingSportLensView: View {
    let metrics: [ProgressWeekMetric]
    let onOpenMuscleExposure: () -> Void

    var body: some View {
        let total = metrics.map(\.value).reduce(0, +)
        SportMetricField(
            tint: .trameRecovery,
            metrics: [
                .init(
                    value: number(total),
                    label: String(localized: "working sets"),
                    accessibilityLabel: String(localized: "\(number(total)) completed bodybuilding working sets in this period")
                )
            ]
        )

        WeeklySetsSportLensView(
            title: String(localized: "Weekly working sets"),
            evidence: String(localized: "Completed non-warm-up bodybuilding sets."),
            metrics: metrics,
            tint: .trameRecovery
        )

        Button(action: onOpenMuscleExposure) {
            SportLensDestinationRow(
                title: String(localized: "Muscle-group exposure"),
                detail: String(localized: "Open the authored muscle-group distribution and its evidence."),
                tint: .trameRecovery
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Opens muscle-group volume."))

        SportEvidenceDisclosure(
            summary: String(localized: "Evidence & method"),
            detail: String(localized: "Weekly exposure counts completed eligible working sets in the selected period. Muscle-group exposure remains in its domain-owned detail view so unknown or uncategorized work is not guessed here.")
        )
    }
}

// MARK: - Hybrid Fitness Racing Lens

private struct HybridRaceSportLensView: View {
    let projection: HybridRaceProgressProjection

    private var latest: HybridRaceSessionProgress? {
        projection.sessions.last
    }

    private var latestComparison: (previous: HybridRaceSessionProgress, current: HybridRaceSessionProgress)? {
        guard projection.sessions.count >= 2 else { return nil }
        let current = projection.sessions[projection.sessions.count - 1]
        guard let previous = projection.sessions.dropLast().last(where: {
            $0.splits.map(\.kind) == current.splits.map(\.kind)
        }) else { return nil }
        return (previous, current)
    }

    var body: some View {
        if let latest {
            SportMetricField(
                tint: .trameConditioning,
                eyebrow: String(localized: "Latest recorded simulation"),
                metrics: [
                    .init(value: duration(latest.totalTime), label: String(localized: "elapsed"), accessibilityLabel: String(localized: "Latest recorded simulation, \(duration(latest.totalTime)) elapsed")),
                    .init(value: duration(latest.runTime), label: String(localized: "run"), accessibilityLabel: String(localized: "Run time, \(duration(latest.runTime))")),
                    .init(value: duration(latest.stationTime), label: String(localized: "station"), accessibilityLabel: String(localized: "Station time, \(duration(latest.stationTime))")),
                    .init(value: duration(latest.transitionTime), label: String(localized: "transition"), accessibilityLabel: String(localized: "Transition time, \(duration(latest.transitionTime))"))
                ]
            )

            SportLensEvidenceChart(
                title: String(localized: "Race composition"),
                evidence: String(localized: "Latest recorded simulation, separated by completed split type.")
            ) {
                Chart(composition(latest)) { item in
                    BarMark(
                        x: .value(String(localized: "Duration"), item.duration),
                        y: .value(String(localized: "Simulation"), String(localized: "Best"))
                    )
                    .foregroundStyle(by: .value(String(localized: "Split type"), item.kind.title))
                }
                .chartForegroundStyleScale(
                    domain: WorkoutSplitPalette.domain,
                    range: WorkoutSplitPalette.range
                )
                .gymChartAxisStyle()
                .frame(height: ComponentSize.compactChartHeight)
                .accessibilityLabel(compositionAccessibilityLabel(latest))
            }

            if let comparison = latestComparison {
                SportLensEvidenceChart(
                    title: String(localized: "Split comparison"),
                    evidence: String(localized: "Latest session versus the previous session with the same recorded split structure. Negative values are faster.")
                ) {
                    Chart(splitDeltas(comparison)) { delta in
                        BarMark(
                            x: .value(String(localized: "Time change"), delta.seconds),
                            y: .value(String(localized: "Split"), delta.label)
                        )
                        .foregroundStyle(delta.seconds <= 0 ? Color.trameCompleted : Color.trameAttention)
                    }
                    .gymChartAxisStyle()
                    .chartXAxisLabel(String(localized: "Seconds versus previous"))
                    .frame(height: ComponentSize.standardChartHeight)
                    .accessibilityLabel(splitDeltaAccessibilityLabel(comparison))
                }
            } else {
                SportLensEvidenceChart(
                    title: String(localized: "Race composition"),
                    evidence: String(localized: "Latest recorded simulation, separated by completed split type.")
                ) {
                    Chart(composition(latest)) { item in
                        BarMark(
                            x: .value(String(localized: "Duration"), item.duration),
                            y: .value(String(localized: "Simulation"), String(localized: "Best"))
                        )
                        .foregroundStyle(by: .value(String(localized: "Split type"), item.kind.title))
                    }
                    .chartForegroundStyleScale(
                        domain: WorkoutSplitPalette.domain,
                        range: WorkoutSplitPalette.range
                    )
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                    .accessibilityLabel(compositionAccessibilityLabel(latest))
                }
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                TrameSectionRule(title: "Recorded splits")
                Text(String(localized: "Latest simulation · performed order"))
                    .font(AppFont.metadata)
                    .foregroundStyle(Color.trameSubdued)
                ForEach(Array(latest.splits.enumerated()), id: \.element.id) { index, split in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                        Text("\(index + 1)")
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.trameSubdued)
                        Text(split.kind.title)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.trameText)
                        Spacer()
                        if let meters = split.distanceMeters {
                            Text(distance(meters))
                                .font(AppFont.captionSemiboldMonospaced)
                                .foregroundStyle(Color.trameSubdued)
                        }
                        Text(duration(split.duration))
                            .font(AppFont.subheadlineSemiboldMonospaced)
                            .foregroundStyle(Color.trameText)
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                    if split.id != latest.splits.last?.id {
                        Divider().overlay(Color.trameSeparator)
                    }
                }
            }

            SportEvidenceDisclosure(
                summary: String(localized: "Evidence & comparison method"),
                detail: hybridMethodology(latest)
            )
        } else {
            SportLensEmptyState(
                title: String(localized: "No simulation splits yet"),
                detail: String(localized: "Complete timed run, station, and transition segments to compare race composition.")
            )
        }
    }

    private func hybridMethodology(_ session: HybridRaceSessionProgress) -> String {
        String(localized: "\(projection.sessions.count) completed simulations are available. The primary composition uses \(session.splits.count) recorded splits from the latest simulation. Session deltas appear only when the prior split-kind sequence matches exactly. Pace appears only for run splits with both duration and distance.")
    }

    private func composition(_ session: HybridRaceSessionProgress) -> [HybridCompositionItem] {
        [
            .init(kind: .run, duration: session.runTime),
            .init(kind: .station, duration: session.stationTime),
            .init(kind: .transition, duration: session.transitionTime)
        ].filter { $0.duration > 0 }
    }

    private func compositionAccessibilityLabel(_ session: HybridRaceSessionProgress) -> String {
        composition(session).map { "\($0.kind.title): \(duration($0.duration))" }.joined(separator: ". ")
    }

    private func splitDeltas(
        _ comparison: (previous: HybridRaceSessionProgress, current: HybridRaceSessionProgress)
    ) -> [HybridSplitDelta] {
        zip(comparison.previous.splits, comparison.current.splits).enumerated().map { index, pair in
            HybridSplitDelta(
                id: pair.1.id,
                label: "\(index + 1) · \(pair.1.kind.title)",
                seconds: pair.1.duration - pair.0.duration
            )
        }
    }

    private func splitDeltaAccessibilityLabel(
        _ comparison: (previous: HybridRaceSessionProgress, current: HybridRaceSessionProgress)
    ) -> String {
        splitDeltas(comparison).map { "\($0.label), \(number($0.seconds)) seconds" }.joined(separator: ". ")
    }
}

private struct HybridSplitDelta: Identifiable {
    let id: UUID
    let label: String
    let seconds: TimeInterval
}

private struct HybridCompositionItem: Identifiable {
    var id: WorkoutSplitKind { kind }
    let kind: WorkoutSplitKind
    let duration: TimeInterval
}

// MARK: - Strongman Lens

private struct StrongmanSportLensView: View {
    let projection: StrongmanProgressProjection

    var body: some View {
        let recordsByFamily = Dictionary(grouping: projection.records, by: \.family)
        let families = StrongmanEventFamily.allCases.filter {
            recordsByFamily[$0]?.isEmpty == false
        }

        if projection.records.isEmpty {
            SportLensEmptyState(
                title: String(localized: "No Strongman records yet"),
                detail: String(localized: "Complete events with snapshotted family and implement conditions to populate this lens.")
            )
        } else {
            ForEach(families, id: \.self) { family in
                let records = recordsByFamily[family] ?? []
                VStack(alignment: .leading, spacing: Spacing.s) {
                    TrameSectionRule(title: LocalizedStringKey(family.title))

                    ForEach(Array(records.prefix(4).enumerated()), id: \.element.id) { index, record in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(record.exerciseName)
                                    .font(AppFont.sectionTitle)
                                    .foregroundStyle(Color.trameText)
                                Text(String(localized: "Condition \(index + 1)"))
                                    .font(AppFont.micro)
                                    .foregroundStyle(Color.trameSubdued)
                            }
                            Spacer(minLength: Spacing.m)
                            Text(strongmanRecord(record))
                                .font(AppFont.metricCompact)
                                .foregroundStyle(Color.trameText)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, Spacing.s)
                        .accessibilityElement(children: .combine)
                        if record.id != records.prefix(4).last?.id {
                            Divider().overlay(Color.trameSeparator)
                        }
                    }
                }
            }

            SportEvidenceDisclosure(
                summary: String(localized: "Evidence & record method"),
                detail: String(localized: "\(projection.records.count) condition-specific records are shown. Each row keeps load, distance, duration, and throw distance in their declared units. Compared only with the same authored event family, load convention, implement, and captured conditions.")
            )
        }
    }

    private func strongmanRecord(_ record: StrongmanEventRecord) -> String {
        var parts: [String] = []
        if let load = record.load, let unit = record.weightUnit { parts.append("\(number(load)) \(unit.rawValue)") }
        if let meters = record.distanceMeters { parts.append(distance(meters)) }
        if let seconds = record.duration { parts.append(duration(seconds)) }
        if let meters = record.throwDistanceMeters { parts.append(String(localized: "\(number(meters)) m throw")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Cardio Lens

private struct CardioSportLensView: View {
    let projection: CardioProgressProjection

    var body: some View {
        if projection.totalDistanceMeters == nil && projection.totalDuration == nil {
            SportLensEmptyState(
                title: String(localized: "No cardio totals yet"),
                detail: String(localized: "Complete cardio sets with distance or duration to populate this lens.")
            )
        } else {
            let metrics: [SportMetricFieldItem] = buildCardioMetrics()

            SportMetricField(tint: .trameConditioning, metrics: metrics)

            let paceWeeks = projection.weeklyDistanceAndDuration.filter {
                $0.value > 0 && ($0.secondaryValue ?? 0) > 0
            }
            if paceWeeks.count > 1 {
                SportLensEvidenceChart(
                    title: String(localized: "Pace trend"),
                    evidence: String(localized: "Weekly duration divided by recorded distance; missing pairs stay absent.")
                ) {
                    Chart(paceWeeks) { metric in
                        LineMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Seconds per kilometer"), (metric.secondaryValue ?? 0) / (metric.value / 1_000))
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color.trameConditioning)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Seconds per kilometer"), (metric.secondaryValue ?? 0) / (metric.value / 1_000))
                        )
                        .symbolSize(64)
                        .foregroundStyle(Color.trameConditioning)
                    }
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                    .accessibilityLabel(paceAccessibilityLabel(paceWeeks))
                }
            } else if projection.weeklyDistanceAndDuration.contains(where: { $0.value > 0 }) {
                SportLensEvidenceChart(
                    title: String(localized: "Distance per week"),
                    evidence: String(localized: "Completed cardio sets with recorded distance.")
                ) {
                    Chart(projection.weeklyDistanceAndDuration) { metric in
                        BarMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Kilometers"), metric.value / 1_000),
                            width: .ratio(0.7)
                        )
                        .foregroundStyle(Color.trameConditioning)
                    }
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                    .accessibilityLabel(cardioAccessibilityLabel)
                }
            }

            SportEvidenceDisclosure(
                summary: String(localized: "Evidence & pace method"),
                detail: cardioMethodology
            )
        }
    }

    private func buildCardioMetrics() -> [SportMetricFieldItem] {
        var metrics: [SportMetricFieldItem] = []
        if let meters = projection.totalDistanceMeters {
            metrics.append(.init(
                value: distance(meters),
                label: String(localized: "distance"),
                accessibilityLabel: String(localized: "\(distance(meters)) total distance")
            ))
        }
        if let seconds = projection.totalDuration {
            metrics.append(.init(
                value: duration(seconds),
                label: String(localized: "duration"),
                accessibilityLabel: String(localized: "\(duration(seconds)) total duration")
            ))
        }
        if let pace = projection.averagePaceSecondsPerKilometer {
            metrics.append(.init(
                value: "\(duration(pace))/km",
                label: String(localized: "average pace"),
                accessibilityLabel: String(localized: "\(duration(pace)) per kilometer average pace")
            ))
        }
        return metrics
    }

    private var cardioAccessibilityLabel: String {
        projection.weeklyDistanceAndDuration.map { metric in
            let date = metric.id.formatted(date: .abbreviated, time: .omitted)
            return metric.evidence.isEmpty
                ? String(localized: "\(date), no recorded cardio distance")
                : String(localized: "\(date), \(number(metric.value / 1_000)) kilometers")
        }.joined(separator: ". ")
    }

    private var cardioMethodology: String {
        let evidenceCount = Set(projection.weeklyDistanceAndDuration.flatMap(\.evidence).map(\.workoutID)).count
        return String(localized: "\(evidenceCount) completed cardio workouts contribute recorded distance or duration in the selected period. Average pace is total recorded duration divided by total recorded distance; activity types and missing distance-duration pairs are not estimated.")
    }

    private func paceAccessibilityLabel(_ metrics: [ProgressWeekMetric]) -> String {
        metrics.map { metric in
            let pace = (metric.secondaryValue ?? 0) / (metric.value / 1_000)
            return String(localized: "\(metric.id.formatted(date: .abbreviated, time: .omitted)), \(duration(pace)) per kilometer")
        }.joined(separator: ". ")
    }
}

// MARK: - Mixed Lens

private struct MixedSportLensView: View {
    let projection: MixedProgressProjection

    var body: some View {
        if projection.composition.isEmpty {
            SportLensEmptyState(
                title: String(localized: "No mixed training yet"),
                detail: String(localized: "Completed workouts will appear here without forcing a primary sport.")
            )
        } else {
            let metrics: [SportMetricFieldItem] = buildMixedMetrics()

            SportMetricField(tint: .trameRecovery, metrics: metrics)

            SportLensEvidenceChart(
                title: String(localized: "Training composition"),
                evidence: String(localized: "Each completed workout contributes one unit, shared across its recorded sports.")
            ) {
                Chart(projection.composition) { item in
                    BarMark(
                        x: .value(String(localized: "Share"), item.proportion),
                        y: .value(String(localized: "Sport"), item.discipline?.title ?? SportDisciplinePalette.unknownLabel)
                    )
                    .foregroundStyle(SportDisciplinePalette.color(for: item.discipline))
                    .annotation(position: .trailing) {
                        Text(item.proportion, format: .percent.precision(.fractionLength(0)))
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.trameText)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.trameSeparator)
                        AxisTick().foregroundStyle(Color.trameSeparator)
                        AxisValueLabel {
                            if let proportion = value.as(Double.self) {
                                Text(proportion, format: .percent.precision(.fractionLength(0)))
                                    .font(AppFont.micro)
                                    .foregroundStyle(Color.trameSubdued)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.trameSeparator)
                        AxisTick().foregroundStyle(Color.trameSeparator)
                        AxisValueLabel()
                            .font(AppFont.micro)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                .chartLegend(.automatic)
                .frame(height: ComponentSize.standardChartHeight)
                .accessibilityLabel(mixedAccessibilityLabel)
            }

            SportEvidenceDisclosure(
                summary: String(localized: "Evidence & composition method"),
                detail: String(localized: "Each of the \(projection.completedWorkoutCount) completed workouts contributes one unit. A workout with multiple recorded sports shares that unit evenly; unknown sport snapshots remain visible as unknown evidence. This is composition, not a score.")
            )
        }
    }

    private func buildMixedMetrics() -> [SportMetricFieldItem] {
        var metrics: [SportMetricFieldItem] = [
            .init(
                value: "\(projection.completedWorkoutCount)",
                label: String(localized: "workouts"),
                accessibilityLabel: String(localized: "\(projection.completedWorkoutCount) completed workouts in this period")
            )
        ]
        if let average = projection.averageWorkoutsPerWeek {
            metrics.append(.init(
                value: number(average),
                label: String(localized: "weekly average"),
                accessibilityLabel: String(localized: "\(number(average)) workouts per week on average")
            ))
        }
        return metrics
    }

    private var mixedAccessibilityLabel: String {
        projection.composition.map { item in
            "\(item.discipline?.title ?? String(localized: "Unknown")): \(item.proportion.formatted(.percent.precision(.fractionLength(0))))"
        }.joined(separator: ". ")
    }
}

// MARK: - Olympic Weightlifting Lens Link

private struct WeightliftingSportLensLink: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Spacing.m) {
                TrameCategoryTile(systemImage: AppIcon.trophy, fill: .trameCompetition)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(String(localized: "Weightlifting dashboard"))
                        .font(AppFont.sectionTitle)
                        .foregroundStyle(Color.trameText)
                    Text(String(localized: "Snatch, Clean & Jerk, attempt outcomes, and technical evidence."))
                        .font(AppFont.metadata)
                        .foregroundStyle(Color.trameSubdued)
                }
                Spacer(minLength: 0)
                Image(systemName: AppIcon.chevronRight)
                    .font(AppFont.micro)
                    .foregroundStyle(Color.trameSubdued)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Opens the detailed Weightlifting evidence dashboard."))
    }
}

// MARK: - Formatters

private func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
}

private func duration(_ seconds: TimeInterval) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: seconds >= 3_600 ? 1 : 0)))
}

private func distance(_ meters: Double) -> String {
    if meters >= 1_000 { return "\(number(meters / 1_000)) km" }
    return "\(number(meters)) m"
}
