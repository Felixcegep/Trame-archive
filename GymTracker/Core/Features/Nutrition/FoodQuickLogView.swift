import SwiftData
import SwiftUI

struct FoodQuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nutritionSelectedDay) private var day
    let food: FoodItem
    var initialQuantity: Double? = nil
    var initialSlot: MealSlot? = nil
    @State private var portionID: UUID?
    @State private var amount: Double?
    @State private var slot: MealSlot = .suggested()
    @State private var showsSaveError = false

    private var portions: [FoodPortion] { FoodLibraryService.portions(for: food) }
    private var portion: FoodPortion { portions.first(where: { $0.id == portionID }) ?? portions[0] }
    private var validAmount: Double { max(amount ?? 0, 0) }
    private var quantity: Double { NutritionLogQuantity.quantity(amount: validAmount, portion: portion) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(food.name).font(AppFont.subheadlineSemibold)
                    Text("\(foodMacroDescription(food)) per \(FoodLibraryService.format(food.referenceAmount)) \(food.referenceUnit.displayName)")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    if day != .today {
                        Text(day.displayName())
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                Section("Portion") {
                    Picker("Serving", selection: $portionID) {
                        ForEach(portions, id: \.id) { portion in
                            Text(portion.name).tag(portion.id)
                        }
                    }
                    LabeledContent(NutritionLogQuantity.amountFieldTitle(for: portion)) {
                        DecimalField(
                            LocalizedStringKey(NutritionLogQuantity.amountFieldTitle(for: portion)),
                            value: $amount,
                            range: NutritionLogQuantity.amountRange(for: portion)
                        )
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 72)
                        .accessibilityIdentifier("food-log-quantity")
                    }
                    if portion.unit == .grams {
                        gramChips
                    }
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("This entry") {
                    LabeledContent("Amount", value: FoodLibraryService.amountDescription(portion: portion, quantity: quantity))
                    LabeledContent("Calories", value: nutrientDescription(food.calories, unit: "kcal"))
                    LabeledContent("Protein", value: nutrientDescription(food.proteinGrams, unit: "g"))
                    LabeledContent("Carbs", value: nutrientDescription(food.carbohydrateGrams, unit: "g"))
                    LabeledContent("Fat", value: nutrientDescription(food.fatGrams, unit: "g"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if NutritionLoggingService.log(
                            food: food,
                            portion: portion,
                            quantity: quantity,
                            day: day,
                            slot: slot,
                            using: modelContext
                        ) != nil {
                            dismiss()
                        } else {
                            showsSaveError = true
                        }
                    }
                    .disabled(NutritionLogQuantity.isValid(quantity: quantity, portionAmount: portion.amount, unit: portion.unit) == false)
                    .accessibilityIdentifier("confirm-log-food")
                }
            }
            .onAppear {
                portionID = portions[0].id
                slot = initialSlot ?? MealSlot.suggested()
                let startingQuantity = initialQuantity ?? 1
                amount = NutritionLogQuantity.displayedAmount(quantity: startingQuantity, portion: portions[0])
            }
            .alert("Food wasn’t added", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your entry is still here. Try again.")
            }
        }
    }

    private var gramChips: some View {
        HStack(spacing: Spacing.s) {
            ForEach([50.0, 100, 150, 200], id: \.self) { grams in
                Button("\(FoodLibraryService.format(grams)) g") { amount = grams }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .accessibilityIdentifier("food-log-gram-chips")
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }

    private func nutrientDescription(_ value: Double?, unit: String) -> String {
        guard let value else { return "Unknown" }
        let multiplier = quantity * portion.equivalentReferenceAmount / food.referenceAmount
        return "\(FoodLibraryService.format(value * multiplier)) \(unit)"
    }
}
