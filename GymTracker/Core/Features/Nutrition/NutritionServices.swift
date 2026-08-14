import Foundation
import SwiftData

enum RecipeLoggingBounds {
    static func gramsRange(yield: Double?) -> ClosedRange<Double> {
        0...max(0, yield ?? 100_000)
    }
}

struct FoodPortion: Hashable {
    let id: UUID?
    let name: String
    let amount: Double
    let unit: NutritionServingUnit
    let equivalentReferenceAmount: Double
}

struct NutritionDaySummary: Equatable {
    let day: LocalDay
    let meals: [LoggedMeal]
    let totals: NutritionMacroTotals

    static func resolve(day: LocalDay, meals: [LoggedMeal]) -> NutritionDaySummary {
        let dayMeals = meals.filter { $0.dayKey == day.rawValue }
        var totals = NutritionMacroTotals()
        for item in dayMeals.flatMap(\.orderedItems) {
            add(item.caloriesSnapshot, to: &totals.calories, unknown: &totals.unknownCaloriesCount)
            add(item.proteinGramsSnapshot, to: &totals.protein, unknown: &totals.unknownProteinCount)
            add(item.carbohydrateGramsSnapshot, to: &totals.carbohydrates, unknown: &totals.unknownCarbohydratesCount)
            add(item.fatGramsSnapshot, to: &totals.fat, unknown: &totals.unknownFatCount)
            // Caffeine is an optional beverage/food fact. Missing caffeine is
            // preserved as unknown rather than interpreted as zero.
            add(item.caffeineMilligramsSnapshot, to: &totals.caffeineMilligrams, unknown: &totals.unknownCaffeineCount)
        }
        return NutritionDaySummary(day: day, meals: dayMeals.sorted { $0.loggedAt > $1.loggedAt }, totals: totals)
    }

    private static func add(_ value: Double?, to total: inout Double, unknown: inout Int) {
        guard let value else { unknown += 1; return }
        total += value
    }
}

@MainActor
enum FoodLibraryService {
    static func portions(for food: FoodItem) -> [FoodPortion] {
        let saved = food.orderedServings.map {
            FoodPortion(id: $0.id, name: $0.name, amount: $0.amount, unit: $0.unit, equivalentReferenceAmount: $0.equivalentReferenceAmount)
        }
        if saved.isEmpty {
            return [FoodPortion(id: nil, name: "\(format(food.referenceAmount)) \(food.referenceUnit.displayName)", amount: food.referenceAmount, unit: food.referenceUnit, equivalentReferenceAmount: food.referenceAmount)]
        }
        return saved
    }

