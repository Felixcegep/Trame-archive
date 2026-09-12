import SwiftData
import SwiftUI

struct NutritionCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDay: LocalDay
    @Query(filter: #Predicate<FoodItem> { !$0.isArchived }, sort: \FoodItem.name)
    private var foods: [FoodItem]
    @Query(
        filter: #Predicate<NutritionTarget> { !$0.isArchived },
        sort: \NutritionTarget.effectiveStartDayKey,
        order: .reverse
    ) private var targets: [NutritionTarget]
    @Query(filter: #Predicate<PlanRun> { $0.endDate == nil }) private var planRuns: [PlanRun]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var allMeals: [LoggedMeal]
    @State private var selectedFood: FoodItem?
    @State private var prefilledRecent: NutritionRecentEntry?
    @State private var selectedLoggedMeal: LoggedMeal?
    @State private var isShowingCaffeineLog = false
    @State private var isShowingQuickAdd = false
    @State private var isShowingPhotoEstimate = false
    @State private var addSlot: MealSlot = .suggested()
    @State private var showsCopyYesterday = false
    private let featureFlags: FeatureFlagConfiguration = FeatureFlags.current

    var body: some View {
        let dayMeals = allMeals.filter { $0.dayKey == selectedDay.rawValue }
        let daySummary = NutritionDaySummary.resolve(day: selectedDay, meals: dayMeals)
        let resolvedTarget = NutritionTargetResolver.resolve(day: selectedDay, planRuns: planRuns, targets: targets)
        let recents = NutritionRecentFoods.ranked(foods: foods, meals: allMeals)
        let favorites = Array(foods.filter(\.isFavorite).prefix(NutritionRecentFoods.favoriteLimit))
        let recentWithoutFavorites = recents.filter { food in favorites.contains { $0.id == food.food.id } == false }

        List {
            Section {
                dayStrip
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                NutritionTotalsView(totals: daySummary.totals, target: resolvedTarget.values, dayKind: resolvedTarget.kind)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                    .accessibilityIdentifier("nutrition-today-totals")
            } header: {
                Text("\(selectedDay.displayName()) · \(resolvedTarget.kind.displayName)")
            } footer: {
                if daySummary.totals.hasUnknownValues {
                    Text("Known totals exclude foods with missing nutrients. Unknown values are never treated as zero.")
                }
            }

            Section("Log food") {
                NavigationLink(value: NutritionRoute.foodLibrary) {
                    Label("Find food", systemImage: AppIcon.nutrition)
                }
                .accessibilityIdentifier("open-food-library")
                Button {
                    addSlot = MealSlot.suggested()
                    isShowingQuickAdd = true
                } label: {
                    Label("Quick add", systemImage: AppIcon.plus)
                }
                .accessibilityIdentifier("open-quick-add")
                if featureFlags.isMealPhotoAnalysisAvailable {
                    Button {
                        addSlot = MealSlot.suggested()
                        isShowingPhotoEstimate = true
                    } label: {
                        Label("Estimate from photo", systemImage: AppIcon.photoEstimate)
                    }
                    .accessibilityIdentifier("open-photo-estimate")
                }
                Button {
                    isShowingCaffeineLog = true
                } label: {
                    Label("Log caffeine", systemImage: AppIcon.caffeine)
                }
                .accessibilityIdentifier("open-caffeine-log")
                if yesterdayMeals.isEmpty == false {
                    Button {
                        showsCopyYesterday = true
                    } label: {
                        Label("Copy yesterday", systemImage: AppIcon.copy)
                    }
                    .accessibilityIdentifier("copy-yesterday")
                }
                if recents.isEmpty && favorites.isEmpty {
                    ContentUnavailableView(
                        "Nothing logged yet",
                        systemImage: AppIcon.nutrition,
                        description: Text("Foods you log or mark as a favorite appear here for one-tap logging. Find food to add your first one.")
                    )
                } else {
                    if favorites.isEmpty == false {
                        ForEach(favorites) { food in
                            foodLogButton(food, detail: "Favorite", recent: recents.first { $0.food.id == food.id })
                        }
                    }
                    if recentWithoutFavorites.isEmpty == false {
                        ForEach(recentWithoutFavorites) { entry in
                            foodLogButton(entry.food, detail: recentDetail(entry), recent: entry)
                        }
                    }
                }
            }

            ForEach(MealSlot.allCases, id: \.self) { slot in
                let slotMeals = daySummary.meals.filter { $0.slot == slot }
                let yesterdaySlotMeals = yesterdayMeals.filter { $0.slot == slot }
                Section {
                    if slotMeals.isEmpty {
                        Text("Nothing yet")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    } else {
                        ForEach(slotMeals) { meal in
                            mealRow(meal)
                        }
                    }
                    Button {
                        addSlot = slot
                        isShowingQuickAdd = true
                    } label: {
                        Label("Add", systemImage: AppIcon.plus)
                    }
                    .accessibilityIdentifier("add-slot-\(slot.rawValue)")
                    if slotMeals.isEmpty, yesterdaySlotMeals.isEmpty == false {
                        Button {
                            _ = NutritionLoggingService.copyMeals(
                                yesterdaySlotMeals,
                                to: selectedDay,
                                using: modelContext
                            )
                        } label: {
                            Label("Copy yesterday’s \(slot.displayName.lowercased())", systemImage: AppIcon.copy)
                        }
                        .accessibilityIdentifier("copy-slot-\(slot.rawValue)")
                    }
                } header: {
                    Text(slot.displayName)
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
        .environment(\.nutritionSelectedDay, selectedDay)
        .sheet(isPresented: $isShowingCaffeineLog) {
            CaffeineQuickLogSheet(day: selectedDay)
        }
        .sheet(isPresented: $isShowingQuickAdd) {
            NutritionQuickAddView(initialSlot: addSlot)
                .environment(\.nutritionSelectedDay, selectedDay)
        }
        .sheet(isPresented: $isShowingPhotoEstimate) {
            MealPhotoEstimateView(initialSlot: addSlot)
                .environment(\.nutritionSelectedDay, selectedDay)
        }
        .onAppear {
            if UITestMealPhotoEstimateResult.launchOverride != nil {
                isShowingPhotoEstimate = true
            }
        }
        .sheet(item: $selectedFood) { food in
            FoodQuickLogView(
                food: food,
                initialQuantity: prefilledRecent?.lastQuantity,
                initialSlot: prefilledRecent?.lastSlot ?? addSlot
            )
            .environment(\.nutritionSelectedDay, selectedDay)
        }
        .sheet(item: $selectedLoggedMeal) { meal in
            LoggedMealDetailSheet(meal: meal, day: selectedDay)
        }
        .confirmationDialog(
            "Copy \(yesterdayMeals.count) meal\(yesterdayMeals.count == 1 ? "" : "s") from yesterday?",
            isPresented: $showsCopyYesterday,
            titleVisibility: .visible
        ) {
            Button("Copy yesterday") {
                _ = NutritionLoggingService.copyMeals(yesterdayMeals, to: selectedDay, using: modelContext)
            }
            .accessibilityIdentifier("confirm-copy-yesterday")
            Button("Cancel", role: .cancel) {}
        }
    }

    private var yesterdayMeals: [LoggedMeal] {
        let key = selectedDay.adding(days: -1).rawValue
        return allMeals.filter { $0.dayKey == key }
    }

    private var dayStrip: some View {
        HStack {
            Button {
                selectedDay = selectedDay.adding(days: -1)
            } label: {
                Image(systemName: AppIcon.chevronLeft)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
            }
            .accessibilityLabel("Previous day")
            .accessibilityIdentifier("nutrition-previous-day")
            Spacer()
            Button {
                selectedDay = .today
            } label: {
                Text(selectedDay.displayName())
                    .font(AppFont.subheadlineSemibold)
                    .foregroundStyle(Color.trameText)
            }
            .accessibilityLabel("Selected day \(selectedDay.displayName())")
            .accessibilityIdentifier("nutrition-selected-day")
            Spacer()
            Button {
                selectedDay = selectedDay.adding(days: 1)
            } label: {
                Image(systemName: AppIcon.chevronRight)
                    .frame(width: ComponentSize.minimumTouchTarget, height: ComponentSize.minimumTouchTarget)
            }
            .accessibilityLabel("Next day")
            .accessibilityIdentifier("nutrition-next-day")
        }
    }

    private func recentDetail(_ entry: NutritionRecentEntry) -> String {
        let amount = FoodLibraryService.amountDescription(portion: entry.lastPortion, quantity: entry.lastQuantity)
        return "\(entry.logCount)× · last \(amount)"
    }

    private func foodLogButton(_ food: FoodItem, detail: String, recent: NutritionRecentEntry?) -> some View {
        Button {
            if let recent {
                _ = NutritionLoggingService.log(
                    food: food,
                    portion: recent.lastPortion,
                    quantity: recent.lastQuantity,
                    day: selectedDay,
                    slot: recent.lastSlot,
                    using: modelContext
                )
            } else {
                prefilledRecent = nil
                addSlot = MealSlot.suggested()
                selectedFood = food
            }
        } label: {
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
        .accessibilityHint(recent == nil ? "Opens portion editor" : "Logs the last amount. Touch and hold to edit first.")
        .accessibilityIdentifier("quick-log-food-\(food.id)")
        .contextMenu {
            Button("Adjust") {
                prefilledRecent = recent
                addSlot = recent?.lastSlot ?? .suggested()
                selectedFood = food
            }
        }
    }

    private func mealRow(_ meal: LoggedMeal) -> some View {
        Button {
            selectedLoggedMeal = meal
        } label: {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(meal.loggedAt.formatted(date: .omitted, time: .shortened))
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
    var day: LocalDay
    @State private var quantity: Double?
    @State private var amount: Double?
    @State private var scale: Double? = 1
    @State private var slot: MealSlot
    @State private var showsDeleteConfirmation = false
    @State private var showsRepeatSheet = false
    @State private var showsSaveError = false

    init(meal: LoggedMeal, day: LocalDay) {
        self.meal = meal
        self.day = day
        _slot = State(initialValue: meal.slot)
        if meal.items.count == 1, let item = meal.items.first {
            _quantity = State(initialValue: item.quantity)
            _amount = State(initialValue: NutritionLogQuantity.displayedAmount(
                quantity: item.quantity,
                portion: FoodPortion(
                    id: nil,
                    name: item.servingNameSnapshot,
                    amount: item.portionAmountSnapshot,
                    unit: item.portionUnit,
                    equivalentReferenceAmount: item.portionAmountSnapshot
                )
            ))
        }
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
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if isSingleFood, let item = singleItem {
                        let portion = FoodPortion(
                            id: nil,
                            name: item.servingNameSnapshot,
                            amount: item.portionAmountSnapshot,
                            unit: item.portionUnit,
                            equivalentReferenceAmount: item.portionAmountSnapshot
                        )
                        LabeledContent(NutritionLogQuantity.amountFieldTitle(for: portion)) {
                            DecimalField(
                                LocalizedStringKey(NutritionLogQuantity.amountFieldTitle(for: portion)),
                                value: $amount,
                                range: NutritionLogQuantity.amountRange(for: portion)
                            )
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72)
                            .accessibilityIdentifier("logged-meal-quantity")
                        }
                        LabeledContent("Serving", value: item.servingNameSnapshot)
                    } else {
                        LabeledContent("Scale") {
                            DecimalField("Scale", value: $scale, range: 0.05...10)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 72)
                                .accessibilityIdentifier("logged-meal-scale")
                        }
                        Text("\(meal.items.count) ingredients. Scale keeps snapshotted ratios.")
                            .font(AppFont.caption)
                            .foregroundStyle(Color.trameSubdued)
                    }
                }

                Section {
                    Button("Repeat on this day", systemImage: AppIcon.repeatingPlan) {
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("save-logged-meal")
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
                Text("This removes it from the day’s totals. This cannot be undone.")
            }
            .sheet(isPresented: $showsRepeatSheet) {
                RepeatMealSheet(meal: meal, day: day)
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

    private var entrySummary: String {
        let items = meal.orderedItems
        return "\(summary(values: items.map(\.caloriesSnapshot), unit: "kcal", unknown: "Calories unknown")) · \(summary(values: items.map(\.proteinGramsSnapshot), unit: "g protein", unknown: "Protein unknown"))"
    }

    private func save() {
        if isSingleFood, let item = singleItem, let amount {
            let portion = FoodPortion(
                id: nil,
                name: item.servingNameSnapshot,
                amount: item.portionAmountSnapshot,
                unit: item.portionUnit,
                equivalentReferenceAmount: item.portionAmountSnapshot
            )
            let quantity = NutritionLogQuantity.quantity(amount: amount, portion: portion)
            guard NutritionLoggingService.updateSingleFoodMeal(meal, quantity: quantity, slot: slot, using: modelContext) else {
                showsSaveError = true
                return
            }
            dismiss()
            return
        }
        guard let scale, NutritionLoggingService.rescaleMeal(meal, factor: scale, slot: slot, using: modelContext) else {
            showsSaveError = true
            return
        }
        dismiss()
    }

    private func summary(values: [Double?], unit: String, unknown: String) -> String {
        let known = values.compactMap { $0 }
        guard known.isEmpty == false else { return unknown }
        let suffix = known.count == values.count ? "" : " + unknown"
        return "\(FoodLibraryService.format(known.reduce(0, +))) \(unit)\(suffix)"
    }
}
