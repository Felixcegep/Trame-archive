import Charts
import SwiftData
import SwiftUI

/// The selected interpretation of completed training. Global is always
/// available; sport lenses exist only when immutable performed snapshots carry
/// evidence for that discipline.
enum ProgressLens: Hashable {
    case global
    case sport(SportDiscipline)

    var title: String {
        switch self {
        case .global: String(localized: "Global")
        case let .sport(discipline): discipline.title
        }
    }
}

/// A stat tile's third piece, per the dataviz method's own stat-tile contract:
/// signed, versus a named period. Deliberately not a bare `+2`/`-2` — the
/// direction is also color and an icon, matching the exact "faster is good,
/// slower isn't" logic `HybridRaceSportLensView`'s split-comparison chart
/// already uses, rather than a third invented color scheme for the same idea.
struct ProgressMetricDelta {
    let current: Int
    let previous: Int

    private var difference: Int { current - previous }

    var text: String {
        if difference == 0 { return String(localized: "No change") }
        return difference > 0 ? "+\(difference)" : "\(difference)"
    }

    var icon: String {
        if difference == 0 { return AppIcon.trendFlat }
        return difference > 0 ? AppIcon.trendUp : AppIcon.trendDown
    }

    /// More is not unconditionally "good" here — training less can be the
    /// right call — but it is the more-active direction, and `gymSecondary`/
    /// `gymAccent` is the same pairing the split-comparison chart already
    /// uses for "the direction that took more work" versus its opposite,
    /// not a claim about which one was the better training decision.
    var color: Color {
        if difference == 0 { return .gymSubduedText }
        return difference > 0 ? .gymSecondary : .gymAccent
    }

    var accessibilityLabel: String {
        if difference == 0 { return String(localized: "No change from the previous period") }
        let magnitude = abs(difference)
        return difference > 0
            ? String(localized: "\(magnitude) more than the previous period")
            : String(localized: "\(magnitude) fewer than the previous period")
    }
}

