import SwiftUI

struct NutritionTotalsView: View {
    let totals: NutritionMacroTotals
    let target: NutritionTargetValues
    let dayKind: NutritionDayKind

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .center, spacing: Spacing.xl) {
                    calorieRing
                    VStack(spacing: Spacing.m) {
                        NutritionMacroValue(label: "Protein", value: totals.protein, target: target.protein, unknown: totals.unknownProteinCount, tint: .chartViolet)
                        NutritionMacroValue(label: "Carbs", value: totals.carbohydrates, target: target.carbohydrates, unknown: totals.unknownCarbohydratesCount, tint: .chartGreen)
                        NutritionMacroValue(label: "Fat", value: totals.fat, target: target.fat, unknown: totals.unknownFatCount, tint: .chartOrange)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                if hasNoTarget {
                    Divider()
                    NavigationLink(value: NutritionRoute.targets) {
                        Label("Set training & rest targets", systemImage: AppIcon.chart)
                            .font(AppFont.subheadlineSemibold)
                    }
                }
            }
        }
    }

    private var hasNoTarget: Bool {
        target.calories == nil && target.protein == nil && target.carbohydrates == nil && target.fat == nil
    }

    private var accessibilitySummary: String {
        let unknownCount = totals.unknownCaloriesCount
            + totals.unknownProteinCount
            + totals.unknownCarbohydratesCount
            + totals.unknownFatCount
        let unknown = unknownCount == 0 ? "" : " \(unknownCount) nutrient values are unknown."
        return "\(dayKind.displayName). \(FoodLibraryService.format(totals.calories)) calories. Protein \(FoodLibraryService.format(totals.protein)) grams. Carbohydrates \(FoodLibraryService.format(totals.carbohydrates)) grams. Fat \(FoodLibraryService.format(totals.fat)) grams.\(unknown)"
    }

    private var calorieRing: some View {
        let progress = target.calories.map { min(max(totals.calories / max($0, 1), 0), 1) } ?? 0
        // Round caps are wider than the arc they finish once the trim gets
        // short: at a few percent of a day's target the two ends merge into a
        // detached lozenge that reads as a marker rather than as progress. The
        // stroke squares off before it gets there, and is not drawn at all
        // when there is nothing yet to report.
        let hasDrawableProgress = progress > 0.001
        let lineCap: CGLineCap = progress < 0.04 ? .butt : .round
        return ZStack {
            Circle().stroke(Color.trameSeparator, lineWidth: Spacing.m)
            if hasDrawableProgress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.trameText, style: StrokeStyle(lineWidth: Spacing.m, lineCap: lineCap))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: Spacing.xxs) {
                Text(FoodLibraryService.format(totals.calories))
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.trameText)
                Text(target.calories.map { "/ \(FoodLibraryService.format($0))" } ?? "kcal")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
            }
        }
        .frame(width: ComponentSize.nutritionRing, height: ComponentSize.nutritionRing)
        .accessibilityHidden(true)
    }
}

private struct NutritionMacroValue: View {
    let label: String
    let value: Double
    let target: Double?
    let unknown: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label).font(AppFont.subheadline).foregroundStyle(Color.trameText)
                Spacer()
                Text(target.map { "\(FoodLibraryService.format(value))/\(FoodLibraryService.format($0)) g" } ?? "\(FoodLibraryService.format(value)) g")
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.trameText)
            }
            if let target {
                ProgressView(value: min(value / max(target, 1), 1))
                    .tint(tint)
            }
            if unknown > 0 { Text("+ unknown").font(AppFont.caption).foregroundStyle(Color.trameDestructiveText) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