    static func archiveOrDelete(_ food: FoodItem, using context: ModelContext) throws {
        let foodID = food.id
        var historyDescriptor = FetchDescriptor<LoggedMealItem>(
            predicate: #Predicate { $0.sourceFoodID == foodID }
        )
        historyDescriptor.fetchLimit = 1
        let isReferencedByHistory = try context.fetch(historyDescriptor).isEmpty == false
        if isReferencedByHistory || food.mealTemplateItems.isEmpty == false {
            food.isArchived = true
            food.updatedAt = .now
        } else {
            context.delete(food)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func format(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// A concrete, human-readable amount for a portion at a given quantity —
    /// "80 g", "250 mL", "2 egg", "1 cup" — instead of an unexplained decimal
    /// number of servings. Mass/volume units use their symbol; count and named
    /// servings use the portion's own name.
    static func amountDescription(portion: FoodPortion, quantity: Double) -> String {
        let total = quantity * portion.amount
        switch portion.unit {
        case .grams:
            return "\(format(total)) g"
        case .milliliters:
            return "\(format(total)) mL"
        case .count, .serving:
            return "\(format(total)) \(portion.name)"
        }
    }

    /// The most meaningful default portion for a newly added food: the first
    /// saved serving if one exists, otherwise the reference-amount portion.
    static func defaultPortion(for food: FoodItem) -> FoodPortion {
        if let saved = food.orderedServings.first {
            return FoodPortion(
                id: saved.id,
                name: saved.name,
                amount: saved.amount,
                unit: saved.unit,
                equivalentReferenceAmount: saved.equivalentReferenceAmount
            )
        }
        return FoodPortion(
            id: nil,
            name: "\(format(food.referenceAmount)) \(food.referenceUnit.displayName)",
            amount: food.referenceAmount,
            unit: food.referenceUnit,
            equivalentReferenceAmount: food.referenceAmount
        )
    }
}

@MainActor
enum NutritionLoggingService {
    @discardableResult
    static func log(
        food: FoodItem,
        portion: FoodPortion? = nil,
        quantity: Double = 1,
        day: LocalDay? = nil,
        slot: MealSlot = .snack,
        loggedAt: Date = .now,
        using context: ModelContext
    ) -> LoggedMeal? {
        guard quantity > 0, food.isArchived == false else { return nil }
        let selected = portion ?? FoodLibraryService.defaultPortion(for: food)
        let meal = LoggedMeal(day: day ?? .today, slot: slot, loggedAt: loggedAt, nameSnapshot: food.name)
        meal.items = [snapshot(food: food, portion: selected, quantity: quantity, orderIndex: 0)]
        context.insert(meal)
        return save(meal, using: context) ? meal : nil
    }

    @discardableResult
    static func log(
        template: MealTemplate,
        fraction: Double = 1,
        day: LocalDay? = nil,
        slot: MealSlot = .snack,
        loggedAt: Date = .now,
        using context: ModelContext
    ) -> LoggedMeal? {
        guard fraction > 0, template.isArchived == false, template.isCurrent, template.orderedItems.isEmpty == false else { return nil }
        let meal = LoggedMeal(day: day ?? .today, slot: slot, loggedAt: loggedAt, nameSnapshot: template.name, sourceMealTemplateID: template.id, sourceMealTemplateName: template.name)
        meal.items = template.orderedItems.enumerated().compactMap { index, item in
            guard item.quantity > 0, item.food.isArchived == false else { return nil }
            let portions = FoodLibraryService.portions(for: item.food)
            let portion = portions.first { $0.id == item.servingID }
                ?? FoodLibraryService.defaultPortion(for: item.food)
            return snapshot(food: item.food, portion: portion, quantity: item.quantity * fraction, orderIndex: index)
        }
        guard meal.items.isEmpty == false else { return nil }
        context.insert(meal)
        return save(meal, using: context) ? meal : nil
    }

    @discardableResult
    static func repeatMeal(_ source: LoggedMeal, day: LocalDay? = nil, slot: MealSlot? = nil, using context: ModelContext) -> LoggedMeal? {
        let copied = LoggedMeal(day: day ?? .today, slot: slot ?? source.slot, nameSnapshot: source.nameSnapshot, sourceMealTemplateID: source.sourceMealTemplateID, sourceMealTemplateName: source.sourceMealTemplateName)
        copied.items = source.orderedItems.enumerated().map { index, item in
            LoggedMealItem(
                sourceFoodID: item.sourceFoodID,
                foodNameSnapshot: item.foodNameSnapshot,
                servingNameSnapshot: item.servingNameSnapshot,
                quantity: item.quantity,
                portionAmountSnapshot: item.portionAmountSnapshot,
                portionUnit: item.portionUnit,
                caloriesSnapshot: item.caloriesSnapshot,
                proteinGramsSnapshot: item.proteinGramsSnapshot,
                carbohydrateGramsSnapshot: item.carbohydrateGramsSnapshot,
                fatGramsSnapshot: item.fatGramsSnapshot,
                caffeineMilligramsSnapshot: item.caffeineMilligramsSnapshot,
                sourceKind: FoodSourceKind(rawValue: item.sourceKindRaw) ?? .userCreated,
                confidence: FoodConfidence(rawValue: item.confidenceRaw) ?? .userProvided,
                preparationState: FoodPreparationState(rawValue: item.preparationStateRaw) ?? .raw,
                orderIndex: index
            )
        }
        context.insert(copied)
        return save(copied, using: context) ? copied : nil
    }

    static func snapshot(food: FoodItem, portion: FoodPortion, quantity: Double, orderIndex: Int) -> LoggedMealItem {
        let multiplier = quantity * portion.equivalentReferenceAmount / food.referenceAmount
        return LoggedMealItem(
            sourceFoodID: food.id,
            foodNameSnapshot: food.name,
            servingNameSnapshot: portion.name,
            quantity: quantity,
            portionAmountSnapshot: portion.amount,
            portionUnit: portion.unit,
            caloriesSnapshot: food.calories.map { $0 * multiplier },
            proteinGramsSnapshot: food.proteinGrams.map { $0 * multiplier },
            carbohydrateGramsSnapshot: food.carbohydrateGrams.map { $0 * multiplier },
            fatGramsSnapshot: food.fatGrams.map { $0 * multiplier },
            caffeineMilligramsSnapshot: food.caffeineMilligrams.map { $0 * multiplier },
            sourceKind: food.sourceKind,
            confidence: food.confidence,
            preparationState: food.preparationState,
            orderIndex: orderIndex
        )
    }

    private static func save(_ meal: LoggedMeal, using context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            return false
        }
    }
}

/// Shared write path for a sized caffeine-preset log (coffee/tea/energy-drink
/// presets keyed by name). `CaffeineQuickLogSheet` and `LogCaffeineIntent`
/// both funnel through this so a shortcut-logged drink and a manually logged
/// one create or reuse the exact same `FoodItem`.
@MainActor
enum CaffeineLoggingService {
    @discardableResult
    static func logPreset(
        name: String,
        defaultMediumMilligrams: Double,
        sizedMilligrams: Double,
        sizeTitle: String,
        using context: ModelContext
    ) -> LoggedMeal? {
        let food = existingOrNewFood(name: name, defaultMediumMilligrams: defaultMediumMilligrams, using: context)
        let ratio = defaultMediumMilligrams > 0 ? (sizedMilligrams / defaultMediumMilligrams) : 1.0
        let portion = FoodPortion(
            id: nil,
            name: sizeTitle,
            amount: 1,
            unit: .serving,
            equivalentReferenceAmount: food.referenceAmount * ratio
        )
        return NutritionLoggingService.log(food: food, portion: portion, slot: .snack, using: context)
    }

    private static func existingOrNewFood(name: String, defaultMediumMilligrams: Double, using context: ModelContext) -> FoodItem {
        var descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.isArchived = false
            existing.updatedAt = .now
            return existing
        }
        let food = FoodItem(
            name: name,
            referenceAmount: 1,
            referenceUnit: .serving,
            caffeineMilligrams: defaultMediumMilligrams,
            sourceKind: .curated,
            confidence: .estimated,
            preparationState: .cooked
        )
        context.insert(food)
        return food
    }
}

@MainActor
enum MealTemplateService {
    @discardableResult
    static func revise(_ template: MealTemplate, name: String, preparationState: FoodPreparationState, finalCookedWeightGrams: Double?, photoIdentifier: String?, items: [(FoodItem, UUID?, Double)], using context: ModelContext) -> MealTemplate? {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, items.isEmpty == false else { return nil }
        template.isCurrent = false
        template.isArchived = true
        template.updatedAt = .now
        // The prior revision keeps its own photo reference, so a shared file is
        // never orphaned by revising.
        let revision = MealTemplate(name: name, preparationState: preparationState, finalCookedWeightGrams: finalCookedWeightGrams, photoIdentifier: photoIdentifier, lineageID: template.lineageID, version: template.version + 1)
        revision.items = items.enumerated().map { MealTemplateItem(food: $0.element.0, orderIndex: $0.offset, servingID: $0.element.1, quantity: $0.element.2) }
        context.insert(revision)
        do { try context.save(); return revision } catch { context.rollback(); return nil }
    }
}

/// Derives a recipe's calories and macros from its ingredients using the same
/// reference-amount math the logging snapshot uses, so the detail screen and a
/// logged meal always agree. `fraction` scales the whole recipe (½, ¼, …).
@MainActor
enum MealTemplateNutrition {
    static func totals(for template: MealTemplate, fraction: Double = 1) -> NutritionMacroTotals {
        var totals = NutritionMacroTotals()
        for item in template.orderedItems where item.food.isArchived == false && item.quantity > 0 {
            let portions = FoodLibraryService.portions(for: item.food)
            let portion = portions.first { $0.id == item.servingID } ?? portions[0]
            let multiplier = item.quantity * fraction * portion.equivalentReferenceAmount / item.food.referenceAmount
            add(item.food.calories.map { $0 * multiplier }, to: &totals.calories, unknown: &totals.unknownCaloriesCount)
            add(item.food.proteinGrams.map { $0 * multiplier }, to: &totals.protein, unknown: &totals.unknownProteinCount)
            add(item.food.carbohydrateGrams.map { $0 * multiplier }, to: &totals.carbohydrates, unknown: &totals.unknownCarbohydratesCount)
            add(item.food.fatGrams.map { $0 * multiplier }, to: &totals.fat, unknown: &totals.unknownFatCount)
        }
        return totals
    }

