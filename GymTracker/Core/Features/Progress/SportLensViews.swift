import Charts
import SwiftUI

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
    @State private var projectionCache: SpecializedSportLensProjectionCache?

    var body: some View {
        let inputID = projectionInputID
        let projection = projectionCache.flatMap {
            $0.inputID == inputID ? $0.projection : nil
        } ?? makeProjection()

        VStack(alignment: .leading, spacing: Spacing.l) {
            GymSectionHeader(title: discipline.title, detail: lensDescription)

            switch projection {
            case .strength(let value):
                StrengthSportLensView(projection: value)
            case .hybrid(let value):
                HybridRaceSportLensView(projection: value)
            case .strongman(let value):
                StrongmanSportLensView(projection: value)
            case .bodybuilding(let metrics):
                WeeklySetsSportLensView(
                    title: String(localized: "Weekly working sets"),
                    evidence: String(localized: "Completed non-warm-up bodybuilding sets."),
                    metrics: metrics
                )
            case .cardio(let value):
                CardioSportLensView(projection: value)
            case .mixed(let value):
                MixedSportLensView(projection: value)
            case .weightlifting:
                WeightliftingSportLensLink()
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

    private var lensDescription: String {
        switch discipline {
        case .powerlifting:
            String(localized: "Exercise records and training exposure from completed Powerlifting snapshots.")
        case .generalStrength:
            String(localized: "Exercise records and weekly working-set exposure.")
        case .hybridFitnessRacing:
            String(localized: "Simulation time, race composition, and recorded splits.")
        case .strongman:
            String(localized: "Best evidence by event family and recorded implement conditions.")
        case .bodybuilding:
            String(localized: "Weekly working-set exposure from completed training.")
        case .generalCardio:
            String(localized: "Distance, duration, and pace from recorded cardio sets.")
        case .mixed:
            String(localized: "A combined view. Mixed training is not treated as one sport.")
        case .olympicWeightlifting:
            String(localized: "Snatch and Clean & Jerk evidence remains in the existing technical dashboard.")
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

private struct StrengthSportLensView: View {
    let projection: StrengthProgressProjection

    private var rankedRecords: [StrengthExerciseProgressRecord] {
        projection.exerciseRecords.sorted {
            ($0.bestEstimatedOneRepMax ?? $0.bestLoad) > ($1.bestEstimatedOneRepMax ?? $1.bestLoad)
        }
    }

    var body: some View {
        if projection.exerciseRecords.isEmpty {
            SportLensEmptyState(
                title: String(localized: "No strength records yet"),
                detail: String(localized: "Complete working sets with load to populate this lens.")
            )
        } else {
            if projection.discipline == .powerlifting {
                GymCard(variant: .accent) {
                    GymEyebrow("Estimated SBD")
                    if let sum = projection.estimatedThreeLiftSum,
                       let unit = projection.estimatedThreeLiftSumUnit {
                        GymMetricValue(value: number(sum), unit: unit.rawValue, isEstimate: true, prominence: .display)
                        Text(String(localized: "Derived from explicitly identified Squat, Bench, and Deadlift history. This is not a competition total."))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    } else {
                        Text(String(localized: "Not available"))
                            .font(AppFont.titleSmallSemibold)
                            .foregroundStyle(Color.gymText)
                        Text(String(localized: "Trame will not guess which historical exercises are the competition Squat, Bench, and Deadlift. Exercise records remain available below."))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                GymSectionHeader(
                    title: String(localized: "Exercise records"),
                    detail: String(localized: "Estimated 1RM is shown only for eligible completed sets of 10 repetitions or fewer.")
                )
                ForEach(rankedRecords.prefix(6)) { record in
                    GymCard {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(record.name)
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.gymText)
                                Text(CountPhrase.sets(record.completedWorkingSetCount))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: Spacing.xs) {
                                GymMetricValue(value: number(record.bestLoad), unit: record.weightUnit.rawValue)
                                if let estimate = record.bestEstimatedOneRepMax {
                                    Text(String(localized: "Estimated 1RM \(number(estimate)) \(record.weightUnit.rawValue)"))
                                        .font(AppFont.captionSemiboldMonospaced)
                                        .foregroundStyle(Color.gymSubduedText)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            WeeklySetsSportLensView(
                title: String(localized: "Working sets per week"),
                evidence: String(localized: "Completed eligible strength sets; warm-ups and non-working sets are excluded."),
                metrics: projection.weeklyWorkingSets
            )
        }
    }
}

private struct WeeklySetsSportLensView: View {
    let title: String
    let evidence: String
    let metrics: [ProgressWeekMetric]

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    var body: some View {
        if metrics.contains(where: { $0.value > 0 }) {
            GymChartCard(title: title, evidence: evidence) {
                Chart(metrics) { metric in
                    BarMark(
                        x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                        y: .value(String(localized: "Sets"), metric.value),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(Color.gymDataEmphasis)
                    .cornerRadius(4)
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

private struct HybridRaceSportLensView: View {
    let projection: HybridRaceProgressProjection

    private var best: HybridRaceSessionProgress? {
        projection.sessions.min { $0.totalTime < $1.totalTime }
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
        if let best {
            GymCard {
                GymEyebrow("Best recorded simulation")
                GymMetricValue(value: duration(best.totalTime), unit: "", prominence: .display)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                    SplitMetric(label: String(localized: "Runs"), value: duration(best.runTime))
                    SplitMetric(label: String(localized: "Stations"), value: duration(best.stationTime))
                    SplitMetric(label: String(localized: "Transitions"), value: duration(best.transitionTime))
                }
            }
            .accessibilityElement(children: .combine)

            GymChartCard(
                title: String(localized: "Race composition"),
                evidence: String(localized: "The fastest recorded simulation, separated by completed split type.")
            ) {
                Chart(composition(best)) { item in
                    BarMark(
                        x: .value(String(localized: "Duration"), item.duration),
                        y: .value(String(localized: "Simulation"), String(localized: "Best"))
                    )
                    .foregroundStyle(by: .value(String(localized: "Split type"), item.kind.title))
                    .cornerRadius(4)
                }
                // Every bar here sits beside the other two at once — a
                // composition, not a time series — so this uses the
                // all-pairs-validated slots rather than the seven-discipline
                // palette's adjacent-pairs ones. See `WorkoutSplitPalette`.
                .chartForegroundStyleScale(
                    domain: WorkoutSplitPalette.domain,
                    range: WorkoutSplitPalette.range
                )
                .gymChartAxisStyle()
                .frame(height: ComponentSize.compactChartHeight)
                .accessibilityLabel(compositionAccessibilityLabel(best))
            }

            if let comparison = latestComparison {
                GymChartCard(
                    title: String(localized: "Split comparison"),
                    evidence: String(localized: "Latest session versus the previous session with the same recorded split structure. Negative values are faster.")
                ) {
                    Chart(splitDeltas(comparison)) { delta in
                        BarMark(
                            x: .value(String(localized: "Time change"), delta.seconds),
                            y: .value(String(localized: "Split"), delta.label)
                        )
                        // Direction, not identity — faster is good, slower
                        // isn't, the same two-state meaning `gymSuccess`/
                        // `gymAccent` already carry everywhere else in the
                        // app. This is status color used correctly, so the
                        // categorical palette above does not apply here.
                        .foregroundStyle(delta.seconds <= 0 ? Color.gymSuccess : Color.gymAccent)
                        .cornerRadius(4)
                    }
                    .gymChartAxisStyle()
                    .chartXAxisLabel(String(localized: "Seconds versus previous"))
                    .frame(height: ComponentSize.standardChartHeight)
                    .accessibilityLabel(splitDeltaAccessibilityLabel(comparison))
                }
            }

            let running = best.splits.filter { $0.kind == .run && ($0.distanceMeters ?? 0) > 0 }
            if running.count > 1 {
                GymChartCard(
                    title: String(localized: "Running degradation"),
                    evidence: String(localized: "Pace across measured run splits in the fastest recorded simulation.")
                ) {
                    Chart {
                        ForEach(Array(running.enumerated()), id: \.element.id) { item in
                            // Area fill under the line at low opacity — the same
                            // "instrument panel" treatment as Oura's trend graphs
                            // (hue at 16% fading to nothing at the baseline)
                            // rather than a bare stroke floating on empty space.
                            AreaMark(
                                x: .value(String(localized: "Run"), item.offset + 1),
                                y: .value(String(localized: "Seconds per kilometer"), item.element.duration / ((item.element.distanceMeters ?? 1) / 1_000))
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.gymDataEmphasis.opacity(0.16), Color.gymDataEmphasis.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            LineMark(
                                x: .value(String(localized: "Run"), item.offset + 1),
                                y: .value(String(localized: "Seconds per kilometer"), item.element.duration / ((item.element.distanceMeters ?? 1) / 1_000))
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(Color.gymDataEmphasis)
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value(String(localized: "Run"), item.offset + 1),
                                y: .value(String(localized: "Seconds per kilometer"), item.element.duration / ((item.element.distanceMeters ?? 1) / 1_000))
                            )
                            .symbolSize(64)
                            .foregroundStyle(Color.gymDataEmphasis)
                        }
                    }
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                    .accessibilityLabel(running.enumerated().map { index, split in
                        String(localized: "Run \(index + 1), \(duration(split.duration / ((split.distanceMeters ?? 1) / 1_000))) per kilometer")
                    }.joined(separator: ". "))
                }
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                GymSectionHeader(
                    title: String(localized: "Recorded splits"),
                    detail: String(localized: "Fastest simulation, in performed order.")
                )
                ForEach(Array(best.splits.enumerated()), id: \.element.id) { index, split in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                        Text("\(index + 1)")
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.gymSubduedText)
                        Text(split.kind.title)
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        Spacer()
                        if let meters = split.distanceMeters {
                            Text(distance(meters))
                                .font(AppFont.captionSemiboldMonospaced)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                        Text(duration(split.duration))
                            .font(AppFont.subheadlineSemiboldMonospaced)
                            .foregroundStyle(Color.gymText)
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
            SportLensEmptyState(
                title: String(localized: "No simulation splits yet"),
                detail: String(localized: "Complete timed run, station, and transition segments to compare race composition.")
            )
        }
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

private struct SplitMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            Text(value)
                .font(AppFont.subheadlineSemiboldMonospaced)
                .foregroundStyle(Color.gymText)
        }
    }
}

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
                    GymSectionHeader(
                        title: family.title,
                        detail: String(localized: "Records compare only identical snapshotted conditions.")
                    )
                    ForEach(records.prefix(4)) { record in
                        GymCard {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                                Text(record.exerciseName)
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.gymText)
                                Spacer(minLength: 0)
                                Text(strongmanRecord(record))
                                    .font(AppFont.subheadlineSemiboldMonospaced)
                                    .foregroundStyle(Color.gymText)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    if let unit = records.compactMap(\.weightUnit).first {
                        let loadRecords = records.filter { $0.weightUnit == unit && $0.load != nil }
                        if loadRecords.count > 1 {
                            GymChartCard(
                                title: String(localized: "\(family.title) load records"),
                                evidence: String(localized: "Only records logged in \(unit.rawValue) are shown together.")
                            ) {
                                Chart(loadRecords) { record in
                                    BarMark(
                                        x: .value(String(localized: "Event"), record.exerciseName),
                                        y: .value(String(localized: "Load"), record.load ?? 0),
                                        width: .ratio(0.6)
                                    )
                                    .foregroundStyle(Color.gymDataEmphasis)
                                    .cornerRadius(4)
                                }
                                .gymChartAxisStyle()
                                .frame(height: ComponentSize.compactChartHeight)
                                .accessibilityLabel(loadRecords.map { "\($0.exerciseName): \(number($0.load ?? 0)) \(unit.rawValue)" }.joined(separator: ". "))
                            }
                        }
                    }

                    eventChart(family: family, records: records)
                }
            }
        }
    }

    @ViewBuilder
    private func eventChart(family: StrongmanEventFamily, records: [StrongmanEventRecord]) -> some View {
        switch family {
        case .carry, .hold:
            let measured = records.filter { $0.load != nil && $0.duration != nil }
            if measured.count > 1, let unit = measured.first?.weightUnit {
                GymChartCard(
                    title: family == .carry ? String(localized: "Load to carry time") : String(localized: "Load to hold time"),
                    evidence: String(localized: "Each point keeps its recorded implement conditions separate.")
                ) {
                    Chart(measured) { record in
                        PointMark(
                            x: .value(String(localized: "Load"), record.load ?? 0),
                            y: .value(String(localized: "Seconds"), record.duration ?? 0)
                        )
                        .symbolSize(64)
                        .foregroundStyle(Color.gymDataEmphasis)
                    }
                    .gymChartAxisStyle()
                    .chartXAxisLabel(unit.rawValue)
                    .frame(height: ComponentSize.compactChartHeight)
                }
            }
        case .throwing:
            let measured = records.filter { $0.throwDistanceMeters != nil }
            if measured.isEmpty == false {
                GymChartCard(
                    title: String(localized: "Throw distance"),
                    evidence: String(localized: "Best measured throw for each compatible event condition.")
                ) {
                    Chart(measured) { record in
                        BarMark(
                            x: .value(String(localized: "Event"), record.exerciseName),
                            y: .value(String(localized: "Meters"), record.throwDistanceMeters ?? 0),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(Color.gymDataEmphasis)
                        .cornerRadius(4)
                    }
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                }
            }
        default:
            EmptyView()
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

private struct CardioSportLensView: View {
    let projection: CardioProgressProjection

    var body: some View {
        if projection.totalDistanceMeters == nil && projection.totalDuration == nil {
            SportLensEmptyState(
                title: String(localized: "No cardio totals yet"),
                detail: String(localized: "Complete cardio sets with distance or duration to populate this lens.")
            )
        } else {
            GymCard {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                    if let meters = projection.totalDistanceMeters {
                        SplitMetric(label: String(localized: "Distance"), value: distance(meters))
                    }
                    if let seconds = projection.totalDuration {
                        SplitMetric(label: String(localized: "Duration"), value: duration(seconds))
                    }
                    if let pace = projection.averagePaceSecondsPerKilometer {
                        SplitMetric(label: String(localized: "Average pace"), value: "\(duration(pace))/km")
                    }
                }
            }
            .accessibilityElement(children: .combine)

            GymChartCard(
                title: String(localized: "Distance per week"),
                evidence: String(localized: "Completed cardio sets with recorded distance.")
            ) {
                Chart(projection.weeklyDistanceAndDuration) { metric in
                    BarMark(
                        x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                        y: .value(String(localized: "Kilometers"), metric.value / 1_000),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(Color.gymDataEmphasis)
                    .cornerRadius(4)
                }
                .gymChartAxisStyle()
                .frame(height: ComponentSize.compactChartHeight)
                .accessibilityLabel(cardioAccessibilityLabel)
            }


            let paceWeeks = projection.weeklyDistanceAndDuration.filter {
                $0.value > 0 && ($0.secondaryValue ?? 0) > 0
            }
            if paceWeeks.count > 1 {
                GymChartCard(
                    title: String(localized: "Pace trend"),
                    evidence: String(localized: "Weekly duration divided by recorded distance; missing pairs stay absent.")
                ) {
                    Chart(paceWeeks) { metric in
                        AreaMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Seconds per kilometer"), (metric.secondaryValue ?? 0) / (metric.value / 1_000))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gymDataEmphasis.opacity(0.16), Color.gymDataEmphasis.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Seconds per kilometer"), (metric.secondaryValue ?? 0) / (metric.value / 1_000))
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color.gymDataEmphasis)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value(String(localized: "Week"), metric.id, unit: .weekOfYear),
                            y: .value(String(localized: "Seconds per kilometer"), (metric.secondaryValue ?? 0) / (metric.value / 1_000))
                        )
                        .symbolSize(64)
                        .foregroundStyle(Color.gymDataEmphasis)
                    }
                    .gymChartAxisStyle()
                    .frame(height: ComponentSize.compactChartHeight)
                }
            }
        }
    }

    private var cardioAccessibilityLabel: String {
        projection.weeklyDistanceAndDuration.map { metric in
            "\(metric.id.formatted(date: .abbreviated, time: .omitted)): \(number(metric.value / 1_000)) kilometers"
        }.joined(separator: ". ")
    }
}

private struct MixedSportLensView: View {
    let projection: MixedProgressProjection

    var body: some View {
        if projection.composition.isEmpty {
            SportLensEmptyState(
                title: String(localized: "No mixed training yet"),
                detail: String(localized: "Completed workouts will appear here without forcing a primary sport.")
            )
        } else {
            GymCard {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                    SplitMetric(label: String(localized: "Workouts"), value: "\(projection.completedWorkoutCount)")
                    if let average = projection.averageWorkoutsPerWeek {
                        SplitMetric(label: String(localized: "Weekly average"), value: number(average))
                    }
                }
            }
            .accessibilityElement(children: .combine)

            GymChartCard(
                title: String(localized: "Training composition"),
                evidence: String(localized: "Each completed workout contributes one unit, shared across its recorded sports.")
            ) {
                Chart(projection.composition) { item in
                    BarMark(
                        x: .value(String(localized: "Share"), item.proportion),
                        y: .value(String(localized: "Sport"), item.discipline?.title ?? SportDisciplinePalette.unknownLabel)
                    )
                    // Each row is already one specific discipline — coloring
                    // it that discipline's own chart color, the same one the
                    // Global lens's focus chart uses, is what makes "which
                    // sport is this" answerable at a glance instead of every
                    // row being the same neutral bar with only a text label
                    // to tell them apart.
                    .foregroundStyle(SportDisciplinePalette.color(for: item.discipline))
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(item.proportion, format: .percent.precision(.fractionLength(0)))
                            .font(AppFont.captionSemiboldMonospaced)
                            .foregroundStyle(Color.gymText)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.gymBorder)
                        AxisTick().foregroundStyle(Color.gymBorder)
                        AxisValueLabel {
                            if let proportion = value.as(Double.self) {
                                Text(proportion, format: .percent.precision(.fractionLength(0)))
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.gymBorder)
                        AxisTick().foregroundStyle(Color.gymBorder)
                        AxisValueLabel().foregroundStyle(Color.gymSubduedText)
                    }
                }
                .chartLegend(.automatic)
                .frame(height: ComponentSize.standardChartHeight)
                .accessibilityLabel(mixedAccessibilityLabel)
            }
        }
    }

    private var mixedAccessibilityLabel: String {
        projection.composition.map { item in
            "\(item.discipline?.title ?? String(localized: "Unknown")): \(item.proportion.formatted(.percent.precision(.fractionLength(0))))"
        }.joined(separator: ". ")
    }
}

private struct WeightliftingSportLensLink: View {
    var body: some View {
        NavigationLink(value: ProgressRoute.weightlifting) {
            GymCard {
                HStack(spacing: Spacing.m) {
                    GymIconChip(systemImage: AppIcon.trophy)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(String(localized: "Open Weightlifting dashboard"))
                            .font(AppFont.subheadlineSemibold)
                            .foregroundStyle(Color.gymText)
                        Text(String(localized: "Snatch, Clean & Jerk, attempt outcomes, and technical evidence."))
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: AppIcon.chevronRight)
                        .foregroundStyle(Color.gymSubduedText)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Opens the detailed Weightlifting evidence dashboard."))
    }
}

private struct SportLensEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        GymCard {
            ContentUnavailableView(title, systemImage: AppIcon.chart, description: Text(detail))
        }
    }
}

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
