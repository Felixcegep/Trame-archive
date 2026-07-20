import SwiftData
import SwiftUI

struct NutritionCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var targets: [NutritionTarget]
    @Query private var planRuns: [PlanRun]
    @State private var selectedFood: FoodItem?
    @State private var selectedMealToRepeat: LoggedMeal?

    private var summary: NutritionDaySummary { .resolve(day: .today, meals: loggedMeals) }
    private var targetResolution: (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues) {
        NutritionTargetResolver.resolve(day: .today, planRuns: planRuns, targets: targets)
    }

    var body: some View {
        List {
            Section {
                NutritionTotalsView(totals: summary.totals, target: targetResolution.values, dayKind: targetResolution.kind)
                    .listRowBackground(Color.gymCard)
                    .accessibilityIdentifier("nutrition-today-totals")
            } header: {
                Text("Today · \(targetResolution.kind.displayName)")
            } footer: {
                if summary.totals.hasUnknownValues {
                    Text("Known totals exclude foods with missing nutrients. Unknown values are never treated as zero.")
                }
            }

            Section("Log food") {
                if recentFoods.isEmpty && favoriteFoods.isEmpty {
                    ContentUnavailableView("No foods ready to log", systemImage: AppIcon.nutrition, description: Text("Create a food in your library, then it will be available here offline."))
                } else {
                    if favoriteFoods.isEmpty == false {
                        ForEach(favoriteFoods) { food in
                            foodLogButton(food, detail: "Favorite")
                        }
                    }
                    if recentFoods.isEmpty == false {
                        ForEach(recentFoods) { food in
                            foodLogButton(food, detail: "Recent")
                        }
                    }
                }
                NavigationLink(value: NutritionRoute.foodLibrary) {
                    Label("Find food", systemImage: AppIcon.nutrition)
                }
                .accessibilityIdentifier("open-food-library")
            }

            if summary.meals.isEmpty == false {
                Section("Today’s log") {
                    ForEach(summary.meals) { meal in
                        Button {
                            selectedMealToRepeat = meal
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(meal.nameSnapshot)
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.gymText)
                                Text("\(meal.slot.displayName) · \(mealMacroDescription(meal))")
                                    .font(AppFont.caption)
                                    .foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityHint("Repeats this meal as a new entry today")
                        .accessibilityIdentifier("repeat-logged-meal-\(meal.id)")
                    }
                }
            }

            Section("Plan") {
                NavigationLink(value: NutritionRoute.mealTemplates) {
                    Label("Recipes", systemImage: AppIcon.routine)
                }
                .accessibilityIdentifier("open-meal-templates")
                NavigationLink(value: NutritionRoute.targets) {
                    Label("Training & rest targets", systemImage: AppIcon.chart)
                }
                .accessibilityIdentifier("open-nutrition-targets")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Nutrition")
        .sheet(item: $selectedFood) { food in
            FoodQuickLogView(food: food)
        }
        .sheet(item: $selectedMealToRepeat) { meal in
            RepeatMealSheet(meal: meal)
        }
    }

    private var favoriteFoods: [FoodItem] {
        foods.filter { $0.isArchived == false && $0.isFavorite }.prefix(4).map { $0 }
    }

    private var recentFoods: [FoodItem] {
        let available = Dictionary(uniqueKeysWithValues: foods.filter { $0.isArchived == false }.map { ($0.id, $0) })
        var seen = Set<UUID>()
        return loggedMeals
            .flatMap(\.orderedItems)
            .compactMap { item in
                guard let id = item.sourceFoodID, seen.insert(id).inserted else { return nil }
                return available[id]
            }
            .filter { $0.isFavorite == false }
            .prefix(4)
            .map { $0 }
    }

    private func foodLogButton(_ food: FoodItem, detail: String) -> some View {
        Button { selectedFood = food } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.nutrition)
                    .foregroundStyle(Color.gymSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(food.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                    Text("\(detail) · \(foodMacroDescription(food))").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
            }
        }
        .accessibilityIdentifier("quick-log-food-\(food.id)")
    }

    private func mealMacroDescription(_ meal: LoggedMeal) -> String {
        let calories = meal.orderedItems.compactMap(\.caloriesSnapshot).reduce(0, +)
        return "\(FoodLibraryService.format(calories)) kcal"
    }
}

