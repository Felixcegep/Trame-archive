import SwiftData
import SwiftUI

struct HomeNutritionSection: View {
    let onOpenNutrition: () -> Void
    @Binding var isShowingCaffeineLog: Bool

    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var nutritionTargets: [NutritionTarget]
    @Query private var planRuns: [PlanRun]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?

    private var caffeineDailyLimit: CaffeineDailyLimit {
        let birthdate = caffeineBirthdateTimestamp.map { Date(timeIntervalSince1970: $0) }
        let ageBand = CaffeineGuidance.ageBand(birthdate: birthdate)
        return CaffeineGuidance.dailyLimit(
            ageBand: ageBand,
            bodyWeightKilograms: bodyWeightEntries.first.map { Double($0.kilograms) }
        )
    }

    var body: some View {
        let summary = NutritionDaySummary.resolve(day: .today, meals: loggedMeals)
        let resolution = NutritionTargetResolver.resolve(
            day: .today,
            planRuns: planRuns,
            targets: nutritionTargets
        )

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("NUTRITION")
                .font(AppFont.captionBold)
                .tracking(0.8)
                .foregroundStyle(Color.gymSubduedText)

            Button(action: onOpenNutrition) {
                HomeDailyContextRow(
                    icon: AppIcon.nutrition,
                    iconColor: Color.gymSecondary,
                    title: "\(FoodLibraryService.format(summary.totals.calories)) kcal · \(FoodLibraryService.format(summary.totals.protein)) g protein",
                    detail: nutritionDetail(summary: summary, resolution: resolution),
                    completion: summary.meals.isEmpty == false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("open-nutrition-today")
            .accessibilityLabel("Nutrition today, \(FoodLibraryService.format(summary.totals.calories)) calories, \(FoodLibraryService.format(summary.totals.protein)) grams protein")

            Button { isShowingCaffeineLog = true } label: {
                HomeDailyContextRow(
                    icon: AppIcon.caffeine,
                    iconColor: Color.gymAccent,
                    title: "Caffeine",
                    detail: caffeineDetail(summary: summary),
                    completion: false
                )
            }
            .buttonStyle(.gymPress)
            .accessibilityIdentifier("today-caffeine-summary")
            .accessibilityLabel("Caffeine today, \(caffeineAccessibilityValue(summary: summary)). Add a drink.")
        }
    }

    private func caffeineReferenceSuffix(loggedMilligrams: Double) -> String {
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

    private func caffeineDetail(summary: NutritionDaySummary) -> String {
        if summary.meals.isEmpty { return "No nutrition entries today" }
        let value = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) mg logged\(caffeineReferenceSuffix(loggedMilligrams: summary.totals.caffeineMilligrams))"
        return summary.totals.unknownCaffeineCount > 0 ? "\(value) · Some entries unknown" : value
    }

    private func caffeineAccessibilityValue(summary: NutritionDaySummary) -> String {
        let value = "\(FoodLibraryService.format(summary.totals.caffeineMilligrams)) milligrams logged\(caffeineReferenceSuffix(loggedMilligrams: summary.totals.caffeineMilligrams))"
        return summary.totals.unknownCaffeineCount > 0 ? "\(value), some entries have unknown caffeine" : value
    }

    private func nutritionDetail(
        summary: NutritionDaySummary,
        resolution: (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues)
    ) -> String {
        let target = resolution.values.calories.map { "of \(FoodLibraryService.format($0)) kcal" } ?? "No calorie target"
        let unknown = summary.totals.hasUnknownValues ? " · Some nutrients unknown" : ""
        return "\(resolution.kind.displayName) · \(target)\(unknown)"
    }
}