    private static func add(_ value: Double?, to total: inout Double, unknown: inout Int) {
        guard let value else { unknown += 1; return }
        total += value
    }
}

@MainActor
enum NutritionTargetResolver {
    static func dayKind(for day: LocalDay, planRuns: [PlanRun]) -> NutritionDayKind {
        let hasTraining = planRuns.contains { run in
            run.status == .active && run.workoutProgress.contains { progress in
                guard let scheduled = progress.scheduledDate else { return false }
                return LocalDay(date: scheduled) == day && progress.status != .skipped
            }
        }
        return hasTraining ? .training : .rest
    }

    static func resolve(day: LocalDay, planRuns: [PlanRun], targets: [NutritionTarget]) -> (target: NutritionTarget?, kind: NutritionDayKind, values: NutritionTargetValues) {
        let kind = dayKind(for: day, planRuns: planRuns)
        let target = targets
            .filter { target in
                target.isArchived == false && target.effectiveStartDayKey <= day.rawValue && (target.effectiveEndDayKey.map { $0 >= day.rawValue } ?? true)
            }
            .sorted { lhs, rhs in
                lhs.effectiveStartDayKey == rhs.effectiveStartDayKey ? lhs.updatedAt > rhs.updatedAt : lhs.effectiveStartDayKey > rhs.effectiveStartDayKey
            }
            .first
        return (target, kind, target?.values(for: kind) ?? .empty)
    }
}

@MainActor
enum NutritionTargetService {
    /// Target prescriptions are effective-dated. Editing a phase creates a
    /// future revision and closes the earlier range instead of changing how a
    /// previously logged day is interpreted.
    @discardableResult
    static func revise(
        _ target: NutritionTarget,
        phase: NutritionGoalPhase,
        requestedStartDay: LocalDay,
        requestedEndDay: LocalDay?,
        training: NutritionTargetValues,
        rest: NutritionTargetValues,
        using context: ModelContext
    ) -> NutritionTarget? {
        let today = LocalDay.today
        if target.effectiveStartDayKey > today.rawValue {
            let startDay = max(requestedStartDay, today)
            guard requestedEndDay.map({ $0 >= startDay }) ?? true else { return nil }
            target.phase = phase
            target.effectiveStartDayKey = startDay.rawValue
            target.effectiveEndDayKey = requestedEndDay?.rawValue
            target.trainingCalories = training.calories
            target.trainingProteinGrams = training.protein
            target.trainingCarbohydrateGrams = training.carbohydrates
            target.trainingFatGrams = training.fat
            target.restCalories = rest.calories
            target.restProteinGrams = rest.protein
            target.restCarbohydrateGrams = rest.carbohydrates
            target.restFatGrams = rest.fat
            target.updatedAt = .now
            do { try context.save(); return target } catch { context.rollback(); return nil }
        }

        let startDay = max(requestedStartDay, nextDay(after: today))
        guard requestedEndDay.map({ $0 >= startDay }) ?? true else { return nil }
        target.effectiveEndDayKey = previousDay(before: startDay).rawValue
        target.updatedAt = .now
        let revision = NutritionTarget(
            phase: phase,
            effectiveStartDay: startDay,
            effectiveEndDay: requestedEndDay,
            training: training,
            rest: rest
        )
        context.insert(revision)
        do { try context.save(); return revision } catch { context.rollback(); return nil }
    }

    private static func previousDay(before day: LocalDay) -> LocalDay {
        shifted(day, by: -1)
    }

    private static func nextDay(after day: LocalDay) -> LocalDay {
        shifted(day, by: 1)
    }

    private static func shifted(_ day: LocalDay, by offset: Int) -> LocalDay {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day.rawValue),
              let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: date) else {
            return day
        }
        return LocalDay(date: shifted, calendar: Calendar(identifier: .gregorian))
    }
}
