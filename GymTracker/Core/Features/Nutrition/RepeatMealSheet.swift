import SwiftData
import SwiftUI

struct RepeatMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let meal: LoggedMeal
    var day: LocalDay = .today
    @State private var slot: MealSlot

    init(meal: LoggedMeal, day: LocalDay = .today) {
        self.meal = meal
        self.day = day
        _slot = State(initialValue: meal.slot)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Repeat") {
                    Text(meal.nameSnapshot)
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Text("Repeating creates a new logged meal with its own immutable food and nutrient snapshots.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Repeat meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { if NutritionLoggingService.repeatMeal(meal, day: day, slot: slot, using: modelContext) != nil { dismiss() } }
                        .accessibilityIdentifier("confirm-repeat-meal")
                }
            }
        }
    }
}
