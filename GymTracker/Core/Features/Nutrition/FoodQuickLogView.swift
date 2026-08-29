import SwiftData
import SwiftUI

struct FoodQuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let food: FoodItem
    @State private var portionID: UUID?
    @State private var quantity: Double? = 1
    @State private var slot: MealSlot = .suggested()
    @State private var showsSaveError = false

    private var portions: [FoodPortion] { FoodLibraryService.portions(for: food) }
    private var portion: FoodPortion { portions.first(where: { $0.id == portionID }) ?? portions[0] }
    private var validQuantity: Double { max(quantity ?? 0, 0) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(food.name).font(AppFont.subheadlineSemibold)
                    Text("\(foodMacroDescription(food)) per \(FoodLibraryService.format(food.referenceAmount)) \(food.referenceUnit.displayName)")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
                Section("Portion") {
                    Picker("Serving", selection: $portionID) {
                        ForEach(portions, id: \.id) { portion in
                            Text(portion.name).tag(portion.id)
                        }
                    }
                    LabeledContent("Quantity") {
                        DecimalField("Quantity", value: $quantity, range: 0.25...20)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72)
                            .accessibilityIdentifier("food-log-quantity")
                    }
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("This entry") {
                    LabeledContent("Amount", value: FoodLibraryService.amountDescription(portion: portion, quantity: validQuantity))
                    LabeledContent("Calories", value: nutrientDescription(food.calories, unit: "kcal"))
                    LabeledContent("Protein", value: nutrientDescription(food.proteinGrams, unit: "g"))
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
                        if NutritionLoggingService.log(food: food, portion: portion, quantity: validQuantity, slot: slot, using: modelContext) != nil {
                            dismiss()
                        } else {
                            showsSaveError = true
                        }
                    }
                    .disabled((0.25...20).contains(validQuantity) == false)
                    .accessibilityIdentifier("confirm-log-food")
                }
            }
            .onAppear { portionID = portions[0].id }
            .alert("Food wasn’t added", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your entry is still here. Try again.")
            }
        }
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }

    private func nutrientDescription(_ value: Double?, unit: String) -> String {
        guard let value else { return "Unknown" }
        let multiplier = validQuantity * portion.equivalentReferenceAmount / food.referenceAmount
        return "\(FoodLibraryService.format(value * multiplier)) \(unit)"
    }
}
