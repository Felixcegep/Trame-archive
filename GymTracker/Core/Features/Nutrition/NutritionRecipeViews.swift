import SwiftData
import SwiftUI
import UIKit

// MARK: - Food picker

/// A searchable, multi-select food picker modeled on the exercise picker.
/// Replaces the long scrolling `Menu` that recipe editing used before. Foods
/// are grouped into Recent / Favorites / All; several can be selected in one
/// visit and are handed back on Done.
struct FoodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]

    /// Food ids already in the recipe. They appear selected and cannot be added
    /// twice.
    let existingSelection: Set<UUID>
    let onAdd: ([FoodItem]) -> Void

    @State private var searchText = ""
    @State private var newlySelected: Set<UUID> = []
    @State private var isCreatingFood = false

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    section("Favorites", foods: favoriteFoods)
                    section("Recent", foods: recentFoods)
                    section("All foods", foods: allFoods)
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("No matching foods", systemImage: AppIcon.nutrition)
                    } description: {
                        Text("Try another name, or create a new food.")
                    } actions: {
                        Button("Create food") { isCreatingFood = true }
                            .buttonStyle(.gymPrimary)
                            .accessibilityIdentifier("food-picker-create-empty")
                    }
                } else {
                    section("Results", foods: searchResults)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Add foods")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreatingFood = true } label: { Label("New food", systemImage: AppIcon.plus) }
                        .accessibilityIdentifier("food-picker-create")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commit() }
                        .disabled(newlySelected.isEmpty)
                        .accessibilityIdentifier("food-picker-done")
                }
            }
            .sheet(isPresented: $isCreatingFood) { FoodEditorView() }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, foods: [FoodItem]) -> some View {
        if foods.isEmpty == false {
            Section(title) {
                ForEach(foods) { food in row(for: food) }
            }
        }
    }

    private func row(for food: FoodItem) -> some View {
        let alreadyInRecipe = existingSelection.contains(food.id)
        let isSelected = alreadyInRecipe || newlySelected.contains(food.id)
        return Button {
            guard alreadyInRecipe == false else { return }
            if newlySelected.contains(food.id) { newlySelected.remove(food.id) } else { newlySelected.insert(food.id) }
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: isSelected ? AppIcon.checkmarkCircle : AppIcon.circle)
                    .foregroundStyle(isSelected ? Color.gymSecondary : Color.gymSubduedText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(food.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                    Text(defaultRowDetail(for: food)).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
                Spacer()
                if food.isFavorite { Image(systemName: AppIcon.favoriteFilled).foregroundStyle(Color.gymAccent).accessibilityHidden(true) }
            }
        }
        .disabled(alreadyInRecipe)
        .accessibilityIdentifier("food-picker-row-\(food.id)")
        .accessibilityLabel("\(food.name), \(defaultRowDetail(for: food))")
        .accessibilityValue(isSelected ? Text("Selected") : Text("Not selected"))
        .accessibilityHint(alreadyInRecipe ? Text("Already in this recipe") : Text("Adds this food to the recipe"))
    }

    private func defaultRowDetail(for food: FoodItem) -> String {
        let portion = FoodLibraryService.defaultPortion(for: food)
        let amount = FoodLibraryService.amountDescription(portion: portion, quantity: 1)
        let multiplier = portion.equivalentReferenceAmount / food.referenceAmount
        let calories = food.calories.map { "\(FoodLibraryService.format($0 * multiplier)) kcal" } ?? String(localized: "kcal unknown")
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0 * multiplier)) g protein" } ?? String(localized: "protein unknown")
        return "\(amount) · \(calories) · \(protein)"
    }

    private func commit() {
        let additions = foods.filter { newlySelected.contains($0.id) && $0.isArchived == false }
        onAdd(additions)
        dismiss()
    }

    private var availableFoods: [FoodItem] { foods.filter { $0.isArchived == false } }
    private var favoriteFoods: [FoodItem] { availableFoods.filter { $0.isFavorite } }

    private var recentFoods: [FoodItem] {
        let byID = Dictionary(uniqueKeysWithValues: availableFoods.map { ($0.id, $0) })
        var seen = Set<UUID>()
        return loggedMeals
            .flatMap(\.orderedItems)
            .compactMap { item -> FoodItem? in
                guard let id = item.sourceFoodID, seen.insert(id).inserted, let food = byID[id] else { return nil }
                return food.isFavorite ? nil : food
            }
            .prefix(6)
            .map { $0 }
    }

    private var allFoods: [FoodItem] {
        let excluded = Set(favoriteFoods.map(\.id)).union(recentFoods.map(\.id))
        return availableFoods.filter { excluded.contains($0.id) == false }
    }

    private var searchResults: [FoodItem] {
        availableFoods.filter { food in
            var extra: [String] = []
            if let cat = food.categoryName { extra.append(cat) }
            extra.append(contentsOf: food.searchAliases)
            return SearchNormalization.matches(query: searchText, primaryName: food.name, alternateName: food.frenchName, aliases: extra)
        }
    }
}

