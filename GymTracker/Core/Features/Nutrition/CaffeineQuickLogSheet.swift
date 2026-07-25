import SwiftData
import SwiftUI

enum CaffeineSource: String, CaseIterable, Identifiable {
    case coffee
    case preWorkout
    case tea
    case energyDrink
    case other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .coffee: "Coffee"
        case .preWorkout: "Pre-workout"
        case .tea: "Tea"
        case .energyDrink: "Energy drink"
        case .other: "Other"
        }
    }
    var emoji: String {
        switch self {
        case .coffee: "☕️"
        case .preWorkout: "⚡️"
        case .tea: "🍵"
        case .energyDrink: "🥤"
        case .other: "➕"
        }
    }
}

enum CaffeineDrinkPreset: String, CaseIterable, Identifiable {
    case espresso
    case brewed
    case coldBrew
    case latte

    var id: String { rawValue }
    var title: String {
        switch self {
        case .espresso: "Espresso"
        case .brewed: "Brewed"
        case .coldBrew: "Cold brew"
        case .latte: "Latte"
        }
    }
    var emoji: String {
        switch self {
        case .espresso: "☕️"
        case .brewed: "☕️"
        case .coldBrew: "🧋"
        case .latte: "🥛"
        }
    }
    var mediumMilligrams: Double {
        caffeineMilligrams(for: .medium)
    }
    func caffeineMilligrams(for size: CaffeineDrinkSize) -> Double {
        switch (self, size) {
        case (.espresso, .small): 47
        case (.espresso, .medium): 94
        case (.espresso, .large): 141
        case (.brewed, .small): 95
        case (.brewed, .medium): 145
        case (.brewed, .large): 190
        case (.coldBrew, .small): 120
        case (.coldBrew, .medium): 180
        case (.coldBrew, .large): 240
        case (.latte, .small): 75
        case (.latte, .medium): 150
        case (.latte, .large): 225
        }
    }
    var foodName: String { "Coffee · \(title)" }
}

enum CaffeineDrinkSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TeaPreset: String, CaseIterable, Identifiable {
    case blackTea
    case greenTea
    case matcha

    var id: String { rawValue }
    var title: String {
        switch self {
        case .blackTea: "Black tea"
        case .greenTea: "Green tea"
        case .matcha: "Matcha"
        }
    }
    var emoji: String { "🍵" }
    var mediumMilligrams: Double {
        caffeineMilligrams(for: .medium)
    }
    func caffeineMilligrams(for size: CaffeineDrinkSize) -> Double {
        switch (self, size) {
        case (.blackTea, .small): 30
        case (.blackTea, .medium): 47
        case (.blackTea, .large): 65
        case (.greenTea, .small): 18
        case (.greenTea, .medium): 28
        case (.greenTea, .large): 40
        case (.matcha, .small): 45
        case (.matcha, .medium): 70
        case (.matcha, .large): 100
        }
    }
    var foodName: String { "Tea · \(title)" }
}

private let energyDrinkFoodName = "Energy drink"

private func energyDrinkMilligrams(for size: CaffeineDrinkSize) -> Double {
    switch size {
    case .small: 80
    case .medium: 114
    case .large: 160
    }
}

enum PreWorkoutIntensity: String, CaseIterable, Identifiable {
    case stimulantFree
    case light
    case moderate
    case high
    case veryHigh
    case custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .stimulantFree: "Stimulant-free"
        case .light: "Light"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very high"
        case .custom: "Custom"
        }
    }
    var rangeDescription: String {
        switch self {
        case .stimulantFree: "0 mg"
        case .light: "1–99 mg"
        case .moderate: "100–199 mg"
        case .high: "200–299 mg"
        case .veryHigh: "300 mg or more"
        case .custom: "Enter the exact label value"
        }
    }
    /// Representative logging estimate for this band; nil for `.custom`, which requires an exact value.
    var estimatedMilligrams: Double? {
        switch self {
        case .stimulantFree: 0
        case .light: 50
        case .moderate: 150
        case .high: 250
        case .veryHigh: 350
        case .custom: nil
        }
    }
    var foodName: String { "Pre-workout · \(title)" }
}

