import SwiftData
import SwiftUI

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let food: FoodItem?
    @State private var name = ""
    @State private var referenceAmount: Double? = 100
    @State private var referenceUnit: NutritionServingUnit = .grams
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbohydrates: Double?
    @State private var fat: Double?
    @State private var caffeine: Double?
    @State private var npn = ""
    @State private var confidence: FoodConfidence = .userProvided
    @State private var preparation: FoodPreparationState = .raw
    @State private var servingName = ""
    @State private var servingAmount: Double?
    @State private var servingEquivalentReferenceAmount: Double?
    @State private var servingUnit: NutritionServingUnit = .serving
    @State private var removesQuickServing = false
    @State private var errorMessage: String?

    init(food: FoodItem? = nil) { self.food = food }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    HStack {
                        DecimalField("Reference amount", value: $referenceAmount, range: 0...100000)
                        Picker("Unit", selection: $referenceUnit) {
                            ForEach(NutritionServingUnit.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }.labelsHidden()
                    }
                    Picker("Preparation", selection: $preparation) {
                        ForEach(FoodPreparationState.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Confidence", selection: $confidence) {
                        ForEach(FoodConfidence.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Macros per reference amount") {
                    DecimalField("Calories (optional)", value: $calories, range: 0...100000)
                    DecimalField("Protein g (optional)", value: $protein, range: 0...100000)
                    DecimalField("Carbohydrates g (optional)", value: $carbohydrates, range: 0...100000)
                    DecimalField("Fat g (optional)", value: $fat, range: 0...100000)
                    DecimalField("Caffeine mg (optional)", value: $caffeine, range: 0...100000)
                    TextField("NPN (optional, Canadian products)", text: $npn)
                }
                Section("Quick serving") {
                    TextField("Serving name (optional)", text: $servingName)
                    HStack {
                        DecimalField("Serving amount", value: $servingAmount, range: 0...100000)
                        Picker("Serving unit", selection: $servingUnit) {
                            ForEach(NutritionServingUnit.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                    }
                    DecimalField("Equivalent reference amount", value: $servingEquivalentReferenceAmount, range: 0...100000)
                    Text("For example, a 1 cup serving can represent 240 reference grams. Leave this blank when the reference amount is the only serving.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    if food?.orderedServings.isEmpty == false {
                        Button("Remove saved serving", role: .destructive) {
                            removesQuickServing = true
                            servingName = ""
                            servingAmount = nil
                            servingEquivalentReferenceAmount = nil
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle(food == nil ? "New food" : "Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-food")
                }
            }
            .alert("Couldn’t save food", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    private func load() {
        guard let food else { return }
        name = food.name; referenceAmount = food.referenceAmount; referenceUnit = food.referenceUnit
        calories = food.calories; protein = food.proteinGrams; carbohydrates = food.carbohydrateGrams; fat = food.fatGrams; caffeine = food.caffeineMilligrams
        npn = food.npn ?? ""
        confidence = food.confidence; preparation = food.preparationState
        if let serving = food.orderedServings.first {
            servingName = serving.name; servingAmount = serving.amount; servingEquivalentReferenceAmount = serving.equivalentReferenceAmount; servingUnit = serving.unit
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = referenceAmount, amount > 0 else { errorMessage = "Enter a positive reference amount."; return }
        let allFoods = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        guard allFoods.allSatisfy({ $0.id == food?.id || $0.name.localizedCaseInsensitiveCompare(trimmed) != .orderedSame }) else { errorMessage = "A food with that name already exists."; return }
        guard [calories, protein, carbohydrates, fat, caffeine].allSatisfy({ ($0 ?? 0) >= 0 }) else { errorMessage = "Nutrition values must be positive numbers or left blank."; return }
        let target = food ?? FoodItem(name: trimmed)
        target.name = trimmed; target.referenceAmount = amount; target.referenceUnit = referenceUnit
        target.calories = calories; target.proteinGrams = protein; target.carbohydrateGrams = carbohydrates; target.fatGrams = fat
        target.caffeineMilligrams = caffeine
        let trimmedNPN = npn.trimmingCharacters(in: .whitespacesAndNewlines)
        target.npn = trimmedNPN.isEmpty ? nil : trimmedNPN
        target.confidence = confidence; target.preparationState = preparation; target.updatedAt = .now
        if food == nil { modelContext.insert(target) }
        let trimmedServing = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if removesQuickServing {
            for serving in target.servings { modelContext.delete(serving) }
            target.servings = []
        } else if trimmedServing.isEmpty == false {
            guard let servingAmount, servingAmount > 0,
                  let equivalent = servingEquivalentReferenceAmount, equivalent > 0 else { errorMessage = "Enter positive serving and equivalent reference amounts."; return }
            let priorServings = target.servings
            target.servings = [FoodServing(name: trimmedServing, amount: servingAmount, unit: servingUnit, equivalentReferenceAmount: equivalent)]
            for serving in priorServings { modelContext.delete(serving) }
        }
        guard modelContext.saveOrRollback() else {
            errorMessage = "The food could not be saved. Try again."
            return
        }
        dismiss()
    }
}