// MARK: - Ingredient editor

/// Compact sheet to edit one recipe ingredient with a concrete amount and
/// portion, plus a remove action. Amount uses the shared decimal field.
struct IngredientEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    @Binding var servingID: UUID?
    @Binding var quantity: Double
    let onRemove: () -> Void

    @State private var draftServingID: UUID?
    @State private var draftQuantity: Double?

    private var portions: [FoodPortion] { FoodLibraryService.portions(for: food) }
    private var portion: FoodPortion { portions.first { $0.id == draftServingID } ?? portions[0] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    Text(food.name).font(AppFont.subheadlineSemibold)
                    Text(FoodLibraryService.amountDescription(portion: portion, quantity: draftQuantity ?? 0))
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        .accessibilityIdentifier("ingredient-editor-amount-summary")
                }
                Section("Amount") {
                    DecimalField("Amount", value: $draftQuantity, range: RecipeDraftValidator.quantityRange)
                        .accessibilityIdentifier("ingredient-editor-amount")
                    if portions.count > 1 {
                        Picker("Portion", selection: $draftServingID) {
                            ForEach(portions, id: \.id) { Text($0.name).tag($0.id) }
                        }
                    }
                    Stepper("Adjust", value: Binding(
                        get: { draftQuantity ?? 0 },
                        set: { draftQuantity = $0 }
                    ), in: RecipeDraftValidator.quantityRange, step: 0.25)
                    .accessibilityIdentifier("ingredient-editor-stepper")
                }
                Section {
                    Button("Remove from recipe", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                    .accessibilityIdentifier("ingredient-editor-remove")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commit() }
                        .disabled((draftQuantity ?? 0) <= 0)
                        .accessibilityIdentifier("ingredient-editor-done")
                }
            }
            .onAppear {
                draftServingID = servingID
                draftQuantity = quantity
            }
        }
    }

    private func commit() {
        guard let value = draftQuantity, value > 0 else { return }
        let clamped = min(max(value, RecipeDraftValidator.quantityRange.lowerBound), RecipeDraftValidator.quantityRange.upperBound)
        servingID = draftServingID
        quantity = clamped
        dismiss()
    }
}

// MARK: - Recipe detail

