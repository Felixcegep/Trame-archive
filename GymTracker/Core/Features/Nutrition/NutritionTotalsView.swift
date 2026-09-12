import SwiftUI

struct NutritionTotalsView: View {
    let totals: NutritionMacroTotals
    let target: NutritionTargetValues
    let dayKind: NutritionDayKind

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .center, spacing: Spacing.xl) {
                    primaryGlance
                    VStack(spacing: Spacing.m) {
                        if usesProteinGlance {
                            NutritionMacroValue(
                                label: "Calories",
                                value: totals.calories,
                                target: target.calories,
                                unknown: totals.unknownCaloriesCount,
                                unit: "kcal",
                                tint: .trameText
                            )
                        } else {
                            NutritionMacroValue(
                                label: "Protein",
                                value: totals.protein,
                                target: target.protein,
                                unknown: totals.unknownProteinCount,
                                unit: "g",
                                tint: .chartViolet
                            )
                        }
                        NutritionMacroValue(label: "Carbs", value: totals.carbohydrates, target: target.carbohydrates, unknown: totals.unknownCarbohydratesCount, unit: "g", tint: .chartGreen)
                        NutritionMacroValue(label: "Fat", value: totals.fat, target: target.fat, unknown: totals.unknownFatCount, unit: "g", tint: .chartOrange)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)

                HStack {
                    Text(dayKind.displayName)
                        .font(AppFont.captionBold)
                        .foregroundStyle(Color.trameSubdued)
                    Spacer()
                    if totals.caffeineMilligrams > 0 || totals.unknownCaffeineCount > 0 {
                        Text(caffeineCaption)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }

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

    private var usesProteinGlance: Bool { target.protein != nil }

    private var hasNoTarget: Bool {
        target.calories == nil && target.protein == nil && target.carbohydrates == nil && target.fat == nil
    }

    private var caffeineCaption: String {
        if totals.unknownCaffeineCount > 0 && totals.caffeineMilligrams == 0 {
            return "Caffeine unknown"
        }
        let suffix = totals.unknownCaffeineCount > 0 ? " + unknown" : ""
        return "\(FoodLibraryService.format(totals.caffeineMilligrams)) mg caffeine\(suffix)"
    }

    private var accessibilitySummary: String {
        let unknownCount = totals.unknownCaloriesCount
            + totals.unknownProteinCount
            + totals.unknownCarbohydratesCount
            + totals.unknownFatCount
        let unknown = unknownCount == 0 ? "" : " \(unknownCount) nutrient values are unknown."
        let remaining = remainingProtein.map { " \($0) grams protein remaining." } ?? ""
        return "\(dayKind.displayName). \(FoodLibraryService.format(totals.calories)) calories. Protein \(FoodLibraryService.format(totals.protein)) grams.\(remaining) Carbohydrates \(FoodLibraryService.format(totals.carbohydrates)) grams. Fat \(FoodLibraryService.format(totals.fat)) grams.\(unknown)"
    }

    private var remainingProtein: Double? {
        target.protein.map { max($0 - totals.protein, 0) }
    }

    private var primaryGlance: some View {
        let progress: Double
        let valueText: String
        let caption: String
        if let proteinTarget = target.protein {
            progress = min(max(totals.protein / max(proteinTarget, 1), 0), 1)
            valueText = FoodLibraryService.format(remainingProtein ?? 0)
            caption = "g protein left"
        } else if let calorieTarget = target.calories {
            progress = min(max(totals.calories / max(calorieTarget, 1), 0), 1)
            valueText = FoodLibraryService.format(totals.calories)
            caption = "/ \(FoodLibraryService.format(calorieTarget))"
        } else {
            progress = 0
            valueText = FoodLibraryService.format(totals.calories)
            caption = "kcal"
        }
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
                Text(valueText)
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.trameText)
                Text(caption)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.trameSubdued)
                    .multilineTextAlignment(.center)
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
    var unit: String = "g"
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label).font(AppFont.subheadline).foregroundStyle(Color.trameText)
                Spacer()
                Text(target.map { "\(FoodLibraryService.format(value))/\(FoodLibraryService.format($0)) \(unit)" } ?? "\(FoodLibraryService.format(value)) \(unit)")
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