struct AthleteIntelligenceSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [TrainingProfile]
    @Binding var selectedLens: ProgressLens
    @Binding var isEditingProfile: Bool
    let range: AnalyticsDateRange
    let workouts: [Workout]
    @State private var projectionCache: AthleteIntelligenceProjectionCache?

    private var profile: TrainingProfile? { profiles.first }

    init(
        selectedLens: Binding<ProgressLens>,
        isEditingProfile: Binding<Bool>,
        range: AnalyticsDateRange,
        workouts: [Workout]
    ) {
        _selectedLens = selectedLens
        _isEditingProfile = isEditingProfile
        self.range = range
        self.workouts = workouts

        var descriptor = FetchDescriptor<TrainingProfile>()
        descriptor.fetchLimit = 1
        _profiles = Query(descriptor)
    }

    /// Completed workout graphs are immutable evidence. Hashing their roots
    /// and the mutable profile revision is enough to reuse the expensive
    /// derived projections across sheet, picker, and other local view-state
    /// updates without walking every exercise/set graph in `body`.
    private var projectionInputID: Int {
        var revision = Hasher()
        revision.combine(range)
        revision.combine(LocalDay.today.rawValue)
        revision.combine(profile?.id)
        revision.combine(profile?.updatedAt)
        for workout in workouts where workout.isCompleted {
            revision.combine(workout.id)
            revision.combine(workout.startTime)
            revision.combine(workout.endTime)
        }
        return revision.finalize()
    }

    private func makeProjection(inputID: Int) -> AthleteIntelligenceProjectionCache {
        let completed = workouts.filter(\.isCompleted)
        let selectedInterval = range.dateInterval()
        let interval = selectedInterval ?? DateInterval(
            start: completed.map(\.startTime).min() ?? Date.now,
            end: Date.now.addingTimeInterval(1)
        )
        let inRange = selectedInterval.map { selected in
            completed.filter { selected.contains($0.startTime) }
        } ?? completed

        let availability = ProgressSportLensAvailabilityProjector.project(
            workouts: completed,
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

        var workoutsByDiscipline: [SportDiscipline: [Workout]] = [:]
        for workout in inRange {
            let disciplines = Set(workout.orderedExercises.compactMap {
                $0.sportDisciplineSnapshotRaw.flatMap(SportDiscipline.init(rawValue:))
            })
            for discipline in disciplines {
                workoutsByDiscipline[discipline, default: []].append(workout)
            }
        }
        // Mixed is the cross-discipline composition of the selected period,
        // not a filter for the rarely-authored `.mixed` exercise snapshot.
        // Supplying only that dictionary bucket made ordinary Powerlifting +
        // Cardio history render as an empty Mixed lens.
        workoutsByDiscipline[.mixed] = inRange

        let delta: ProgressMetricDelta? = {
            guard let currentInterval = selectedInterval,
                  let previousInterval = range.dateInterval(endingAt: currentInterval.start)
            else { return nil }
            var previousCount = 0
            for workout in completed where previousInterval.contains(workout.startTime) {
                previousCount += 1
            }
            return ProgressMetricDelta(current: inRange.count, previous: previousCount)
        }()

        return AthleteIntelligenceProjectionCache(
            inputID: inputID,
            availability: availability,
            suggestion: shouldOfferSuggestion
                ? SportProfileSuggestionService.suggest(workouts: completed)
                : nil,
            interval: interval,
            timeline: ProgressSportFocusTimeline.project(workouts: completed, interval: interval),
            global: GlobalProgressProjection.project(workouts: inRange),
            workoutCountDelta: delta,
            workoutsByDiscipline: workoutsByDiscipline
        )
    }

    var body: some View {
        let inputID = projectionInputID
        let projection = projectionCache.flatMap {
            $0.inputID == inputID ? $0 : nil
        } ?? makeProjection(inputID: inputID)

        athleteProfileCard(suggestion: projection.suggestion)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .task(id: inputID) {
                guard projectionCache?.inputID != inputID else { return }
                projectionCache = projection
            }

        lensPicker(availability: projection.availability)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: Spacing.s, trailing: 0))

        switch selectedLens {
        case .global:
            globalContent(projection)
        case let .sport(discipline):
            sportContent(discipline, projection: projection)
        }
    }

    private func athleteProfileCard(suggestion: SportProfileSuggestion?) -> some View {
        GymCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .top, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        GymEyebrow("Athlete profile")
                        Text(profileTitle)
                            .font(AppFont.titleSmallSemibold)
                            .foregroundStyle(Color.gymText)
                        if let detail = profileDetail {
                            Text(detail)
                                .font(AppFont.caption)
                                .foregroundStyle(Color.gymSubduedText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(String(localized: "Edit")) { isEditingProfile = true }
                        .font(AppFont.subheadlineSemibold)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("progress-athlete-profile-edit")
                }

                if shouldOfferSuggestion, let suggestion {
                    Divider().overlay(Color.gymBorder)
                    suggestionView(suggestion)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress-athlete-profile")
    }

    private var profileTitle: String {
        guard let profile else { return String(localized: "Training profile not set") }
        switch profile.progressOrganizationMode {
        case .mixed: return String(localized: "Mixed training")
        case .undecided: return String(localized: "No primary sport")
        case .sportPriority, nil: return profile.primaryDiscipline?.title ?? String(localized: "Training profile not set")
        }
    }

    private var profileDetail: String? {
        guard let profile else {
            return String(localized: "Add optional preferences to prioritize Progress without changing training history.")
        }
        var parts: [String] = []
        if let experience = profile.experienceLevel { parts.append(experience.title) }
        if let goal = profile.primaryGoal { parts.append(goal.title) }
        if !profile.secondaryDisciplines.isEmpty {
            let titles = profile.secondaryDisciplines.map(\.title).formatted(.list(type: .and))
            parts.append(String(localized: "Also trains: \(titles)"))
        }
        if let days = profile.preferredDaysPerWeek { parts.append(CountPhrase.days(days)) }
        if let competition = profile.competition {
            if let discipline = competition.discipline { parts.append(discipline.title) }
            if let date = competition.eventDate {
                parts.append(String(localized: "Competition \(date.formatted(date: .abbreviated, time: .omitted))"))
            }
        }
        return parts.isEmpty ? String(localized: "Profile controls priority, not historical truth.") : parts.joined(separator: " · ")
    }

    private var shouldOfferSuggestion: Bool {
        profile?.primaryDiscipline == nil
            && profile?.progressOrganizationMode != .mixed
            && profile?.progressOrganizationMode != .undecided
    }

    private func suggestionView(_ suggestion: SportProfileSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(String(localized: "Your recent training looks mostly like \(suggestion.discipline.title)."))
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            Text(suggestion.reasons.first ?? String(localized: "Based on completed training snapshots."))
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            HStack(spacing: Spacing.s) {
                Button(String(localized: "Use \(suggestion.discipline.title)")) {
                    applySuggestion(suggestion)
                }
                .buttonStyle(GymPrimaryButtonStyle(prominence: .standard))
                .accessibilityIdentifier("progress-profile-use-suggestion")
                Button(String(localized: "Keep mixed")) { keepMixed() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("progress-profile-keep-mixed")
            }
            Button(String(localized: "Not now")) { deferCategorization() }
                .font(AppFont.captionBold)
                .frame(minHeight: 44)
                .accessibilityIdentifier("progress-profile-not-now")
        }
        .accessibilityIdentifier("progress-profile-suggestion")
    }

    private func lensPicker(availability: [ProgressSportLensAvailability]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                lensButton(.global)
                if profile?.progressOrganizationMode == .mixed || availability.count > 1 {
                    lensButton(.sport(.mixed))
                }
                ForEach(availability) { lens in
                    lensButton(.sport(lens.discipline))
                }
            }
            .padding(.horizontal, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("progress-sport-lens-picker")
    }

    private func lensButton(_ lens: ProgressLens) -> some View {
        Button(lens.title) { selectedLens = lens }
            .font(AppFont.subheadlineSemibold)
            .foregroundStyle(selectedLens == lens ? Color.white : Color.gymText)
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(selectedLens == lens ? Color.gymPrimaryDeep : Color.gymCard)
            )
            .overlay(Capsule().stroke(Color.gymBorder, lineWidth: selectedLens == lens ? 0 : 1))
            .accessibilityAddTraits(selectedLens == lens ? .isSelected : [])
            .accessibilityIdentifier("progress-lens-\(lensIdentifier(lens))")
    }

    @ViewBuilder
    private func globalContent(_ projection: AthleteIntelligenceProjectionCache) -> some View {
        globalSummary(projection.global, delta: projection.workoutCountDelta)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

        if projection.timeline.periods.contains(where: \.hasEvidence) {
            sportFocusChart(projection.timeline)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }

        sportHighlights(projection.global.sportHighlights)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }

    private func globalSummary(
        _ projection: GlobalProgressProjection,
        delta: ProgressMetricDelta?
    ) -> some View {
        GymCard {
            GymEyebrow("Selected period")
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xl) {
                metric(
                    value: "\(projection.completedWorkoutCount)",
                    label: projection.completedWorkoutCount == 1
                        ? String(localized: "workout")
                        : String(localized: "workouts"),
                    delta: delta
                )
                if let duration = projection.trainingTime {
                    metric(value: trainingTimeText(duration), label: String(localized: "trained"))
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-global-summary")
    }

    /// The workout-count stat tile used to be `label` and `value` alone — half
    /// of the dataviz method's own stat-tile contract, which names `delta`
    /// (signed, versus a named period) as the third piece: a number on its own
    /// answers "how much," never "is that more or less than usual," which is
    /// the question a lifter glancing at this card is actually asking.
    ///
    /// Compared against the immediately preceding period of the same length —
    /// `range.dateInterval(endingAt:)` ending right where the current window
    /// begins — rather than a fixed "last four weeks," so a 12-week or
    /// 6-month selection is compared like-for-like instead of against a
    /// window a different size than the one on screen. `nil` for All Time:
    /// there is no equivalent prior window to name, and a delta with nothing
    /// real to compare against is worse than the plain number.
    private func sportFocusChart(_ timeline: ProgressSportFocusTimeline) -> some View {
        let marks = timeline.periods.flatMap { period in
            period.slices.map { slice in
                SportFocusChartMark(
                    week: period.id,
                    disciplineTitle: slice.discipline?.title ?? SportDisciplinePalette.unknownLabel,
                    proportion: slice.proportion
                )
            }
        }
        return GymChartCard(
            title: String(localized: "Sport focus over time"),
            evidence: String(localized: "Each completed workout contributes at most one unit, shared across its recorded sports."),
            takeaway: timeline.quality == .insufficient ? String(localized: "More completed training is needed before describing a trend.") : nil
        ) {
            Chart {
                ForEach(marks) { mark in
                    BarMark(
                        x: .value(String(localized: "Week"), mark.week, unit: .weekOfYear),
                        y: .value(String(localized: "Share"), mark.proportion),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(by: .value(String(localized: "Sport"), mark.disciplineTitle))
                    .cornerRadius(4)
                }
            }
            // Fixed-order, validated colors instead of Swift Charts' own
            // auto-generated ramp — see `SportDisciplinePalette`. This is
            // what makes the legend below stable: the same discipline is the
            // same color on every device, every dataset, every week.
            .chartForegroundStyleScale(
                domain: SportDisciplinePalette.domain,
                range: SportDisciplinePalette.range
            )
            .chartYAxis {
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
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.gymBorder)
                    AxisTick().foregroundStyle(Color.gymBorder)
                    AxisValueLabel().foregroundStyle(Color.gymSubduedText)
                }
            }
            .chartLegend(.automatic)
            .frame(height: 190)
            .accessibilityLabel(sportFocusAccessibilityLabel(timeline))
        }
        .accessibilityIdentifier("progress-sport-focus-chart")
    }

    private func sportHighlights(_ highlights: [ProgressSportHighlight]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: String(localized: "Sport highlights"), detail: String(localized: "Completed historical snapshots only."))
            if highlights.isEmpty {
                ContentUnavailableView(String(localized: "No sport highlights"), systemImage: AppIcon.chart)
            } else {
                ForEach(highlights.filter { $0.metric == .completedWorkouts }) { highlight in
                    GymCard {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(highlight.discipline.title)
                                    .font(AppFont.subheadlineSemibold)
                                Text(highlightText(highlight))
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer()
                            Image(systemName: AppIcon.chevronRight)
                                .foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedLens = .sport(highlight.discipline) }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .accessibilityIdentifier("progress-sport-highlights")
    }

    private func sportContent(
        _ discipline: SportDiscipline,
        projection: AthleteIntelligenceProjectionCache
    ) -> some View {
        SpecializedSportLensView(
            discipline: discipline,
            workouts: projection.workoutsByDiscipline[discipline] ?? [],
            interval: projection.interval,
            competitionLifts: powerliftingLiftIdentity
        )
    }

    private var powerliftingLiftIdentity: PowerliftingLiftIdentity? {
        guard let competition = profile?.competition,
              let squat = competition.squatExerciseID,
              let bench = competition.benchExerciseID,
              let deadlift = competition.deadliftExerciseID,
              Set([squat, bench, deadlift]).count == 3
        else { return nil }
        return PowerliftingLiftIdentity(
            squatExerciseID: squat,
            benchExerciseID: bench,
            deadliftExerciseID: deadlift
        )
    }

    private func metric(value: String, label: String, delta: ProgressMetricDelta? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppFont.displayMedium)
                .monospacedDigit()
                .foregroundStyle(Color.gymText)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
            if let delta {
                Label(delta.text, systemImage: delta.icon)
                    .font(AppFont.captionSemiboldMonospaced)
                    .foregroundStyle(delta.color)
                    .accessibilityLabel(delta.accessibilityLabel)
            }
        }
    }

    /// Sets the profile's primary sport *and* moves the picker to it.
    ///
    /// Before this, accepting a suggestion ("Use Powerlifting") saved the
    /// profile and left the lens picker exactly where it was — the pill for
    /// the sport the lifter just confirmed appeared in the row, but nothing
    /// took them to it. They had just answered "what is my sport" and were
    /// shown the same Global chart as before, as if the question hadn't
    /// landed anywhere. The suggestion card's whole premise is "this is your
    /// sport" — finishing that action should be the thing that shows it.
    private func applySuggestion(_ suggestion: SportProfileSuggestion) {
        let target = profile ?? {
            let created = TrainingProfile()
            modelContext.insert(created)
            return created
        }()
        target.primaryDisciplineRaw = suggestion.discipline.rawValue
        target.progressOrganizationModeRaw = ProgressOrganizationMode.sportPriority.rawValue
        target.updatedAt = .now
        saveProfile()
        if let discipline = suggestion.discipline.sportDiscipline {
            selectedLens = .sport(discipline)
        }
    }

    private func keepMixed() {
        let target = profile ?? {
            let created = TrainingProfile()
            modelContext.insert(created)
            return created
        }()
        target.progressOrganizationModeRaw = ProgressOrganizationMode.mixed.rawValue
        target.updatedAt = .now
        saveProfile()
        selectedLens = .sport(.mixed)
    }

    private func deferCategorization() {
        let target = profile ?? {
            let created = TrainingProfile()
            modelContext.insert(created)
            return created
        }()
        target.progressOrganizationModeRaw = ProgressOrganizationMode.undecided.rawValue
        target.updatedAt = .now
        saveProfile()
    }

    private func saveProfile() {
        do { try modelContext.save() } catch { modelContext.rollback() }
    }

    private func lensIdentifier(_ lens: ProgressLens) -> String {
        switch lens {
        case .global: "global"
        case let .sport(discipline): discipline.rawValue
        }
    }

    private func highlightText(_ highlight: ProgressSportHighlight) -> String {
        let value = Int(highlight.value ?? 0)
        return CountPhrase.completedWorkouts(value)
    }

    private func sportFocusAccessibilityLabel(_ timeline: ProgressSportFocusTimeline) -> String {
        timeline.periods.map { period in
            let date = period.id.formatted(date: .abbreviated, time: .omitted)
            guard period.hasEvidence else { return String(localized: "\(date), no completed training") }
            let slices = period.slices.map { slice in
                let title = slice.discipline?.title ?? String(localized: "Unknown")
                return "\(title) \(Int((slice.proportion * 100).rounded())) percent"
            }.joined(separator: ", ")
            return "\(date), \(slices)"
        }.joined(separator: ". ")
    }

    private func trainingTimeText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

}

@MainActor
private struct AthleteIntelligenceProjectionCache {
    let inputID: Int
    let availability: [ProgressSportLensAvailability]
    let suggestion: SportProfileSuggestion?
    let interval: DateInterval
    let timeline: ProgressSportFocusTimeline
    let global: GlobalProgressProjection
    let workoutCountDelta: ProgressMetricDelta?
    let workoutsByDiscipline: [SportDiscipline: [Workout]]
}

private struct SportFocusChartMark: Identifiable {
    var id: String { "\(week.timeIntervalSinceReferenceDate):\(disciplineTitle)" }
    let week: Date
    let disciplineTitle: String
    let proportion: Double
}
