import SwiftUI

struct NutritionTotalsView: View {
    let totals: NutritionMacroTotals
    let target: NutritionTargetValues
    let dayKind: NutritionDayKind

    var body: some View {
        GymCard {
            HStack(spacing: Spacing.xl) {
                calorieRing
                VStack(spacing: Spacing.m) {
                    NutritionMacroValue(label: "Protein", value: totals.protein, target: target.protein, unknown: totals.unknownProteinCount, tint: .chartViolet)
                    NutritionMacroValue(label: "Carbs", value: totals.carbohydrates, target: target.carbohydrates, unknown: totals.unknownCarbohydratesCount, tint: .chartGreen)
                    NutritionMacroValue(label: "Fat", value: totals.fat, target: target.fat, unknown: totals.unknownFatCount, tint: .chartOrange)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayKind.displayName). \(FoodLibraryService.format(totals.calories)) calories. Protein \(FoodLibraryService.format(totals.protein)) grams. Carbohydrates \(FoodLibraryService.format(totals.carbohydrates)) grams. Fat \(FoodLibraryService.format(totals.fat)) grams.")
    }

    private var calorieRing: some View {
        let progress = target.calories.map { min(max(totals.calories / max($0, 1), 0), 1) } ?? 0
        return ZStack {
            Circle().stroke(Color.trameRow, lineWidth: Spacing.m)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.trameText, style: StrokeStyle(lineWidth: Spacing.m, lineCap: .round))
                .rotationEffect(.degrees(-90))
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
            ProgressView(value: target.map { min(value / max($0, 1), 1) } ?? 0)
                .tint(tint)
            if unknown > 0 { Text("+ unknown").font(AppFont.caption).foregroundStyle(Color.trameDestructiveText) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
