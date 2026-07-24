import SwiftData
import UIKit
import XCTest
@testable import GymTracker

@MainActor
final class RecipePhotoAndLoggingTests: XCTestCase {
    // MARK: - Photo store

    func testCompressionReducesLargeImageToThumbnail() throws {
        let large = Self.solidImage(size: CGSize(width: 2000, height: 1500))
        let data = try XCTUnwrap(RecipePhotoStore.compressedData(from: large))
        let restored = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(restored.size.width, restored.size.height), RecipePhotoStore.maxDimension + 1)
    }

    func testStoreLoadDeleteLifecycle() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let image = Self.solidImage(size: CGSize(width: 128, height: 128))
        let identifier = try XCTUnwrap(RecipePhotoStore.store(image))
        XCTAssertNotNil(RecipePhotoStore.loadImage(identifier))

        // No MealTemplate references it, so it is removed.
        RecipePhotoStore.deleteIfUnreferenced(identifier, in: context)
        XCTAssertNil(RecipePhotoStore.loadImage(identifier))
    }

    func testSharedPhotoSurvivesWhileAnyRevisionReferencesIt() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let image = Self.solidImage(size: CGSize(width: 64, height: 64))
        let identifier = try XCTUnwrap(RecipePhotoStore.store(image))
        let keeper = MealTemplate(name: "With photo", photoIdentifier: identifier)
        context.insert(keeper)
        try context.save()

        RecipePhotoStore.deleteIfUnreferenced(identifier, in: context)
        XCTAssertNotNil(RecipePhotoStore.loadImage(identifier), "A still-referenced photo must not be deleted")

        // Clean up the file once nothing references it.
        keeper.photoIdentifier = nil
        try context.save()
        RecipePhotoStore.deleteIfUnreferenced(identifier, in: context)
        XCTAssertNil(RecipePhotoStore.loadImage(identifier))
    }

    // MARK: - Fractional recipe logging + totals

    func testWholeFractionAndGramLoggingScaleConsistently() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Rice", calories: 130, proteinGrams: 2.4, carbohydrateGrams: 28, fatGrams: 0.3)
        context.insert(food)
        let recipe = MealTemplate(name: "Rice bowl", finalCookedWeightGrams: 400)
        recipe.items = [MealTemplateItem(food: food, orderIndex: 0, servingID: nil, quantity: 4)] // 4 × 100 g reference
        context.insert(recipe)
        try context.save()

        let whole = try XCTUnwrap(NutritionLoggingService.log(template: recipe, fraction: 1, using: context))
        let half = try XCTUnwrap(NutritionLoggingService.log(template: recipe, fraction: 0.5, using: context))
        // 200 g of a 400 g yield is exactly half.
        let byGrams = try XCTUnwrap(NutritionLoggingService.log(template: recipe, fraction: 200.0 / 400.0, using: context))

        let wholeCals = try XCTUnwrap(whole.items.first?.caloriesSnapshot)
        let halfCals = try XCTUnwrap(half.items.first?.caloriesSnapshot)
        let gramCals = try XCTUnwrap(byGrams.items.first?.caloriesSnapshot)
        XCTAssertEqual(wholeCals, 130 * 4, accuracy: 0.001)
        XCTAssertEqual(halfCals, wholeCals / 2, accuracy: 0.001)
        XCTAssertEqual(gramCals, halfCals, accuracy: 0.001)
    }

    func testDerivedTotalsMatchWholeRecipeLogging() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Beef", calories: 250, proteinGrams: 26, carbohydrateGrams: 0, fatGrams: 15)
        context.insert(food)
        let recipe = MealTemplate(name: "Beef plate")
        recipe.items = [MealTemplateItem(food: food, orderIndex: 0, servingID: nil, quantity: 2)]
        context.insert(recipe)
        try context.save()

        let totals = MealTemplateNutrition.totals(for: recipe)
        let logged = try XCTUnwrap(NutritionLoggingService.log(template: recipe, using: context))
        XCTAssertEqual(totals.calories, try XCTUnwrap(logged.items.first?.caloriesSnapshot), accuracy: 0.001)
        XCTAssertEqual(totals.protein, try XCTUnwrap(logged.items.first?.proteinGramsSnapshot), accuracy: 0.001)
    }

    func testUnknownMacroStaysUnknownInTotals() throws {
        let context = try GymTrackerTestStore.makeInMemoryContext()
        let food = FoodItem(name: "Mystery", calories: nil, proteinGrams: 10)
        context.insert(food)
        let recipe = MealTemplate(name: "Mystery meal")
        recipe.items = [MealTemplateItem(food: food, orderIndex: 0, servingID: nil, quantity: 1)]
        context.insert(recipe)
        try context.save()

        let totals = MealTemplateNutrition.totals(for: recipe)
        XCTAssertEqual(totals.unknownCaloriesCount, 1, "Missing calories must remain unknown, not zero")
        XCTAssertEqual(totals.protein, 10, accuracy: 0.001)
    }

    private static func solidImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
