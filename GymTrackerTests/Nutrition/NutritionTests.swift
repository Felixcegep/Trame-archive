import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class NutritionTests: XCTestCase {
    func testMealSlotSuggestionMatchesOrdinaryMealTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        func date(hour: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: hour)))
        }

        XCTAssertEqual(MealSlot.suggested(at: try date(hour: 8), calendar: calendar), .breakfast)
        XCTAssertEqual(MealSlot.suggested(at: try date(hour: 12), calendar: calendar), .lunch)
        XCTAssertEqual(MealSlot.suggested(at: try date(hour: 18), calendar: calendar), .dinner)
        XCTAssertEqual(MealSlot.suggested(at: try date(hour: 23), calendar: calendar), .snack)
    }

    func testReferencePortionUsesFormattedAmountAndUnitAsItsName() {
        let food = FoodItem(
            name: "Rice",
            referenceAmount: 100,
            referenceUnit: .grams,
            calories: 130
        )

        let portion = FoodLibraryService.defaultPortion(for: food)

        XCTAssertEqual(portion.name, "100 g")
        XCTAssertEqual(portion.amount, 100)
        XCTAssertEqual(portion.unit, .grams)
    }

    func testRecipeLoggingBoundsNeverCreatesAnInvalidRangeForCorruptYield() {
        XCTAssertEqual(RecipeLoggingBounds.gramsRange(yield: -25), 0...0)
        XCTAssertEqual(RecipeLoggingBounds.gramsRange(yield: nil), 0...100_000)
        XCTAssertEqual(RecipeLoggingBounds.gramsRange(yield: 500), 0...500)
    }

    func testFoodEditsDoNotRewriteLoggedMealSnapshotOrDailyTotals() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Yogurt", calories: 100, proteinGrams: 18, carbohydrateGrams: 8, fatGrams: 1)
        context.insert(food)
        try context.save()

        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))
        let item = try XCTUnwrap(meal.items.first)
        XCTAssertEqual(item.caloriesSnapshot, 100)
        XCTAssertEqual(item.proteinGramsSnapshot, 18)

        food.name = "Edited yogurt"
        food.calories = 420
        food.proteinGrams = 2
        food.isArchived = true
        try context.save()

        let summary = NutritionDaySummary.resolve(day: .today, meals: [meal])
        XCTAssertEqual(item.foodNameSnapshot, "Yogurt")
        XCTAssertEqual(summary.totals.calories, 100)
        XCTAssertEqual(summary.totals.protein, 18)
    }

    func testUnknownNutrientsAreNotInterpretedAsZeroCompleteness() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Estimate", calories: 200, proteinGrams: nil, carbohydrateGrams: 20, fatGrams: nil, confidence: .estimated)
        context.insert(food)
        try context.save()
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))

        let summary = NutritionDaySummary.resolve(day: .today, meals: [meal])
        XCTAssertEqual(summary.totals.calories, 200)
        XCTAssertEqual(summary.totals.protein, 0)
        XCTAssertEqual(summary.totals.unknownProteinCount, 1)
        XCTAssertEqual(summary.totals.unknownFatCount, 1)
        XCTAssertTrue(summary.totals.hasUnknownValues)
    }

    func testCaffeineIsSnapshottedScaledAndDerivedFromNutritionTruth() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let coffee = FoodItem(
            name: "Coffee",
            referenceAmount: 1,
            referenceUnit: .serving,
            caffeineMilligrams: 100,
            sourceKind: .curated,
            confidence: .estimated,
            preparationState: .cooked
        )
        context.insert(coffee)
        try context.save()

        let large = FoodPortion(id: nil, name: "Large", amount: 1, unit: .serving, equivalentReferenceAmount: 1.5)
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: coffee, portion: large, using: context))
        coffee.caffeineMilligrams = 20
        try context.save()

        let summary = NutritionDaySummary.resolve(day: .today, meals: [meal])
        XCTAssertEqual(meal.items.first?.caffeineMilligramsSnapshot, 150)
        XCTAssertEqual(summary.totals.caffeineMilligrams, 150)
        XCTAssertEqual(summary.totals.unknownCaffeineCount, 0)

        let backup = try BackupDTO.create(from: context, restTimer: 90, darkMode: false, unitSystem: .metric)
        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)
        let restoredFood = try XCTUnwrap(
            restored.fetch(FetchDescriptor<FoodItem>()).first(where: { $0.id == coffee.id })
        )
        let restoredItem = try XCTUnwrap(restored.fetch(FetchDescriptor<LoggedMealItem>()).first)
        XCTAssertEqual(restoredFood.caffeineMilligrams, 20)
        XCTAssertEqual(restoredItem.caffeineMilligramsSnapshot, 150)
    }

    func testMissingCaffeineRemainsUnknownRatherThanZero() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Unknown drink", calories: 10)
        context.insert(food)
        try context.save()
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))
        let summary = NutritionDaySummary.resolve(day: .today, meals: [meal])

        XCTAssertEqual(summary.totals.caffeineMilligrams, 0)
        XCTAssertEqual(summary.totals.unknownCaffeineCount, 1)
    }

    func testCaffeinePresetValuesMatchReferenceAverages() {
        XCTAssertEqual(CaffeineDrinkPreset.espresso.caffeineMilligrams(for: .small), 47)
        XCTAssertEqual(CaffeineDrinkPreset.espresso.caffeineMilligrams(for: .medium), 94)
        XCTAssertEqual(CaffeineDrinkPreset.espresso.caffeineMilligrams(for: .large), 141)

        XCTAssertEqual(CaffeineDrinkPreset.brewed.caffeineMilligrams(for: .small), 95)
        XCTAssertEqual(CaffeineDrinkPreset.brewed.caffeineMilligrams(for: .medium), 145)
        XCTAssertEqual(CaffeineDrinkPreset.brewed.caffeineMilligrams(for: .large), 190)

        XCTAssertEqual(CaffeineDrinkPreset.coldBrew.caffeineMilligrams(for: .small), 120)
        XCTAssertEqual(CaffeineDrinkPreset.coldBrew.caffeineMilligrams(for: .medium), 180)
        XCTAssertEqual(CaffeineDrinkPreset.coldBrew.caffeineMilligrams(for: .large), 240)

        XCTAssertEqual(CaffeineDrinkPreset.latte.caffeineMilligrams(for: .small), 75)
        XCTAssertEqual(CaffeineDrinkPreset.latte.caffeineMilligrams(for: .medium), 150)
        XCTAssertEqual(CaffeineDrinkPreset.latte.caffeineMilligrams(for: .large), 225)

        XCTAssertEqual(TeaPreset.blackTea.caffeineMilligrams(for: .medium), 47)
        XCTAssertEqual(TeaPreset.greenTea.caffeineMilligrams(for: .medium), 28)
        XCTAssertEqual(TeaPreset.matcha.caffeineMilligrams(for: .medium), 70)

        XCTAssertEqual(PreWorkoutIntensity.stimulantFree.estimatedMilligrams, 0)
        XCTAssertEqual(PreWorkoutIntensity.light.estimatedMilligrams, 50)
        XCTAssertEqual(PreWorkoutIntensity.moderate.estimatedMilligrams, 150)
        XCTAssertEqual(PreWorkoutIntensity.high.estimatedMilligrams, 250)
        XCTAssertEqual(PreWorkoutIntensity.veryHigh.estimatedMilligrams, 350)
        XCTAssertNil(PreWorkoutIntensity.custom.estimatedMilligrams)
    }

    // testNPNRoundTripsThroughFoodBackup removed: BackupFieldCoverageTests
    // .testFoodItemRoundTripsEveryPersistedField (GymTrackerTests/Data/
    // BackupFieldCoverageTests.swift) already builds a FoodItem with
    // `npn: "sentinel-npn"`, runs it through the full create → JSON encode →
    // JSON decode → restore path (strictly more rigorous than this test's
    // in-process create→restore, which skipped serialization), and asserts
    // `restored.npn == "sentinel-npn"`. Same field, same assertion, more
    // thorough round trip -- provably redundant.

    func testRepeatingMealCreatesIndependentLoggedIdentifiers() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice", calories: 130, proteinGrams: 3, carbohydrateGrams: 28, fatGrams: 0.3)
        context.insert(food)
        try context.save()
        let source = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))
        let repeated = try XCTUnwrap(NutritionLoggingService.repeatMeal(source, using: context))

        XCTAssertNotEqual(source.id, repeated.id)
        XCTAssertNotEqual(source.items.first?.id, repeated.items.first?.id)
        XCTAssertEqual(source.items.first?.caloriesSnapshot, repeated.items.first?.caloriesSnapshot)
    }

    func testEditingLoggedFoodScalesSnapshotsWithoutReadingEditedFood() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice", calories: 130, proteinGrams: 3, carbohydrateGrams: 28, fatGrams: 0.3)
        context.insert(food)
        try context.save()
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, quantity: 1, using: context))
        food.calories = 999
        try context.save()

        let originalMealID = meal.id
        let originalItemID = try XCTUnwrap(meal.items.first?.id)
        XCTAssertTrue(NutritionLoggingService.updateSingleFoodMeal(meal, quantity: 1.5, slot: .dinner, using: context))
        let replacement = try XCTUnwrap(context.fetch(FetchDescriptor<LoggedMeal>()).first)
        let replacementItem = try XCTUnwrap(replacement.items.first)
        XCTAssertNotEqual(replacement.id, originalMealID)
        XCTAssertNotEqual(replacementItem.id, originalItemID)
        XCTAssertEqual(replacement.slot, .dinner)
        XCTAssertEqual(replacementItem.quantity, 1.5)
        XCTAssertEqual(replacementItem.caloriesSnapshot, 195)
        XCTAssertEqual(replacementItem.proteinGramsSnapshot, 4.5)
    }

    func testLoggedFoodCorrectionRejectsOutOfRangeQuantity() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice", calories: 130)
        context.insert(food)
        try context.save()
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))

        XCTAssertFalse(NutritionLoggingService.updateSingleFoodMeal(meal, quantity: 0.1, slot: .lunch, using: context))
        XCTAssertFalse(NutritionLoggingService.updateSingleFoodMeal(meal, quantity: 21, slot: .lunch, using: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<LoggedMeal>()).count, 1)
        XCTAssertEqual(meal.items.first?.quantity, 1)
    }

    func testDeletingLoggedFoodRemovesItFromDailyTotals() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Apple", calories: 95)
        context.insert(food)
        try context.save()
        let meal = try XCTUnwrap(NutritionLoggingService.log(food: food, using: context))

        XCTAssertTrue(NutritionLoggingService.delete(meal, using: context))
        let meals = try context.fetch(FetchDescriptor<LoggedMeal>())
        XCTAssertTrue(meals.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LoggedMealItem>()).isEmpty)
        XCTAssertEqual(NutritionDaySummary.resolve(day: .today, meals: meals).totals.calories, 0)
    }

    func testReferencedFoodArchivesInsteadOfDeleting() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Egg", calories: 70, proteinGrams: 6, carbohydrateGrams: 0, fatGrams: 5)
        context.insert(food)
        try context.save()
        _ = NutritionLoggingService.log(food: food, using: context)

        try FoodLibraryService.archiveOrDelete(food, using: context)
        XCTAssertTrue(food.isArchived)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodItem>()).contains { $0.id == food.id })
    }

    func testTargetResolutionUsesActivePlanRunScheduleOnLocalDay() throws {
        let day = LocalDay(rawValue: "2026-07-20")
        let trainingTarget = NutritionTarget(
            phase: .bulk,
            effectiveStartDay: LocalDay(rawValue: "2026-07-01"),
            training: NutritionTargetValues(calories: 3_200, protein: 190, carbohydrates: 400, fat: 85),
            rest: NutritionTargetValues(calories: 2_700, protein: 190, carbohydrates: 280, fat: 90)
        )
        let run = PlanRun(sourcePlanID: UUID(), sourcePlanName: "Strength", startDate: .now)
        let scheduled = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 20))!
        let progress = PlanWorkoutProgress(plannedWorkoutID: UUID(), plannedWorkoutName: "Squat", weekIndex: 0, workoutIndex: 0, scheduledDate: scheduled)
        run.workoutProgress = [progress]

        let resolvedTraining = NutritionTargetResolver.resolve(day: day, planRuns: [run], targets: [trainingTarget])
        XCTAssertEqual(resolvedTraining.kind, .training)
        XCTAssertEqual(resolvedTraining.values.calories, 3_200)

        progress.status = .skipped
        let resolvedRest = NutritionTargetResolver.resolve(day: day, planRuns: [run], targets: [trainingTarget])
        XCTAssertEqual(resolvedRest.kind, .rest)
        XCTAssertEqual(resolvedRest.values.calories, 2_700)
    }

    func testTargetRevisionPreservesEarlierEffectiveDays() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let existing = NutritionTarget(
            phase: .maintenance,
            effectiveStartDay: LocalDay(rawValue: "2020-01-01"),
            training: NutritionTargetValues(calories: 2_500, protein: nil, carbohydrates: nil, fat: nil),
            rest: NutritionTargetValues(calories: 2_500, protein: nil, carbohydrates: nil, fat: nil)
        )
        context.insert(existing)
        try context.save()
        let revised = try XCTUnwrap(NutritionTargetService.revise(
            existing,
            phase: .bulk,
            requestedStartDay: .today,
            requestedEndDay: nil,
            training: NutritionTargetValues(calories: 3_000, protein: nil, carbohydrates: nil, fat: nil),
            rest: .empty,
            using: context
        ))
        let oldDay = NutritionTargetResolver.resolve(day: LocalDay(rawValue: "2020-07-01"), planRuns: [], targets: [existing, revised])
        XCTAssertEqual(oldDay.values.calories, 2_500)
        XCTAssertGreaterThan(revised.effectiveStartDayKey, LocalDay.today.rawValue)
        XCTAssertLessThan(try XCTUnwrap(existing.effectiveEndDayKey), revised.effectiveStartDayKey)
    }

    func testEditingFutureTargetDoesNotCreateAnInvalidHistoricalRange() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let future = LocalDay(rawValue: "2099-01-01")
        let target = NutritionTarget(
            phase: .maintenance,
            effectiveStartDay: future,
            training: NutritionTargetValues(calories: 2_500, protein: nil, carbohydrates: nil, fat: nil),
            rest: .empty
        )
        context.insert(target)
        try context.save()

        let updated = try XCTUnwrap(NutritionTargetService.revise(
            target,
            phase: .cut,
            requestedStartDay: future,
            requestedEndDay: nil,
            training: NutritionTargetValues(calories: 2_100, protein: nil, carbohydrates: nil, fat: nil),
            rest: .empty,
            using: context
        ))
        XCTAssertEqual(updated.id, target.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NutritionTarget>()).count, 1)
        XCTAssertNil(updated.effectiveEndDayKey)
        XCTAssertEqual(updated.trainingCalories, 2_100)
    }

    func testRecipeRevisionAndBackupKeepConsumptionHistoryStable() throws {
        let source = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Chicken", calories: 165, proteinGrams: 31, carbohydrateGrams: 0, fatGrams: 3.6)
        food.servings = [FoodServing(name: "150 g", amount: 150, unit: .grams, equivalentReferenceAmount: 150)]
        source.insert(food)
        let recipe = MealTemplate(name: "Chicken bowl")
        recipe.items = [MealTemplateItem(food: food, orderIndex: 0, servingID: food.servings.first?.id, quantity: 1)]
        source.insert(recipe)
        try source.save()

        let logged = try XCTUnwrap(NutritionLoggingService.log(template: recipe, using: source))
        let revision = try XCTUnwrap(MealTemplateService.revise(recipe, name: "Chicken bowl", preparationState: .cooked, finalCookedWeightGrams: 450, photoIdentifier: nil, items: [(food, food.servings.first?.id, 2)], using: source))
        XCTAssertFalse(recipe.isCurrent)
        XCTAssertEqual(revision.version, 2)
        XCTAssertEqual(try XCTUnwrap(logged.items.first?.proteinGramsSnapshot), 46.5, accuracy: 0.001)

        let target = NutritionTarget(phase: .maintenance, training: NutritionTargetValues(calories: 3_000, protein: 180, carbohydrates: 350, fat: 90), rest: NutritionTargetValues(calories: 2_700, protein: 180, carbohydrates: 280, fat: 90))
        source.insert(target)
        try source.save()
        let backup = try BackupDTO.create(from: source, restTimer: 90, darkMode: false, unitSystem: .metric)
        XCTAssertEqual(backup.version, BackupDTO.currentVersion)
        XCTAssertEqual(backup.foods.count, 1)
        XCTAssertEqual(backup.mealTemplates.count, 2)
        XCTAssertEqual(backup.loggedMeals.count, 1)
        XCTAssertEqual(backup.nutritionTargets.count, 1)

        let restored = try GymTrackerTestStore.makeInMemoryContext()
        try backup.restore(to: restored)
        let restoredMeal = try XCTUnwrap(restored.fetch(FetchDescriptor<LoggedMeal>()).first)
        XCTAssertEqual(try XCTUnwrap(restoredMeal.items.first?.proteinGramsSnapshot), 46.5, accuracy: 0.001)
        XCTAssertEqual(
            try restored.fetch(FetchDescriptor<MealTemplate>()).filter {
                $0.name == "Chicken bowl" && $0.isCurrent
            }.count,
            1
        )
        XCTAssertEqual(try restored.fetch(FetchDescriptor<NutritionTarget>()).count, 1)
    }

    func testInvalidNutritionBackupDoesNotReplaceExistingFood() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let sentinel = FoodItem(name: "Keep this food", calories: 100)
        context.insert(sentinel)
        try context.save()
        let invalid = BackupDTO(
            version: BackupDTO.currentVersion,
            preferences: PreferencesDTO(darkMode: false, restTimer: 90, unitSystem: UnitSystem.metric.rawValue),
            exercises: [],
            templates: [],
            collections: [],
            workouts: [],
            foods: [
                FoodItemDTO(
                    id: UUID().uuidString,
                    name: "Invalid food",
                    referenceAmount: 0,
                    referenceUnit: NutritionServingUnit.grams.rawValue,
                    calories: 100,
                    proteinGrams: nil,
                    carbohydrateGrams: nil,
                    fatGrams: nil,
                    sourceKind: FoodSourceKind.userCreated.rawValue,
                    confidence: FoodConfidence.userProvided.rawValue,
                    preparationState: FoodPreparationState.raw.rawValue,
                    isFavorite: false,
                    isArchived: false,
                    createdAt: .now,
                    updatedAt: .now,
                    servings: []
                )
            ]
        )

        XCTAssertThrowsError(try invalid.restore(to: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodItem>()).contains { $0.id == sentinel.id })
    }

    func testSeedingPopulatesTheCurrentCatalogIdempotently() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        NutritionSeedData.seedIfNeeded(using: context)

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let templates = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertFalse(foods.isEmpty)
        XCTAssertFalse(templates.isEmpty)

        // Seeding again should be idempotent
        NutritionSeedData.seedIfNeeded(using: context)
        let reFetchedFoods = try context.fetch(FetchDescriptor<FoodItem>())
        let reFetchedTemplates = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(reFetchedFoods.count, foods.count)
        XCTAssertEqual(reFetchedTemplates.count, templates.count)
    }

    func testSeededRecipesResolveEveryCatalogIngredient() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        try NutritionSeedData.stage(using: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        let expected: [(String, [String])] = [
            ("Chicken, Rice & Broccoli Bowl", ["Chicken breast", "White rice", "Broccoli"]),
            ("High-Protein Oatmeal Bowl", ["Rolled oats", "Whey protein powder", "Bananas", "Peanut butter"]),
            ("Steak & Sweet Potato Recovery Meal", ["Beef sirloin", "Sweet potatoes", "Green beans"]),
            ("Greek Yogurt & Berry Bowl", ["Greek yogurt", "Blueberries", "Chia seeds", "Whey protein powder"]),
            ("Egg White & Avocado Wrap", ["Whole-wheat tortillas", "Egg whites", "Whole eggs", "Avocado"]),
            ("Salmon & Quinoa Bowl", ["Fresh salmon", "Quinoa", "Spinach"])
        ]
        let templates = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(templates.filter(\.isCurrent).count, expected.count)
        for (name, foodNames) in expected {
            let template = try XCTUnwrap(templates.first { $0.name == name && $0.isCurrent })
            XCTAssertEqual(template.orderedItems.map(\.food.name), foodNames)
        }
    }

    func testSeedingRepairsIncompleteBundledRecipesWithoutTouchingRevisions() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        try NutritionSeedData.stage(using: context, registry: SystemSeedRegistry(context: context))
        try context.save()

        let chickenBowl = try XCTUnwrap(
            try context.fetch(FetchDescriptor<MealTemplate>()).first { $0.name == "Chicken, Rice & Broccoli Bowl" && $0.isCurrent }
        )
        let leftover = try XCTUnwrap(chickenBowl.orderedItems.first)
        for item in chickenBowl.items where item.id != leftover.id {
            context.delete(item)
        }
        try context.save()
        XCTAssertEqual(chickenBowl.orderedItems.count, 1)

        try NutritionSeedData.stage(using: context, registry: SystemSeedRegistry(context: context))
        try context.save()
        XCTAssertEqual(
            chickenBowl.orderedItems.map(\.food.name),
            ["Chicken breast", "White rice", "Broccoli"]
        )

        let firstIngredient = try XCTUnwrap(chickenBowl.orderedItems.first)
        let revised = try XCTUnwrap(
            MealTemplateService.revise(
                chickenBowl,
                name: chickenBowl.name,
                preparationState: .cooked,
                finalCookedWeightGrams: nil,
                photoIdentifier: nil,
                items: [(firstIngredient.food, firstIngredient.servingID, 2)],
                using: context
            )
        )
        try NutritionSeedData.stage(using: context, registry: SystemSeedRegistry(context: context))
        try context.save()
        XCTAssertEqual(revised.orderedItems.count, 1)
        XCTAssertEqual(revised.orderedItems.first?.quantity, 2)
    }
}
