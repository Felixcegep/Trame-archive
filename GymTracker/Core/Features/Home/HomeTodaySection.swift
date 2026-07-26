import SwiftData
import SwiftUI

/// Today's daily log, as one grouped card.
///
/// This replaces the former `TODAY` / `NUTRITION` / `MOBILITY` sections, which
/// stacked six full-width cards under three headings to convey five one-line
/// facts. Rows are state-driven: a row that has nothing to say is not rendered
/// at all rather than rendered as an empty state, so the card only ever shows
/// actions the user can take right now.
struct HomeTodaySection: View {
    @Environment(\.modelContext) private var modelContext

    let activeWorkout: Workout?
    @Binding var isShowingDailyCheckIn: Bool
    @Binding var isShowingCaffeineLog: Bool
    let onOpenNutrition: () -> Void
    let onStartMobility: (MobilityRoutine, MobilitySessionContext, UUID?) -> Void
    let onResumeMobility: (MobilitySession) -> Void

    @Query private var dailyLogEntries: [DailyLogEntry]
    @Query private var supplementOccurrences: [SupplementOccurrence]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var nutritionTargets: [NutritionTarget]
    @Query private var planRuns: [PlanRun]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
    @Query(sort: \MobilityRoutine.updatedAt, order: .reverse) private var mobilityRoutines: [MobilityRoutine]
    @Query(sort: \MobilitySession.updatedAt, order: .reverse) private var mobilitySessions: [MobilitySession]
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Today")

            LibraryGroupCard {
                checkInRow

                if featureFlags.isEnabled(.nutrition) {
                    LibraryGroupDivider()
                    nutritionRow

                    LibraryGroupDivider()
                    caffeineRow
                }

                LibraryGroupDivider()
                creatineRow

                if hasMobilityRow {
                    LibraryGroupDivider()
                    mobilityRow
                }
            }
        }
    }
}

// MARK: - Check-in

private extension HomeTodaySection {
    var todayDay: LocalDay { .today }

    var dailyLogEntry: DailyLogEntry? {
        dailyLogEntries.first { $0.dayKey == todayDay.rawValue }
    }

