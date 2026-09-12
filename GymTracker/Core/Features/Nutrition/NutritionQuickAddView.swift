import SwiftData
import SwiftUI

struct NutritionQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nutritionSelectedDay) private var day
    var initialSlot: MealSlot = .suggested()
    @State private var name = ""
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbohydrates: Double?
    @State private var fat: Double?
    @State private var slot: MealSlot = .suggested()
    @State private var showsSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Estimate") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("quick-add-name")
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if day != .today {
                        Text(day.displayName())
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }
                Section("Known values") {
                    DecimalField("Calories (optional)", value: $calories, range: 0...20_000)
                        .accessibilityIdentifier("quick-add-calories")
                    DecimalField("Protein g (optional)", value: $protein, range: 0...1_000)
                    DecimalField("Carbs g (optional)", value: $carbohydrates, range: 0...1_000)
                    DecimalField("Fat g (optional)", value: $fat, range: 0...1_000)
                    Text("Logs an estimated snapshot. Missing values stay unknown, never zero.")
                        .font(AppFont.caption)
                        .foregroundStyle(Color.trameSubdued)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if NutritionLoggingService.logEstimate(
                            name: name,
                            calories: calories,
                            proteinGrams: protein,
                            carbohydrateGrams: carbohydrates,
                            fatGrams: fat,
                            day: day,
                            slot: slot,
                            using: modelContext
                        ) != nil {
                            dismiss()
                        } else {
                            showsSaveError = true
                        }
                    }
                    .disabled(canSave == false)
                    .accessibilityIdentifier("confirm-quick-add")
                }
            }
            .onAppear { slot = initialSlot }
            .alert("Estimate wasn’t added", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a name and at least one nutrient.")
            }
        }
    }

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && [calories, protein, carbohydrates, fat].contains { $0 != nil }
    }
}