struct NutritionTotalsView: View {
    let totals: NutritionMacroTotals
    let target: NutritionTargetValues
    let dayKind: NutritionDayKind

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("\(FoodLibraryService.format(totals.calories)) kcal")
                        .font(AppFont.titleMedium)
                        .foregroundStyle(Color.gymText)
                    if let calories = target.calories {
                        Text("of \(FoodLibraryService.format(calories)) kcal target")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    } else {
                        Text("No calorie target set")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                Spacer()
                Image(systemName: AppIcon.nutrition).foregroundStyle(Color.gymSecondary)
            }
            HStack(spacing: Spacing.m) {
                NutritionMacroValue(label: "Protein", value: totals.protein, target: target.protein, unknown: totals.unknownProteinCount)
                NutritionMacroValue(label: "Carbs", value: totals.carbohydrates, target: target.carbohydrates, unknown: totals.unknownCarbohydratesCount)
                NutritionMacroValue(label: "Fat", value: totals.fat, target: target.fat, unknown: totals.unknownFatCount)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayKind.displayName). \(FoodLibraryService.format(totals.calories)) calories. Protein \(FoodLibraryService.format(totals.protein)) grams. Carbohydrates \(FoodLibraryService.format(totals.carbohydrates)) grams. Fat \(FoodLibraryService.format(totals.fat)) grams.")
    }
}