    var checkInRow: some View {
        Button {
            isShowingDailyCheckIn = true
        } label: {
            TodayLogRow(
                icon: AppIcon.checkIn,
                iconColor: Color.gymAccent,
                title: "Check-in",
                value: checkInValue,
                isComplete: dailyLogEntry?.status == .completed
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("open-daily-check-in")
        .accessibilityLabel("Daily check-in, \(checkInValue)")
    }

    var checkInValue: String {
        guard let dailyLogEntry else { return String(localized: "Not logged") }
        return dailyLogEntry.status == .completed
            ? String(localized: "Logged")
            : String(localized: "Skipped")
    }
}

// MARK: - Creatine

private extension HomeTodaySection {
    var creatineOccurrence: SupplementOccurrence? {
        supplementOccurrences.first {
            $0.dayKey == todayDay.rawValue && $0.kind == .creatine
        }
    }

    var creatineTaken: Bool {
        creatineOccurrence?.status == .completed
    }

    var creatineRow: some View {
        Button(action: toggleCreatine) {
            TodayLogRow(
                icon: AppIcon.supplement,
                iconColor: Color.gymSecondary,
                title: "Creatine",
                value: creatineTaken
                    ? String(localized: "Confirmed")
                    : String(localized: "Confirm"),
                isComplete: creatineTaken
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("toggle-creatine")
        .accessibilityValue(creatineTaken ? "Confirmed" : "Not confirmed")
    }

    func toggleCreatine() {
        _ = SupplementOccurrenceService.setCreatine(
            taken: !creatineTaken,
            day: todayDay,
            using: modelContext
        )
    }
}

// MARK: - Nutrition

private extension HomeTodaySection {
    var nutritionSummary: NutritionDaySummary {
        NutritionDaySummary.resolve(day: .today, meals: loggedMeals)
    }

    var nutritionRow: some View {
        let summary = nutritionSummary
        let resolution = NutritionTargetResolver.resolve(
            day: .today,
            planRuns: planRuns,
            targets: nutritionTargets
        )
        let value = "\(FoodLibraryService.format(summary.totals.calories)) kcal · \(FoodLibraryService.format(summary.totals.protein)) g protein"

        return Button(action: onOpenNutrition) {
            TodayLogRow(
                icon: AppIcon.nutrition,
                iconColor: Color.gymSecondary,
                title: "Nutrition",
                value: value,
                isComplete: !summary.meals.isEmpty
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("open-nutrition-today")
        .accessibilityLabel("Nutrition today, \(value), \(nutritionDetail(summary: summary, resolution: resolution))")
    }

    func nutritionDetail(
        summary: NutritionDaySummary,
        resolution: (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues)
    ) -> String {
        let target = resolution.values.calories.map { "of \(FoodLibraryService.format($0)) kcal" } ?? "No calorie target"
        let unknown = summary.totals.hasUnknownValues ? " · Some nutrients unknown" : ""
        return "\(resolution.kind.displayName) · \(target)\(unknown)"
    }
}

// MARK: - Caffeine

private extension HomeTodaySection {
    var caffeineDailyLimit: CaffeineDailyLimit {
        let birthdate = caffeineBirthdateTimestamp.map { Date(timeIntervalSince1970: $0) }
        let ageBand = CaffeineGuidance.ageBand(birthdate: birthdate)
        return CaffeineGuidance.dailyLimit(
            ageBand: ageBand,
            bodyWeightKilograms: bodyWeightEntries.first.map { Double($0.kilograms) }
        )
    }

    var caffeineRow: some View {
        let summary = nutritionSummary

        return Button { isShowingCaffeineLog = true } label: {
            TodayLogRow(
                icon: AppIcon.caffeine,
                iconColor: Color.gymAccent,
                title: "Caffeine",
                value: caffeineValue(summary: summary)
            )
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("today-caffeine-summary")
        .accessibilityLabel("Caffeine today, \(caffeineAccessibilityValue(summary: summary)). Add a drink.")
    }

    /// Compact enough for a trailing value. The full daily-reference comparison
    /// stays in the accessibility label, where there is room for it.
    func caffeineValue(summary: NutritionDaySummary) -> String {
        let milligrams = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) mg"
        if case .milligrams(let limit, _) = caffeineDailyLimit,
           summary.totals.caffeineMilligrams > limit {
            return "\(milligrams) · over reference"
        }
        return milligrams
    }

    func caffeineReferenceSuffix(loggedMilligrams: Double) -> String {
        guard case .milligrams(let mg, _) = caffeineDailyLimit else { return "" }
        let isOver = loggedMilligrams > mg
        let isNear = !isOver && mg > 0 && loggedMilligrams >= mg * 0.8
        var suffix = " · \(FoodLibraryService.format(mg)) mg reference"
        if isOver {
            suffix += " · Over daily reference"
        } else if isNear {
            suffix += " · Near daily reference"
        }
        return suffix
    }

    func caffeineAccessibilityValue(summary: NutritionDaySummary) -> String {
        let value = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) milligrams logged\(caffeineReferenceSuffix(loggedMilligrams: summary.totals.caffeineMilligrams))"
        return summary.totals.unknownCaffeineCount > 0 ? "\(value), some entries have unknown caffeine" : value
    }
}

// MARK: - Mobility

private extension HomeTodaySection {
    var activeMobilitySession: MobilitySession? {
        mobilitySessions.first { $0.status == .active }
    }

    var availableMobilityRoutine: MobilityRoutine? {
        mobilityRoutines.first { $0.isArchived == false && $0.items.isEmpty == false }
    }

    /// Discovering and creating routines is the Train tab's job, so Today stays
    /// silent when there is nothing to run rather than advertising an empty state.
    var hasMobilityRow: Bool {
        guard featureFlags.isEnabled(.mobility) else {
            // An already-running session still resumes: disabling a domain hides
            // new entry points, it never strands in-progress work.
            return activeMobilitySession != nil
        }
        return activeMobilitySession != nil || availableMobilityRoutine != nil
    }

    @ViewBuilder
    var mobilityRow: some View {
        if let activeMobilitySession {
            Button {
                onResumeMobility(activeMobilitySession)
            } label: {
                TodayLogRow(
                    icon: AppIcon.mobility,
                    iconColor: Color.gymAccent,
                    title: "Mobility",
                    value: "Resume · \(min(activeMobilitySession.currentEntryIndex + 1, activeMobilitySession.entries.count)) of \(activeMobilitySession.entries.count)"
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("resume-mobility-session")
        } else if let routine = availableMobilityRoutine {
            Button {
                let context: MobilitySessionContext = activeWorkout == nil ? .standalone : .warmup
                onStartMobility(routine, context, activeWorkout?.id)
            } label: {
                TodayLogRow(
                    icon: AppIcon.mobility,
                    iconColor: Color.gymAccent,
                    title: activeWorkout == nil ? "Mobility" : "Mobility warm-up",
                    value: routine.name
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("start-mobility-routine")
        }
    }
}