struct CaffeineQuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var foods: [FoodItem]
    @Query(sort: \LoggedMeal.loggedAt, order: .reverse) private var loggedMeals: [LoggedMeal]
    @Query(sort: \BodyWeightEntry.measuredAt, order: .reverse) private var bodyWeightEntries: [BodyWeightEntry]
    @AppStorage(DefaultsKey.caffeineBirthdateTimestamp) private var caffeineBirthdateTimestamp: Double?

    @State private var source: CaffeineSource = .coffee
    @State private var drink: CaffeineDrinkPreset = .brewed
    @State private var size: CaffeineDrinkSize = .medium
    @State private var teaPreset: TeaPreset = .blackTea
    @State private var preWorkoutIntensity: PreWorkoutIntensity = .moderate
    @State private var otherName = ""
    @State private var exactMilligramsText = ""
    @State private var npnText = ""
    @State private var errorMessage: String?

    private var birthdate: Date? {
        caffeineBirthdateTimestamp.map { Date(timeIntervalSince1970: $0) }
    }
    private var ageBand: CaffeineAgeBand {
        CaffeineGuidance.ageBand(birthdate: birthdate)
    }
    private var dailyLimit: CaffeineDailyLimit {
        CaffeineGuidance.dailyLimit(ageBand: ageBand, bodyWeightKilograms: bodyWeightEntries.first.map { Double($0.kilograms) })
    }
    private var loggedTodayMilligrams: Double {
        NutritionDaySummary.resolve(day: .today, meals: loggedMeals).totals.caffeineMilligrams
    }

    private var exactMilligrams: Double? {
        let trimmed = exactMilligramsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    private var estimatedMilligrams: Double {
        switch source {
        case .coffee:
            let base = foods.first(where: { $0.name == drink.foodName })?.caffeineMilligrams ?? drink.mediumMilligrams
            return scaled(base: base, defaultMedium: drink.mediumMilligrams, defaultSizeValue: drink.caffeineMilligrams(for: size))
        case .tea:
            let base = foods.first(where: { $0.name == teaPreset.foodName })?.caffeineMilligrams ?? teaPreset.mediumMilligrams
            return scaled(base: base, defaultMedium: teaPreset.mediumMilligrams, defaultSizeValue: teaPreset.caffeineMilligrams(for: size))
        case .energyDrink:
            let base = foods.first(where: { $0.name == energyDrinkFoodName })?.caffeineMilligrams ?? energyDrinkMilligrams(for: .medium)
            return scaled(base: base, defaultMedium: energyDrinkMilligrams(for: .medium), defaultSizeValue: energyDrinkMilligrams(for: size))
        case .preWorkout:
            if preWorkoutIntensity == .custom {
                return exactMilligrams ?? 0
            }
            return foods.first(where: { $0.name == preWorkoutIntensity.foodName })?.caffeineMilligrams ?? (preWorkoutIntensity.estimatedMilligrams ?? 0)
        case .other:
            return exactMilligrams ?? 0
        }
    }

    private func scaled(base: Double, defaultMedium: Double, defaultSizeValue: Double) -> Double {
        guard defaultMedium > 0 else { return base }
        return base * (defaultSizeValue / defaultMedium)
    }

    private var canLog: Bool {
        switch source {
        case .coffee, .tea, .energyDrink:
            return true
        case .preWorkout:
            return preWorkoutIntensity != .custom || exactMilligrams != nil
        case .other:
            return exactMilligrams != nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    sourcePicker
                    sourceContent
                    referenceCard
                    sourcesDisclosure
                }
                .padding(Spacing.xl)
            }
            .background(Color.gymBackground)
            .navigationTitle("Log caffeine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: logSelection)
                        .disabled(!canLog)
                        .accessibilityIdentifier("confirm-log-caffeine")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Couldn’t log caffeine", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Please try again.") }
    }

    // MARK: - Source picker

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "What kind of caffeine?", detail: "Choose the closest source. You can fine-tune amounts in the food library.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(CaffeineSource.allCases) { candidate in
                    Button {
                        source = candidate
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Text(candidate.emoji).font(AppFont.titleMedium)
                            Text(candidate.title).font(AppFont.captionBold).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Color.gymText)
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background(source == candidate ? Color.gymPrimarySurface : Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay { RoundedRectangle(cornerRadius: Radius.medium).stroke(source == candidate ? Color.gymPrimary : Color.gymBorder, lineWidth: 1) }
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityAddTraits(source == candidate ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Per-source content

    @ViewBuilder
    private var sourceContent: some View {
        switch source {
        case .coffee:
            drinkPresetPicker(title: "Coffee", presets: CaffeineDrinkPreset.allCases, selection: $drink) { $0.emoji } title: { $0.title }
            sizePicker
        case .tea:
            drinkPresetPicker(title: "Tea", presets: TeaPreset.allCases, selection: $teaPreset) { $0.emoji } title: { $0.title }
            sizePicker
        case .energyDrink:
            sizePicker
        case .preWorkout:
            preWorkoutPicker
        case .other:
            otherEntry
        }
    }

    private func drinkPresetPicker<Preset: Identifiable & Hashable>(
        title: String,
        presets: [Preset],
        selection: Binding<Preset>,
        emoji: @escaping (Preset) -> String,
        title presetTitle: @escaping (Preset) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                ForEach(presets) { preset in
                    Button {
                        selection.wrappedValue = preset
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Text(emoji(preset)).font(AppFont.titleMedium)
                            Text(presetTitle(preset)).font(AppFont.captionBold).lineLimit(1)
                        }
                        .foregroundStyle(Color.gymText)
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background(selection.wrappedValue == preset ? Color.gymPrimarySurface : Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay { RoundedRectangle(cornerRadius: Radius.medium).stroke(selection.wrappedValue == preset ? Color.gymPrimary : Color.gymBorder, lineWidth: 1) }
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityAddTraits(selection.wrappedValue == preset ? .isSelected : [])
                }
            }
        }
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Size").font(AppFont.headline)
            Picker("Size", selection: $size) {
                ForEach(CaffeineDrinkSize.allCases) { size in Text(size.title).tag(size) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var preWorkoutPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "How strong?", detail: "Based on caffeine per serving, not the product name.")
            VStack(spacing: Spacing.s) {
                ForEach(PreWorkoutIntensity.allCases) { intensity in
                    Button {
                        preWorkoutIntensity = intensity
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(intensity.title).font(AppFont.headline).foregroundStyle(Color.gymText)
                                Text(intensity.rangeDescription).font(AppFont.caption).foregroundStyle(Color.gymSubduedText)
                            }
                            Spacer()
                            if preWorkoutIntensity == intensity {
                                Image(systemName: AppIcon.checkmarkCircle).foregroundStyle(Color.gymPrimary)
                            }
                        }
                        .padding(Spacing.m)
                        .background(preWorkoutIntensity == intensity ? Color.gymPrimarySurface : Color.gymCard, in: RoundedRectangle(cornerRadius: Radius.medium))
                        .overlay { RoundedRectangle(cornerRadius: Radius.medium).stroke(preWorkoutIntensity == intensity ? Color.gymPrimary : Color.gymBorder, lineWidth: 1) }
                    }
                    .buttonStyle(.gymPress)
                    .accessibilityAddTraits(preWorkoutIntensity == intensity ? .isSelected : [])
                }
            }
            if preWorkoutIntensity == .custom {
                TextField("Caffeine (mg)", text: $exactMilligramsText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("caffeine-preworkout-exact-mg")
                TextField("NPN (optional, Canadian products)", text: $npnText)
                    .textFieldStyle(.roundedBorder)
            }
            if let minorNotice {
                Text(minorNotice)
                    .font(AppFont.caption)
                    .foregroundStyle(Color.gymSubduedText)
            }
        }
    }

    private var minorNotice: String? {
        guard source == .preWorkout else { return nil }
        switch ageBand {
        case .teen where preWorkoutIntensity != .stimulantFree:
            return "This serving contains \(FoodLibraryService.format(estimatedMilligrams)) mg of caffeine and may exceed your daily reference amount. Pre-workout supplements are not recommended for minors without guidance from a healthcare professional."
        case .child:
            return "Pre-workout and caffeinated supplements aren't recommended under age 14. You can still log this for reference."
        default:
            return nil
        }
    }

    private var otherEntry: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            GymSectionHeader(title: "What did you have?", detail: "Log any other caffeine source with its exact amount.")
            TextField("Name (optional)", text: $otherName)
                .textFieldStyle(.roundedBorder)
            TextField("Caffeine (mg)", text: $exactMilligramsText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("caffeine-other-exact-mg")
            TextField("NPN (optional, Canadian products)", text: $npnText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Reference card

    private var referenceCard: some View {
        GymCard(variant: .accent) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Estimated caffeine").font(AppFont.captionBold).foregroundStyle(Color.gymSubduedText)
                    GymMetricValue(value: FoodLibraryService.format(estimatedMilligrams), unit: "mg", isEstimate: true)
                }
                Spacer()
                Text(source.emoji).font(AppFont.displayMedium)
            }
            referenceLine
                .font(AppFont.caption)
                .foregroundStyle(referenceIsOverLimit ? Color.gymDestructive : Color.gymSubduedText)
        }
    }

    private var referenceIsOverLimit: Bool {
        guard case .milligrams(let mg, _) = dailyLimit else { return false }
        return (loggedTodayMilligrams + estimatedMilligrams) > mg
    }

    private var referenceLine: Text {
        let projected = loggedTodayMilligrams + estimatedMilligrams
        switch dailyLimit {
        case .milligrams(let mg, _):
            let isOver = projected > mg
            let isNear = !isOver && mg > 0 && projected >= mg * 0.8
            var suffix = ""
            if isOver { suffix = " · Over daily reference" } else if isNear { suffix = " · Near daily reference" }
            return Text("This brings today to \(FoodLibraryService.format(projected)) mg of \(FoodLibraryService.format(mg)) mg reference\(suffix)")
        case .needsBodyWeight:
            return Text("Today: \(FoodLibraryService.format(projected)) mg · Add your weight in Settings for a personalized teen reference")
        case .notRecommended:
            return Text("Today: \(FoodLibraryService.format(projected)) mg · Daily reference not available under age 14")
        }
    }

    private var sourcesDisclosure: some View {
        DisclosureGroup("Sources") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("FDA: up to 400 mg/day is generally not associated with negative effects for healthy adults.")
                Text("Health Canada: recommends no more than 2.5 mg/kg body weight per day for children and adolescents.")
                Text("American Academy of Pediatrics: recommends minors avoid caffeine.")
                Text("NIH Office of Dietary Supplements: pre-workout effects and safety can't always be predicted from caffeine content alone.")
            }
            .font(AppFont.caption)
            .foregroundStyle(Color.gymSubtleText)
            .padding(.top, Spacing.xs)
        }
        .font(AppFont.caption)
        .foregroundStyle(Color.gymSubduedText)
        .tint(Color.gymSubduedText)
    }

    // MARK: - Logging

    private func logSelection() {
        switch source {
        case .coffee:
            logSizedPreset(name: drink.foodName, defaultMedium: drink.mediumMilligrams, defaultSizeValue: drink.caffeineMilligrams(for: size))
        case .tea:
            logSizedPreset(name: teaPreset.foodName, defaultMedium: teaPreset.mediumMilligrams, defaultSizeValue: teaPreset.caffeineMilligrams(for: size))
        case .energyDrink:
            logSizedPreset(name: energyDrinkFoodName, defaultMedium: energyDrinkMilligrams(for: .medium), defaultSizeValue: energyDrinkMilligrams(for: size))
        case .preWorkout:
            logPreWorkout()
        case .other:
            logOther()
        }
    }

    private func logSizedPreset(name: String, defaultMedium: Double, defaultSizeValue: Double) {
        if CaffeineLoggingService.logPreset(
            name: name,
            defaultMediumMilligrams: defaultMedium,
            sizedMilligrams: defaultSizeValue,
            sizeTitle: size.title,
            using: modelContext
        ) != nil {
            dismiss()
        } else {
            errorMessage = "Your selection is still here. Please try again."
        }
    }

    private func logPreWorkout() {
        let food: FoodItem
        if preWorkoutIntensity == .custom {
            guard let mg = exactMilligrams else { return }
            let trimmedNPN = npnText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = foods.first(where: { $0.name == preWorkoutIntensity.foodName }) {
                food = existing
                food.isArchived = false
                food.updatedAt = .now
            } else {
                food = FoodItem(
                    name: preWorkoutIntensity.foodName,
                    referenceAmount: 1,
                    referenceUnit: .serving,
                    sourceKind: .userCreated,
                    confidence: .userProvided,
                    preparationState: .cooked
                )
                modelContext.insert(food)
            }
            food.caffeineMilligrams = mg
            food.npn = trimmedNPN.isEmpty ? nil : trimmedNPN
        } else {
            if let existing = foods.first(where: { $0.name == preWorkoutIntensity.foodName }) {
                food = existing
                food.isArchived = false
                food.updatedAt = .now
            } else {
                food = FoodItem(
                    name: preWorkoutIntensity.foodName,
                    referenceAmount: 1,
                    referenceUnit: .serving,
                    caffeineMilligrams: preWorkoutIntensity.estimatedMilligrams,
                    sourceKind: .curated,
                    confidence: .estimated,
                    preparationState: .cooked
                )
                modelContext.insert(food)
            }
        }
        let portion = FoodPortion(id: nil, name: "Serving", amount: 1, unit: .serving, equivalentReferenceAmount: food.referenceAmount)
        complete(food: food, portion: portion)
    }

    private func logOther() {
        guard let mg = exactMilligrams else { return }
        let trimmedName = otherName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Other caffeine source" : trimmedName
        let trimmedNPN = npnText.trimmingCharacters(in: .whitespacesAndNewlines)
        let food: FoodItem
        if let existing = foods.first(where: { $0.name == name }) {
            food = existing
            food.isArchived = false
            food.updatedAt = .now
        } else {
            food = FoodItem(
                name: name,
                referenceAmount: 1,
                referenceUnit: .serving,
                sourceKind: .userCreated,
                confidence: .userProvided,
                preparationState: .cooked
            )
            modelContext.insert(food)
        }
        food.caffeineMilligrams = mg
        food.npn = trimmedNPN.isEmpty ? nil : trimmedNPN
        let portion = FoodPortion(id: nil, name: "Serving", amount: 1, unit: .serving, equivalentReferenceAmount: food.referenceAmount)
        complete(food: food, portion: portion)
    }

    private func complete(food: FoodItem, portion: FoodPortion) {
        if NutritionLoggingService.log(food: food, portion: portion, slot: .snack, using: modelContext) != nil {
            dismiss()
        } else {
            errorMessage = "Your selection is still here. Please try again."
        }
    }
}