/// Read-first recipe screen. Tapping a saved recipe lands here rather than in
/// the editor, with a prominent "Add to today" action and Edit as secondary.
struct MealTemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: MealTemplate
    @State private var isEditing = false
    @State private var isLogging = false

    private var totals: NutritionMacroTotals { MealTemplateNutrition.totals(for: template) }

    var body: some View {
        List {
            if template.photoIdentifier != nil {
                Section {
                    RecipePhotoImage(identifier: template.photoIdentifier, content: { image in
                        image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .accessibilityHidden(true)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }, placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .accessibilityLabel("Loading recipe photo")
                    })
                }
            }

            Section {
                Button { isLogging = true } label: {
                    Label("Add to today", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gymPrimary)
                .accessibilityIdentifier("recipe-add-to-today")
            }
            .listRowBackground(Color.clear)

            Section("Nutrition · whole recipe") {
                nutritionRow("Calories", value: totals.calories, unit: "kcal", unknown: totals.unknownCaloriesCount)
                nutritionRow("Protein", value: totals.protein, unit: "g", unknown: totals.unknownProteinCount)
                nutritionRow("Carbohydrates", value: totals.carbohydrates, unit: "g", unknown: totals.unknownCarbohydratesCount)
                nutritionRow("Fat", value: totals.fat, unit: "g", unknown: totals.unknownFatCount)
            }

            Section("Ingredients") {
                ForEach(template.orderedItems) { item in
                    HStack {
                        Text(item.food.name).foregroundStyle(Color.gymText)
                        Spacer()
                        Text(FoodLibraryService.amountDescription(portion: portion(for: item), quantity: item.quantity))
                            .font(AppFont.subheadlineSemiboldMonospaced)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                LabeledContent("Preparation", value: template.preparationState.displayName)
                if let yield = template.finalCookedWeightGrams {
                    LabeledContent("Recipe yield", value: "\(FoodLibraryService.format(yield)) g")
                }
                LabeledContent("Version", value: "v\(template.version)")
                LabeledContent("Last updated", value: template.updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { isEditing = true } label: { Label("Edit recipe", systemImage: AppIcon.edit) }
                    Button(role: .destructive) {
                        template.isArchived = true
                        template.updatedAt = .now
                        _ = modelContext.saveOrRollback()
                    } label: { Label("Archive recipe", systemImage: AppIcon.archive) }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("recipe-detail-menu")
            }
        }
        .sheet(isPresented: $isEditing) { MealTemplateEditorView(template: template) }
        .sheet(isPresented: $isLogging) { LogRecipeSheet(template: template) }
    }

    private func portion(for item: MealTemplateItem) -> FoodPortion {
        let portions = FoodLibraryService.portions(for: item.food)
        return portions.first { $0.id == item.servingID } ?? portions[0]
    }

    private func nutritionRow(_ label: LocalizedStringKey, value: Double, unit: String, unknown: Int) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.gymText)
            Spacer()
            Text("\(FoodLibraryService.format(value)) \(unit)")
                .font(AppFont.subheadlineSemiboldMonospaced)
                .foregroundStyle(Color.gymText)
            if unknown > 0 {
                Text("+ unknown").font(AppFont.caption).foregroundStyle(Color.gymAccent)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Log recipe

private enum RecipeLogAmount: Hashable {
    case whole
    case threeQuarter
    case half
    case quarter
    case grams

    var fraction: Double? {
        switch self {
        case .whole: 1
        case .threeQuarter: 0.75
        case .half: 0.5
        case .quarter: 0.25
        case .grams: nil
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .whole: "Whole recipe"
        case .threeQuarter: "¾ recipe"
        case .half: "½ recipe"
        case .quarter: "¼ recipe"
        case .grams: "By grams"
        }
    }
}

/// Logs a recipe to today as an immutable meal. The consumed amount can be the
/// whole recipe, a fraction, or grams when a recipe yield is known.
struct LogRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let template: MealTemplate

    @State private var slot: MealSlot = .snack
    @State private var amount: RecipeLogAmount = .whole
    @State private var grams: Double?
    @State private var loggedAt = Date.now
    @State private var errorMessage: String?

    private var yield: Double? { template.finalCookedWeightGrams }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    DatePicker("Time", selection: $loggedAt)
                }
                Section("Amount") {
                    Picker("Amount", selection: $amount) {
                        ForEach(amountOptions, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("log-recipe-amount")
                    if amount == .grams {
                        DecimalField("Grams", value: $grams, range: RecipeLoggingBounds.gramsRange(yield: yield))
                            .accessibilityIdentifier("log-recipe-grams")
                        if let yield {
                            Text("Recipe yield is \(FoodLibraryService.format(yield)) g.")
                                .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
                Section {
                    Text("Logging saves an immutable snapshot. Editing the recipe later never changes this meal.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gymBackground)
            .navigationTitle("Add to today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(resolvedFraction == nil)
                        .accessibilityIdentifier("confirm-log-recipe")
                }
            }
            .alert("Couldn’t log recipe", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    private var amountOptions: [RecipeLogAmount] {
        var options: [RecipeLogAmount] = [.whole, .threeQuarter, .half, .quarter]
        if yield != nil { options.append(.grams) }
        return options
    }

    /// The scaling factor to apply to the whole recipe. Nil means the current
    /// selection is not loggable yet (e.g. grams chosen but none entered).
    private var resolvedFraction: Double? {
        if let fraction = amount.fraction { return fraction }
        guard let yield, yield > 0, let grams, grams > 0 else { return nil }
        return grams / yield
    }

    private func add() {
        guard let fraction = resolvedFraction else { return }
        if NutritionLoggingService.log(template: template, fraction: fraction, slot: slot, loggedAt: loggedAt, using: modelContext) != nil {
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Recipe added to today."))
            dismiss()
        } else {
            errorMessage = String(localized: "The recipe could not be logged. Try again.")
        }
    }
}