private struct NutritionMacroValue: View {
    let label: String
    let value: Double
    let target: Double?
    let unknown: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(AppFont.captionBold).foregroundStyle(Color.gymSubduedText)
            Text("\(FoodLibraryService.format(value)) g")
                .font(AppFont.subheadlineSemibold)
                .foregroundStyle(Color.gymText)
            if let target {
                Text("/ \(FoodLibraryService.format(target)) g").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
            } else if unknown > 0 {
                Text("+ unknown").font(AppFont.caption).foregroundStyle(Color.gymAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FoodLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var searchText = ""
    @State private var showsArchived = false
    @State private var editingFood: FoodItem?
    @State private var selectedFood: FoodItem?
    @State private var isCreatingFood = false

    var body: some View {
        List {
            if visibleFoods.isEmpty {
                ContentUnavailableView(showsArchived ? "No archived foods" : "No foods found", systemImage: AppIcon.nutrition, description: Text(showsArchived ? "Archived foods stay available to historical meals." : "Create a custom food to log it offline."))
            } else {
                ForEach(visibleFoods) { food in
                    Button {
                        if food.isArchived {
                            editingFood = food
                        } else {
                            selectedFood = food
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack {
                                Text(food.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                                if food.isFavorite { Image(systemName: AppIcon.favoriteFilled).foregroundStyle(Color.gymAccent) }
                            }
                            Text("\(foodMacroDescription(food)) · \(food.confidence.displayName)")
                                .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .accessibilityHint(food.isArchived ? "Edit or restore this archived food" : "Log this food")
                    .accessibilityIdentifier("food-row-\(food.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            food.isFavorite.toggle()
                            food.updatedAt = .now
                            try? modelContext.save()
                        } label: {
                            Label(food.isFavorite ? "Remove favorite" : "Favorite", systemImage: food.isFavorite ? AppIcon.favoriteRemove : AppIcon.favorite)
                        }
                        .tint(Color.gymAccent)
                        Button { editingFood = food } label: { Label("Edit", systemImage: AppIcon.edit) }
                            .tint(Color.gymAccent)
                        Button(role: food.isArchived ? nil : .destructive) {
                            food.isArchived.toggle()
                            food.updatedAt = .now
                            try? modelContext.save()
                        } label: { Label(food.isArchived ? "Restore" : "Archive", systemImage: food.isArchived ? AppIcon.restore : AppIcon.archive) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gymBackground)
        .navigationTitle("Food library")
        .searchable(text: $searchText, prompt: "Search foods")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(showsArchived ? "Current" : "Archived") { showsArchived.toggle() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { isCreatingFood = true } label: { Label("New food", systemImage: AppIcon.plus) }
                    .accessibilityIdentifier("create-food")
            }
        }
        .sheet(isPresented: $isCreatingFood) { FoodEditorView() }
        .sheet(item: $editingFood) { FoodEditorView(food: $0) }
        .sheet(item: $selectedFood) { FoodQuickLogView(food: $0) }
    }

    private var visibleFoods: [FoodItem] {
        foods.filter {
            $0.isArchived == showsArchived && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }
}

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
}

struct RepeatMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let meal: LoggedMeal
    @State private var slot: MealSlot

    init(meal: LoggedMeal) {
        self.meal = meal
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
                    Button("Add") { if NutritionLoggingService.repeatMeal(meal, slot: slot, using: modelContext) != nil { dismiss() } }
                        .accessibilityIdentifier("confirm-repeat-meal")
                }
            }
        }
    }
}

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let food: FoodItem?
    @State private var name = ""
    @State private var referenceAmount = "100"
    @State private var referenceUnit: NutritionServingUnit = .grams
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var confidence: FoodConfidence = .userProvided
    @State private var preparation: FoodPreparationState = .raw
    @State private var servingName = ""
    @State private var servingAmount = ""
    @State private var servingEquivalentReferenceAmount = ""
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
                        TextField("Reference amount", text: $referenceAmount).keyboardType(.decimalPad)
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
                    TextField("Calories (optional)", text: $calories).keyboardType(.decimalPad)
                    TextField("Protein g (optional)", text: $protein).keyboardType(.decimalPad)
                    TextField("Carbohydrates g (optional)", text: $carbohydrates).keyboardType(.decimalPad)
                    TextField("Fat g (optional)", text: $fat).keyboardType(.decimalPad)
                }
                Section("Quick serving") {
                    TextField("Serving name (optional)", text: $servingName)
                    HStack {
                        TextField("Serving amount", text: $servingAmount).keyboardType(.decimalPad)
                        Picker("Serving unit", selection: $servingUnit) {
                            ForEach(NutritionServingUnit.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Equivalent reference amount", text: $servingEquivalentReferenceAmount).keyboardType(.decimalPad)
                    Text("For example, a 1 cup serving can represent 240 reference grams. Leave this blank when the reference amount is the only serving.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    if food?.orderedServings.isEmpty == false {
                        Button("Remove saved serving", role: .destructive) {
                            removesQuickServing = true
                            servingName = ""
                            servingAmount = ""
                            servingEquivalentReferenceAmount = ""
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
        name = food.name; referenceAmount = FoodLibraryService.format(food.referenceAmount); referenceUnit = food.referenceUnit
        calories = string(food.calories); protein = string(food.proteinGrams); carbohydrates = string(food.carbohydrateGrams); fat = string(food.fatGrams)
        confidence = food.confidence; preparation = food.preparationState
        if let serving = food.orderedServings.first {
            servingName = serving.name; servingAmount = FoodLibraryService.format(serving.amount); servingEquivalentReferenceAmount = FoodLibraryService.format(serving.equivalentReferenceAmount); servingUnit = serving.unit
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(referenceAmount), amount > 0 else { errorMessage = "Enter a positive reference amount."; return }
        let allFoods = (try? modelContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        guard allFoods.allSatisfy({ $0.id == food?.id || $0.name.localizedCaseInsensitiveCompare(trimmed) != .orderedSame }) else { errorMessage = "A food with that name already exists."; return }
        guard [calories, protein, carbohydrates, fat].allSatisfy(validOptionalNumber) else { errorMessage = "Macros must be positive numbers or left blank."; return }
        let target = food ?? FoodItem(name: trimmed)
        target.name = trimmed; target.referenceAmount = amount; target.referenceUnit = referenceUnit
        target.calories = optionalNumber(calories); target.proteinGrams = optionalNumber(protein); target.carbohydrateGrams = optionalNumber(carbohydrates); target.fatGrams = optionalNumber(fat)
        target.confidence = confidence; target.preparationState = preparation; target.updatedAt = .now
        if food == nil { modelContext.insert(target) }
        let trimmedServing = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if removesQuickServing {
            for serving in target.servings { modelContext.delete(serving) }
            target.servings = []
        } else if trimmedServing.isEmpty == false {
            guard let servingAmount = Double(servingAmount), servingAmount > 0,
                  let equivalent = Double(servingEquivalentReferenceAmount), equivalent > 0 else { errorMessage = "Enter positive serving and equivalent reference amounts."; return }
            let priorServings = target.servings
            target.servings = [FoodServing(name: trimmedServing, amount: servingAmount, unit: servingUnit, equivalentReferenceAmount: equivalent)]
            for serving in priorServings { modelContext.delete(serving) }
        }
        do { try modelContext.save(); dismiss() } catch { errorMessage = "The food could not be saved. Try again." }
    }
}

struct MealTemplateLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var templates: [MealTemplate]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var editingTemplate: MealTemplate?
    @State private var isCreatingTemplate = false

    var body: some View {
        List {
            if currentTemplates.isEmpty {
                ContentUnavailableView("No recipes", systemImage: AppIcon.routine, description: Text("Create a simple recipe from foods in your library."))
            } else {
                ForEach(currentTemplates) { template in
                    Button { editingTemplate = template } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(template.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                            Text("\(template.items.count) foods · v\(template.version) · \(template.preparationState.displayName)").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                    .swipeActions { Button(role: .destructive) { template.isArchived = true; template.updatedAt = .now; try? modelContext.save() } label: { Label("Archive", systemImage: AppIcon.archive) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.gymBackground)
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreatingTemplate = true } label: { Label("New recipe", systemImage: AppIcon.plus) }.disabled(foods.filter { !$0.isArchived }.isEmpty) }
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .sheet(isPresented: $isCreatingTemplate) { MealTemplateEditorView() }
        .sheet(item: $editingTemplate) { MealTemplateEditorView(template: $0) }
    }

    private var currentTemplates: [MealTemplate] { templates.filter { $0.isCurrent && !$0.isArchived } }
}

struct MealTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    let template: MealTemplate?
    @State private var name = ""
    @State private var preparation: FoodPreparationState = .cooked
    @State private var cookedWeight = ""
    @State private var selected: [(FoodItem, UUID?, Double)] = []
    @State private var errorMessage: String?

    init(template: MealTemplate? = nil) { self.template = template }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    Picker("Preparation", selection: $preparation) { ForEach(FoodPreparationState.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    TextField("Final cooked weight g (optional)", text: $cookedWeight).keyboardType(.decimalPad)
                }
                Section("Foods") {
                    ForEach(Array(selected.enumerated()), id: \.element.0.id) { index, item in
                        HStack {
                            VStack(alignment: .leading) { Text(item.0.name); Text("\(FoodLibraryService.format(item.2)) serving").font(AppFont.caption).foregroundStyle(Color.gymSubduedText) }
                            Spacer()
                            Stepper("", value: Binding(get: { selected[index].2 }, set: { selected[index].2 = $0 }), in: 0.25...20, step: 0.25).labelsHidden()
                        }
                    }
                    .onDelete { selected.remove(atOffsets: $0) }
                    Menu {
                        ForEach(availableFoods) { food in Button(food.name) { selected.append((food, FoodLibraryService.portions(for: food).first?.id, 1)) } }
                    } label: { Label("Add food", systemImage: AppIcon.plus) }
                }
            }
            .scrollContentBackground(.hidden).background(Color.gymBackground)
            .navigationTitle(template == nil ? "New recipe" : "Revise recipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty) }
            }
            .alert("Couldn’t save recipe", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    private var availableFoods: [FoodItem] {
        let selectedIDs = Set(selected.map { $0.0.id })
        return foods.filter { !$0.isArchived && !selectedIDs.contains($0.id) }
    }
    private func load() {
        guard let template else { return }
        name = template.name; preparation = template.preparationState; cookedWeight = string(template.finalCookedWeightGrams)
        selected = template.orderedItems.map { ($0.food, $0.servingID, $0.quantity) }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cookedWeight.isEmpty || (Double(cookedWeight) ?? 0) > 0 else { errorMessage = "Final cooked weight must be positive or blank."; return }
        if let template {
            guard MealTemplateService.revise(template, name: trimmed, preparationState: preparation, finalCookedWeightGrams: optionalNumber(cookedWeight), items: selected, using: modelContext) != nil else { errorMessage = "The recipe could not be saved."; return }
        } else {
            let newTemplate = MealTemplate(name: trimmed, preparationState: preparation, finalCookedWeightGrams: optionalNumber(cookedWeight))
            newTemplate.items = selected.enumerated().map { MealTemplateItem(food: $0.element.0, orderIndex: $0.offset, servingID: $0.element.1, quantity: $0.element.2) }
            modelContext.insert(newTemplate)
            do { try modelContext.save() } catch { errorMessage = "The recipe could not be saved."; return }
        }
        dismiss()
    }
}

struct NutritionTargetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var targets: [NutritionTarget]
    @State private var editingTarget: NutritionTarget?
    @State private var isCreatingTarget = false

    var body: some View {
        List {
            if targets.filter({ !$0.isArchived }).isEmpty {
                ContentUnavailableView("No targets", systemImage: AppIcon.chart, description: Text("Add a training and rest-day target when you are ready."))
            } else {
                ForEach(targets.filter { !$0.isArchived }) { target in
                    Button { editingTarget = target } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(target.phase.displayName).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                            Text("From \(target.effectiveStartDayKey) · Training \(target.trainingCalories.map { FoodLibraryService.format($0) + " kcal" } ?? "not set")").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.gymBackground)
        .navigationTitle("Nutrition targets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreatingTarget = true } label: { Label("New target", systemImage: AppIcon.plus) } }
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .sheet(isPresented: $isCreatingTarget) { NutritionTargetEditorView() }
        .sheet(item: $editingTarget) { NutritionTargetEditorView(target: $0) }
    }
}

struct NutritionTargetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let target: NutritionTarget?
    @State private var phase: NutritionGoalPhase = .maintenance
    @State private var startDate = Date.now
    @State private var endEnabled = false
    @State private var endDate = Date.now
    @State private var training = ["", "", "", ""]
    @State private var rest = ["", "", "", ""]
    @State private var errorMessage: String?

    init(target: NutritionTarget? = nil) { self.target = target }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phase") {
                    Picker("Goal", selection: $phase) { ForEach(NutritionGoalPhase.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Set an end date", isOn: $endEnabled)
                    if endEnabled { DatePicker("Ends", selection: $endDate, displayedComponents: .date) }
                }
                if target != nil {
                    Section {
                        Text("Saving creates a future target revision. Previous days keep their original target phase.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                    }
                }
                macroFields(title: "Training day", values: $training)
                macroFields(title: "Rest day", values: $rest)
            }
            .scrollContentBackground(.hidden).background(Color.gymBackground)
            .navigationTitle(target == nil ? "New target" : "Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("save-nutrition-target") }
            }
            .alert("Couldn’t save target", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    @ViewBuilder private func macroFields(title: String, values: Binding<[String]>) -> some View {
        Section(title) {
            TextField("Calories (optional)", text: values[0]).keyboardType(.decimalPad)
            TextField("Protein g (optional)", text: values[1]).keyboardType(.decimalPad)
            TextField("Carbohydrates g (optional)", text: values[2]).keyboardType(.decimalPad)
            TextField("Fat g (optional)", text: values[3]).keyboardType(.decimalPad)
        }
    }

    private func load() {
        guard let target else { return }
        phase = target.phase; startDate = dayDate(target.effectiveStartDayKey) ?? .now
        if let end = target.effectiveEndDayKey { endEnabled = true; endDate = dayDate(end) ?? .now }
        training = [string(target.trainingCalories), string(target.trainingProteinGrams), string(target.trainingCarbohydrateGrams), string(target.trainingFatGrams)]
        rest = [string(target.restCalories), string(target.restProteinGrams), string(target.restCarbohydrateGrams), string(target.restFatGrams)]
    }
    private func save() {
        guard training.allSatisfy(validOptionalNumber), rest.allSatisfy(validOptionalNumber) else { errorMessage = "Targets must be positive numbers or left blank."; return }
        let start = LocalDay(date: startDate), end = endEnabled ? LocalDay(date: endDate) : nil
        guard end.map({ $0 >= start }) ?? true else { errorMessage = "The end date must be on or after the start date."; return }
        let trainingValues = NutritionTargetValues(calories: optionalNumber(training[0]), protein: optionalNumber(training[1]), carbohydrates: optionalNumber(training[2]), fat: optionalNumber(training[3]))
        let restValues = NutritionTargetValues(calories: optionalNumber(rest[0]), protein: optionalNumber(rest[1]), carbohydrates: optionalNumber(rest[2]), fat: optionalNumber(rest[3]))
        if let target {
            guard NutritionTargetService.revise(target, phase: phase, requestedStartDay: start, requestedEndDay: end, training: trainingValues, rest: restValues, using: modelContext) != nil else {
                errorMessage = "The target revision could not be saved."
                return
            }
        } else {
            modelContext.insert(NutritionTarget(phase: phase, effectiveStartDay: start, effectiveEndDay: end, training: trainingValues, rest: restValues))
            do { try modelContext.save() } catch { errorMessage = "The target could not be saved."; return }
        }
        dismiss()
    }
}

private func foodMacroDescription(_ food: FoodItem) -> String {
    let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
    let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
    return "\(energy) · \(protein)"
}

private func optionalNumber(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return nil }
    return Double(trimmed)
}

private func validOptionalNumber(_ value: String) -> Bool {
    optionalNumber(value).map { $0 >= 0 } ?? value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func string(_ value: Double?) -> String { value.map(FoodLibraryService.format) ?? "" }

private func dayDate(_ key: String) -> Date? {
    let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: key)
}
