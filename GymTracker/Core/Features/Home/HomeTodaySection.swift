import SwiftData
import SwiftUI

/// What supports today's training, as one grouped card.
///
/// Named "Today's support", not "Today": the screen is already called Today,
/// and repeating it made the group read as *the* content of the screen rather
/// than as the tier below the workout. Everything here exists to serve the
/// session — preparing for it, fuelling it, recording context for it — and the
/// heading now says so.
///
/// Rows are state-driven twice over. A row with nothing to say is not rendered
/// at all, and a row whose action is already *handled* drops behind a
/// disclosure instead of holding a full-weight slot. Six domains existing is
/// not a reason to show six equal rows; the group should only ever lead with
/// what the user can still usefully do.
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
    @Query(sort: \MobilitySession.updatedAt, order: .reverse) private var mobilitySessions: [MobilitySession]
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?

    @State private var isShowingHandledItems = false

    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            LibrarySectionTitle("Today's support")

            LibraryGroupCard {
                let open = openItems
                let handled = handledItems

                rows(for: open, isFirstInCard: true)

                if !handled.isEmpty {
                    // No leading rule when nothing precedes it — a day with
                    // everything handled would otherwise open the card with a
                    // divider separating the disclosure row from nothing.
                    if !open.isEmpty {
                        LibraryGroupDivider()
                    }
                    handledDisclosureRow(for: handled)

                    if isShowingHandledItems {
                        rows(for: handled, isFirstInCard: false)
                    }
                }
            }
        }
    }

    /// The rows the user can still act on, in the order they matter: work
    /// already in progress, then what is due, then the day's running totals.
    private var openItems: [SupportItem] {
        var items: [SupportItem] = []
        // Routed through the policy rather than testing the session inline, so
        // the rule that Today resumes work but never picks a routine stays in
        // one place with its own coverage.
        if TodayMobilityRowPolicy.shouldShowRow(hasActiveMobilitySession: activeMobilitySession != nil) {
            items.append(.mobility)
        }
        if dailyLogEntry == nil { items.append(.checkIn) }
        if featureFlags.isEnabled(.nutrition) { items.append(.nutrition) }
        if !creatineTaken { items.append(.creatine) }
        if featureFlags.isEnabled(.nutrition), nutritionSummary.totals.caffeineMilligrams > 0 {
            items.append(.caffeine)
        }
        return items
    }

    /// Settled or not-yet-relevant rows. They stay reachable — confirming
    /// creatine by mistake has to be undoable, and the caffeine quick log has
    /// to survive a day with nothing logged — but they do not compete with
    /// what is still open.
    private var handledItems: [SupportItem] {
        var items: [SupportItem] = []
        if dailyLogEntry != nil { items.append(.checkIn) }
        if creatineTaken { items.append(.creatine) }
        if featureFlags.isEnabled(.nutrition), nutritionSummary.totals.caffeineMilligrams == 0 {
            items.append(.caffeine)
        }
        return items
    }

    private func rows(for items: [SupportItem], isFirstInCard: Bool) -> some View {
        ForEach(Array(items.enumerated()), id: \.element) { index, item in
            if index > 0 || !isFirstInCard {
                LibraryGroupDivider()
            }
            row(for: item)
        }
    }

    @ViewBuilder
    private func row(for item: SupportItem) -> some View {
        switch item {
        case .mobility: mobilityRow
        case .checkIn: checkInRow
        case .nutrition: nutritionRow
        case .creatine: creatineRow
        case .caffeine: caffeineRow
        }
    }

    private func handledDisclosureRow(for items: [SupportItem]) -> some View {
        let summary = handledSummary(for: items)
        return Button {
            withAnimation(AppMotion.compact) { isShowingHandledItems.toggle() }
        } label: {
            HStack(spacing: Spacing.m) {
                Text(summary)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                Image(systemName: isShowingHandledItems ? AppIcon.chevronUp : AppIcon.chevronDown)
                    .font(AppFont.captionBold)
                    .foregroundStyle(Color.gymSubtleText)
            }
            .padding(.horizontal, Spacing.l - 2)
            .frame(minHeight: ComponentSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gymPress)
        .accessibilityIdentifier("today-toggle-handled-support")
        .accessibilityLabel(summary)
        .accessibilityHint(
            isShowingHandledItems
                ? String(localized: "Hides items you have already handled today.")
                : String(localized: "Shows items you have already handled today.")
        )
    }

    /// Names what is hidden rather than saying "More", so collapsing never
    /// costs the user the answer to "did I take creatine?".
    private func handledSummary(for items: [SupportItem]) -> String {
        items.map(\.shortName).formatted(.list(type: .and))
    }
}

/// The rows Today's support can offer, in one place so ordering and
/// open/handled classification cannot disagree about what exists.
private enum SupportItem: Hashable {
    case mobility
    case checkIn
    case nutrition
    case creatine
    case caffeine

    var shortName: String {
        switch self {
        case .mobility: String(localized: "Mobility")
        case .checkIn: String(localized: "Check-in")
        case .nutrition: String(localized: "Nutrition")
        case .creatine: String(localized: "Creatine")
        case .caffeine: String(localized: "Caffeine")
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
        guard summary.totals.caffeineMilligrams > 0 else {
            return String(localized: "Add a drink")
        }
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
        }
    }
}

/// Today resumes performed work but never selects a reusable prescription.
///
/// A warm-up is prescription context selected through a template or rotation
/// link before workout creation. Standalone routine discovery and selection
/// belongs to Train.
enum TodayMobilityRowPolicy {
    static func shouldShowRow(hasActiveMobilitySession: Bool) -> Bool {
        hasActiveMobilitySession
    }
}
