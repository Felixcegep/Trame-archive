import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct NutritionCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var loggedMeals: [LoggedMeal]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var mealTemplates: [MealTemplate]
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var targets: [NutritionTarget]
    @Query private var planRuns: [PlanRun]
    @State private var selectedFood: FoodItem?
    @State private var selectedMealToRepeat: LoggedMeal?
    @State private var recentFoodIDs: [UUID] = []

    init() {
        let todayKey = LocalDay.today.rawValue
        _loggedMeals = Query(
            filter: #Predicate<LoggedMeal> { $0.dayKey == todayKey },
            sort: [SortDescriptor(\LoggedMeal.loggedAt, order: .reverse)]
        )
    }

    private var summary: NutritionDaySummary { .resolve(day: .today, meals: loggedMeals) }
    private var targetResolution: (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues) {
        NutritionTargetResolver.resolve(day: .today, planRuns: planRuns, targets: targets)
    }

    var body: some View {
        let daySummary = summary
        let resolvedTarget = targetResolution
        let favorites = favoriteFoods
        let recents = recentFoods

        List {
            Section {
                NutritionTotalsView(totals: daySummary.totals, target: resolvedTarget.values, dayKind: resolvedTarget.kind)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                    .accessibilityIdentifier("nutrition-today-totals")
            } header: {
                Text("Today · \(resolvedTarget.kind.displayName)")
            } footer: {
                if daySummary.totals.hasUnknownValues {
                    Text("Known totals exclude foods with missing nutrients. Unknown values are never treated as zero.")
                }
            }

            Section("Log food") {
                if recents.isEmpty && favorites.isEmpty {
                    ContentUnavailableView("No foods ready to log", systemImage: AppIcon.nutrition, description: Text("Create a food in your library, then it will be available here offline."))
                } else {
                    if favorites.isEmpty == false {
                        ForEach(favorites) { food in
                            foodLogButton(food, detail: "Favorite")
                        }
                    }
                    if recents.isEmpty == false {
                        ForEach(recents) { food in
                            foodLogButton(food, detail: "Recent")
                        }
                    }
                }
                NavigationLink(value: NutritionRoute.foodLibrary) {
                    Label("Find food", systemImage: AppIcon.nutrition)
                }
                .accessibilityIdentifier("open-food-library")
            }

            if daySummary.meals.isEmpty == false {
                Section("Today’s log") {
                    ForEach(daySummary.meals) { meal in
                        Button {
                            selectedMealToRepeat = meal
                        } label: {
                            HStack(spacing: Spacing.m) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(meal.slot.displayName)
                                        .font(AppFont.captionBold)
                                        .foregroundStyle(Color.gymAccent)
                                    Text(meal.nameSnapshot)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.gymText)
                                }
                                Spacer()
                                Text(mealMacroDescription(meal))
                                    .font(AppFont.subheadlineSemiboldMonospaced)
                                    .foregroundStyle(Color.gymText)
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
        .task(id: loggedMeals.map(\.id)) {
            updateRecentFoodIDs()
        }
    }

    private var favoriteFoods: [FoodItem] {
        foods.filter { $0.isArchived == false && $0.isFavorite }.prefix(4).map { $0 }
    }

    private var recentFoods: [FoodItem] {
        let available = Dictionary(uniqueKeysWithValues: foods.filter { $0.isArchived == false }.map { ($0.id, $0) })
        return recentFoodIDs
            .compactMap { available[$0] }
            .filter { $0.isFavorite == false }
            .prefix(4)
            .map { $0 }
    }

    private func updateRecentFoodIDs() {
        var descriptor = FetchDescriptor<LoggedMeal>(
            sortBy: [SortDescriptor(\LoggedMeal.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let meals = (try? modelContext.fetch(descriptor)) ?? []
        var seen = Set<UUID>()
        recentFoodIDs = meals
            .flatMap(\.orderedItems)
            .compactMap { item in
                guard let id = item.sourceFoodID, seen.insert(id).inserted else { return nil }
                return id
            }
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
        GymCard {
            HStack(spacing: Spacing.xl) {
                calorieRing
                VStack(spacing: Spacing.m) {
                    NutritionMacroValue(label: "Protein", value: totals.protein, target: target.protein, unknown: totals.unknownProteinCount, tint: .gymPrimary)
                    NutritionMacroValue(label: "Carbs", value: totals.carbohydrates, target: target.carbohydrates, unknown: totals.unknownCarbohydratesCount, tint: .gymSecondary)
                    NutritionMacroValue(label: "Fat", value: totals.fat, target: target.fat, unknown: totals.unknownFatCount, tint: .gymAccent)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayKind.displayName). \(FoodLibraryService.format(totals.calories)) calories. Protein \(FoodLibraryService.format(totals.protein)) grams. Carbohydrates \(FoodLibraryService.format(totals.carbohydrates)) grams. Fat \(FoodLibraryService.format(totals.fat)) grams.")
    }

    private var calorieRing: some View {
        let progress = target.calories.map { min(max(totals.calories / max($0, 1), 0), 1) } ?? 0
        return ZStack {
            Circle().stroke(Color.gymPrimarySurface, lineWidth: Spacing.m)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.gymPrimary, style: StrokeStyle(lineWidth: Spacing.m, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Spacing.xxs) {
                Text(FoodLibraryService.format(totals.calories))
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Color.gymText)
                Text(target.calories.map { "/ \(FoodLibraryService.format($0))" } ?? "kcal")
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
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
                Text(label).font(AppFont.subheadline).foregroundStyle(Color.gymText)
                Spacer()
                Text(target.map { "\(FoodLibraryService.format(value))/\(FoodLibraryService.format($0)) g" } ?? "\(FoodLibraryService.format(value)) g")
                    .font(AppFont.subheadlineSemiboldMonospaced)
                    .foregroundStyle(Color.gymText)
            }
            ProgressView(value: target.map { min(value / max($0, 1), 1) } ?? 0)
                .tint(tint)
            if unknown > 0 { Text("+ unknown").font(AppFont.caption).foregroundStyle(Color.gymAccent) }
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
                            _ = modelContext.saveOrRollback()
                        } label: {
                            Label(food.isFavorite ? "Remove favorite" : "Favorite", systemImage: food.isFavorite ? AppIcon.favoriteRemove : AppIcon.favorite)
                        }
                        .tint(Color.gymAccent)
                        Button { editingFood = food } label: { Label("Edit", systemImage: AppIcon.edit) }
                            .tint(Color.gymAccent)
                        Button(role: food.isArchived ? nil : .destructive) {
                            food.isArchived.toggle()
                            food.updatedAt = .now
                            _ = modelContext.saveOrRollback()
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
        foods.filter { food in
            guard food.isArchived == showsArchived else { return false }
            guard !searchText.isEmpty else { return true }
            var extraTerms: [String] = []
            if let cat = food.categoryName { extraTerms.append(cat) }
            extraTerms.append(contentsOf: food.searchAliases)
            return SearchNormalization.matches(
                query: searchText,
                primaryName: food.name,
                alternateName: food.frenchName,
                aliases: extraTerms
            )
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

struct MealTemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealTemplate.updatedAt, order: .reverse) private var templates: [MealTemplate]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var isCreatingTemplate = false

    var body: some View {
        List {
            if currentTemplates.isEmpty {
                ContentUnavailableView("No recipes", systemImage: AppIcon.routine, description: Text("Create a simple recipe from foods in your library."))
            } else {
                ForEach(currentTemplates) { template in
                    NavigationLink {
                        MealTemplateDetailView(template: template)
                    } label: {
                        HStack(spacing: Spacing.m) {
                            recipeThumbnail(for: template)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(template.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.gymText)
                                Text("\(template.items.count) foods · v\(template.version) · \(template.preparationState.displayName)").font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                        }
                    }
                    .accessibilityIdentifier("recipe-row-\(template.id)")
                    .swipeActions { Button(role: .destructive) { template.isArchived = true; template.updatedAt = .now; _ = modelContext.saveOrRollback() } label: { Label("Archive", systemImage: AppIcon.archive) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.gymBackground)
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreatingTemplate = true } label: { Label("New recipe", systemImage: AppIcon.plus) }.disabled(foods.filter { !$0.isArchived }.isEmpty).accessibilityIdentifier("create-meal-template") }
        }
        .sheet(isPresented: $isCreatingTemplate) { MealTemplateEditorView() }
    }

    @ViewBuilder
    private func recipeThumbnail(for template: MealTemplate) -> some View {
        RecipePhotoImage(identifier: template.photoIdentifier, content: { image in
            image
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityHidden(true)
        }, placeholder: {
            Image(systemName: AppIcon.routine)
                .foregroundStyle(Color.gymSecondary)
                .frame(width: 44, height: 44)
                .background(Color.gymMutedSurface)
        })
    }

    private var currentTemplates: [MealTemplate] { templates.filter { $0.isCurrent && !$0.isArchived } }
}

private enum RecipeGenerationNotice: Equatable {
    case draftGenerated
    case noMatches
    case partialMatch
    case generationFailed
    case unclearImage
    case unsafeImage
}

private enum RecipeField: Hashable {
    case name
    case yield
}

/// Identifies which ingredient row the ingredient editor sheet is editing.
private struct IngredientEditContext: Identifiable {
    let id: Int
}

struct MealTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    let template: MealTemplate?
    let generator: RecipeDraftGenerator

    @State private var name = ""
    @State private var preparation: FoodPreparationState = .cooked
    @State private var recipeYield: Double?
    @State private var yieldEditingText: String?
    @State private var selected: [(FoodItem, UUID?, Double)] = []
    @State private var errorMessage: String?
    @FocusState private var focusedField: RecipeField?

    // Persisted recipe photo (recognition thumbnail), distinct from the
    // transient generation photo below.
    @State private var recipePhotoIdentifier: String?
    @State private var pendingRecipePhotoData: Data?
    @State private var recipePhotoPreview: UIImage?
    @State private var recipePhotoPickerItem: PhotosPickerItem?
    @State private var isShowingFoodPicker = false
    @State private var editingIngredient: IngredientEditContext?

    @State private var availability: RecipeGenerationAvailabilityStatus = .unsupportedDevice
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImagePreview: UIImage?
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var generationTask: Task<Void, Never>?
    @State private var hasGeneratedDraft = false
    @State private var lastAppliedDraftSnapshot: [UUID: Double]?
    @State private var pendingReplaceConfirmation = false
    @State private var generationNotice: RecipeGenerationNotice?
    @State private var draftGeneratedFeedbackTrigger = false

    init(template: MealTemplate? = nil, generator: RecipeDraftGenerator = MealTemplateEditorView.defaultGenerator()) {
        self.template = template
        self.generator = generator
    }

    private static func defaultGenerator() -> RecipeDraftGenerator {
        if let scripted = UITestRecipeDraftGenerationResult.launchOverride {
            return ScriptedRecipeDraftGenerator(result: scripted)
        }
        return FoundationRecipeDraftGenerator()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name).focused($focusedField, equals: .name)
                    generationControls
                    Picker("Preparation", selection: $preparation) { ForEach(FoodPreparationState.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    TextField("Recipe yield g (optional)", text: yieldTextBinding, prompt: Text("—"))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .yield)
                        .accessibilityIdentifier("recipe-yield-field")
                    Text("Total weight after cooking. This lets you log part of the recipe in grams.")
                        .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                }
                recipePhotoSection
                Section("Foods") {
                    if let generationNotice {
                        noticeText(generationNotice)
                            .font(AppFont.caption)
                            .foregroundStyle(Color.gymSubduedText)
                            .accessibilityIdentifier("recipe-generation-notice")
                    }
                    if selected.isEmpty {
                        Text("Add foods from your library to build this recipe.")
                            .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                    }
                    ForEach(Array(selected.enumerated()), id: \.element.0.id) { index, item in
                        Button {
                            editingIngredient = IngredientEditContext(id: index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(item.0.name).foregroundStyle(Color.gymText)
                                    Text(ingredientAmountText(item)).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                                }
                                Spacer()
                                Text(ingredientCaloriesText(item)).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                        }
                        .accessibilityLabel("\(item.0.name), \(ingredientAmountText(item))")
                        .accessibilityHint("Edit amount or remove")
                        .accessibilityIdentifier("recipe-ingredient-\(item.0.id)")
                    }
                    .onDelete { selected.remove(atOffsets: $0) }
                    Button { isShowingFoodPicker = true } label: { Label("Add foods", systemImage: AppIcon.plus) }
                        .accessibilityIdentifier("recipe-add-foods")
                }
            }
            .scrollContentBackground(.hidden).background(Color.gymBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(template == nil ? "New recipe" : "Revise recipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                load()
                availability = RecipeGenerationAvailability.status()
            }
            .onDisappear { generationTask?.cancel() }
            .task(id: recipePhotoIdentifier) {
                guard pendingRecipePhotoData == nil else { return }
                recipePhotoPreview = await RecipePhotoStore.loadImageAsync(recipePhotoIdentifier)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        guard !Task.isCancelled else { return }
                        selectedImageData = data
                        selectedImagePreview = await RecipePhotoStore.decodeImageAsync(data)
                    }
                }
            }
            .onChange(of: recipePhotoPickerItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        guard !Task.isCancelled else { return }
                        pendingRecipePhotoData = data
                        recipePhotoPreview = await RecipePhotoStore.decodeImageAsync(data)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        generationTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isGenerating || isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty)
                        .accessibilityIdentifier("save-meal-template")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button { focusedField = .name } label: { Label("Previous field", systemImage: "chevron.left") }
                        .disabled(focusedField == .name)
                    Button { focusedField = .yield } label: { Label("Next field", systemImage: "chevron.right") }
                        .disabled(focusedField == .yield)
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerSheet(existingSelection: Set(selected.map { $0.0.id })) { additions in
                    for food in additions {
                        selected.append((food, FoodLibraryService.defaultPortion(for: food).id, 1))
                    }
                }
            }
            .sheet(item: $editingIngredient) { context in
                if selected.indices.contains(context.id) {
                    IngredientEditorSheet(
                        food: selected[context.id].0,
                        servingID: Binding(get: { selected[context.id].1 }, set: { selected[context.id].1 = $0 }),
                        quantity: Binding(get: { selected[context.id].2 }, set: { selected[context.id].2 = $0 }),
                        onRemove: { selected.remove(at: context.id) }
                    )
                }
            }
            .alert("Couldn’t save recipe", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) { errorMessage = nil } } message: { Text(errorMessage ?? "Try again.") }
            .alert("Replace the current draft?", isPresented: $pendingReplaceConfirmation) {
                Button("Replace", role: .destructive) { runGeneration() }
                Button("Keep editing", role: .cancel) {}
            }
            .sensoryFeedback(.success, trigger: draftGeneratedFeedbackTrigger) { _, newValue in newValue }
        }
    }

    // MARK: - Recipe photo

    @ViewBuilder
    private var recipePhotoSection: some View {
        Section("Photo") {
            if let image = recipePhotoPreview {
                HStack(spacing: Spacing.m) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PhotosPicker(selection: $recipePhotoPickerItem, matching: .images) { Text("Replace photo") }
                            .accessibilityIdentifier("recipe-replace-photo")
                        Button("Remove photo", role: .destructive) {
                            pendingRecipePhotoData = nil
                            recipePhotoIdentifier = nil
                            recipePhotoPreview = nil
                            recipePhotoPickerItem = nil
                        }
                        .accessibilityIdentifier("recipe-remove-photo")
                    }
                }
            } else {
                PhotosPicker(selection: $recipePhotoPickerItem, matching: .images) {
                    Label("Add recipe photo", systemImage: AppIcon.recipePhoto)
                }
                .accessibilityIdentifier("recipe-add-photo")
                if let selectedImageData, selectedImagePreview != nil {
                    Button {
                        pendingRecipePhotoData = selectedImageData
                        recipePhotoPreview = selectedImagePreview
                    } label: {
                        Label("Keep generation photo with recipe", systemImage: "photo.on.rectangle")
                    }
                    .accessibilityIdentifier("recipe-keep-generation-photo")
                }
                Text("Optional recognition photo. It is never used as nutrition evidence.")
                    .font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    /// Locale-aware decimal binding for the recipe-yield field, preserving
    /// partial input like "." while editing.
    private var yieldTextBinding: Binding<String> {
        Binding(
            get: { yieldEditingText ?? DecimalParser.displayText(for: recipeYield) },
            set: { candidate in
                guard let sanitized = DecimalParser.sanitizedEditingText(candidate) else { return }
                yieldEditingText = sanitized
                if sanitized.isEmpty {
                    recipeYield = nil
                } else if let parsed = DecimalParser.value(from: sanitized) {
                    recipeYield = parsed
                }
            }
        )
    }

    private func ingredientAmountText(_ item: (FoodItem, UUID?, Double)) -> String {
        let portions = FoodLibraryService.portions(for: item.0)
        let portion = portions.first { $0.id == item.1 } ?? portions[0]
        return FoodLibraryService.amountDescription(portion: portion, quantity: item.2)
    }

    private func ingredientCaloriesText(_ item: (FoodItem, UUID?, Double)) -> String {
        let portions = FoodLibraryService.portions(for: item.0)
        let portion = portions.first { $0.id == item.1 } ?? portions[0]
        let multiplier = item.2 * portion.equivalentReferenceAmount / item.0.referenceAmount
        return item.0.calories.map { "\(FoodLibraryService.format($0 * multiplier)) kcal" } ?? String(localized: "kcal unknown")
    }

    // MARK: - Generation controls

    @ViewBuilder
    private var generationControls: some View {
        switch availability {
        case .fullyAvailable, .textOnly:
            photoControl
            Text("Prototype — generated results may be inaccurate. Review all foods and quantities before saving.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
                .accessibilityLabel("Prototype. Generated results may be inaccurate. Review all foods and quantities before saving.")
            generateButton
        case .modelDownloading:
            Text("Recipe generation will be available when setup finishes.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        case .unsupportedDevice, .unsupportedLocale:
            EmptyView()
        }
    }

    @ViewBuilder
    private var photoControl: some View {
        if selectedImageData != nil, let uiImage = selectedImagePreview {
            HStack(spacing: Spacing.m) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Selected recipe photo").font(AppFont.footnote).foregroundStyle(Color.gymSubduedText)
                    HStack(spacing: Spacing.l) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) { Text("Replace") }
                            .disabled(isGenerating)
                            .accessibilityLabel("Replace photo")
                            .accessibilityHint("Choose a different recipe photo")
                            .accessibilityIdentifier("replace-recipe-photo")
                        Button(role: .destructive) {
                            selectedImageData = nil
                            selectedImagePreview = nil
                            selectedPhotoItem = nil
                        } label: { Text("Remove") }
                        .disabled(isGenerating)
                        .accessibilityLabel("Remove photo")
                        .accessibilityHint("Removes the selected recipe photo")
                        .accessibilityIdentifier("remove-recipe-photo")
                    }
                }
                Spacer()
            }
        } else if availability.allowsImageInput {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Add one photo", systemImage: AppIcon.recipePhoto)
            }
            .disabled(isGenerating)
            .accessibilityHint("Optional. Helps identify the recipe and ingredients.")
            .accessibilityIdentifier("add-recipe-photo")
            Text("Optional — helps identify the recipe and ingredients.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        } else {
            Label("Add one photo", systemImage: AppIcon.recipePhoto)
                .foregroundStyle(Color.gymSubduedText)
            Text("Recipe generation from photos isn’t available on this device.")
                .font(AppFont.caption)
                .foregroundStyle(Color.gymSubduedText)
        }
    }

    private var generateButton: some View {
        Button {
            requestGeneration()
        } label: {
            if isGenerating {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Generating recipe…")
                }
            } else {
                Text(hasGeneratedDraft ? "Generate again" : "Generate recipe")
            }
        }
        .disabled(isGenerating || (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil))
        .accessibilityLabel(isGenerating ? "Generating recipe" : (hasGeneratedDraft ? "Generate again" : "Generate recipe"))
        .accessibilityIdentifier("generate-recipe")
    }

    @ViewBuilder
    private func noticeText(_ notice: RecipeGenerationNotice) -> some View {
        switch notice {
        case .draftGenerated:
            Text("Generated draft. Check the ingredients and quantities.")
        case .noMatches:
            Text("No matching foods were found in your library. Add foods manually.")
        case .partialMatch:
            Text("Some ingredients could not be matched. Review the draft and add missing foods.")
        case .generationFailed:
            Text("The recipe couldn’t be generated. Try again or add foods manually.")
        case .unclearImage:
            Text("The photo didn’t contain enough detail. Try another photo or enter a recipe name.")
        case .unsafeImage:
            Text("The photo couldn’t be used to generate a recipe. Try a different photo.")
        }
    }

    private func requestGeneration() {
        if hasGeneratedDraft, let snapshot = lastAppliedDraftSnapshot, snapshot != currentSelectionSnapshot() {
            pendingReplaceConfirmation = true
            return
        }
        runGeneration()
    }

    private func runGeneration() {
        guard isGenerating == false else { return }
        focusedField = nil
        isGenerating = true
        generationNotice = nil
        draftGeneratedFeedbackTrigger = false
        announce(String(localized: "Generating recipe."))
        let input = RecipeGenerationInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageData: selectedImageData,
            availableFoods: RecipeGenerationCatalogue.build(from: foods)
        )
        generationTask = Task {
            do {
                let validated = try await RecipeGenerationCoordinator.generateAndValidate(input: input, currentFoods: foods, using: generator)
                apply(validated)
            } catch is CancellationError {
                // Preserve current input; no notice for a user-initiated cancel.
            } catch let error as RecipeDraftGeneratorError {
                handle(error)
            } catch {
                generationNotice = .generationFailed
            }
            isGenerating = false
        }
    }

    private func apply(_ validated: ValidatedRecipeDraft) {
        if let newName = validated.name { name = newName }
        if let preparationState = validated.preparationState { preparation = preparationState }
        if let cookedWeightGrams = validated.finalCookedWeightGrams { recipeYield = cookedWeightGrams; yieldEditingText = nil }
        selected = validated.items
        hasGeneratedDraft = true
        lastAppliedDraftSnapshot = currentSelectionSnapshot()

        let imageOnly = selectedImageData != nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if validated.isEmpty {
            generationNotice = imageOnly ? .unclearImage : .noMatches
        } else if validated.hasUnmatchedIngredients {
            generationNotice = .partialMatch
        } else {
            generationNotice = .draftGenerated
            draftGeneratedFeedbackTrigger = true
            announce(String(localized: "Recipe draft generated. Review ingredients and quantities."))
        }
    }

    private func handle(_ error: RecipeDraftGeneratorError) {
        switch error {
        case .modelUnavailable, .generationFailed:
            generationNotice = .generationFailed
        case .imageUnsupported:
            generationNotice = .generationFailed
        case .unclearImage:
            generationNotice = .unclearImage
        case .unsafeImage:
            generationNotice = .unsafeImage
        case .cancelled:
            break
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func currentSelectionSnapshot() -> [UUID: Double] {
        Dictionary(uniqueKeysWithValues: selected.map { ($0.0.id, $0.2) })
    }

    private func load() {
        guard let template else { return }
        name = template.name; preparation = template.preparationState; recipeYield = template.finalCookedWeightGrams
        recipePhotoIdentifier = template.photoIdentifier
        selected = template.orderedItems.map { ($0.food, $0.servingID, $0.quantity) }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (recipeYield ?? 1) > 0 else { errorMessage = "Recipe yield must be positive or blank."; return }
        guard isSaving == false else { return }
        isSaving = true
        let pendingPhotoData = pendingRecipePhotoData

        Task {
            let photoIdentifier: String?
            if let pendingPhotoData {
                guard let stored = await RecipePhotoStore.storeImageDataAsync(pendingPhotoData) else {
                    guard !Task.isCancelled else { return }
                    errorMessage = "The recipe photo could not be saved. Try another image."
                    isSaving = false
                    return
                }
                photoIdentifier = stored
            } else {
                photoIdentifier = recipePhotoIdentifier
            }

            guard !Task.isCancelled else {
                isSaving = false
                return
            }
            persistRecipe(named: trimmed, photoIdentifier: photoIdentifier)
            isSaving = false
        }
    }

    private func persistRecipe(named trimmed: String, photoIdentifier: String?) {
        if let template {
            guard MealTemplateService.revise(template, name: trimmed, preparationState: preparation, finalCookedWeightGrams: recipeYield, photoIdentifier: photoIdentifier, items: selected, using: modelContext) != nil else { errorMessage = "The recipe could not be saved."; return }
        } else {
            let newTemplate = MealTemplate(name: trimmed, preparationState: preparation, finalCookedWeightGrams: recipeYield, photoIdentifier: photoIdentifier)
            newTemplate.items = selected.enumerated().map { MealTemplateItem(food: $0.element.0, orderIndex: $0.offset, servingID: $0.element.1, quantity: $0.element.2) }
            modelContext.insert(newTemplate)
            guard modelContext.saveOrRollback() else { errorMessage = "The recipe could not be saved."; return }
        }
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct NutritionTargetsView: View {
    @Query(sort: \NutritionTarget.effectiveStartDayKey, order: .reverse) private var targets: [NutritionTarget]
    @State private var editingTarget: NutritionTarget?
    @State private var isCreatingTarget = false

    var body: some View {
        List {
            if targets.filter({ !$0.isArchived }).isEmpty {
                ContentUnavailableView {
                    Label("No targets", systemImage: AppIcon.chart)
                } description: {
                    Text("Add a training and rest-day target when you are ready.")
                } actions: {
                    Button("Add target") {
                        isCreatingTarget = true
                    }
                    .buttonStyle(.gymPrimary)
                    .accessibilityIdentifier("create-nutrition-target-empty")
                }
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
    @State private var training: [Double?] = [nil, nil, nil, nil]
    @State private var rest: [Double?] = [nil, nil, nil, nil]
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

    @ViewBuilder private func macroFields(title: String, values: Binding<[Double?]>) -> some View {
        Section(title) {
            DecimalField("Calories (optional)", value: values[0], range: 0...100000)
            DecimalField("Protein g (optional)", value: values[1], range: 0...100000)
            DecimalField("Carbohydrates g (optional)", value: values[2], range: 0...100000)
            DecimalField("Fat g (optional)", value: values[3], range: 0...100000)
        }
    }

    private func load() {
        guard let target else { return }
        phase = target.phase; startDate = dayDate(target.effectiveStartDayKey) ?? .now
        if let end = target.effectiveEndDayKey { endEnabled = true; endDate = dayDate(end) ?? .now }
        training = [target.trainingCalories, target.trainingProteinGrams, target.trainingCarbohydrateGrams, target.trainingFatGrams]
        rest = [target.restCalories, target.restProteinGrams, target.restCarbohydrateGrams, target.restFatGrams]
    }
    private func save() {
        guard training.allSatisfy({ ($0 ?? 0) >= 0 }), rest.allSatisfy({ ($0 ?? 0) >= 0 }) else { errorMessage = "Targets must be positive numbers or left blank."; return }
        let start = LocalDay(date: startDate), end = endEnabled ? LocalDay(date: endDate) : nil
        guard end.map({ $0 >= start }) ?? true else { errorMessage = "The end date must be on or after the start date."; return }
        let trainingValues = NutritionTargetValues(calories: training[0], protein: training[1], carbohydrates: training[2], fat: training[3])
        let restValues = NutritionTargetValues(calories: rest[0], protein: rest[1], carbohydrates: rest[2], fat: rest[3])
        if let target {
            guard NutritionTargetService.revise(target, phase: phase, requestedStartDay: start, requestedEndDay: end, training: trainingValues, rest: restValues, using: modelContext) != nil else {
                errorMessage = "The target revision could not be saved."
                return
            }
        } else {
            modelContext.insert(NutritionTarget(phase: phase, effectiveStartDay: start, effectiveEndDay: end, training: trainingValues, rest: restValues))
            guard modelContext.saveOrRollback() else { errorMessage = "The target could not be saved."; return }
        }
        dismiss()
    }
}

private func foodMacroDescription(_ food: FoodItem) -> String {
    let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
    let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
    return "\(energy) · \(protein)"
}

private func dayDate(_ key: String) -> Date? {
    let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: key)
}
