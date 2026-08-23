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
                                        .foregroundStyle(Color.trameSubdued)
                                    Text(meal.nameSnapshot)
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(Color.trameText)
                                }
                                Spacer()
                                Text(mealMacroDescription(meal))
                                    .font(AppFont.subheadlineSemiboldMonospaced)
                                    .foregroundStyle(Color.trameText)
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
        .background(Color.trameCanvas)
        .tint(Color.trameAction)
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
        let calories = meal.orderedItems.compactMap(\.caloriesSnapshot).reduce(0, +)
        return "\(FoodLibraryService.format(calories)) kcal"
    }

    private func foodMacroDescription(_ food: FoodItem) -> String {
        let energy = food.calories.map { "\(FoodLibraryService.format($0)) kcal" } ?? "Calories unknown"
        let protein = food.proteinGrams.map { "\(FoodLibraryService.format($0))g protein" } ?? "protein unknown"
        return "\(energy) · \(protein)"
    }
}
