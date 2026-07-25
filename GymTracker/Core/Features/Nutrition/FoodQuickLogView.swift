import SwiftData
import SwiftUI

struct FoodQuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let food: FoodItem
    @State private var portionID: UUID?
    @State private var quantity = 1.0
    @State private var slot: MealSlot = .snack

    private var portions: [FoodPortion] { FoodLibraryService.portions(for: food) }
    private var portion: FoodPortion { portions.first(where: { $0.id == portionID }) ?? portions[0] }

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
                    Stepper("Quantity: \(FoodLibraryService.format(quantity))", value: $quantity, in: 0.25...20, step: 0.25)
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
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
                        if NutritionLoggingService.log(food: food, portion: portion, quantity: quantity, slot: slot, using: modelContext) != nil { dismiss() }
                    }
                    .accessibilityIdentifier("confirm-log-food")
                }
            }
            .onAppear { portionID = portions[0].id }
        }
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }
}
