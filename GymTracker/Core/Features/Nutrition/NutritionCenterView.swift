import SwiftData
import SwiftUI

struct NutritionCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var loggedMeals: [LoggedMeal]
    @Query(filter: #Predicate<FoodItem> { !$0.isArchived }, sort: \FoodItem.name)
    private var foods: [FoodItem]
    @Query(
        filter: #Predicate<NutritionTarget> { !$0.isArchived },
        sort: \NutritionTarget.effectiveStartDayKey,
        order: .reverse
    ) private var targets: [NutritionTarget]
    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]
    @State private var selectedFood: FoodItem?
    @State private var selectedLoggedMeal: LoggedMeal?
    @State private var isShowingCaffeineLog = false
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
                    // "No foods ready to log" described the *app* as
                    // unprepared, and did so while the library sat full of
                    // seeded foods one row below. This section is the
                    // one-tap shortcut list, so it should report the only
                    // thing that is actually empty: the user's own history.
                    ContentUnavailableView(
                        "Nothing logged yet",
                        systemImage: AppIcon.nutrition,
                        description: Text("Foods you log or mark as a favorite appear here for one-tap logging. Find food to add your first one.")
                    )
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
                Button {
                    isShowingCaffeineLog = true
                } label: {
                    Label("Log caffeine", systemImage: AppIcon.caffeine)
                }
                .accessibilityIdentifier("open-caffeine-log")
            }

            if daySummary.meals.isEmpty == false {
                Section("Today’s log") {
                    ForEach(daySummary.meals) { meal in
                        Button {
                            selectedLoggedMeal = meal
                        } label: {
                            HStack(spacing: Spacing.m) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("\(meal.slot.displayName) · \(meal.loggedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(AppFont.captionBold)
                                        .foregroundStyle(Color.trameSubdued)
                                    Text(meal.nameSnapshot)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.trameText)
                                    Text(mealAmountDescription(meal))
                                        .font(AppFont.caption)
                                        .foregroundStyle(Color.trameSubdued)
                                }
                                Spacer()
                                Text(mealMacroDescription(meal))
                                    .font(AppFont.subheadlineSemiboldMonospaced)
                                    .foregroundStyle(Color.trameText)
                            }
                            .frame(maxWidth: .infinity, minHeight: ComponentSize.minimumTouchTarget, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens entry details and actions")
                        .accessibilityIdentifier("logged-meal-\(meal.id)")
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
        .background(Color.trameCanvas)
        .tint(Color.trameAction)
        .navigationTitle("Nutrition")
        .listStyle(.plain)
        .contentMargins(.bottom, ComponentSize.tabBarClearance, for: .scrollContent)
        .sheet(isPresented: $isShowingCaffeineLog) {
            CaffeineQuickLogSheet()
        }
        .sheet(item: $selectedFood) { food in
            FoodQuickLogView(food: food)
        }
        .sheet(item: $selectedLoggedMeal) { meal in
            LoggedMealDetailSheet(meal: meal)
        }
        .task(id: loggedMeals.map(\.id)) {
            updateRecentFoodIDs()
        }
    }

    private var favoriteFoods: [FoodItem] {
        var result: [FoodItem] = []
        result.reserveCapacity(4)
        for food in foods where food.isFavorite {
            result.append(food)
            if result.count == 4 { break }
        }
        return result
    }

    private var recentFoods: [FoodItem] {
        let available = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
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
        var recentIDs: [UUID] = []
        recentIDs.reserveCapacity(4)
        mealLoop: for meal in meals {
            for item in meal.orderedItems {
                guard let id = item.sourceFoodID, seen.insert(id).inserted else { continue }
                recentIDs.append(id)
                if recentIDs.count == 4 { break mealLoop }
            }
        }
        recentFoodIDs = recentIDs
    }

    private func foodLogButton(_ food: FoodItem, detail: String) -> some View {
        Button { selectedFood = food } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: AppIcon.nutrition)
                    .foregroundStyle(Color.trameText)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(food.name).font(AppFont.subheadlineSemibold).foregroundStyle(Color.trameText)
                    Text("\(detail) · \(foodMacroDescription(food))").font(AppFont.caption).foregroundStyle(Color.trameSubdued)
                }
            }
        }
        .accessibilityIdentifier("quick-log-food-\(food.id)")
    }

    private func mealMacroDescription(_ meal: LoggedMeal) -> String {
        let items = meal.orderedItems
        return "\(summedDescription(items.map(\.caloriesSnapshot), unit: "kcal", unknownLabel: "Calories unknown"))\n\(summedDescription(items.map(\.proteinGramsSnapshot), unit: "g protein", unknownLabel: "Protein unknown"))"
    }

    private func mealAmountDescription(_ meal: LoggedMeal) -> String {
        guard meal.items.count == 1, let item = meal.items.first else {
            return "\(meal.items.count) ingredients"
        }
        let amount = FoodLibraryService.format(item.quantity * item.portionAmountSnapshot)
        switch item.portionUnit {
        case .grams: return "\(amount) g"
        case .milliliters: return "\(amount) mL"
        case .count, .serving: return "\(FoodLibraryService.format(item.quantity)) × \(item.servingNameSnapshot)"
        }
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }

    private func summedDescription(_ values: [Double?], unit: String, unknownLabel: String) -> String {
        let known = values.compactMap { $0 }
        guard known.isEmpty == false else { return unknownLabel }
        let suffix = known.count == values.count ? "" : " + unknown"
        return "\(FoodLibraryService.format(known.reduce(0, +))) \(unit)\(suffix)"
    }
}

private struct LoggedMealDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let meal: LoggedMeal
    @State private var quantity: Double?
    @State private var slot: MealSlot
    @State private var showsDeleteConfirmation = false
    @State private var showsRepeatSheet = false
    @State private var showsSaveError = false

    init(meal: LoggedMeal) {
        self.meal = meal
        _quantity = State(initialValue: meal.items.count == 1 ? meal.items.first?.quantity : nil)
        _slot = State(initialValue: meal.slot)
    }

    private var isSingleFood: Bool { meal.items.count == 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(meal.nameSnapshot)
                        .font(AppFont.titleMedium)
                    Text(entrySummary)
                        .font(AppFont.subheadline)
                        .foregroundStyle(Color.trameSubdued)
                }

                Section("Entry") {
                    if isSingleFood {
                        Picker("Meal", selection: $slot) {
                            ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        LabeledContent("Quantity") {
                            DecimalField("Quantity", value: $quantity, range: 0.25...20)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 72)
                                .accessibilityIdentifier("logged-meal-quantity")
                        }
                        LabeledContent("Serving", value: singleItem?.servingNameSnapshot ?? "Unknown")
                        LabeledContent("Amount", value: correctedAmountDescription)
                    }
                }

                Section {
                    Button("Repeat today", systemImage: AppIcon.repeatingPlan) {
                        showsRepeatSheet = true
                    }
                    .accessibilityIdentifier("repeat-logged-meal")
                    Button("Delete entry", systemImage: AppIcon.trash, role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("delete-logged-meal")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.trameCanvas)
            .navigationTitle("Food entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if isSingleFood {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let quantity,
                                  NutritionLoggingService.updateSingleFoodMeal(meal, quantity: quantity, slot: slot, using: modelContext)
                            else {
                                showsSaveError = true
                                return
                            }
                            dismiss()
                        }
                        .disabled((0.25...20).contains(quantity ?? 0) == false)
                        .accessibilityIdentifier("save-logged-meal")
                    }
                }
            }
            .confirmationDialog("Delete this food entry?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete entry", role: .destructive) {
                    if NutritionLoggingService.delete(meal, using: modelContext) {
                        dismiss()
                    } else {
                        showsSaveError = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes it from today’s totals. This cannot be undone.")
            }
            .sheet(isPresented: $showsRepeatSheet) {
                RepeatMealSheet(meal: meal)
            }
            .alert("Entry wasn’t saved", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your original entry is unchanged. Try again.")
            }
        }
    }

    private var singleItem: LoggedMealItem? {
        isSingleFood ? meal.items.first : nil
    }

    private var correctedAmountDescription: String {
        guard let item = singleItem, let quantity else { return "Unknown" }
        let amount = FoodLibraryService.format(quantity * item.portionAmountSnapshot)
        switch item.portionUnit {
        case .grams: return "\(amount) g"
        case .milliliters: return "\(amount) mL"
        case .count, .serving: return "\(FoodLibraryService.format(quantity)) × \(item.servingNameSnapshot)"
        }
    }

    private var entrySummary: String {
        let items = meal.orderedItems
        return "\(summary(values: items.map(\.caloriesSnapshot), unit: "kcal", unknown: "Calories unknown")) · \(summary(values: items.map(\.proteinGramsSnapshot), unit: "g protein", unknown: "Protein unknown"))"
    }

    private func summary(values: [Double?], unit: String, unknown: String) -> String {
        let known = values.compactMap { $0 }
        guard known.isEmpty == false else { return unknown }
        let suffix = known.count == values.count ? "" : " + unknown"
        return "\(FoodLibraryService.format(known.reduce(0, +))) \(unit)\(suffix)"
    }
}
